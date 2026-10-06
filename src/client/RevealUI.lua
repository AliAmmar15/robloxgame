--[[
	RevealUI.lua

	The egg-reveal moment, which the GDD calls the hook of the whole game:
	  1. screen dims, a rarity-colored ray burst starts spinning
	  2. the creature appears as a black SILHOUETTE (you know the rarity, not the shape)
	  3. it pops into full color, the name and a rarity banner slam in
	  4. tap anywhere to dismiss (it also auto-closes)

	Sound is per-rarity but the IDs in Config.RaritySound are placeholders
	(rbxassetid://0 = silent). Every beat above is carried by motion and color, so the
	reveal still reads correctly with no audio at all. See docs/SOUNDS.md.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local UIHelpers = require(script.Parent.UIHelpers)

local RevealUI = {}

local SILHOUETTE_SECONDS = 1.0
local AUTO_HIDE_SECONDS = 4.5
local RAY_COUNT = 12

local scrim, card, rays, viewportHolder, nameLabel, rarityBanner, sound
local spinConnection
local activeToken = 0

local function stopSpin()
	if spinConnection then
		spinConnection:Disconnect()
		spinConnection = nil
	end
end

local function hide()
	activeToken += 1
	stopSpin()
	scrim.Visible = false
end

-- Short FOV punch. Deliberately small and self-restoring so it never fights the
-- default camera script or leaves the player's view altered.
local function cameraNudge()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local base = cam.FieldOfView
	TweenService:Create(cam, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = base - 6,
	}):Play()
	task.delay(0.14, function()
		if cam and cam.Parent then
			TweenService:Create(cam, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				FieldOfView = base,
			}):Play()
		end
	end)
end

function RevealUI.Init(gui)
	sound = Instance.new("Sound")
	sound.Name = "RevealSound"
	sound.Parent = gui

	scrim = Instance.new("TextButton")
	scrim.Name = "RevealScrim"
	scrim.BackgroundColor3 = UIHelpers.Colors.Scrim
	scrim.BackgroundTransparency = 0.25
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.Text = ""
	scrim.AutoButtonColor = false
	scrim.Visible = false
	scrim.ZIndex = 50
	scrim.Parent = gui
	scrim.Activated:Connect(hide)

	-- spinning ray burst behind the card
	rays = Instance.new("Frame")
	rays.Name = "Rays"
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.46)
	rays.Size = UDim2.fromOffset(460, 460)
	rays.BackgroundTransparency = 1
	rays.ZIndex = 50
	rays.Parent = scrim
	for i = 1, RAY_COUNT do
		local ray = Instance.new("Frame")
		ray.Name = "Ray" .. i
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromOffset(14, 460)
		ray.Rotation = (i - 1) * (180 / RAY_COUNT)
		ray.BackgroundTransparency = 0.72
		ray.BorderSizePixel = 0
		ray.ZIndex = 50
		ray.Parent = rays
	end

	card = Instance.new("Frame")
	card.Name = "RevealCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.46)
	card.Size = UDim2.fromOffset(280, 320)
	card.BackgroundColor3 = UIHelpers.Colors.Panel
	card.ZIndex = 52
	card.Parent = scrim
	UIHelpers.Corner(card, 24)

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Name = "Glow"
	cardStroke.Thickness = 4
	cardStroke.Parent = card

	local cap = Instance.new("UISizeConstraint")
	cap.MaxSize = Vector2.new(320, 360)
	cap.Parent = card

	rarityBanner = Instance.new("TextLabel")
	rarityBanner.Name = "RarityBanner"
	rarityBanner.AnchorPoint = Vector2.new(0.5, 0)
	rarityBanner.Position = UDim2.new(0.5, 0, 0, 14)
	rarityBanner.Size = UDim2.new(1, -40, 0, 36)
	rarityBanner.BackgroundColor3 = Color3.new(1, 1, 1)
	rarityBanner.Text = "COMMON"
	rarityBanner.TextColor3 = UIHelpers.Colors.Ink
	rarityBanner.Font = Enum.Font.FredokaOne
	rarityBanner.TextScaled = true
	rarityBanner.ZIndex = 53
	rarityBanner.AutoLocalize = false
	rarityBanner.Parent = card
	UIHelpers.Corner(rarityBanner, 10)
	local bannerPad = Instance.new("UIPadding")
	bannerPad.PaddingTop = UDim.new(0, 5)
	bannerPad.PaddingBottom = UDim.new(0, 5)
	bannerPad.Parent = rarityBanner
	local bannerCap = Instance.new("UITextSizeConstraint")
	bannerCap.MaxTextSize = 22
	bannerCap.Parent = rarityBanner

	viewportHolder = Instance.new("Frame")
	viewportHolder.Name = "ViewportHolder"
	viewportHolder.AnchorPoint = Vector2.new(0.5, 0)
	viewportHolder.Position = UDim2.new(0.5, 0, 0, 58)
	viewportHolder.Size = UDim2.new(1, -24, 0, 190)
	viewportHolder.BackgroundTransparency = 1
	viewportHolder.ZIndex = 53
	viewportHolder.Parent = card

	nameLabel = UIHelpers.Label(card, "???", { bold = true, maxTextSize = 30 })
	nameLabel.Name = "NameLabel"
	nameLabel.AnchorPoint = Vector2.new(0.5, 1)
	nameLabel.Position = UDim2.new(0.5, 0, 1, -36)
	nameLabel.Size = UDim2.new(1, -20, 0, 34)
	nameLabel.ZIndex = 53

	local hint = UIHelpers.Label(card, "tap to continue", { muted = true, maxTextSize = 14 })
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -8)
	hint.Size = UDim2.new(1, -20, 0, 18)
	hint.ZIndex = 53
