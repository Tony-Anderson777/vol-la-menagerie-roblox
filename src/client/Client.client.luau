-- Client : tout ce que le joueur voit à l'écran (argent, messages, boutique Robux).
-- (LocalScript, à placer dans StarterPlayer > StarterPlayerScripts, nommé "Client")
--
-- Ce script ne décide de rien d'important : c'est le serveur qui gère l'argent et les créatures.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local StateUpdate = remotes:WaitForChild("StateUpdate")
local Notify = remotes:WaitForChild("Notify")

local format = Config.formatNumber

local COLORS = {
	panel = Color3.fromRGB(35, 28, 60),
	panelLight = Color3.fromRGB(55, 45, 90),
	text = Color3.fromRGB(255, 255, 255),
	gold = Color3.fromRGB(255, 205, 60),
	green = Color3.fromRGB(90, 220, 120),
	red = Color3.fromRGB(255, 90, 100),
	blue = Color3.fromRGB(90, 160, 255),
	orange = Color3.fromRGB(255, 160, 60),
}

---------------------------------------------------------------------
-- Petit outil pour créer des éléments d'interface
---------------------------------------------------------------------
local function create(className, props, children)
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

local function rounded(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

local function textLabel(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or COLORS.text
	props.TextScaled = true
	return create("TextLabel", props)
end

---------------------------------------------------------------------
-- L'écran
---------------------------------------------------------------------
local gui = create("ScreenGui", {
	Name = "MenagerieUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- En haut à gauche : argent et revenus
local statsFrame = create("Frame", {
	Size = UDim2.new(0, 230, 0, 96),
	Position = UDim2.new(0, 12, 0, 12),
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.15,
	Parent = gui,
}, { rounded(14), create("UIPadding", {
	PaddingLeft = UDim.new(0, 12),
	PaddingRight = UDim.new(0, 12),
	PaddingTop = UDim.new(0, 8),
	PaddingBottom = UDim.new(0, 8),
}) })

local coinsLabel = textLabel({
	Size = UDim2.new(1, 0, 0.45, 0),
	Text = "🪙 0",
	TextColor3 = COLORS.gold,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = statsFrame,
})
local incomeLabel = textLabel({
	Size = UDim2.new(1, 0, 0.27, 0),
	Position = UDim2.new(0, 0, 0.47, 0),
	Text = "+0 / s",
	TextColor3 = COLORS.green,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = statsFrame,
})
local slotsLabel = textLabel({
	Size = UDim2.new(1, 0, 0.24, 0),
	Position = UDim2.new(0, 0, 0.76, 0),
	Text = "🏠 0 / 10",
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = statsFrame,
})

-- Sous les stats : état du bouclier
local shieldLabel = textLabel({
	Size = UDim2.new(0, 230, 0, 26),
	Position = UDim2.new(0, 12, 0, 114),
	Text = "",
	TextColor3 = COLORS.blue,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = gui,
})

-- Bandeau quand on porte une créature volée
local carryBanner = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.new(0.6, 0, 0, 54),
	Position = UDim2.new(0.5, 0, 0, 70),
	BackgroundColor3 = COLORS.orange,
	Visible = false,
	Parent = gui,
}, { rounded(14), create("UISizeConstraint", { MaxSize = Vector2.new(520, 54) }) })
local carryLabel = textLabel({
	Size = UDim2.new(1, -20, 1, -10),
	Position = UDim2.new(0, 10, 0, 5),
	Text = "",
	Parent = carryBanner,
})

-- Messages qui apparaissent puis disparaissent
local toastHolder = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.new(0.6, 0, 0, 200),
	Position = UDim2.new(0.5, 0, 0, 132),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	create("UISizeConstraint", { MaxSize = Vector2.new(520, 200) }),
	create("UIListLayout", {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local TOAST_COLORS = {
	info = COLORS.panelLight,
	success = Color3.fromRGB(40, 150, 80),
	danger = Color3.fromRGB(190, 50, 60),
	warning = Color3.fromRGB(200, 120, 30),
	coins = Color3.fromRGB(170, 130, 20),
}
local toastCount = 0

local function showToast(text, kind)
	toastCount += 1
	local toast = create("Frame", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = TOAST_COLORS[kind] or TOAST_COLORS.info,
		LayoutOrder = toastCount,
		Parent = toastHolder,
	}, { rounded(10) })
	local label = textLabel({
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.new(0, 8, 0, 4),
		Text = text,
		Parent = toast,
	})
	-- Pas plus de 4 messages à la fois
	local toasts = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #toasts > 4 do
		table.remove(toasts, 1):Destroy()
	end
	task.delay(3.5, function()
		if toast.Parent then
			local info = TweenInfo.new(0.4)
			TweenService:Create(toast, info, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, info, { TextTransparency = 1 }):Play()
			task.wait(0.4)
			toast:Destroy()
		end
	end)
end

Notify.OnClientEvent:Connect(showToast)

---------------------------------------------------------------------
-- Boutique Robux
---------------------------------------------------------------------
local shopButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5),
	Size = UDim2.new(0, 130, 0, 54),
	Position = UDim2.new(1, -12, 0.5, 0),
	BackgroundColor3 = COLORS.gold,
	Text = "⭐ Boutique",
	TextColor3 = Color3.fromRGB(40, 30, 10),
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	Parent = gui,
}, { rounded(14), create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })

local shopPanel = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.new(0.9, 0, 0.8, 0),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	BackgroundColor3 = COLORS.panel,
	Visible = false,
	Parent = gui,
}, { rounded(16), create("UISizeConstraint", { MaxSize = Vector2.new(520, 560) }) })

