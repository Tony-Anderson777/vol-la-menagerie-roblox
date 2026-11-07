-- PlayerData : charge et sauvegarde la progression des joueurs (pièces, créatures).
-- (ModuleScript, à placer dans ServerScriptService, nommé "PlayerData")
--
-- Les autres scripts ne touchent jamais directement aux DataStores :
-- ils lisent et modifient la table renvoyée par PlayerData.get(player).
-- Ce module s'occupe de sauvegarder automatiquement.
--
-- Protection "verrou de session" : un seul serveur à la fois peut modifier les
-- données d'un joueur. Ça évite la duplication de créatures si un joueur
-- change de serveur très vite.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local STORE_NAME = "VoleLaMenagerie_v1"
local AUTOSAVE_INTERVAL = 60 -- secondes
local LOCK_TIMEOUT = 300 -- un verrou plus vieux que ça est considéré comme abandonné
local CURRENT_VERSION = 1
local MAX_RECEIPTS = 50
local CREDIT_RECEIPT_LIFETIME = 90 * 24 * 3600 -- 90 jours

local JOB_ID = game.JobId
if JOB_ID == "" then
	JOB_ID = "studio-" .. tostring(math.random(1, 1000000000))
end

local function newDefaultData()
	return {
		version = CURRENT_VERSION,
		coins = Config.STARTING_COINS,
		creatures = {}, -- ["1"] = { id = "grenouille", mut = "normal", uid = "..." }
		receipts = {}, -- achats Robux déjà livrés (évite de donner 2 fois)
		pendingCash = 0, -- argent gagné dans la base mais pas encore récupéré sur la plaque
		-- Vols (voir commitStolenCreature dans GameServer). Clé = identifiant de transaction,
		-- différent de l'identifiant de la créature, car une créature peut être volée plusieurs fois.
		debits = {}, -- créatures qu'on m'a volées, transfert pas encore confirmé : [txId] = { to, id, mut, uid, at }
		credits = {}, -- reçus des créatures que j'ai volées : [txId] = date (enregistré AVEC la créature)
		returned = {}, -- créatures à me rendre (vol jamais crédité au voleur)
	}
end

-- Mises à jour du format des données (pour plus tard).
-- Exemple : [1] = function(data) data.gems = 0 return data end
local MIGRATIONS = {}

local function migrate(data)
	data.version = data.version or 1
	while data.version < CURRENT_VERSION do
		local step = MIGRATIONS[data.version]
		if not step then
			error("Migration manquante depuis la version " .. tostring(data.version))
		end
		data = step(data)
		data.version += 1
	end
	-- Ajoute les champs qui manqueraient
	local defaults = newDefaultData()
	for key, value in defaults do
		if data[key] == nil then
			data[key] = value
		end
	end
	-- Ancien format (jamais publié) : "outgoing" remplacé par "debits"
	if data.outgoing then
		for uid, transfer in data.outgoing do
			data.debits[uid] = { to = transfer.to, id = transfer.id, mut = transfer.mut, uid = uid, at = os.time() }
		end
		data.outgoing = nil
	end
	-- On oublie les vieux reçus de vol (le volé a eu largement le temps de revenir)
	for txId, time in data.credits do
		if os.time() - time > CREDIT_RECEIPT_LIFETIME then
			data.credits[txId] = nil
		end
	end
	-- Chaque créature a un identifiant unique (sert à suivre les vols)
	for _, creature in data.creatures do
		if not creature.uid then
			creature.uid = HttpService:GenerateGUID(false)
		end
	end
	return data
end

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[PlayerData] DataStore indisponible : " .. tostring(result))
	end
end

-- Réessaie une fonction plusieurs fois en attendant de plus en plus longtemps.
local function withRetry(attempts, fn)
	local delaySeconds = 1
	local lastError = nil
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = result
		warn(string.format("[PlayerData] essai %d/%d raté : %s", attempt, attempts, tostring(result)))
		if attempt < attempts then
			task.wait(delaySeconds)
			delaySeconds = math.min(delaySeconds * 2, 16)
		end
	end
	return false, lastError
end

local PlayerData = {}

local profiles = {} -- [player] = { data = {...}, canSave = bool, released = bool }
local activeWrites = 0