end

-- creatureId and rarity come straight from the server's GrabEgg response. The client
-- never picks or guesses either one.
function RevealUI.Show(creatureId, rarity)
	if not scrim then
		return
	end
	activeToken += 1
	local token = activeToken

	local creature = Config.CreatureById[creatureId]
	local color = Config.RarityColor[rarity] or Color3.new(1, 1, 1)

	-- paint everything in the rarity color
	card.Glow.Color = color
	rarityBanner.BackgroundColor3 = color
	rarityBanner.Text = string.upper(rarity)
	nameLabel.Text = "???"
	nameLabel.TextColor3 = UIHelpers.Colors.TextMutedOnDark
	for _, ray in rays:GetChildren() do
		ray.BackgroundColor3 = color
	end

	-- stage 1: SILHOUETTE
	for _, c in viewportHolder:GetChildren() do
		if c:IsA("ViewportFrame") or c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	UIHelpers.CreatureViewport(viewportHolder, creatureId, true)

	scrim.Visible = true
	card.Size = UDim2.fromOffset(280, 320)

	stopSpin()
	spinConnection = RunService.RenderStepped:Connect(function(dt)
		rays.Rotation = (rays.Rotation + dt * 26) % 360
	end)

	-- Only touch the Sound if a REAL asset id has been filled in. "rbxassetid://0" is the
	-- placeholder in Config.RaritySound, and trying to load it spams
	-- "Failed to load sound ... asset was not found" into the Output on every single
	-- reveal. Skipping it keeps the console clean until real IDs land (see docs/SOUNDS.md).
	local soundConfig = Config.RaritySound[rarity]
	local id = soundConfig and soundConfig.SoundId
	if id and id ~= "" and id ~= "rbxassetid://0" then
		sound.SoundId = id
		sound.Volume = soundConfig.Volume
		sound.PlaybackSpeed = soundConfig.Pitch
		pcall(function()
			sound:Play()
		end)
	end

	cameraNudge()

	-- stage 2: POP into full color + name
	task.delay(SILHOUETTE_SECONDS, function()
		if token ~= activeToken or not scrim.Visible then
			return
		end
		for _, c in viewportHolder:GetChildren() do
			if c:IsA("ViewportFrame") or c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		UIHelpers.CreatureViewport(viewportHolder, creatureId, false)

		nameLabel.Text = creature and creature.Name or creatureId
		nameLabel.TextColor3 = color

		-- overshoot pop
		card.Size = UDim2.fromOffset(250, 286)
		TweenService:Create(card, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(280, 320),
		}):Play()
		cameraNudge()
	end)

	task.delay(AUTO_HIDE_SECONDS, function()
		if token == activeToken then
			hide()
		end
	end)
end

function RevealUI.IsOpen()
	return scrim and scrim.Visible
end

return RevealUI
