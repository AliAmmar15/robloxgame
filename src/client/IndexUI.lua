--[[
	IndexUI.lua

	A grid of all 12 creatures. Undiscovered ones render as flat black silhouettes
	labelled "???"; discovered ones render in full color with their name and rarity.

	The viewports are built lazily on first open and only rebuilt when a tile's
	discovered-state actually flips, so opening the Index doesn't re-create 12 3D
	scenes every time.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIHelpers = require(script.Parent.UIHelpers)

local IndexUI = {}

local root, scrim, grid, counterLabel
local tiles = {} -- creatureId -> { Frame, Name, Rarity, Holder, built (bool|nil) }
local latestIndex = {}
local built = false

local function renderTile(creatureId)
	local tile = tiles[creatureId]
	if not tile then
		return
	end
	local creature = Config.CreatureById[creatureId]
	local discovered = latestIndex[creatureId] == true

	-- only rebuild the 3D view if the state actually changed
	if tile.builtAs ~= discovered then
		tile.builtAs = discovered
		for _, c in tile.Holder:GetChildren() do
			if c:IsA("ViewportFrame") then
				c:Destroy()
			end
		end
		UIHelpers.CreatureViewport(tile.Holder, creatureId, not discovered)
	end

	if discovered then
		tile.Name.Text = creature.Name
		tile.Name.TextColor3 = Config.RarityColor[creature.Rarity] or UIHelpers.Colors.TextOnDark
		tile.Rarity.Text = creature.Rarity
		tile.Rarity.Visible = true
		tile.Frame.BackgroundColor3 = UIHelpers.Colors.PanelRaised
	else
		tile.Name.Text = "???"
		tile.Name.TextColor3 = UIHelpers.Colors.TextMutedOnDark
		tile.Rarity.Visible = false
		tile.Frame.BackgroundColor3 = UIHelpers.Colors.Panel
	end
end

local function renderAll()
	local found = 0
	for creatureId in tiles do
		renderTile(creatureId)
		if latestIndex[creatureId] == true then
			found += 1
		end
	end
	if counterLabel then
		counterLabel.Text = found .. " / " .. #Config.Creatures .. " discovered"
	end
end

local function buildGrid()
	if built then
		return
	end
	built = true
	for _, creature in Config.Creatures do
		local tile = Instance.new("Frame")
		tile.Name = creature.Id
		tile.BackgroundColor3 = UIHelpers.Colors.Panel
		tile.Parent = grid
		UIHelpers.Corner(tile, 14)

		local holder = Instance.new("Frame")
		holder.Name = "Holder"
		holder.BackgroundTransparency = 1
		holder.Position = UDim2.new(0, 0, 0, 4)
		holder.Size = UDim2.new(1, 0, 1, -40)
		holder.Parent = tile

		local name = UIHelpers.Label(tile, "???", {
			bold = true, size = UDim2.new(1, -8, 0, 18), maxTextSize = 14,
		})
		name.AnchorPoint = Vector2.new(0.5, 1)
		name.Position = UDim2.new(0.5, 0, 1, -18)

		local rarity = UIHelpers.Label(tile, "", {
			muted = true, size = UDim2.new(1, -8, 0, 14), maxTextSize = 12,
		})
		rarity.AnchorPoint = Vector2.new(0.5, 1)
		rarity.Position = UDim2.new(0.5, 0, 1, -3)

		tiles[creature.Id] = {
			Frame = tile, Holder = holder, Name = name, Rarity = rarity, builtAs = nil,
		}
	end
end

function IndexUI.Init(gui)
	scrim = Instance.new("TextButton")
	scrim.Name = "IndexScrim"
	scrim.BackgroundColor3 = UIHelpers.Colors.Scrim
	scrim.BackgroundTransparency = 0.35
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.Text = ""
	scrim.AutoButtonColor = false
	scrim.Visible = false
	scrim.ZIndex = 20
	scrim.Parent = gui
	scrim.Activated:Connect(function()
		IndexUI.Toggle()
	end)

	local insets = UIHelpers.SafeInsets()

	root = Instance.new("Frame")
	root.Name = "IndexPanel"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.new(1, -insets.Side * 2, 1, -(insets.Top + insets.Bottom + 70))
	root.BackgroundColor3 = UIHelpers.Colors.Panel
	root.Visible = false
	root.ZIndex = 21
	root.Parent = scrim
	UIHelpers.Corner(root, 20)

	local cap = Instance.new("UISizeConstraint")
	cap.MaxSize = Vector2.new(560, 720)
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

	local title = UIHelpers.Label(header, "Creature Index", {
		bold = true, align = Enum.TextXAlignment.Left,
		size = UDim2.new(1, -60, 0, 26), maxTextSize = 26,
	})
	title.Position = UDim2.new(0, 4, 0, 0)

	counterLabel = UIHelpers.Label(header, "0 / " .. #Config.Creatures .. " discovered", {
		muted = true, align = Enum.TextXAlignment.Left,
		size = UDim2.new(1, -60, 0, 16), maxTextSize = 14,
	})
	counterLabel.Position = UDim2.new(0, 4, 0, 26)

	local close = UIHelpers.Button(header, {
		name = "Close", text = "✕", color = UIHelpers.Colors.Neutral,
		height = 44, width = 44,
		onClick = function() IndexUI.Toggle() end,
	})
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, 0, 0.5, 0)

	grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.new(0, 0, 0, 52)
	grid.Size = UDim2.new(1, 0, 1, -52)
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = UIHelpers.Colors.TextMutedOnDark
	grid.Parent = root

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
	gridLayout.CellSize = UDim2.new(0.32, -6, 0, 132)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	Remotes.Get("PlayerDataUpdated").OnClientEvent:Connect(function(data)
		latestIndex = data.Index or {}
		if built then
			renderAll()
		end
	end)
end

function IndexUI.Toggle()
	if not root then
		return
	end
	local show = not root.Visible
	root.Visible = show
	scrim.Visible = show
	if show then
		buildGrid()
		renderAll()
	end
end

function IndexUI.IsOpen()
	return root and root.Visible
end

return IndexUI
