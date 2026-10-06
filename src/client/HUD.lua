--[[
	HUD.lua

	Always-on screen furniture:
	  * bottom bar  - Incubators / Index (big, bright, Ink-on-yellow / Ink-on-sky)
	  * top-left    - free-egg counter + countdown to the next one
	  * top-right   - debug button, hidden unless the SERVER says this player may use it

	The old bottom bar was dark text on a dark panel and was effectively unreadable.
	Everything here now goes through UIHelpers.Button, which only produces Ink-on-bright.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIHelpers = require(script.Parent.UIHelpers)
local IncubatorUI = require(script.Parent.IncubatorUI)
local IndexUI = require(script.Parent.IndexUI)
local DebugPanelUI = require(script.Parent.DebugPanelUI)

local HUD = {}

local player = Players.LocalPlayer
local eggCountLabel, eggTimerLabel, carryLabel
local latestData

local function refreshEggPill()
	if not latestData then
		return
	end
	local stock = latestData.FreeEgg.Stockpile
	eggCountLabel.Text = "🥚 " .. stock .. " / " .. Config.FreeEgg.StockpileCap

	if stock >= Config.FreeEgg.StockpileCap then
		eggTimerLabel.Text = "FULL"
	else
		-- NOTE: uses the normal cooldown. If a tester has the debug "shorten all timers"
		-- toggle on, the server is using 10s and this line will read high until the next
		-- server push corrects the stockpile. Debug-only cosmetic drift, not a logic bug.
		local nextAt = latestData.FreeEgg.LastClaimedAt + Config.FreeEgg.CooldownSeconds
		eggTimerLabel.Text = "next " .. UIHelpers.FormatDuration(nextAt - os.time())
	end

	local carrying = 0
	for _ in latestData.CarriedEggs do
		carrying += 1
	end
	carryLabel.Text = carrying > 0 and ("Carrying " .. carrying .. (carrying > 1 and " eggs" or " egg")) or ""
	carryLabel.Visible = carrying > 0
end

function HUD.Init(gui)
	local insets = UIHelpers.SafeInsets()

	-- ===== BOTTOM BAR =====
	local bar = Instance.new("Frame")
	bar.Name = "HUDBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -insets.Bottom)
	bar.Size = UDim2.new(1, -insets.Side * 2, 0, 64)
	bar.BackgroundTransparency = 1
	bar.ZIndex = 10
	bar.Parent = gui

	local maxWidth = Instance.new("UISizeConstraint")
	maxWidth.MaxSize = Vector2.new(560, math.huge) -- don't stretch absurdly wide on tablets
	maxWidth.Parent = bar

	local barLayout = Instance.new("UIListLayout")
	barLayout.FillDirection = Enum.FillDirection.Horizontal
	barLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	barLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	barLayout.Padding = UDim.new(0, 12)
	barLayout.Parent = bar

	local incubatorBtn = UIHelpers.Button(bar, {
		name = "IncubatorsButton",
		text = "Incubators",
		icon = "🥚",
		color = UIHelpers.Colors.Primary,
		layoutOrder = 1,
		onClick = function()
			IncubatorUI.Toggle()
		end,
	})
	incubatorBtn.Size = UDim2.new(0.5, -6, 0, 60)

	local indexBtn = UIHelpers.Button(bar, {
		name = "IndexButton",
		text = "Index",
		icon = "📖",
		color = UIHelpers.Colors.Secondary,
		layoutOrder = 2,
		onClick = function()
			IndexUI.Toggle()
		end,
	})
	indexBtn.Size = UDim2.new(0.5, -6, 0, 60)

	-- ===== TOP-LEFT: free egg pill =====
	local pill = Instance.new("Frame")
	pill.Name = "FreeEggPill"
	pill.Position = UDim2.new(0, insets.Side, 0, insets.Top)
	pill.Size = UDim2.new(0, 150, 0, 48)
	pill.BackgroundColor3 = UIHelpers.Colors.Panel
	pill.BackgroundTransparency = 0.08
	pill.ZIndex = 10
	pill.Parent = gui
	UIHelpers.Corner(pill, 14)
	UIHelpers.Stroke(pill, UIHelpers.Colors.PanelRaised, 2)

	local pillLayout = Instance.new("UIListLayout")
	pillLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	pillLayout.Padding = UDim.new(0, 1)
	pillLayout.Parent = pill
	UIHelpers.Pad(pill, 7)

	eggCountLabel = UIHelpers.Label(pill, "🥚 0 / " .. Config.FreeEgg.StockpileCap, {
		bold = true, size = UDim2.new(1, 0, 0, 20), maxTextSize = 18,
	})
	eggTimerLabel = UIHelpers.Label(pill, "", {
		muted = true, size = UDim2.new(1, 0, 0, 14), maxTextSize = 13,
	})

	-- carried-egg readout, directly under the pill (never overlaps the objective banner)
	carryLabel = UIHelpers.Label(gui, "", {
		bold = true,
		align = Enum.TextXAlignment.Left,
		size = UDim2.new(0, 190, 0, 20),
		maxTextSize = 16,
	})
	carryLabel.Name = "CarryCountLabel"
	carryLabel.Position = UDim2.new(0, insets.Side + 4, 0, insets.Top + 54)
	carryLabel.TextColor3 = UIHelpers.Colors.Primary
	carryLabel.TextStrokeTransparency = 0.4
	carryLabel.TextStrokeColor3 = UIHelpers.Colors.Scrim
	carryLabel.ZIndex = 10
	carryLabel.Visible = false

	-- ===== TOP-RIGHT: debug toggle (visibility driven by the server attribute) =====
	local debugBtn = UIHelpers.Button(gui, {
		name = "DebugToggle",
		text = "🛠",
		color = UIHelpers.Colors.Neutral,
		height = 48,
		width = 48,
		onClick = function()
			DebugPanelUI.Toggle()
		end,
	})
	debugBtn.AnchorPoint = Vector2.new(1, 0)
	debugBtn.Position = UDim2.new(1, -insets.Side, 0, insets.Top)
	debugBtn.ZIndex = 10

	-- The SERVER sets DebugAllowed (Studio or whitelisted UserId only). The client never
	-- decides this for itself - and even if someone forces this button visible, every
	-- debug remote re-checks authorization server-side anyway.
	local function syncDebugVisibility()
		local allowed = player:GetAttribute("DebugAllowed") == true
		debugBtn.Visible = allowed
		if not allowed then
			DebugPanelUI.ForceHide()
		end
	end
	player:GetAttributeChangedSignal("DebugAllowed"):Connect(syncDebugVisibility)
	syncDebugVisibility()

	Remotes.Get("PlayerDataUpdated").OnClientEvent:Connect(function(data)
		latestData = data
		refreshEggPill()
	end)

	-- the free-egg countdown has to tick on its own between server pushes
	task.spawn(function()
		while true do
			task.wait(1)
			refreshEggPill()
		end
	end)
end

return HUD