local function keyFor(userId)
	return "joueur_" .. tostring(userId)
end

-- Libère juste le verrou (quand le joueur part pendant son chargement).
local function releaseLockOnly(key)
	withRetry(2, function()
		store:UpdateAsync(key, function(old)
			if old and old.lock and old.lock.jobId == JOB_ID then
				old.lock = nil
				return old
			end
			return nil
		end)
	end)
end

-- Vérifie les vols dont le transfert a pu être interrompu (voir commitStolenCreature dans GameServer).
-- On regarde le REÇU du voleur (credits[txId]), jamais son inventaire : il a pu revendre
-- ou se faire voler la créature depuis. Cette vérification peut tourner plusieurs fois sans effet.
--  * reçu présent            -> le voleur a bien été crédité : on efface la note ;
--  * voleur encore en jeu    -> on ne sait pas encore : on revérifiera au prochain chargement ;
--  * pas de reçu, voleur parti -> il ne l'a jamais reçue : la créature revient au volé.
local function resolveDebits(data)
	for txId, debit in data.debits do
		-- Le voleur est peut-être sur ce serveur, avec son reçu encore en mémoire
		local localThief = nil
		for _, profile in profiles do
			if profile.userId == debit.to then
				localThief = profile
			end
		end

		local received, thiefActive = false, false
		local ok = true
		if localThief then
			received = localThief.data.credits[txId] ~= nil
			thiefActive = true
		else
			local stored
			ok, stored = withRetry(2, function()
				return store:GetAsync(keyFor(debit.to))
			end)
			if ok then
				local thiefData = stored and stored.data
				received = thiefData ~= nil and thiefData.credits ~= nil and thiefData.credits[txId] ~= nil
				local thiefLock = stored and stored.lock
				thiefActive = thiefLock ~= nil and os.time() - thiefLock.time < LOCK_TIMEOUT
			end
		end

		if ok then
			if received then
				data.debits[txId] = nil
			elseif not thiefActive then
				table.insert(data.returned, { id = debit.id, mut = debit.mut, uid = debit.uid })
				data.debits[txId] = nil
			end
		end
	end
end

-- Charge les données. Renvoie la table de données, ou nil si le joueur a été expulsé.
function PlayerData.load(player)
	if not store then
		profiles[player] = { data = migrate(newDefaultData()), canSave = false, released = false, userId = player.UserId }
		return profiles[player].data
	end

	local key = keyFor(player.UserId)
	for attempt = 1, 5 do
		local lockedByOther = false
		local ok, stored = withRetry(3, function()
			return store:UpdateAsync(key, function(old)
				lockedByOther = false
				old = old or { data = newDefaultData() }
				local lock = old.lock
				-- (dans Studio on ignore le verrou, sinon un test arrêté brutalement bloquerait le suivant)
				local isOtherServer = lock and lock.jobId ~= JOB_ID and not RunService:IsStudio()
				if isOtherServer and os.time() - lock.time < LOCK_TIMEOUT then
					lockedByOther = true
					return nil -- on n'écrit rien : un autre serveur utilise ces données
				end
				old.lock = { jobId = JOB_ID, time = os.time() }
				return old
			end)
		end)

		if not player.Parent then
			-- Le joueur est parti pendant le chargement : on rend le verrou tout de suite
			if ok and stored and not lockedByOther then
				releaseLockOnly(key)
			end
			return nil
		end

		if not ok then
			if RunService:IsStudio() then
				-- Dans Studio sans "Accès aux services API", on joue quand même, sans sauvegarde.
				warn("[PlayerData] Pas de sauvegarde dans ce test Studio (active l'accès aux services API).")
				profiles[player] = { data = migrate(newDefaultData()), canSave = false, released = false, userId = player.UserId }
				return profiles[player].data
			end
			player:Kick("Impossible de charger ta progression. Reviens dans un instant !")
			return nil
		end

		if not lockedByOther and stored then
			local okMigrate, data = pcall(migrate, stored.data or newDefaultData())
			if not okMigrate then
				releaseLockOnly(key)
				player:Kick("Erreur de données. Reviens dans un instant !")
				return nil
			end
			resolveDebits(data)
			if not player.Parent then
				releaseLockOnly(key)
				return nil
			end
			profiles[player] = { data = data, canSave = true, released = false, userId = player.UserId }
			return data
		end

		-- Un autre serveur termine peut-être sa sauvegarde : on attend un peu.
		task.wait(5)
	end

	player:Kick("Ta progression est encore en train de se sauvegarder. Reviens dans quelques secondes !")
	return nil
