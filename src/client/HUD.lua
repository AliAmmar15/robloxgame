--[[
	HUD.lua

	Always-on bottom bar: Index button, Incubators button, carried-egg count. Also the
	small debug toggle button, tucked in a corner (see DebugPanelUI.lua - the button is
	always shown, but the server rejects every action unless Studio or whitelisted, so
	showing it to everyone is harmless, just occasionally a dead button for randoms).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIHelpers = require(script.Parent.UIHelpers)
local IncubatorUI = require(script.Parent.IncubatorUI)
local IndexUI = require(script.Parent.IndexUI)
local DebugPanelUI = require(script.Parent.DebugPanelUI)

local HUD = {}

function HUD.Init(gui: ScreenGui)
	local bar = Instance.new("Frame")
	bar.Name = "HUDBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -16)
	bar.Size = UDim2.new(0.9, 0, 0, 64)
	bar.BackgroundColor3 = UIHelpers.Colors.PanelBackground
	bar.BackgroundTransparency = 0.1
	bar.ZIndex = 10
	bar.Parent = gui
	UIHelpers.RoundCorner(bar, 16)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = bar

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = bar

	local incubatorButton = UIHelpers.MakeButton(bar, "🥚 Incubators", function()
		IncubatorUI.Toggle()
	end)
	incubatorButton.Size = UDim2.new(0.45, 0, 0, 48)

	local indexButton = UIHelpers.MakeButton(bar, "📖 Index", function()
		IndexUI.Toggle()
	end)
	indexButton.Size = UDim2.new(0.45, 0, 0, 48)
	indexButton.BackgroundColor3 = UIHelpers.Colors.ButtonBackgroundSecondary

	-- Small carried-egg counter, top-left, out of the way of the raid/reveal action.
	local carryLabel = UIHelpers.MakeLabel(gui, "", 18)
	carryLabel.Name = "CarryCountLabel"
	carryLabel.Position = UDim2.new(0, 16, 0, 16)
	carryLabel.Size = UDim2.new(0, 220, 0, 26)
	carryLabel.TextXAlignment = Enum.TextXAlignment.Left
	carryLabel.BackgroundTransparency = 1
	carryLabel.ZIndex = 10

	-- Small debug toggle, top-right corner, out of the way.
	local debugButton = Instance.new("TextButton")
	debugButton.Name = "DebugToggle"
	debugButton.AnchorPoint = Vector2.new(1, 0)
	debugButton.Position = UDim2.new(1, -12, 0, 12)
	debugButton.Size = UDim2.new(0, 44, 0, 44)
	debugButton.BackgroundColor3 = UIHelpers.Colors.ButtonBackgroundSecondary
	debugButton.BackgroundTransparency = 0.3
	debugButton.Text = "🛠"
	debugButton.TextScaled = true
	debugButton.ZIndex = 10
	debugButton.Parent = gui
	UIHelpers.RoundCorner(debugButton, 10)
	debugButton.Activated:Connect(function()
		DebugPanelUI.Toggle()
	end)

	Remotes.Get("PlayerDataUpdated").OnClientEvent:Connect(function(data)
		local count = 0
		for _ in data.CarriedEggs do
			count += 1
		end
		carryLabel.Text = count > 0 and ("Carrying: " .. count .. " egg" .. (count > 1 and "s" or "")) or ""
	end)
end

return HUD
