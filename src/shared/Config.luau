-- Config : TOUS les réglages du jeu sont ici.
-- Tu peux changer les prix, les créatures, les vitesses... sans toucher au reste du code.
-- (ModuleScript, à placer dans ReplicatedStorage, nommé "Config")

local Config = {}

---------------------------------------------------------------------
-- Réglages généraux
---------------------------------------------------------------------
Config.STARTING_COINS = 50 -- argent de départ d'un nouveau joueur
Config.BASE_SLOTS = 10 -- emplacements de créatures dans une base
Config.EXTRA_SLOTS = 5 -- emplacements en plus avec le pass "+5 emplacements"

Config.CONVEYOR_SPEED = 5 -- vitesse du tapis roulant (studs par seconde)
Config.SPAWN_INTERVAL = 2.5 -- une nouvelle créature arrive toutes les X secondes

Config.NORMAL_WALK_SPEED = 16 -- vitesse normale d'un joueur
Config.FAST_WALK_SPEED = 24 -- vitesse avec le pass "Course rapide"
Config.CARRY_WALK_SPEED = 13 -- vitesse quand on porte une créature volée
Config.STEAL_TIME_LIMIT = 45 -- secondes pour ramener une créature volée
Config.CATCH_DISTANCE = 7 -- le propriétaire attrape le voleur s'il s'approche à moins de X studs

Config.LOCK_DURATION = 30 -- durée du verrou gratuit de la base (secondes)
Config.LOCK_COOLDOWN = 120 -- temps d'attente avant de pouvoir re-verrouiller
Config.SHIELD_PRODUCT_DURATION = 600 -- bouclier acheté en Robux : 10 minutes

Config.SELL_RATIO = 0.5 -- revendre une créature rapporte 50 % de son prix

---------------------------------------------------------------------
-- Raretés (couleur du texte)
---------------------------------------------------------------------
Config.Rarities = {
	Commun = Color3.fromRGB(200, 200, 200),
	["Peu commun"] = Color3.fromRGB(90, 220, 110),
	Rare = Color3.fromRGB(70, 150, 255),
	["Épique"] = Color3.fromRGB(180, 90, 255),
	["Légendaire"] = Color3.fromRGB(255, 190, 40),
	Mythique = Color3.fromRGB(255, 70, 110),
	Secret = Color3.fromRGB(20, 255, 230),
}

---------------------------------------------------------------------
-- Les créatures
-- price  = prix d'achat sur le tapis
-- income = pièces gagnées par seconde dans ta base
-- weight = chance d'apparaître sur le tapis (plus c'est grand, plus c'est fréquent)
---------------------------------------------------------------------
Config.Creatures = {
	{ id = "grenouille", name = "Grenouille Pantoufle", rarity = "Commun", price = 25, income = 1, weight = 40, size = 2.4, color = Color3.fromRGB(110, 200, 90), accent = Color3.fromRGB(240, 120, 160) },
	{ id = "herisson", name = "Hérisson Cupcake", rarity = "Peu commun", price = 120, income = 4, weight = 28, size = 2.8, color = Color3.fromRGB(150, 100, 70), accent = Color3.fromRGB(255, 170, 210) },
	{ id = "pingouin", name = "Pingouin Disco", rarity = "Rare", price = 500, income = 14, weight = 16, size = 3.1, color = Color3.fromRGB(40, 40, 60), accent = Color3.fromRGB(255, 240, 80) },
	{ id = "poulpe", name = "Poulpe Astronaute", rarity = "Épique", price = 2000, income = 45, weight = 9, size = 3.4, color = Color3.fromRGB(230, 90, 130), accent = Color3.fromRGB(220, 230, 255) },
	{ id = "lama", name = "Lama Tornade", rarity = "Épique", price = 8000, income = 150, weight = 4.5, size = 3.7, color = Color3.fromRGB(240, 230, 210), accent = Color3.fromRGB(120, 200, 255) },
	{ id = "dragon", name = "Dragon Chaussette", rarity = "Légendaire", price = 35000, income = 550, weight = 1.8, size = 4.1, color = Color3.fromRGB(230, 70, 50), accent = Color3.fromRGB(255, 255, 255) },
	{ id = "baleine", name = "Baleine Galactique", rarity = "Mythique", price = 150000, income = 2000, weight = 0.6, size = 4.6, color = Color3.fromRGB(60, 60, 170), accent = Color3.fromRGB(255, 120, 255) },
	{ id = "chat", name = "Chat Quantique", rarity = "Secret", price = 800000, income = 9000, weight = 0.1, size = 5, color = Color3.fromRGB(20, 20, 30), accent = Color3.fromRGB(20, 255, 230) },
}