end

function PlayerData.get(player)
	local profile = profiles[player]
	return profile and profile.data
end

-- Attend la fin de la sauvegarde finale et renvoie si elle a réussi.
local function waitForFinal(profile)
	while not profile.finished do
		task.wait(0.1)
	end
	return profile.finalOk == true
end

-- Écrit les données. Les écritures d'un même joueur passent une par une, dans l'ordre,
-- et plus rien n'est écrit après la sauvegarde finale (celle qui libère le verrou).
-- Renvoie true seulement si les données sont vraiment enregistrées.
-- Si le joueur est en train de partir, on attend sa sauvegarde finale et on renvoie
-- SON résultat (elle contient les mêmes données, puisqu'elle part de la même table).
local function write(profile, releaseLock)
	if not profile.canSave or not store then
		return true
	end
	if not releaseLock and profile.released then
		return waitForFinal(profile)
	end
	activeWrites += 1
	while profile.writing do
		task.wait(0.1)
	end
	if not releaseLock and profile.released then
		activeWrites -= 1
		return waitForFinal(profile)
	end
	if releaseLock and profile.finished then
		activeWrites -= 1
		return profile.finalOk == true
	end
	profile.writing = true

	local aborted = false
	local ok = withRetry(3, function()
		store:UpdateAsync(keyFor(profile.userId), function(old)
			aborted = false
			if old and old.lock and old.lock.jobId ~= JOB_ID and not RunService:IsStudio() then
				aborted = true
				return nil -- un autre serveur a pris la main : on n'écrase rien
			end
			local newLock = nil
			if not releaseLock then
				newLock = { jobId = JOB_ID, time = os.time() }
			end
			return { data = profile.data, lock = newLock }
		end)
	end)
	local success = ok and not aborted

	if releaseLock then
		profile.finalOk = success
		profile.finished = true
	end
	profile.writing = false
	activeWrites -= 1
	if aborted then
		warn("[PlayerData] Sauvegarde refusée : un autre serveur a pris les données de " .. profile.userId)
	end
	return success
end

-- Le "profil" d'un joueur : garde ses données même après son départ, le temps de finir
-- une opération en cours (utilisé par le vol). Ne pas le garder plus longtemps.
function PlayerData.getProfile(player)
	return profiles[player]
end

function PlayerData.saveProfile(profile)
	return write(profile, false)
end

function PlayerData.save(player)
	local profile = profiles[player]
	if not profile then
		return false
	end
	return write(profile, false)
end

-- Sauvegarde une dernière fois et libère le verrou (quand le joueur part).
function PlayerData.release(player)
	local profile = profiles[player]
	if not profile or profile.released then
		return
	end
	profile.released = true
	write(profile, true)
	if profiles[player] == profile then
		profiles[player] = nil
	end
end

-- Achats Robux déjà livrés
function PlayerData.hasReceipt(player, purchaseId)
	local data = PlayerData.get(player)
	return data ~= nil and table.find(data.receipts, purchaseId) ~= nil
end

function PlayerData.addReceipt(player, purchaseId)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	table.insert(data.receipts, purchaseId)
	while #data.receipts > MAX_RECEIPTS do
		table.remove(data.receipts, 1)
	end
end

-- À appeler une fois au démarrage du serveur.
function PlayerData.start()
	-- Sauvegarde automatique
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			local toSave = {}
			for player in profiles do
				table.insert(toSave, player)
			end
			for _, player in toSave do
				task.spawn(PlayerData.save, player)
				task.wait(0.5) -- on étale les sauvegardes
			end
		end
	end)

	-- Quand le serveur s'arrête : on sauvegarde tout le monde.
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(PlayerData.release, player)
		end
		local started = os.clock()
		task.wait(0.1)
		while activeWrites > 0 and os.clock() - started < 25 do
			task.wait(0.2)
		end
	end)
end

return PlayerData