textLabel({
	Size = UDim2.new(1, -80, 0, 44),
	Position = UDim2.new(0, 16, 0, 10),
	Text = "⭐ Boutique",
	TextColor3 = COLORS.gold,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = shopPanel,
})

local closeButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.new(0, 44, 0, 44),
	Position = UDim2.new(1, -10, 0, 10),
	BackgroundColor3 = COLORS.red,
	Text = "X",
	TextColor3 = COLORS.text,
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	Parent = shopPanel,
}, { rounded(10) })

local shopList = create("ScrollingFrame", {
	Size = UDim2.new(1, -24, 1, -74),
	Position = UDim2.new(0, 12, 0, 62),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 6,
	Parent = shopPanel,
}, { create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

local ownedPasses = {}
local buyButtons = {} -- [key] = { button, item }

local function idFor(item)
	if item.kind == "pass" then
		return Config.GamePasses[item.key] or 0
	end
	return Config.Products[item.key] or 0
end

local function refreshShopButtons()
	for _, entry in buyButtons do
		local item = entry.item
		local id = idFor(item)
		if item.kind == "pass" and ownedPasses[item.key] then
			entry.button.Text = "✅ Acquis"
			entry.button.BackgroundColor3 = COLORS.panelLight
		elseif id == 0 then
			entry.button.Text = "Bientôt"
			entry.button.BackgroundColor3 = COLORS.panelLight
		else
			entry.button.Text = entry.priceText or "Acheter"
			entry.button.BackgroundColor3 = COLORS.green
		end
	end
end

for order, item in Config.ShopItems do
	local row = create("Frame", {
		Size = UDim2.new(1, -8, 0, 76),
		BackgroundColor3 = COLORS.panelLight,
		LayoutOrder = order,
		Parent = shopList,
	}, { rounded(12) })
	textLabel({
		Size = UDim2.new(0.68, -12, 0, 30),
		Position = UDim2.new(0, 12, 0, 8),
		Text = item.title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	textLabel({
		Size = UDim2.new(0.68, -12, 0, 28),
		Position = UDim2.new(0, 12, 0, 40),
		Text = item.desc,
		Font = Enum.Font.Gotham,
		TextColor3 = Color3.fromRGB(210, 205, 230),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Parent = row,
	})
	local button = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.new(0.3, -8, 0, 46),
		Position = UDim2.new(1, -10, 0.5, 0),
		BackgroundColor3 = COLORS.green,
		Text = "Acheter",
		TextColor3 = COLORS.text,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		Parent = row,
	}, { rounded(10), create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }) })

	local entry = { button = button, item = item, priceText = nil }
	buyButtons[item.key] = entry

	button.Activated:Connect(function()
		local id = idFor(item)
		if id == 0 then
			showToast("Cet achat n'est pas encore configuré.", "info")
			return
		end
		if item.kind == "pass" then
			if not ownedPasses[item.key] then
				MarketplaceService:PromptGamePassPurchase(player, id)
			end
		else
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end)

	-- On va chercher le prix en Robux (si l'ID est configuré)
	local id = idFor(item)
	if id ~= 0 then
		task.spawn(function()
			local infoType = if item.kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, infoType)
			end)
			if ok and info and info.PriceInRobux then
				entry.priceText = "R$ " .. tostring(info.PriceInRobux)
				refreshShopButtons()
			end
		end)
	end
end
refreshShopButtons()

shopButton.Activated:Connect(function()
	shopPanel.Visible = not shopPanel.Visible
end)
closeButton.Activated:Connect(function()
	shopPanel.Visible = false
end)

---------------------------------------------------------------------
-- Mise à jour avec les infos du serveur
---------------------------------------------------------------------
StateUpdate.OnClientEvent:Connect(function(state)
	coinsLabel.Text = "🪙 " .. format(state.coins)
	incomeLabel.Text = "+" .. format(state.income) .. " / s"
	slotsLabel.Text = "🏠 Créatures : " .. state.used .. " / " .. state.max

	if state.shield > 0 then
		shieldLabel.Text = "🛡️ Base protégée : " .. state.shield .. " s"
	elseif state.lockCooldown > 0 then
		shieldLabel.Text = "⏳ Verrou dispo dans " .. state.lockCooldown .. " s"
	else
		shieldLabel.Text = "🔒 Verrou prêt (bouton bleu dans ta base)"
	end

	if state.carrying then
		carryBanner.Visible = true
		carryLabel.Text = "🏃 Ramène " .. state.carrying.name .. " dans ta base ! " .. state.carrying.timeLeft .. " s"
	else
		carryBanner.Visible = false
	end

	ownedPasses = state.passes or {}
	refreshShopButtons()
end)

---------------------------------------------------------------------
-- Boutons au-dessus des créatures : on n'affiche que ceux qui te concernent
-- ("Voler" sur les créatures des autres, "Vendre" sur les tiennes)
---------------------------------------------------------------------
local function hookPrompt(prompt)
	local function refresh()
		local kind = prompt:GetAttribute("Kind")
		local ownerId = prompt:GetAttribute("OwnerId") or 0
		if kind == "Steal" then
			prompt.Enabled = ownerId ~= 0 and ownerId ~= player.UserId
		elseif kind == "Sell" or kind == "Lock" then
			prompt.Enabled = ownerId == player.UserId
		end
	end
	refresh()
	prompt:GetAttributeChangedSignal("OwnerId"):Connect(refresh)
end

local world = Workspace:WaitForChild("Menagerie")
for _, descendant in world:GetDescendants() do
	if descendant:IsA("ProximityPrompt") then
		hookPrompt(descendant)
	end
end
world.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("ProximityPrompt") then
		hookPrompt(descendant)
	end
end)
