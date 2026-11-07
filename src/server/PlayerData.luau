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
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local STORE_NAME = "VoleLaMenagerie_v1"
local AUTOSAVE_INTERVAL = 60 -- secondes
local LOCK_TIMEOUT = 300 -- un verrou plus vieux que ça est considéré comme abandonné
local CURRENT_VERSION = 1
local MAX_RECEIPTS = 50

local JOB_ID = game.JobId
if JOB_ID == "" then
	JOB_ID = "studio-" .. tostring(math.random(1, 1000000000))
end

local function newDefaultData()
	return {
		version = CURRENT_VERSION,
		coins = Config.STARTING_COINS,
		creatures = {}, -- ["1"] = { id = "grenouille", mut = "normal" }
		receipts = {}, -- achats Robux déjà livrés (évite de donner 2 fois)
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

-- Charge les données. Renvoie la table de données, ou nil si le joueur a été expulsé.
function PlayerData.load(player)
	if not store then
		profiles[player] = { data = newDefaultData(), canSave = false, released = false }
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
			return nil -- le joueur est parti pendant le chargement
		end

		if not ok then
			if RunService:IsStudio() then
				-- Dans Studio sans "Accès aux services API", on joue quand même, sans sauvegarde.
				warn("[PlayerData] Pas de sauvegarde dans ce test Studio (active l'accès aux services API).")
				profiles[player] = { data = newDefaultData(), canSave = false, released = false }
				return profiles[player].data
			end
			player:Kick("Impossible de charger ta progression. Reviens dans un instant !")
			return nil
		end

		if not lockedByOther and stored then
			local okMigrate, data = pcall(migrate, stored.data or newDefaultData())
			if not okMigrate then
				player:Kick("Erreur de données. Reviens dans un instant !")
				return nil
			end
			profiles[player] = { data = data, canSave = true, released = false }
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

local function write(player, releaseLock)
	local profile = profiles[player]
	if not profile or not profile.canSave or not store then
		return true
	end
	activeWrites += 1
	local key = keyFor(player.UserId)
	local ok = withRetry(3, function()
		store:UpdateAsync(key, function(old)
			if old and old.lock and old.lock.jobId ~= JOB_ID and not RunService:IsStudio() then
				return nil -- un autre serveur a pris la main : on n'écrase rien
			end
			local newLock = nil
			if not releaseLock then
				newLock = { jobId = JOB_ID, time = os.time() }
			end
			return { data = profile.data, lock = newLock }
		end)
	end)
	activeWrites -= 1
	return ok
end

function PlayerData.save(player)
	return write(player, false)
end

-- Sauvegarde une dernière fois et libère le verrou (quand le joueur part).
function PlayerData.release(player)
	local profile = profiles[player]
	if not profile or profile.released then
		return
	end
	profile.released = true
	write(player, true)
	profiles[player] = nil
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
