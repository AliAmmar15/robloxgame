--[[
	DebugPanelUI.lua

	Test tools. VISIBILITY is driven by the server-set player attribute "DebugAllowed"
	(see HUD.lua and DebugService.lua) - the client never decides for itself whether it
	is allowed. Even if someone forced this panel open, every button below calls a real
	remote that re-checks Studio-or-whitelist authorization server-side, so a forced
	panel is a panel full of buttons that all return "not enabled for you".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIHelpers = require(script.Parent.UIHelpers)

local DebugPanelUI = {}

local scrim, root, statusLabel, shortTimersButton
local shortTimersOn = false

local function setStatus(text, ok)
	if not statusLabel then
		return
	end
	statusLabel.Text = text
	statusLabel.TextColor3 = ok and UIHelpers.Colors.Success or UIHelpers.Colors.Danger
end

local function call(remoteName, ...)
	local okCall, result = pcall(function(...)
		return Remotes.Get(remoteName):InvokeServer(...)
	end, ...)
	if not okCall then
		setStatus(remoteName .. ": call failed", false)
		return { ok = false }
	end
	if result and result.ok then
		setStatus(remoteName .. " ✓", true)
	else
		setStatus(remoteName .. ": " .. tostring(result and result.error or "failed"), false)
	end
	return result or { ok = false }
end

function DebugPanelUI.Init(gui)
	scrim = Instance.new("TextButton")
	scrim.Name = "DebugScrim"
	scrim.BackgroundColor3 = UIHelpers.Colors.Scrim
	scrim.BackgroundTransparency = 0.35
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.Text = ""
	scrim.AutoButtonColor = false
	scrim.Visible = false
	scrim.ZIndex = 30
	scrim.Parent = gui
	scrim.Activated:Connect(function()
		DebugPanelUI.Toggle()
	end)

	local insets = UIHelpers.SafeInsets()

	root = Instance.new("Frame")
	root.Name = "DebugPanel"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.new(1, -insets.Side * 2, 1, -(insets.Top + insets.Bottom + 50))
	root.BackgroundColor3 = UIHelpers.Colors.Panel
	root.Visible = false
	root.ZIndex = 31
	root.Parent = scrim
	UIHelpers.Corner(root, 20)

	local cap = Instance.new("UISizeConstraint")
	cap.MaxSize = Vector2.new(520, 700)
	cap.Parent = root
	UIHelpers.Pad(root, 12)

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 44)
	header.Parent = root

	local title = UIHelpers.Label(header, "🛠 Debug Tools", {
		bold = true, align = Enum.TextXAlignment.Left,
		size = UDim2.new(1, -60, 1, 0), maxTextSize = 24,
	})
	title.Position = UDim2.new(0, 4, 0, 0)

	local close = UIHelpers.Button(header, {
		name = "Close", text = "X", color = UIHelpers.Colors.Neutral,
		height = 44, width = 44,
		onClick = function() DebugPanelUI.Toggle() end,
	})
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, 0, 0.5, 0)

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "Scroller"
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Position = UDim2.new(0, 0, 0, 52)
	scroller.Size = UDim2.new(1, 0, 1, -52)
	scroller.CanvasSize = UDim2.new()
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 6
	scroller.ScrollBarImageColor3 = UIHelpers.Colors.TextMutedOnDark
	scroller.Parent = root

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroller

	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	-- ---- force rarity ----
	UIHelpers.Label(scroller, "Force next egg's rarity", {
		muted = true, align = Enum.TextXAlignment.Left,
		size = UDim2.new(1, 0, 0, 20), maxTextSize = 15, layoutOrder = nextOrder(),
	})

	local rarityRow = Instance.new("Frame")
	rarityRow.Name = "RarityRow"
	rarityRow.BackgroundTransparency = 1
	rarityRow.Size = UDim2.new(1, 0, 0, 104)
	rarityRow.LayoutOrder = nextOrder()
	rarityRow.Parent = scroller

	local rarityGrid = Instance.new("UIGridLayout")
	rarityGrid.CellPadding = UDim2.new(0, 6, 0, 6)
	rarityGrid.CellSize = UDim2.new(0.333, -6, 0, 48)
	rarityGrid.Parent = rarityRow

	for _, rarity in Config.Rarities do
		local b = UIHelpers.Button(rarityRow, {
			name = rarity.Id,
			text = rarity.Id,
			color = Config.RarityColor[rarity.Id],
			height = 48,
			onClick = function()
				call("DebugForceRarity", rarity.Id)
			end,
		})
		b.Size = UDim2.new(0.333, -6, 0, 48)
	end

	-- ---- skip timers ----
	UIHelpers.Label(scroller, "Incubators", {
		muted = true, align = Enum.TextXAlignment.Left,
		size = UDim2.new(1, 0, 0, 20), maxTextSize = 15, layoutOrder = nextOrder(),
	})
	for slotIndex = 1, Config.IncubatorSlotCount do
		UIHelpers.Button(scroller, {
			name = "SkipSlot" .. slotIndex,
			text = "Skip Slot " .. slotIndex .. " timer",
			color = UIHelpers.Colors.Secondary,
			layoutOrder = nextOrder(),
			onClick = function()
				call("DebugSkipTimer", slotIndex)
			end,
		})
	end

	shortTimersButton = UIHelpers.Button(scroller, {
		name = "ShortTimers",
		text = "Short timers: OFF",
		color = UIHelpers.Colors.Neutral,
		layoutOrder = nextOrder(),
	})
	shortTimersButton.Activated:Connect(function()
		local want = not shortTimersOn
		local result = call("DebugSetShortTimers", want)
		if result.ok then
			shortTimersOn = want
			shortTimersButton.Text = "Short timers: " .. (want and "ON (10s)" or "OFF")
			shortTimersButton.BackgroundColor3 = want and UIHelpers.Colors.Success or UIHelpers.Colors.Neutral
		end
	end)

	-- ---- eggs / data ----
	UIHelpers.Label(scroller, "Eggs & data", {
		muted = true, align = Enum.TextXAlignment.Left,
		size = UDim2.new(1, 0, 0, 20), maxTextSize = 15, layoutOrder = nextOrder(),
	})
	UIHelpers.Button(scroller, {
		name = "GiveEgg",
		text = "Give free egg now",
		color = UIHelpers.Colors.Primary,
		layoutOrder = nextOrder(),
		onClick = function()
			call("DebugGiveFreeEgg")
		end,
	})
	UIHelpers.Button(scroller, {
		name = "ResetData",
		text = "Reset my data",
		color = UIHelpers.Colors.Danger,
		layoutOrder = nextOrder(),
		onClick = function()
			call("DebugResetData")
		end,
	})

	statusLabel = UIHelpers.Label(scroller, "", {
		align = Enum.TextXAlignment.Left,
		size = UDim2.new(1, 0, 0, 36), maxTextSize = 14, layoutOrder = nextOrder(),
	})
	statusLabel.TextWrapped = true
end

function DebugPanelUI.Toggle()
	if not root then
		return
	end
	local show = not root.Visible
	root.Visible = show
	scrim.Visible = show
end

-- Called by HUD when the server says this player is NOT allowed to use debug tools.
function DebugPanelUI.ForceHide()
	if root then
		root.Visible = false
		scrim.Visible = false
	end
end

function DebugPanelUI.IsOpen()
	return root and root.Visible
end

return DebugPanelUI
