-- PlayerDataTests : tests automatiques de la sauvegarde et du vol (Script dans ServerScriptService).
--
-- Ils ne tournent QUE dans Studio, et seulement si tu l'as demandé :
--   1. Dans l'Explorer, clique sur Workspace.
--   2. Dans Propriétés, tout en bas : "Attributs" -> "+" -> nom RunTests, type boolean, coché.
--   3. Lance le jeu (F5) et regarde la fenêtre Sortie : chaque test affiche ✅ ou ❌.
--
-- Chaque test utilise une copie neuve de PlayerData branchée sur un faux DataStore
-- (ServerStorage > Tests > FakeDataStore) et une fausse horloge : le vrai jeu n'est pas touché.

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

if not RunService:IsStudio() or Workspace:GetAttribute("RunTests") ~= true then
	return
end

local FakeDataStore = require(ServerStorage:WaitForChild("Tests"):WaitForChild("FakeDataStore"))
local PlayerDataModule = ServerScriptService:WaitForChild("PlayerData")

local DAY = 24 * 3600

---------------------------------------------------------------------
-- Petits outils
---------------------------------------------------------------------
local function setup()
	local copy = PlayerDataModule:Clone()
	copy.Name = "PlayerData_Test"
	copy.Parent = ServerStorage
	local PlayerData = require(copy)
	local store = FakeDataStore.new()
	local clock = { t = 1000000000 }
	PlayerData._setTestDeps({
		store = store,
		now = function()
			return clock.t
		end,
		wait = function()
			task.wait()
		end,
		isStudio = function()
			return false -- on teste le vrai comportement (verrous compris)
		end,
	})
	return PlayerData, store, clock
end

local function fakePlayer(userId)
	return {
		UserId = userId,
		Parent = Workspace, -- "toujours dans le jeu"
		Kick = function() end,
	}
end

local function victimDataWithDebit(txId, thiefId, at)
	return {
		debits = { [txId] = { to = thiefId, id = "grenouille", mut = "normal", uid = "uid-1", at = at } },
		returned = {},
	}
end

local function expect(condition, message)
	if not condition then
		error(message, 2)
	end
end

local tests = {}
local function test(name, fn)
	table.insert(tests, { name = name, fn = fn })
end

---------------------------------------------------------------------
-- Les tests
---------------------------------------------------------------------

