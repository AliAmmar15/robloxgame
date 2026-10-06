--[[
	IncubatorUI.lua

	The incubator panel: 2 slots, each showing empty / counting down / ready-to-collect.
	Tapping an empty slot places whichever carried egg comes first (simple and fine for a
	2-slot prototype); tapping a ready slot collects it. Reachable from the HUD from
	anywhere - see CONTRACTS.md's "scope simplification for today" note.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIHelpers = require(script.Parent.UIHelpers)

local IncubatorUI = {}

local frame
local slotFrames = {} -- slotIndex -> { Container, NameLabel, StatusLabel, ActionButton }
local latestData = nil -- most recent full PlayerData from the server

local function firstCarriedEgg(data)
	for eggId, egg in data.CarriedEggs do
		return eggId, egg
	end
	return nil, nil
end

local function renderSlot(slotIndex)
	local widgets = slotFrames[slotIndex]
	if not widgets or not latestData then
		return
	end

	local incubating = latestData.Incubators[slotIndex]

	if not incubating then
		local eggId, egg = firstCarriedEgg(latestData)
		if eggId then
			local creature = Config.CreatureById[egg.CreatureId]
			widgets.NameLabel.Text = "Empty slot"
			widgets.StatusLabel.Text = "Tap to place: " .. (creature and creature.Name or egg.CreatureId)
			widgets.ActionButton.Text = "Place Egg"
			widgets.ActionButton.Visible = true
			widgets.ActionButton.Active = true
		else
			widgets.NameLabel.Text = "Empty slot"
			widgets.StatusLabel.Text = "Grab an egg to fill this"
			widgets.ActionButton.Visible = false
		end
		return
	end

	local creature = Config.CreatureById[incubating.CreatureId]
	widgets.NameLabel.Text = creature and creature.Name or incubating.CreatureId
	widgets.NameLabel.TextColor3 = Config.RarityColor[incubating.Rarity] or UIHelpers.Colors.Text

	local remaining = incubating.HatchAt - os.time()
	if remaining <= 0 then
		widgets.StatusLabel.Text = "Ready to hatch!"
		widgets.ActionButton.Text = "Collect"
		widgets.ActionButton.Visible = true
		widgets.ActionButton.Active = true
	else
		widgets.StatusLabel.Text = UIHelpers.FormatDuration(remaining) .. " remaining"
		widgets.ActionButton.Visible = false
	end
end

local function renderAll()
	for slotIndex in slotFrames do
		renderSlot(slotIndex)
	end
end

local function handleSlotAction(slotIndex)
	if not latestData then
		return
	end
	local incubating = latestData.Incubators[slotIndex]

	if incubating then
		if os.time() >= incubating.HatchAt then
			Remotes.Get("CollectHatch"):InvokeServer(slotIndex)
			-- no need to manually refresh here - the server's PlayerDataUpdated push does it
		end
		return
	end

	local eggId = firstCarriedEgg(latestData)
	if eggId then
		Remotes.Get("PlaceInIncubator"):InvokeServer(eggId, slotIndex)
	end
end

function IncubatorUI.Init(gui: ScreenGui)
	frame = Instance.new("Frame")
	frame.Name = "IncubatorPanel"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.new(0.85, 0, 0.5, 0)
	frame.BackgroundColor3 = UIHelpers.Colors.PanelBackground
	frame.Visible = false
	frame.ZIndex = 20
	frame.Parent = gui
	UIHelpers.RoundCorner(frame, 18)

	local title = UIHelpers.MakeLabel(frame, "Incubators", 30)
	title.Font = Enum.Font.GothamBold
	title.Position = UDim2.new(0, 0, 0, 10)
	title.Size = UDim2.new(1, 0, 0, 40)

	local closeButton = UIHelpers.MakeButton(frame, "Close", function()
		frame.Visible = false
	end)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -10, 0, 10)
	closeButton.Size = UDim2.new(0, 90, 0, 36)
	closeButton.BackgroundColor3 = UIHelpers.Colors.ButtonBackgroundSecondary

	local slotsContainer = Instance.new("Frame")
	slotsContainer.Name = "Slots"
	slotsContainer.BackgroundTransparency = 1
	slotsContainer.Position = UDim2.new(0, 0, 0, 60)
	slotsContainer.Size = UDim2.new(1, 0, 1, -70)
	slotsContainer.Parent = frame

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.Padding = UDim.new(0, 12)
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.Parent = slotsContainer

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = slotsContainer

	for slotIndex = 1, Config.IncubatorSlotCount do
		local container = Instance.new("Frame")
		container.Name = "Slot" .. slotIndex
		container.BackgroundColor3 = UIHelpers.Colors.ButtonBackgroundSecondary
		container.Size = UDim2.new(1, 0, 0, 90)
		container.Parent = slotsContainer
		UIHelpers.RoundCorner(container, 12)

		local innerPadding = Instance.new("UIPadding")
		innerPadding.PaddingLeft = UDim.new(0, 14)
		innerPadding.PaddingRight = UDim.new(0, 14)
		innerPadding.PaddingTop = UDim.new(0, 8)
		innerPadding.Parent = container

		local nameLabel = UIHelpers.MakeLabel(container, "Empty slot", 22)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Size = UDim2.new(0.6, 0, 0, 30)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left

		local statusLabel = UIHelpers.MakeLabel(container, "", 18)
		statusLabel.Position = UDim2.new(0, 0, 0, 32)
		statusLabel.Size = UDim2.new(0.6, 0, 0, 24)
		statusLabel.TextColor3 = UIHelpers.Colors.TextDim
		statusLabel.TextXAlignment = Enum.TextXAlignment.Left

		local actionButton = UIHelpers.MakeButton(container, "Place Egg", function()
			handleSlotAction(slotIndex)
		end)
		actionButton.AnchorPoint = Vector2.new(1, 0.5)
		actionButton.Position = UDim2.new(1, 0, 0.5, 0)
		actionButton.Size = UDim2.new(0, 140, 0, 50)
		actionButton.Visible = false

		slotFrames[slotIndex] = {
			Container = container,
			NameLabel = nameLabel,
			StatusLabel = statusLabel,
			ActionButton = actionButton,
		}
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

	Remotes.Get("HatchReady").OnClientEvent:Connect(function()
		renderAll() -- an incubator just became ready - refresh so "Collect" appears immediately
	end)

	-- Countdown labels need to tick down even when nothing has changed server-side.
	task.spawn(function()
		while true do
			task.wait(1)
			if frame.Visible then
				renderAll()
			end
		end
	end)
end

function IncubatorUI.Toggle()
	if frame then
		frame.Visible = not frame.Visible
		if frame.Visible then
			renderAll()
		end
	end
end

return IncubatorUI
