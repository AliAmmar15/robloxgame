--[[
	DebugPanelUI.lua

	Test tools panel: force a rarity, skip a slot's timer, shorten all timers to 10s, give a
	free egg, reset my data. The button is always visible (see HUD.lua) but every action goes
	through a real server remote that checks Studio-or-whitelisted - see DebugService.lua and
	Config.DebugWhitelist. This file does NOT gate anything itself; it can't, the client can
	never be trusted for that.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIHelpers = require(script.Parent.UIHelpers)

local DebugPanelUI = {}

local frame
local statusLabel
local shortTimersEnabled = false

local function setStatus(text: string)
	statusLabel.Text = text
end

local function callDebugRemote(remoteName: string, ...)
	local result = Remotes.Get(remoteName):InvokeServer(...)
	if result.ok then
		setStatus(remoteName .. ": OK")
	else
		setStatus(remoteName .. " failed: " .. tostring(result.error))
	end
	return result
end

function DebugPanelUI.Init(gui: ScreenGui)
	frame = Instance.new("Frame")
	frame.Name = "DebugPanel"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.new(0.9, 0, 0.8, 0)
	frame.BackgroundColor3 = UIHelpers.Colors.PanelBackground
	frame.Visible = false
	frame.ZIndex = 30
	frame.Parent = gui
	UIHelpers.RoundCorner(frame, 18)

	local title = UIHelpers.MakeLabel(frame, "Debug Tools", 26)
	title.Font = Enum.Font.GothamBold
	title.Position = UDim2.new(0, 0, 0, 10)
	title.Size = UDim2.new(1, 0, 0, 34)

	local closeButton = UIHelpers.MakeButton(frame, "Close", function()
		frame.Visible = false
	end)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -10, 0, 10)
	closeButton.Size = UDim2.new(0, 90, 0, 36)
	closeButton.BackgroundColor3 = UIHelpers.Colors.ButtonBackgroundSecondary

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "Scroller"
	scroller.BackgroundTransparency = 1
	scroller.Position = UDim2.new(0, 0, 0, 54)
	scroller.Size = UDim2.new(1, 0, 1, -64)
	scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 8
	scroller.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 10)
	layout.Parent = scroller

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = scroller

	-- Force rarity: one row of 6 buttons.
	local forceLabel = UIHelpers.MakeLabel(scroller, "Force next egg's rarity:", 18)
	forceLabel.TextXAlignment = Enum.TextXAlignment.Left
	forceLabel.Size = UDim2.new(1, 0, 0, 24)

	local forceRow = Instance.new("Frame")
	forceRow.BackgroundTransparency = 1
	forceRow.Size = UDim2.new(1, 0, 0, 44)
	forceRow.Parent = scroller
	local forceRowLayout = Instance.new("UIGridLayout")
	forceRowLayout.CellPadding = UDim2.new(0, 6, 0, 6)
	forceRowLayout.CellSize = UDim2.new(0.31, 0, 0, 40)
	forceRowLayout.Parent = forceRow

	for _, rarity in Config.Rarities do
		local button = UIHelpers.MakeButton(forceRow, rarity.Id, function()
			callDebugRemote("DebugForceRarity", rarity.Id)
		end)
		button.BackgroundColor3 = Config.RarityColor[rarity.Id]
		button.TextColor3 = Color3.new(0, 0, 0)
	end

	-- Skip timer: one button per incubator slot.
	local skipLabel = UIHelpers.MakeLabel(scroller, "Skip incubator timer:", 18)
	skipLabel.TextXAlignment = Enum.TextXAlignment.Left
	skipLabel.Size = UDim2.new(1, 0, 0, 24)

	for slotIndex = 1, Config.IncubatorSlotCount do
		UIHelpers.MakeButton(scroller, "Skip Slot " .. slotIndex, function()
			callDebugRemote("DebugSkipTimer", slotIndex)
		end)
	end

	-- Shorten all timers toggle.
	local shortTimersButton = UIHelpers.MakeButton(scroller, "Shorten All Timers: OFF", function()
		shortTimersEnabled = not shortTimersEnabled
		local result = callDebugRemote("DebugSetShortTimers", shortTimersEnabled)
		if result.ok then
			shortTimersButton.Text = "Shorten All Timers: " .. (shortTimersEnabled and "ON" or "OFF")
		else
			shortTimersEnabled = not shortTimersEnabled -- revert on failure
		end
	end)

	UIHelpers.MakeButton(scroller, "Give Free Egg Now", function()
		callDebugRemote("DebugGiveFreeEgg")
	end)

	local resetButton = UIHelpers.MakeButton(scroller, "Reset My Data", function()
		callDebugRemote("DebugResetData")
	end)
	resetButton.BackgroundColor3 = Color3.fromRGB(200, 70, 70)

	statusLabel = UIHelpers.MakeLabel(scroller, "", 16)
	statusLabel.TextColor3 = UIHelpers.Colors.TextDim
	statusLabel.Size = UDim2.new(1, 0, 0, 40)
	statusLabel.TextWrapped = true
end

function DebugPanelUI.Toggle()
	if frame then
		frame.Visible = not frame.Visible
	end
end

return DebugPanelUI
