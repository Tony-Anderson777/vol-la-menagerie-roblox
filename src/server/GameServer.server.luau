-- GameServer : le cerveau du jeu. Il tourne sur le serveur (les joueurs ne peuvent pas tricher dessus).
-- (Script, à placer dans ServerScriptService, nommé "GameServer")
--
-- Ce script construit la carte tout seul (tapis roulant + 6 bases), fait défiler
-- les créatures, gère les achats, l'argent, le vol et les achats Robux.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local Monetization = require(script.Parent:WaitForChild("Monetization"))

PlayerData.start()

local format = Config.formatNumber

---------------------------------------------------------------------
-- Communication serveur -> joueurs
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local StateUpdate = Instance.new("RemoteEvent")
StateUpdate.Name = "StateUpdate"
StateUpdate.Parent = remotes
local Notify = Instance.new("RemoteEvent")
Notify.Name = "Notify"
Notify.Parent = remotes
remotes.Parent = ReplicatedStorage

local function notify(player, text, kind)
	if player and player.Parent then
		Notify:FireClient(player, text, kind or "info")
	end
end

local function notifyAll(text, kind)
	Notify:FireAllClients(text, kind or "info")
end

---------------------------------------------------------------------
-- Petits outils pour construire la carte
---------------------------------------------------------------------
local world = Instance.new("Folder")
world.Name = "Menagerie"
world.Parent = Workspace

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local parent = props.Parent
	props.Parent = nil
	for key, value in props do
		part[key] = value
	end
	part.Parent = parent
	return part
end

local function makeBillboard(adornee, sizeY, offsetY, maxDistance)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 220, 0, sizeY)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = maxDistance or 80
	gui.LightInfluence = 0
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.RichText = true
	label.Parent = gui
	gui.Parent = adornee
	return label
end