---------------------------------------------------------------------
-- Mutations : une créature peut apparaître en version spéciale.
-- multiplier multiplie son prix ET ses gains.
---------------------------------------------------------------------
Config.Mutations = {
	{ id = "diamant", name = "Diamant", multiplier = 5, chance = 0.01, color = Color3.fromRGB(120, 240, 255), material = Enum.Material.Glass, sparkle = true },
	{ id = "dore", name = "Doré", multiplier = 2, chance = 0.05, color = Color3.fromRGB(255, 200, 40), material = Enum.Material.Foil, sparkle = true },
}
Config.NormalMutation = { id = "normal", name = "", multiplier = 1 }

---------------------------------------------------------------------
-- Monétisation (Robux)
-- Remplace les 0 par les vrais numéros (ID) que tu crées sur le Creator Hub.
-- Tant qu'un ID vaut 0, le bouton affiche "Bientôt disponible".
---------------------------------------------------------------------
Config.GamePasses = {
	DoubleCash = 0, -- Argent x2
	FastRun = 0, -- Course rapide
	ExtraSlots = 0, -- +5 emplacements
}

Config.Products = {
	Shield = 0, -- Bouclier 10 minutes
	MysteryEgg = 0, -- Œuf mystère (créature rare)
	CashSmall = 0, -- Petit sac de pièces
	CashBig = 0, -- Gros coffre de pièces
}

Config.CashRewards = {
	CashSmall = 5000,
	CashBig = 60000,
}

-- Chances de l'Œuf mystère (seulement des créatures rares)
Config.MysteryEggWeights = {
	poulpe = 50,
	lama = 30,
	dragon = 15,
	baleine = 4.5,
	chat = 0.5,
}

-- Textes affichés dans la boutique Robux du jeu
Config.ShopItems = {
	{ kind = "pass", key = "DoubleCash", title = "💰 Argent x2", desc = "Toutes tes créatures rapportent 2 fois plus, pour toujours." },
	{ kind = "pass", key = "FastRun", title = "👟 Course rapide", desc = "Cours plus vite pour voler et t'enfuir." },
	{ kind = "pass", key = "ExtraSlots", title = "🏠 +5 emplacements", desc = "Ta base peut garder 15 créatures au lieu de 10." },
	{ kind = "product", key = "Shield", title = "🛡️ Bouclier 10 min", desc = "Personne ne peut voler dans ta base pendant 10 minutes." },
	{ kind = "product", key = "MysteryEgg", title = "🥚 Œuf mystère", desc = "Une créature Épique ou mieux, direct dans ta base." },
	{ kind = "product", key = "CashSmall", title = "🪙 Sac de 5 000 pièces", desc = "Un petit coup de pouce." },
	{ kind = "product", key = "CashBig", title = "💎 Coffre de 60 000 pièces", desc = "Un gros coup de pouce." },
}

---------------------------------------------------------------------
-- Ne pas modifier en dessous (outils utilisés par les scripts)
---------------------------------------------------------------------
Config.CreaturesById = {}
for _, creature in Config.Creatures do
	Config.CreaturesById[creature.id] = creature
end

Config.MutationsById = { normal = Config.NormalMutation }
for _, mutation in Config.Mutations do
	Config.MutationsById[mutation.id] = mutation
end

function Config.getMutation(mutationId)
	return Config.MutationsById[mutationId] or Config.NormalMutation
end

function Config.displayName(creatureId, mutationId)
	local creature = Config.CreaturesById[creatureId]
	local mutation = Config.getMutation(mutationId)
	if mutation.name ~= "" then
		return creature.name .. " " .. mutation.name
	end
	return creature.name
end

function Config.incomeOf(creatureId, mutationId)
	return Config.CreaturesById[creatureId].income * Config.getMutation(mutationId).multiplier
end

function Config.priceOf(creatureId, mutationId)
	return Config.CreaturesById[creatureId].price * Config.getMutation(mutationId).multiplier
end

-- Écrit les grands nombres en court : 1500 -> 1.5K, 2000000 -> 2M
function Config.formatNumber(n)
	n = math.floor(n)
	local suffixes = { "", "K", "M", "B", "T" }
	local index = 1
	local value = n
	while math.abs(value) >= 1000 and index < #suffixes do
		value = value / 1000
		index += 1
	end
	if index == 1 then
		return tostring(value)
	end
	local text = string.format("%.1f", value)
	text = (string.gsub(text, "%.0$", ""))
	return text .. suffixes[index]
end

return Config