test("Reçu seulement en mémoire chez un voleur sur ce serveur : le débit est gardé", function()
	local PlayerData, store, clock = setup()
	local thief = fakePlayer(2)
	PlayerData.load(thief)
	local thiefProfile = PlayerData.getProfile(thief)
	thiefProfile.data.credits.tx1 = { from = 1, at = clock.t }

	store.failUpdates = true
	expect(PlayerData.saveProfile(thiefProfile) == false, "la sauvegarde aurait dû échouer")

	local victimData = victimDataWithDebit("tx1", 2, clock.t)
	PlayerData._resolveDebits(victimData)
	expect(victimData.debits.tx1 ~= nil, "le débit a été effacé alors que le reçu n'est pas enregistré")
	expect(#victimData.returned == 0, "la créature a été rendue alors que le voleur est encore là")

	store.failUpdates = false
	expect(PlayerData.saveProfile(thiefProfile) == true, "la sauvegarde aurait dû réussir")
	PlayerData._resolveDebits(victimData)
	expect(victimData.debits.tx1 == nil, "le débit aurait dû être effacé après l'enregistrement du reçu")
	expect(#victimData.returned == 0, "rien ne doit être rendu")
end)

test("Voleur parti avec reçu enregistré, créature revendue : rien n'est rendu (2 vérifications)", function()
	local PlayerData, store, clock = setup()
	store:seed(PlayerData._keyFor(2), { data = { creatures = {}, credits = { tx1 = { from = 1, at = clock.t } } } })
	local victimData = victimDataWithDebit("tx1", 2, clock.t)
	PlayerData._resolveDebits(victimData)
	PlayerData._resolveDebits(victimData)
	expect(victimData.debits.tx1 == nil, "le débit aurait dû être effacé")
	expect(#victimData.returned == 0, "la créature ne doit pas être rendue")
end)

test("Voleur parti sans reçu : la créature est rendue une seule fois", function()
	local PlayerData, store, clock = setup()
	store:seed(PlayerData._keyFor(2), { data = { creatures = {}, credits = {} } })
	local victimData = victimDataWithDebit("tx1", 2, clock.t)
	PlayerData._resolveDebits(victimData)
	PlayerData._resolveDebits(victimData)
	expect(#victimData.returned == 1, "la créature aurait dû être rendue exactement une fois")
	expect(victimData.debits.tx1 == nil, "le débit aurait dû être effacé")
end)

test("Voleur en jeu sur un autre serveur sans reçu : on attend, puis on rend si son verrou expire", function()
	local PlayerData, store, clock = setup()
	store:seed(PlayerData._keyFor(2), {
		data = { creatures = {}, credits = {} },
		lock = { jobId = "autre-serveur", time = clock.t },
	})
	local victimData = victimDataWithDebit("tx1", 2, clock.t)
	PlayerData._resolveDebits(victimData)
	expect(victimData.debits.tx1 ~= nil and #victimData.returned == 0, "il fallait attendre")
	clock.t += 301 -- le verrou du voleur est maintenant abandonné (serveur planté)
	PlayerData._resolveDebits(victimData)
	expect(#victimData.returned == 1, "la créature aurait dû être rendue")
end)

test("Vieux reçu : gardé tant que le volé a encore le débit, nettoyé ensuite", function()
	local PlayerData, store, clock = setup()
	local thiefData = { credits = {
		old = { from = 1, at = clock.t },
		recent = { from = 1, at = clock.t + 100 * DAY },
	} }
	store:seed(PlayerData._keyFor(1), { data = { debits = { old = { to = 2 } } } })
	clock.t += 100 * DAY

	PlayerData._pruneCredits(thiefData)
	expect(thiefData.credits.old ~= nil, "le reçu a été supprimé alors que le volé en a encore besoin")

	store:seed(PlayerData._keyFor(1), { data = { debits = {} } })
	PlayerData._pruneCredits(thiefData)
	PlayerData._pruneCredits(thiefData)
	expect(thiefData.credits.old == nil, "le vieux reçu inutile aurait dû être nettoyé")
	expect(thiefData.credits.recent ~= nil, "un reçu récent ne doit pas être vérifié")
end)

test("Panne pendant le nettoyage des reçus : on ne supprime rien", function()
	local PlayerData, store, clock = setup()
	local thiefData = { credits = { old = { from = 1, at = clock.t } } }
	clock.t += 100 * DAY
	store.failGets = true
	PlayerData._pruneCredits(thiefData)
	expect(thiefData.credits.old ~= nil, "le reçu ne doit pas être supprimé sans preuve")
end)

test("Joueur qui part avec une sauvegarde finale ratée : saveProfile renvoie false", function()
	local PlayerData, store = setup()
	local victim = fakePlayer(1)
	PlayerData.load(victim)
	local profile = PlayerData.getProfile(victim)
	store.failUpdates = true
	task.spawn(PlayerData.release, victim)
	expect(PlayerData.get(victim) ~= nil or profile.released, "la libération aurait dû commencer")
	expect(PlayerData.saveProfile(profile) == false, "un départ raté ne doit jamais compter comme sauvegardé")
end)

test("Joueur qui part avec une sauvegarde finale réussie : saveProfile renvoie true", function()
	local PlayerData = setup()
	local victim = fakePlayer(1)
	PlayerData.load(victim)
	local profile = PlayerData.getProfile(victim)
	task.spawn(PlayerData.release, victim)
	expect(PlayerData.saveProfile(profile) == true, "la sauvegarde finale a réussi")
end)

test("Aucune écriture après la sauvegarde finale", function()
	local PlayerData, store = setup()
	local player = fakePlayer(1)
	PlayerData.load(player)
	local profile = PlayerData.getProfile(player)
	PlayerData.release(player)
	profile.data.coins = 999
	PlayerData.saveProfile(profile)
	local stored = store:peek(PlayerData._keyFor(1))
	expect(stored.lock == nil, "le verrou ne doit pas revenir après le départ")
	expect(stored.data.coins ~= 999, "rien ne doit être écrit après la sauvegarde finale")
end)

test("Une sauvegarde réussie plus tard confirme le reçu (onSaved)", function()
	local PlayerData, store, clock = setup()
	local thief = fakePlayer(2)
	PlayerData.load(thief)
	local profile = PlayerData.getProfile(thief)
	local confirmed = false
	PlayerData.onSaved(function(savedProfile)
		if savedProfile == profile and savedProfile.persistedCredits.tx1 then
			confirmed = true
		end
	end)
	profile.data.credits.tx1 = { from = 1, at = clock.t }

	store.failUpdates = true
	for _ = 1, 5 do
		PlayerData.saveProfile(profile)
	end
	task.wait()
	expect(not confirmed, "rien ne doit être confirmé tant que les sauvegardes échouent")

	store.failUpdates = false
	PlayerData.saveProfile(profile) -- comme une autosave plus tard
	task.wait()
	expect(confirmed, "la sauvegarde réussie aurait dû confirmer le reçu")
end)

---------------------------------------------------------------------
-- Lancement
---------------------------------------------------------------------
task.spawn(function()
	print("🧪 Tests PlayerData : " .. #tests .. " tests")
	local passed = 0
	for _, entry in tests do
		local ok, err = pcall(entry.fn)
		if ok then
			passed += 1
			print("  ✅ " .. entry.name)
		else
			warn("  ❌ " .. entry.name .. " : " .. tostring(err))
		end
	end
	local summary = string.format("🧪 Résultat : %d / %d réussis", passed, #tests)
	if passed == #tests then
		print(summary)
	else
		warn(summary)
	end
end)