local function colorToHex(color)
	return string.format(
		"#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function makePrompt(parent, kind, actionText, objectText, holdDuration, distance)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText or ""
	prompt.HoldDuration = holdDuration or 0
	prompt.MaxActivationDistance = distance or 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Kind", kind)
	prompt.Parent = parent
	return prompt
end

---------------------------------------------------------------------
-- Les créatures (construites avec des formes simples)
---------------------------------------------------------------------
local function buildCreature(creatureId, mutationId)
	local def = Config.CreaturesById[creatureId]
	local mutation = Config.getMutation(mutationId)
	local s = def.size

	local model = Instance.new("Model")
	model.Name = Config.displayName(creatureId, mutationId)

	local body = makePart({
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(s, s, s),
		CFrame = CFrame.new(0, s / 2, 0),
		Color = mutation.color or def.color,
		Material = mutation.material or Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = model,
	})
	body.PivotOffset = CFrame.new(0, -s / 2, 0) -- le "point d'appui" est sous les pieds
	model.PrimaryPart = body

	-- Yeux (le devant de la créature est vers -Z)
	for _, side in { -1, 1 } do
		makePart({
			Name = "Oeil",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * s * 0.3,
			CFrame = CFrame.new(side * s * 0.2, s * 0.65, -s * 0.38),
			Color = Color3.new(1, 1, 1),
			CanCollide = false,
			CanQuery = false,
			Parent = model,
		})
		makePart({
			Name = "Pupille",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * s * 0.15,
			CFrame = CFrame.new(side * s * 0.2, s * 0.65, -s * 0.5),
			Color = Color3.new(0.05, 0.05, 0.05),
			CanCollide = false,
			CanQuery = false,
			Parent = model,
		})
	end

	-- Petit chapeau de couleur
	makePart({
		Name = "Chapeau",
		Size = Vector3.new(s * 0.55, s * 0.3, s * 0.55),
		CFrame = CFrame.new(0, s * 1.05, 0),
		Color = def.accent,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})

	-- Pieds
	for _, side in { -1, 1 } do
		makePart({
			Name = "Pied",
			Size = Vector3.new(s * 0.3, s * 0.15, s * 0.4),
			CFrame = CFrame.new(side * s * 0.25, s * 0.07, -s * 0.1),
			Color = def.accent,
			CanCollide = false,
			CanQuery = false,
			Parent = model,
		})
	end

	if mutation.sparkle then
		local particles = Instance.new("ParticleEmitter")
		particles.Rate = 8
		particles.Lifetime = NumberRange.new(0.6, 1.2)
		particles.Speed = NumberRange.new(1, 3)
		particles.Size = NumberSequence.new(0.3, 0)
		particles.Color = ColorSequence.new(mutation.color)
		particles.LightEmission = 1
		particles.SpreadAngle = Vector2.new(180, 180)
		particles.Parent = body
	end

	local label = makeBillboard(body, 60, s / 2 + 2.2, 70)
	return model, label
end

local function creatureLabelText(creatureId, mutationId, showPrice)
	local def = Config.CreaturesById[creatureId]
	local rarityColor = colorToHex(Config.Rarities[def.rarity] or Color3.new(1, 1, 1))
	local lines = {
		string.format('<font color="%s">%s</font>', rarityColor, Config.displayName(creatureId, mutationId)),
		string.format('<font color="%s">%s</font>  +%s/s', rarityColor, def.rarity, format(Config.incomeOf(creatureId, mutationId))),
	}
	if showPrice then
		table.insert(lines, "🪙 " .. format(Config.priceOf(creatureId, mutationId)))
	end
	return table.concat(lines, "\n")
end

local function pickWeighted(entries)
	-- entries = { { value = ..., weight = nombre }, ... }
	local total = 0
	for _, entry in entries do
		total += entry.weight
	end
	local roll = math.random() * total
	for _, entry in entries do
		roll -= entry.weight
		if roll <= 0 then
			return entry.value
		end
	end
	return entries[#entries].value
end

local creatureWeights = {}
for _, def in Config.Creatures do
	table.insert(creatureWeights, { value = def.id, weight = def.weight })
end

local function rollMutation()
	local roll = math.random()
	for _, mutation in Config.Mutations do
		if roll < mutation.chance then
			return mutation.id
		end
		roll -= mutation.chance
	end
	return "normal"
end

---------------------------------------------------------------------
-- La carte : sol, point d'apparition, tapis roulant
---------------------------------------------------------------------
if not Workspace:FindFirstChild("Baseplate") then
	makePart({
		Name = "Sol",
		Size = Vector3.new(300, 2, 300),
		Position = Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(95, 170, 90),
		Material = Enum.Material.Grass,
		Parent = world,
	})
end

local spawnLocation = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
if spawnLocation then
	spawnLocation.Position = Vector3.new(0, 0.5, 18)
else
	spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(8, 1, 8)
	spawnLocation.Position = Vector3.new(0, 0.5, 18)
	spawnLocation.Parent = world
end

local CONVEYOR_START_X = -80
local CONVEYOR_END_X = 80
local CONVEYOR_Y = 1

makePart({
	Name = "TapisRoulant",
	Size = Vector3.new(CONVEYOR_END_X - CONVEYOR_START_X + 4, 1, 10),
	Position = Vector3.new(0, 0.5, 0),
	Color = Color3.fromRGB(45, 45, 55),
	Material = Enum.Material.DiamondPlate,
	Parent = world,
})
for _, side in { -1, 1 } do
	makePart({
		Name = "Bordure",
		Size = Vector3.new(CONVEYOR_END_X - CONVEYOR_START_X + 4, 1.6, 0.8),
		Position = Vector3.new(0, 0.8, side * 5.4),
		Color = Color3.fromRGB(255, 200, 40),
		Material = Enum.Material.SmoothPlastic,
		Parent = world,
	})
end
local conveyorSign = makePart({
	Name = "PanneauTapis",
	Size = Vector3.new(1, 1, 1),
	Position = Vector3.new(CONVEYOR_START_X, 10, 0),
	Transparency = 1,
	CanCollide = false,
	Parent = world,
})
makeBillboard(conveyorSign, 70, 0, 200).Text = "🐾 Vole la Ménagerie 🐾\nAchète des créatures sur le tapis !"

---------------------------------------------------------------------
-- Les 6 bases des joueurs
---------------------------------------------------------------------
local BASE_CENTERS = {
	Vector3.new(-50, 0, -55),
	Vector3.new(0, 0, -55),
	Vector3.new(50, 0, -55),
	Vector3.new(-50, 0, 55),
	Vector3.new(0, 0, 55),
	Vector3.new(50, 0, 55),
}
local BASE_COLORS = {
	Color3.fromRGB(255, 120, 120),
	Color3.fromRGB(120, 180, 255),
	Color3.fromRGB(255, 210, 90),
	Color3.fromRGB(150, 230, 130),
	Color3.fromRGB(200, 140, 255),
	Color3.fromRGB(255, 160, 220),
}
local SLOT_COLUMNS = { -14, -7, 0, 7, 14 }
local SLOT_ROWS = { 12, 4, -4 } -- 3 rangées de 5 = 15 emplacements (la 3e rangée demande le pass)
local BASE_HALF_SIZE = 20

local sessions = {} -- [player] = { base, passes, data }
local bases = {}
local steals = {} -- [voleur] = { victim, base, slotIndex, model, startedAt }

local function maxSlots(player)
	local session = sessions[player]
	if session and session.passes.ExtraSlots then
		return Config.BASE_SLOTS + Config.EXTRA_SLOTS
	end
	return Config.BASE_SLOTS
end

local function isShielded(base)
	return base.shieldUntil > os.clock()
end

for index, center in BASE_CENTERS do
	local towardConveyor = if center.Z > 0 then -1 else 1
	local cf = CFrame.lookAt(center, center + Vector3.new(0, 0, towardConveyor))
	local color = BASE_COLORS[index]
	local model = Instance.new("Model")
	model.Name = "Base" .. index
	model.Parent = world

	local base = {
		index = index,
		cf = cf,
		rotation = cf - cf.Position,
		model = model,
		owner = nil,
		slots = {},
		shieldUntil = 0,
		lockReadyAt = 0,
	}

	makePart({
		Name = "Sol",
		Size = Vector3.new(BASE_HALF_SIZE * 2, 0.4, BASE_HALF_SIZE * 2),
		CFrame = cf * CFrame.new(0, 0.2, 0),
		Color = color:Lerp(Color3.new(1, 1, 1), 0.5),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	-- Murs (le devant, côté tapis, est ouvert)
	makePart({ Name = "Mur", Size = Vector3.new(40, 8, 1), CFrame = cf * CFrame.new(0, 4, 20), Color = color, Parent = model })
	makePart({ Name = "Mur", Size = Vector3.new(1, 8, 40), CFrame = cf * CFrame.new(-20, 4, 0), Color = color, Parent = model })
	makePart({ Name = "Mur", Size = Vector3.new(1, 8, 40), CFrame = cf * CFrame.new(20, 4, 0), Color = color, Parent = model })

	local signPart = makePart({
		Name = "Panneau",
		Size = Vector3.one,
		CFrame = cf * CFrame.new(0, 12, 20),
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})
	base.signLabel = makeBillboard(signPart, 50, 0, 150)
	base.signLabel.Text = "Base libre"

	-- Emplacements des créatures
	for _, rowZ in SLOT_ROWS do
		for _, columnX in SLOT_COLUMNS do
			local pad = makePart({
				Name = "Emplacement",
				Size = Vector3.new(5, 0.3, 5),
				CFrame = cf * CFrame.new(columnX, 0.5, rowZ),
				Color = Color3.fromRGB(240, 240, 240),
				Material = Enum.Material.SmoothPlastic,
				Parent = model,
			})
			table.insert(base.slots, {
				pad = pad,
				creatureId = nil,
				mutation = nil,
				uid = nil, -- identifiant unique de la créature (sert à suivre les vols)
				model = nil,
				stolenBy = nil,
				transferring = false, -- vrai pendant l'enregistrement d'un vol réussi
			})
		end
	end

	-- Plaque pour récupérer l'argent
	base.collectPad = makePart({
		Name = "Collecte",
		Size = Vector3.new(7, 0.5, 7),
		CFrame = cf * CFrame.new(-12, 0.5, -14),
		Color = Color3.fromRGB(90, 220, 110),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	base.pendingLabel = makeBillboard(base.collectPad, 50, 3, 60)
	base.pendingLabel.Text = "💰 0"

	-- Bouton de verrouillage
	base.lockButton = makePart({
		Name = "Verrou",
		Size = Vector3.new(4, 3, 4),
		CFrame = cf * CFrame.new(12, 1.5, -14),
		Color = Color3.fromRGB(80, 140, 255),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	base.lockLabel = makeBillboard(base.lockButton, 40, 3.5, 60)
	base.lockLabel.Text = "🔒 Verrou"
	base.lockPrompt = makePrompt(base.lockButton, "Lock", "Verrouiller", "Ta base", 0.3, 8)

	-- Dôme du bouclier (invisible quand il n'est pas actif)
	base.dome = makePart({
		Name = "Bouclier",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 58,
		CFrame = cf,
		Color = Color3.fromRGB(100, 180, 255),
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = model,
	})

	bases[index] = base
end

local function isInBase(base, position)
	local localPos = base.cf:PointToObjectSpace(position)
	return math.abs(localPos.X) < BASE_HALF_SIZE and math.abs(localPos.Z) < BASE_HALF_SIZE
end

local function getRoot(player)
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function refreshPadColors(base)
	local limit = base.owner and maxSlots(base.owner) or Config.BASE_SLOTS
	for i, slot in base.slots do
		if i <= limit then
			slot.pad.Color = Color3.fromRGB(240, 240, 240)
		else
			slot.pad.Color = Color3.fromRGB(70, 70, 80) -- emplacement bloqué (pass)
		end
	end
end

local function findFreeSlot(base, player)
	for i = 1, maxSlots(player) do
		if not base.slots[i].creatureId then
			return i
		end
	end
	return nil
end

local function countUsed(base)
	local used = 0
	for _, slot in base.slots do
		if slot.creatureId then
			used += 1
		end
	end
	return used
end

---------------------------------------------------------------------
-- Argent
---------------------------------------------------------------------
local function setCoins(player, amount)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	data.coins = math.max(0, math.floor(amount))
	local leaderstats = player:FindFirstChild("leaderstats")
	local coinsValue = leaderstats and leaderstats:FindFirstChild("Pièces")
	if coinsValue then
		coinsValue.Value = data.coins
	end
end

local function addCoins(player, amount)
	local data = PlayerData.get(player)
	if data then
		setCoins(player, data.coins + amount)
	end
end

local function baseIncome(base)
	local total = 0
	for _, slot in base.slots do
		-- Une créature en train d'être volée, ou dont le vol n'est pas encore enregistré, ne rapporte rien
		if slot.creatureId and not slot.stolenBy and not slot.transferring then
			total += Config.incomeOf(slot.creatureId, slot.mutation)
		end
	end
	local session = base.owner and sessions[base.owner]
	if session and session.passes.DoubleCash then
		total *= 2
	end
	return total
end

---------------------------------------------------------------------
-- Infos envoyées à l'écran du joueur
---------------------------------------------------------------------
local function pushState(player)
	local session = sessions[player]
	local data = PlayerData.get(player)
	if not session or not data then
		return
	end
	local base = session.base
	local now = os.clock()
	local steal = steals[player]
	local carrying = nil
	if steal then
		local slot = steal.base.slots[steal.slotIndex]
		carrying = {
			name = Config.displayName(slot.creatureId, slot.mutation),
			timeLeft = math.max(0, math.ceil(Config.STEAL_TIME_LIMIT - (now - steal.startedAt))),
		}
	end
	StateUpdate:FireClient(player, {
		coins = data.coins,
		income = base and baseIncome(base) or 0,
		used = base and countUsed(base) or 0,
		max = maxSlots(player),
		shield = base and math.max(0, math.ceil(base.shieldUntil - now)) or 0,
		lockCooldown = base and math.max(0, math.ceil(base.lockReadyAt - now)) or 0,
		carrying = carrying,
		passes = session.passes,
	})
end

---------------------------------------------------------------------
-- Placer / enlever une créature dans une base
---------------------------------------------------------------------
local onStealPrompt -- déclarées plus bas
local onSellPrompt

local function setCreaturePromptsOwner(model, ownerId)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			descendant:SetAttribute("OwnerId", ownerId)
		end
	end
end

local function placeCreature(base, slotIndex, creatureId, mutationId, uid, saveToData)
	local slot = base.slots[slotIndex]
	if slot.model then
		slot.model:Destroy()
	end
	local model, label = buildCreature(creatureId, mutationId)
	label.Text = creatureLabelText(creatureId, mutationId, false)
	local padTop = slot.pad.Position + Vector3.new(0, slot.pad.Size.Y / 2, 0)
	model:PivotTo(CFrame.new(padTop) * base.rotation)

	local sellValue = math.floor(Config.priceOf(creatureId, mutationId) * Config.SELL_RATIO)
	local stealPrompt = makePrompt(model.PrimaryPart, "Steal", "Voler", model.Name, 1.2, 9)
	local sellPrompt = makePrompt(model.PrimaryPart, "Sell", "Vendre", "+" .. format(sellValue) .. " 🪙", 0.8, 9)
	stealPrompt.Triggered:Connect(function(player)
		onStealPrompt(player, base, slotIndex, model)
	end)
	sellPrompt.Triggered:Connect(function(player)
		onSellPrompt(player, base, slotIndex, model)
	end)
	setCreaturePromptsOwner(model, base.owner and base.owner.UserId or 0)
	model.Parent = base.model

	slot.creatureId = creatureId
	slot.mutation = mutationId
	slot.uid = uid or HttpService:GenerateGUID(false)
	slot.model = model
	slot.stolenBy = nil
	slot.transferring = false

	if saveToData and base.owner then
		local data = PlayerData.get(base.owner)
		if data then
			data.creatures[tostring(slotIndex)] = { id = creatureId, mut = mutationId, uid = slot.uid }
		end
	end
end

local function clearSlot(base, slotIndex, saveToData)
	local slot = base.slots[slotIndex]
	if slot.model then
		slot.model:Destroy()
	end
	slot.model = nil
	slot.creatureId = nil
	slot.mutation = nil
	slot.uid = nil
	slot.stolenBy = nil
	slot.transferring = false
	if saveToData and base.owner then
		local data = PlayerData.get(base.owner)
		if data then
			data.creatures[tostring(slotIndex)] = nil
		end
	end
end

---------------------------------------------------------------------
-- Le vol
---------------------------------------------------------------------
local function applyWalkSpeed(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local session = sessions[player]
	if steals[player] then
		humanoid.WalkSpeed = Config.CARRY_WALK_SPEED
	elseif session and session.passes.FastRun then
		humanoid.WalkSpeed = Config.FAST_WALK_SPEED
	else
		humanoid.WalkSpeed = Config.NORMAL_WALK_SPEED
	end
end

-- Transfert d'une créature volée. Chaque vol a son propre identifiant de transaction (txId).
--  1. DÉBIT : on retire la créature au volé et on note debits[txId]. On sauvegarde le volé.
--     On continue seulement si cette sauvegarde a réussi (ou, s'il part, si SA sauvegarde
--     finale a réussi) : la disparition du profil ne prouve rien.
--  2. CRÉDIT : on ajoute la créature au voleur ET le reçu credits[txId], dans la même écriture.
--     Tant que ce n'est pas enregistré, la créature reste "en transfert" chez le voleur :
--     elle ne rapporte rien et ne peut être ni vendue ni volée.
--  3. Si le serveur s'arrête entre 1 et 2, PlayerData (resolveDebits) lit le reçu du voleur au
--     retour du volé : pas de reçu et voleur parti = la créature est rendue. Ni duplication, ni perte.
local THIEF_SAVE_ATTEMPTS = 5
local THIEF_SAVE_RETRY_DELAY = 10

local function commitStolenCreature(victim, victimBase, victimSlotIndex, thief, thiefBase, thiefSlotIndex)
	local victimSlot = victimBase.slots[victimSlotIndex]
	local creatureId, mutationId, uid = victimSlot.creatureId, victimSlot.mutation, victimSlot.uid
	local name = Config.displayName(creatureId, mutationId)
	local victimProfile = PlayerData.getProfile(victim)
	local thiefProfile = PlayerData.getProfile(thief)
	if not victimProfile or not thiefProfile then
		placeCreature(victimBase, victimSlotIndex, creatureId, mutationId, uid, false)
		return false
	end
	local txId = HttpService:GenerateGUID(false)

	-- 1. Débit (en mémoire), puis affichage "en transfert" chez le voleur
	victimProfile.data.creatures[tostring(victimSlotIndex)] = nil
	victimProfile.data.debits[txId] = {
		to = thief.UserId,
		id = creatureId,
		mut = mutationId,
		uid = uid,
		at = os.time(),
	}
	clearSlot(victimBase, victimSlotIndex, false)
	placeCreature(thiefBase, thiefSlotIndex, creatureId, mutationId, uid, false)
	local thiefSlot = thiefBase.slots[thiefSlotIndex]
	thiefSlot.transferring = true

	local function thiefStillHasSlot()
		return thiefBase.owner == thief and thiefSlot.uid == uid
	end

	-- Le vol n'a pas abouti : la créature revient au volé
	local function cancel()
		if thiefStillHasSlot() then
			clearSlot(thiefBase, thiefSlotIndex, false)
		end
		if not victimProfile.released then
			-- Le volé est encore là : on annule le débit dans ses données
			victimProfile.data.debits[txId] = nil
			local backSlot = victimBase.owner == victim and findFreeSlot(victimBase, victim)
			if backSlot then
				placeCreature(victimBase, backSlot, creatureId, mutationId, uid, true)
			else
				table.insert(victimProfile.data.returned, { id = creatureId, mut = mutationId, uid = uid })
			end
			notify(victim, "😮‍💨 " .. name .. " est revenu chez toi.", "info")
			pushState(victim)
		end
		-- Si le volé est parti : soit son débit n'a pas été enregistré (sa sauvegarde a encore
		-- la créature), soit il l'a été et resolveDebits la lui rendra à son retour.
		notify(thief, "Le vol n'a pas pu être enregistré, la créature est rendue.", "danger")
		pushState(thief)
	end

	task.spawn(function()
		-- 1. Le débit doit être enregistré
		local debitSaved = PlayerData.saveProfile(victimProfile)
		if not debitSaved or not thiefStillHasSlot() or thiefProfile.released then
			cancel()
			return
		end

		-- 2. Crédit + reçu, dans la même écriture
		thiefProfile.data.creatures[tostring(thiefSlotIndex)] = { id = creatureId, mut = mutationId, uid = uid }
		thiefProfile.data.credits[txId] = os.time()
		for attempt = 1, THIEF_SAVE_ATTEMPTS do
			if PlayerData.saveProfile(thiefProfile) then
				-- Transfert terminé. Effacer la note est du ménage : si cette ligne n'est pas
				-- sauvegardée, resolveDebits trouvera le reçu et l'effacera.
				victimProfile.data.debits[txId] = nil
				if thiefStillHasSlot() then
					thiefSlot.transferring = false
				end
				pushState(thief)
				return
			end
			if thiefProfile.released then
				break -- sa sauvegarde finale a échoué : resolveDebits rendra la créature au volé
			end
			task.wait(THIEF_SAVE_RETRY_DELAY)
		end
		-- Crédit toujours pas confirmé : la créature reste inactive pour cette partie.
		-- Les prochaines sauvegardes du voleur l'enregistreront avec son reçu ; si aucune ne
		-- réussit, resolveDebits la rendra au volé.
		warn("[GameServer] Vol " .. txId .. " : crédit du voleur pas encore enregistré")
	end)
	return true
end

local function endSteal(thief, success, reason)
	local steal = steals[thief]
	if not steal then
		return
	end
	steals[thief] = nil
	applyWalkSpeed(thief)

	local base = steal.base
	local slot = base.slots[steal.slotIndex]
	local stillThere = base.owner == steal.victim and slot.model == steal.model and slot.creatureId ~= nil

	if not stillThere then
		pushState(thief)
		return
	end

	local creatureId, mutationId, uid = slot.creatureId, slot.mutation, slot.uid
	local name = Config.displayName(creatureId, mutationId)
	local thiefSession = sessions[thief]
	local thiefBase = thiefSession and thiefSession.base
	local freeSlot = thiefBase and findFreeSlot(thiefBase, thief)

	if success and freeSlot then
		if not commitStolenCreature(steal.victim, base, steal.slotIndex, thief, thiefBase, freeSlot) then
			pushState(thief)
			return
		end
		notify(thief, "🎉 Tu as volé " .. name .. " !", "success")
		notify(steal.victim, "😱 " .. thief.DisplayName .. " t'a volé " .. name .. " !", "danger")
	else
		-- La créature retourne à sa place
		placeCreature(base, steal.slotIndex, creatureId, mutationId, uid, false)
		if reason == "caught" then
			notify(thief, "🚨 " .. steal.victim.DisplayName .. " t'a attrapé ! La créature est rendue.", "danger")
			notify(steal.victim, "💪 Tu as récupéré " .. name .. " !", "success")
		elseif reason == "timeout" then
			notify(thief, "⌛ Trop lent ! " .. name .. " est retourné chez lui.", "danger")
			notify(steal.victim, "😮‍💨 " .. name .. " est revenu dans ta base.", "info")
		elseif reason == "full" then
			notify(thief, "Ta base est pleine ! " .. name .. " est retourné chez lui.", "danger")
		else
			notify(thief, name .. " est retourné chez lui.", "info")
			notify(steal.victim, "😮‍💨 " .. name .. " est revenu dans ta base.", "info")
		end
	end
	pushState(thief)
	pushState(steal.victim)
end

onStealPrompt = function(thief, base, slotIndex, model)
	local thiefSession = sessions[thief]
	local slot = base.slots[slotIndex]
	if not thiefSession or not thiefSession.base then
		return
	end
	if base.owner == nil or base.owner == thief then
		return
	end
	if slot.model ~= model or not slot.creatureId or slot.stolenBy or slot.transferring then
		return
	end
	if steals[thief] then
		notify(thief, "Tu portes déjà une créature !", "danger")
		return
	end
	if isShielded(base) then
		notify(thief, "🛡️ Cette base est protégée !", "danger")
		return
	end
	if not findFreeSlot(thiefSession.base, thief) then
		notify(thief, "Ta base est pleine ! Vends une créature d'abord.", "danger")
		return
	end
	local root = getRoot(thief)
	if not root or (root.Position - model:GetPivot().Position).Magnitude > 14 then
		return -- trop loin (anti-triche)
	end

	slot.stolenBy = thief
	steals[thief] = {
		victim = base.owner,
		base = base,
		slotIndex = slotIndex,
		model = model,
		startedAt = os.clock(),
	}
	setCreaturePromptsOwner(model, 0) -- plus de boutons pendant le transport
	applyWalkSpeed(thief)

	local name = Config.displayName(slot.creatureId, slot.mutation)
	notify(thief, "🏃 Ramène " .. name .. " dans ta base !", "warning")
	notify(base.owner, "⚠️ " .. thief.DisplayName .. " vole ton " .. name .. " ! Touche-le pour le récupérer !", "danger")
	pushState(thief)
	pushState(base.owner)
end

onSellPrompt = function(player, base, slotIndex, model)
	local slot = base.slots[slotIndex]
	if base.owner ~= player or slot.model ~= model or not slot.creatureId or slot.stolenBy or slot.transferring then
		return
	end
	local value = math.floor(Config.priceOf(slot.creatureId, slot.mutation) * Config.SELL_RATIO)
	local name = Config.displayName(slot.creatureId, slot.mutation)
	clearSlot(base, slotIndex, true)
	addCoins(player, value)
	notify(player, "Tu as vendu " .. name .. " pour " .. format(value) .. " 🪙", "success")
	pushState(player)
end

---------------------------------------------------------------------
-- Le tapis roulant
---------------------------------------------------------------------
local conveyorItems = {} -- liste de { model, creatureId, mutation, x, sold }

local function onBuyPrompt(player, item)
	if item.sold then
		return
	end
	local session = sessions[player]
	local data = PlayerData.get(player)
	if not session or not session.base or not data then
		return
	end
	local price = Config.priceOf(item.creatureId, item.mutation)
	if data.coins < price then
		notify(player, "Pas assez de pièces ! Il te faut " .. format(price) .. " 🪙", "danger")
		return
	end
	local freeSlot = findFreeSlot(session.base, player)
	if not freeSlot then
		notify(player, "Ta base est pleine ! Vends une créature d'abord.", "danger")
		return
	end
	local root = getRoot(player)
	if not root or (root.Position - item.model:GetPivot().Position).Magnitude > 16 then
		return -- trop loin (anti-triche)
	end

	item.sold = true
	item.model:Destroy()
	setCoins(player, data.coins - price)
	placeCreature(session.base, freeSlot, item.creatureId, item.mutation, nil, true)
	notify(player, "✅ " .. Config.displayName(item.creatureId, item.mutation) .. " est dans ta base !", "success")

	local def = Config.CreaturesById[item.creatureId]
	if def.weight <= 1.8 or item.mutation ~= "normal" then
		notifyAll("✨ " .. player.DisplayName .. " a acheté " .. Config.displayName(item.creatureId, item.mutation) .. " !", "info")
	end
	pushState(player)
end

local function spawnConveyorCreature()
	local creatureId = pickWeighted(creatureWeights)
	local mutationId = rollMutation()
	local model, label = buildCreature(creatureId, mutationId)
	label.Text = creatureLabelText(creatureId, mutationId, true)

	local item = { model = model, creatureId = creatureId, mutation = mutationId, x = CONVEYOR_START_X, sold = false }
	local prompt = makePrompt(
		model.PrimaryPart,
		"Buy",
		"Acheter",
		model.Name .. " - " .. format(Config.priceOf(creatureId, mutationId)) .. " 🪙",
		0,
		10
	)
	prompt.Triggered:Connect(function(player)
		onBuyPrompt(player, item)
	end)
	model:PivotTo(CFrame.new(item.x, CONVEYOR_Y, 0))
	model.Parent = world
	table.insert(conveyorItems, item)

	local def = Config.CreaturesById[creatureId]
	if def.weight <= 0.6 then
		notifyAll("🌟 Un " .. model.Name .. " (" .. def.rarity .. ") arrive sur le tapis !", "warning")
	end
end

task.spawn(function()
	while true do
		spawnConveyorCreature()
		task.wait(Config.SPAWN_INTERVAL)
	end
end)

-- À chaque image : on fait avancer le tapis et on colle les créatures volées au-dessus des voleurs.
local FACE_CONVEYOR_DIRECTION = CFrame.Angles(0, -math.pi / 2, 0)
RunService.Heartbeat:Connect(function(dt)
	for index = #conveyorItems, 1, -1 do
		local item = conveyorItems[index]
		if item.sold then
			table.remove(conveyorItems, index)
		else
			item.x += Config.CONVEYOR_SPEED * dt
			if item.x > CONVEYOR_END_X then
				item.model:Destroy()
				table.remove(conveyorItems, index)
			else
				local bob = math.abs(math.sin(item.x * 0.8)) * 0.4
				item.model:PivotTo(CFrame.new(item.x, CONVEYOR_Y + bob, 0) * FACE_CONVEYOR_DIRECTION)
			end
		end
	end

	for thief, steal in steals do
		local root = getRoot(thief)
		if root and steal.model.Parent then
			steal.model:PivotTo(root.CFrame * CFrame.new(0, 3.2, 0))
		end
	end
end)

-- Toutes les 0,2 seconde : on vérifie les vols en cours.
task.spawn(function()
	while true do
		task.wait(0.2)
		for thief, steal in steals do
			local root = getRoot(thief)
			local thiefSession = sessions[thief]
			if not root or not thiefSession then
				endSteal(thief, false, "dropped")
			elseif os.clock() - steal.startedAt > Config.STEAL_TIME_LIMIT then
				endSteal(thief, false, "timeout")
			else
				local victimRoot = getRoot(steal.victim)
				if victimRoot and (victimRoot.Position - root.Position).Magnitude < Config.CATCH_DISTANCE then
					endSteal(thief, false, "caught")
				elseif thiefSession.base and isInBase(thiefSession.base, root.Position) then
					local hasRoom = findFreeSlot(thiefSession.base, thief) ~= nil
					endSteal(thief, hasRoom, if hasRoom then nil else "full")
				end
			end
		end
	end
end)

---------------------------------------------------------------------
-- Revenus, collecte, verrou
---------------------------------------------------------------------
local function collect(base, player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local amount = math.floor(data.pendingCash)
	if amount < 1 then
		return
	end
	data.pendingCash -= amount
	addCoins(player, amount)
	base.pendingLabel.Text = "💰 0"
	notify(player, "+" .. format(amount) .. " 🪙", "coins")
	pushState(player)
end

local function activateLock(player, base)
	if base.owner ~= player then
		return
	end
	local now = os.clock()
	if now < base.lockReadyAt then
		notify(player, "Le verrou se recharge encore " .. math.ceil(base.lockReadyAt - now) .. " s", "danger")
		return
	end
	base.shieldUntil = math.max(base.shieldUntil, now + Config.LOCK_DURATION)
	base.lockReadyAt = now + Config.LOCK_COOLDOWN
	notify(player, "🔒 Base verrouillée pendant " .. Config.LOCK_DURATION .. " s !", "success")
	pushState(player)
end

for _, base in bases do
	base.collectPad.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and player == base.owner then
			collect(base, player)
		end
	end)
	base.lockPrompt.Triggered:Connect(function(player)
		activateLock(player, base)
	end)
end

task.spawn(function()
	while true do
		task.wait(1)
		local now = os.clock()
		for _, base in bases do
			local ownerData = base.owner and PlayerData.get(base.owner)
			if ownerData then
				-- La cagnotte est dans les données du joueur : elle est sauvegardée avec le reste
				ownerData.pendingCash += baseIncome(base)
				base.pendingLabel.Text = "💰 "
					.. format(ownerData.pendingCash)
					.. "\n<font size=\"14\">Marche ici pour récupérer</font>"

				local shieldLeft = base.shieldUntil - now
				base.dome.Transparency = if shieldLeft > 0 then 0.6 else 1
				if shieldLeft > 0 then
					base.lockLabel.Text = "🛡️ Protégé " .. math.ceil(shieldLeft) .. " s"
				elseif now < base.lockReadyAt then
					base.lockLabel.Text = "⏳ Recharge " .. math.ceil(base.lockReadyAt - now) .. " s"
				else
					base.lockLabel.Text = "🔒 Verrou prêt"
				end
			end
		end
		for player in sessions do
			pushState(player)
		end
	end
end)

---------------------------------------------------------------------
-- Arrivée et départ des joueurs
---------------------------------------------------------------------
local function teleportToBase(player)
	local session = sessions[player]
	local character = player.Character
	if not session or not session.base or not character then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if root and character.Parent then
		character:PivotTo(session.base.cf * CFrame.new(0, 4, -10))
	end
	applyWalkSpeed(player)
end

local function onPlayerAdded(player)
	local data = PlayerData.load(player)
	if not data or not player.Parent then
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coinsValue = Instance.new("IntValue")
	coinsValue.Name = "Pièces"
	coinsValue.Value = data.coins
	coinsValue.Parent = leaderstats
	leaderstats.Parent = player

	local session = { base = nil, passes = {} }
	sessions[player] = session

	-- Game passes déjà achetés
	session.passes = Monetization.loadPasses(player)
	if not player.Parent or sessions[player] ~= session then
		return -- le joueur est parti pendant la vérification : PlayerRemoving a déjà tout nettoyé
	end

	-- On donne une base libre au joueur
	for _, base in bases do
		if base.owner == nil then
			base.owner = player
			session.base = base
			base.shieldUntil = 0
			base.lockReadyAt = 0
			base.pendingLabel.Text = "💰 " .. format(data.pendingCash)
			base.signLabel.Text = "Base de " .. player.DisplayName
			base.lockPrompt:SetAttribute("OwnerId", player.UserId)
			refreshPadColors(base)
			for slotKey, saved in data.creatures do
				local slotIndex = tonumber(slotKey)
				if slotIndex and base.slots[slotIndex] and Config.CreaturesById[saved.id] then
					placeCreature(base, slotIndex, saved.id, saved.mut or "normal", saved.uid, false)
				end
			end
			-- Créatures rendues après un vol interrompu
			for _, returned in data.returned do
				local name = Config.displayName(returned.id, returned.mut)
				local freeSlot = findFreeSlot(base, player)
				if freeSlot then
					placeCreature(base, freeSlot, returned.id, returned.mut, returned.uid, true)
					notify(player, "😮‍💨 " .. name .. " est revenu chez toi.", "info")
				else
					local value = Config.priceOf(returned.id, returned.mut)
					addCoins(player, value)
					notify(player, name .. " est revenu, mais ta base est pleine : +" .. format(value) .. " 🪙", "info")
				end
			end
			data.returned = {}
			break
		end
	end
	if not session.base then
		notify(player, "Le serveur est plein, aucune base libre. Essaie un autre serveur !", "danger")
	end

	player.CharacterAdded:Connect(function()
		task.defer(teleportToBase, player)
	end)
	if player.Character then
		task.defer(teleportToBase, player)
	end

	notify(player, "Bienvenue ! Achète une créature sur le tapis roulant pour commencer 🐸", "info")
	pushState(player)
end

local function onPlayerRemoving(player)
	-- Le joueur part : on annule les vols qui le concernent
	endSteal(player, false, "dropped")
	for thief, steal in steals do
		if steal.victim == player then
			endSteal(thief, false, "dropped")
		end
	end

	local session = sessions[player]
	if session and session.base then
		local base = session.base
		for slotIndex in base.slots do
			clearSlot(base, slotIndex, false)
		end
		base.owner = nil
		base.shieldUntil = 0
		base.dome.Transparency = 1
		base.signLabel.Text = "Base libre"
		base.pendingLabel.Text = "💰 0"
		base.lockLabel.Text = "🔒 Verrou"
		base.lockPrompt:SetAttribute("OwnerId", 0)
		refreshPadColors(base)
	end
	sessions[player] = nil
	PlayerData.release(player)
end

---------------------------------------------------------------------
-- Robux : game passes et produits (voir le module Monetization)
---------------------------------------------------------------------
Monetization.start({
	sessions = sessions,
	notify = notify,
	notifyAll = notifyAll,
	pushState = pushState,
	addCoins = addCoins,
	applyWalkSpeed = applyWalkSpeed,
	refreshPadColors = refreshPadColors,
	findFreeSlot = findFreeSlot,
	placeCreature = placeCreature,
	pickWeighted = pickWeighted,
	rollMutation = rollMutation,
})

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
