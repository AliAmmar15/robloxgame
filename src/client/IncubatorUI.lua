--[[
	IncubatorUI.lua

	One card per incubator slot. Each card shows the actual creature model (it was
	already revealed at pickup, so there's nothing to hide here), its name in its
	rarity color, a progress bar, and the time left - or a big Collect button.

	Opening the panel is allowed from anywhere; placing/collecting still goes through
	the real server remotes with full validation (see docs/CONTRACTS.md).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIHelpers = require(script.Parent.UIHelpers)

local IncubatorUI = {}

local root, scrim
local cards = {} -- slotIndex -> widget table
local latestData

local function firstCarriedEgg()
	if not latestData then
		return nil, nil
	end
	for eggId, egg in latestData.CarriedEggs do
		return eggId, egg
	end
	return nil, nil
end

local function setViewport(card, creatureId)
	if card.currentCreature == creatureId then
		return
	end
	card.currentCreature = creatureId
	for _, c in card.ViewportHolder:GetChildren() do
		if c:IsA("ViewportFrame") or c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	if creatureId then
		UIHelpers.CreatureViewport(card.ViewportHolder, creatureId, false)
	else
		local q = UIHelpers.Label(card.ViewportHolder, "—", { bold = true, muted = true })
		q.Size = UDim2.fromScale(1, 1)
	end
end

local function renderSlot(slotIndex)
	local card = cards[slotIndex]
	if not card or not latestData then
		return
	end
	local incubating = latestData.Incubators[slotIndex]

	if not incubating then
		setViewport(card, nil)
		card.Title.Text = "Empty slot " .. slotIndex
		card.Title.TextColor3 = UIHelpers.Colors.TextOnDark
		card.Track.Visible = false

		local eggId, egg = firstCarriedEgg()
		if eggId then
			local creature = Config.CreatureById[egg.CreatureId]
			card.Subtitle.Text = "Ready to place"
			card.Action.Visible = true
			card.Action.Text = "Place " .. (creature and creature.Name or egg.CreatureId)
			card.Action.BackgroundColor3 = UIHelpers.Colors.Primary
			card.action = function()
				Remotes.Get("PlaceInIncubator"):InvokeServer(eggId, slotIndex)
			end
		else
			card.Subtitle.Text = "Raid the den for an egg"
			card.Action.Visible = false
			card.action = nil
		end
		return
	end

	local creature = Config.CreatureById[incubating.CreatureId]
	local rarityColor = Config.RarityColor[incubating.Rarity] or UIHelpers.Colors.TextOnDark
	setViewport(card, incubating.CreatureId)

	card.Title.Text = creature and creature.Name or incubating.CreatureId
	card.Title.TextColor3 = rarityColor

	local remaining = incubating.HatchAt - os.time()
	if remaining <= 0 then
		card.Subtitle.Text = incubating.Rarity .. " · ready!"
		card.Track.Visible = false
		card.Action.Visible = true
		card.Action.Text = "✨ Collect"
		card.Action.BackgroundColor3 = UIHelpers.Colors.Success
		card.action = function()
			Remotes.Get("CollectHatch"):InvokeServer(slotIndex)
		end
	else
		local total = math.max(1, incubating.HatchAt - incubating.StartedAt)
		card.Subtitle.Text = incubating.Rarity .. " · " .. UIHelpers.FormatDuration(remaining) .. " left"
		card.Track.Visible = true
		card.setProgress(1 - (remaining / total))
		card.Action.Visible = false
		card.action = nil
	end
end

local function renderAll()
	for slotIndex in cards do
		renderSlot(slotIndex)
	end
end

local function buildCard(parent, slotIndex)
	local card = Instance.new("Frame")
	card.Name = "Slot" .. slotIndex
	card.BackgroundColor3 = UIHelpers.Colors.PanelRaised
	card.Size = UDim2.new(1, 0, 0, 112)
	card.LayoutOrder = slotIndex
	card.Parent = parent
	UIHelpers.Corner(card, 16)

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = card

	local viewportHolder = Instance.new("Frame")
	viewportHolder.Name = "ViewportHolder"
	viewportHolder.BackgroundColor3 = UIHelpers.Colors.Panel
	viewportHolder.Size = UDim2.new(0, 92, 1, 0)
	viewportHolder.Parent = card
	UIHelpers.Corner(viewportHolder, 12)

	local info = Instance.new("Frame")
	info.Name = "Info"
	info.BackgroundTransparency = 1
	info.Position = UDim2.new(0, 102, 0, 0)
	info.Size = UDim2.new(1, -102, 1, 0)
	info.Parent = card

	local infoLayout = Instance.new("UIListLayout")
	infoLayout.FillDirection = Enum.FillDirection.Vertical
	infoLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	infoLayout.Padding = UDim.new(0, 5)
	infoLayout.Parent = info

	local title = UIHelpers.Label(info, "Empty slot", {
		bold = true, align = Enum.TextXAlignment.Left,
		size = UDim2.new(1, 0, 0, 26), maxTextSize = 22, layoutOrder = 1,
	})
	local subtitle = UIHelpers.Label(info, "", {
		muted = true, align = Enum.TextXAlignment.Left,
		size = UDim2.new(1, 0, 0, 18), maxTextSize = 15, layoutOrder = 2,
	})

	local trackHolder = Instance.new("Frame")
	trackHolder.Name = "TrackHolder"
	trackHolder.BackgroundTransparency = 1
	trackHolder.Size = UDim2.new(1, 0, 0, 12)
	trackHolder.LayoutOrder = 3
	trackHolder.Parent = info
	local track, setProgress = UIHelpers.ProgressBar(trackHolder, UIHelpers.Colors.Secondary)

	local action = UIHelpers.Button(info, {
		name = "Action",
		text = "Place",
		color = UIHelpers.Colors.Primary,
		height = 44,
		layoutOrder = 4,
	})
	action.Size = UDim2.new(1, 0, 0, 44)

	local widget = {
		Frame = card,
		ViewportHolder = viewportHolder,
		Title = title,
		Subtitle = subtitle,
		Track = track,
		setProgress = setProgress,
		Action = action,
		action = nil,
		currentCreature = false,
	}
	action.Activated:Connect(function()
		if widget.action then
			widget.action()
		end
	end)
	cards[slotIndex] = widget
	return widget
end

function IncubatorUI.Init(gui)
	scrim = Instance.new("TextButton")
	scrim.Name = "IncubatorScrim"
	scrim.BackgroundColor3 = UIHelpers.Colors.Scrim
	scrim.BackgroundTransparency = 0.35
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.Text = ""
	scrim.AutoButtonColor = false
	scrim.Visible = false
	scrim.ZIndex = 20
	scrim.Parent = gui
	scrim.Activated:Connect(function()
		IncubatorUI.Toggle()
	end)

	local insets = UIHelpers.SafeInsets()

	root = Instance.new("Frame")
	root.Name = "IncubatorPanel"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.new(1, -insets.Side * 2, 0, 330)
	root.BackgroundColor3 = UIHelpers.Colors.Panel
	root.Visible = false
	root.ZIndex = 21
	root.Parent = scrim
	UIHelpers.Corner(root, 20)

	local cap = Instance.new("UISizeConstraint")
	cap.MaxSize = Vector2.new(520, math.huge)
	cap.Parent = root

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = root

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 44)
	header.Parent = root

	local title = UIHelpers.Label(header, "Incubators", {
		bold = true, align = Enum.TextXAlignment.Left,
		size = UDim2.new(1, -60, 1, 0), maxTextSize = 28,
	})
	title.Position = UDim2.new(0, 4, 0, 0)

	local close = UIHelpers.Button(header, {
		name = "Close", text = "✕", color = UIHelpers.Colors.Neutral,
		height = 44, width = 44,
		onClick = function() IncubatorUI.Toggle() end,
	})
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, 0, 0.5, 0)

	local list = Instance.new("Frame")
	list.Name = "Slots"
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0, 0, 0, 52)
	list.Size = UDim2.new(1, 0, 1, -52)
	list.Parent = root

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.Padding = UDim.new(0, 10)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list

	for slotIndex = 1, Config.IncubatorSlotCount do
		buildCard(list, slotIndex)
	end

	Remotes.Get("PlayerDataUpdated").OnClientEvent:Connect(function(data)
		latestData = data
		renderAll()
	end)
	Remotes.Get("IncubatorUpdated").OnClientEvent:Connect(function(incubators)
		if latestData then
			latestData.Incubators = incubators
		end
		renderAll()
	end)
	Remotes.Get("HatchReady").OnClientEvent:Connect(renderAll)

	-- countdowns have to tick between server pushes
	task.spawn(function()
		while true do
			task.wait(1)
			if root.Visible then
				renderAll()
			end
		end
	end)
end

function IncubatorUI.Toggle()
	if not root then
		return
	end
	local show = not root.Visible
	root.Visible = show
	scrim.Visible = show
	if show then
		renderAll()
	end
end

function IncubatorUI.IsOpen()
	return root and root.Visible
end

return IncubatorUI
