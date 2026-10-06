--[[
	IndexUI.lua

	The Index screen: a grid of all 12 creatures. Discovered ones show their name and
	rarity color; undiscovered ones show "???" silhouettes. Reads straight from
	data.Index (a set of discovered CreatureIds) on every PlayerDataUpdated push.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIHelpers = require(script.Parent.UIHelpers)

local IndexUI = {}

local frame
local tileByCreatureId = {} -- creatureId -> { Container, NameLabel }

local function renderTile(creatureId, discovered)
	local tile = tileByCreatureId[creatureId]
	if not tile then
		return
	end
	local creature = Config.CreatureById[creatureId]

	if discovered then
		tile.Container.BackgroundColor3 = Config.RarityColor[creature.Rarity] or UIHelpers.Colors.ButtonBackgroundSecondary
		tile.NameLabel.Text = creature.Name
		tile.RarityLabel.Text = creature.Rarity
	else
		tile.Container.BackgroundColor3 = UIHelpers.Colors.ButtonBackgroundSecondary
		tile.NameLabel.Text = "???"
		tile.RarityLabel.Text = ""
	end
end

local function renderAll(index)
	for creatureId in tileByCreatureId do
		renderTile(creatureId, index[creatureId] == true)
	end
end

function IndexUI.Init(gui: ScreenGui)
	frame = Instance.new("Frame")
	frame.Name = "IndexPanel"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.new(0.9, 0, 0.75, 0)
	frame.BackgroundColor3 = UIHelpers.Colors.PanelBackground
	frame.Visible = false
	frame.ZIndex = 20
	frame.Parent = gui
	UIHelpers.RoundCorner(frame, 18)

	local title = UIHelpers.MakeLabel(frame, "Creature Index", 30)
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

	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.new(0, 0, 0, 60)
	grid.Size = UDim2.new(1, 0, 1, -70)
	grid.CanvasSize = UDim2.new(0, 0, 0, 0) -- grown automatically by UIGridLayout below
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollBarThickness = 8
	grid.Parent = frame

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	gridLayout.CellSize = UDim2.new(0.31, 0, 0, 110) -- ~3 columns, readable on a phone
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = grid

	for _, creature in Config.Creatures do
		local container = Instance.new("Frame")
		container.Name = creature.Id
		container.BackgroundColor3 = UIHelpers.Colors.ButtonBackgroundSecondary
		container.Parent = grid
		UIHelpers.RoundCorner(container, 10)

		local nameLabel = UIHelpers.MakeLabel(container, "???", 18)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Position = UDim2.new(0, 0, 0.3, 0)
		nameLabel.Size = UDim2.new(1, 0, 0, 24)

		local rarityLabel = UIHelpers.MakeLabel(container, "", 14)
		rarityLabel.Position = UDim2.new(0, 0, 0.6, 0)
		rarityLabel.Size = UDim2.new(1, 0, 0, 18)
		rarityLabel.TextColor3 = UIHelpers.Colors.TextDim

		tileByCreatureId[creature.Id] = {
			Container = container,
			NameLabel = nameLabel,
			RarityLabel = rarityLabel,
		}
	end

	Remotes.Get("PlayerDataUpdated").OnClientEvent:Connect(function(data)
		renderAll(data.Index)
	end)
end

function IndexUI.Toggle()
	if frame then
		frame.Visible = not frame.Visible
	end
end

return IndexUI
