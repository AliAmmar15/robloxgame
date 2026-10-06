--[[
	RevealUI.lua

	Full-screen "you got an egg" reveal: rarity-colored glow, silhouette first, then the
	creature's name. Shown the instant a grab succeeds (see docs/CONTRACTS.md - the GDD is
	explicit that reveal happens at pickup, not at hatch). Tap anywhere to dismiss early.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local UIHelpers = require(script.Parent.UIHelpers)

local RevealUI = {}

local SILHOUETTE_SECONDS = 0.9
local AUTO_HIDE_SECONDS = 3.5

local frame

function RevealUI.Init(gui: ScreenGui)
	frame = Instance.new("Frame")
	frame.Name = "RevealFrame"
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = 0.3
	frame.Size = UDim2.fromScale(1, 1)
	frame.Visible = false
	frame.ZIndex = 50
	frame.Parent = gui

	local dismissButton = Instance.new("TextButton")
	dismissButton.Name = "DismissCatcher"
	dismissButton.BackgroundTransparency = 1
	dismissButton.Text = ""
	dismissButton.Size = UDim2.fromScale(1, 1)
	dismissButton.ZIndex = 50
	dismissButton.Parent = frame
	dismissButton.Activated:Connect(function()
		frame.Visible = false
	end)

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.45)
	card.Size = UDim2.new(0.8, 0, 0.4, 0)
	card.BackgroundColor3 = UIHelpers.Colors.PanelBackground
	card.ZIndex = 51
	card.Parent = frame
	UIHelpers.RoundCorner(card, 20)

	local glow = Instance.new("UIStroke")
	glow.Name = "Glow"
	glow.Thickness = 4
	glow.Color = Color3.fromRGB(255, 255, 255)
	glow.Parent = card

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = card

	local rarityLabel = UIHelpers.MakeLabel(card, "???", 28)
	rarityLabel.Name = "RarityLabel"
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.Size = UDim2.new(0.9, 0, 0, 36)

	local nameLabel = UIHelpers.MakeLabel(card, "???", 44)
	nameLabel.Name = "NameLabel"
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.Size = UDim2.new(0.9, 0, 0, 56)

	local hintLabel = UIHelpers.MakeLabel(card, "Carry it home to an incubator!", 20)
	hintLabel.Name = "HintLabel"
	hintLabel.TextColor3 = UIHelpers.Colors.TextDim
	hintLabel.Size = UDim2.new(0.9, 0, 0, 24)
end

-- Called right after a successful GrabEgg. rarity/creatureId come straight from the
-- server's response - never guessed or computed client-side.
function RevealUI.Show(creatureId: string, rarity: string)
	if not frame then
		return
	end

	local creature = Config.CreatureById[creatureId]
	local color = Config.RarityColor[rarity] or Color3.new(1, 1, 1)

	local card = frame.Card
	local glow = card.Glow
	local rarityLabel = card.RarityLabel
	local nameLabel = card.NameLabel

	card.BackgroundColor3 = UIHelpers.Colors.PanelBackground
	glow.Color = color
	rarityLabel.TextColor3 = color
	rarityLabel.Text = rarity
	nameLabel.Text = "???" -- silhouette stage: rarity + glow visible, name hidden

	frame.Visible = true
	glow.Transparency = 0
	local tween = TweenService:Create(glow, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Thickness = 8,
	})
	tween:Play()

	task.delay(SILHOUETTE_SECONDS, function()
		if frame.Visible then
			nameLabel.Text = creature and creature.Name or creatureId
		end
	end)

	task.delay(AUTO_HIDE_SECONDS, function()
		tween:Cancel()
		frame.Visible = false
	end)
end

return RevealUI
