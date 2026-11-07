-- Monetization : tout ce qui touche aux Robux (game passes et produits de développeur).
-- (ModuleScript, à placer dans ServerScriptService, nommé "Monetization")
--
-- Game pass = acheté UNE fois, gardé pour toujours (ex : Argent x2).
-- Produit de développeur = achetable autant de fois qu'on veut (ex : sac de pièces).
-- Les numéros (ID) se règlent dans Config.luau.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local format = Config.formatNumber

local Monetization = {}

-- Regarde quels game passes le joueur possède déjà.
function Monetization.loadPasses(player)
	local passes = {}
	for key, passId in Config.GamePasses do
		if passId ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
			end)
			if ok and owns then
				passes[key] = true
			end
		end
	end
	return passes
end

-- game : la table d'outils fournie par GameServer
function Monetization.start(game_)
	local sessions = game_.sessions
	local notify = game_.notify

	local eggWeights = {}
	for creatureId, weight in Config.MysteryEggWeights do
		table.insert(eggWeights, { value = creatureId, weight = weight })
	end

	-----------------------------------------------------------------
	-- Game passes
	-----------------------------------------------------------------
	local passKeyById = {}
	for key, passId in Config.GamePasses do
		if passId ~= 0 then
			passKeyById[passId] = key
		end
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = passKeyById[passId]
		local session = sessions[player]
		if not purchased or not key or not session then
			return
		end
		session.passes[key] = true
		if session.base then
			game_.refreshPadColors(session.base)
		end
		game_.applyWalkSpeed(player)
		notify(player, "🎉 Merci pour ton achat !", "success")
		game_.pushState(player)
	end)

	-----------------------------------------------------------------
	-- Produits de développeur
	-----------------------------------------------------------------
	local productHandlers = {}

	local function addHandler(key, handler)
		local productId = Config.Products[key]
		if productId and productId ~= 0 then
			productHandlers[productId] = handler
		end
	end

	addHandler("CashSmall", function(player)
		game_.addCoins(player, Config.CashRewards.CashSmall)
		notify(player, "🪙 +" .. format(Config.CashRewards.CashSmall) .. " pièces !", "success")
	end)

	addHandler("CashBig", function(player)
		game_.addCoins(player, Config.CashRewards.CashBig)
		notify(player, "💎 +" .. format(Config.CashRewards.CashBig) .. " pièces !", "success")
	end)

	addHandler("Shield", function(player)
		local session = sessions[player]
		local base = session and session.base
		if not base then
			error("pas de base")
		end
		base.shieldUntil = math.max(base.shieldUntil, os.clock()) + Config.SHIELD_PRODUCT_DURATION
		notify(player, "🛡️ Bouclier activé pour 10 minutes !", "success")
	end)

	addHandler("MysteryEgg", function(player)
		local session = sessions[player]
		local base = session and session.base
		if not base then
			error("pas de base")
		end
		local creatureId = game_.pickWeighted(eggWeights)
		local mutationId = game_.rollMutation()
		local name = Config.displayName(creatureId, mutationId)
		local freeSlot = game_.findFreeSlot(base, player)
		if freeSlot then
			game_.placeCreature(base, freeSlot, creatureId, mutationId, true)
			notify(player, "🥚 L'œuf a éclos : " .. name .. " !", "success")
			game_.notifyAll("🥚 " .. player.DisplayName .. " a obtenu " .. name .. " dans un Œuf mystère !", "info")
		else
			-- Base pleine : on rembourse en pièces la valeur de la créature
			local value = Config.priceOf(creatureId, mutationId)
			game_.addCoins(player, value)
			notify(player, "🥚 Base pleine ! " .. name .. " a été échangé contre " .. format(value) .. " 🪙", "warning")
		end
	end)

	-- Roblox appelle cette fonction à chaque achat de produit.
	-- Elle doit renvoyer PurchaseGranted UNIQUEMENT si le joueur a bien reçu son achat.
	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if not player or not PlayerData.get(player) or not sessions[player] then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if PlayerData.hasReceipt(player, receipt.PurchaseId) then
			return Enum.ProductPurchaseDecision.PurchaseGranted -- déjà livré
		end
		local handler = productHandlers[receipt.ProductId]
		if not handler then
			warn("[Monetization] Produit inconnu : " .. tostring(receipt.ProductId))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok, err = pcall(handler, player)
		if not ok then
			warn("[Monetization] Erreur en livrant un achat : " .. tostring(err))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		PlayerData.addReceipt(player, receipt.PurchaseId)
		PlayerData.save(player)
		game_.pushState(player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

return Monetization
