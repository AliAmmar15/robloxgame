--[[
	TutorialUI.lua

	Two things that answer the same question ("what do I do next?"):
	  * a one-line objective banner at the top of the screen
	  * a glowing beam on the ground from the player to the next objective

	The stage is recomputed from the current PlayerData snapshot every time rather than
	tracked step-by-step. Each stage's condition stays true once reached (collecting fills
	the Index, which also satisfies every earlier stage), so recomputing can never regress.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIHelpers = require(script.Parent.UIHelpers)

local TutorialUI = {}

local player = Players.LocalPlayer
local banner
local beam, originAttachment, targetAttachment, beamHolder
local currentStage = -1

-- One line each, as short as they can be and still be unambiguous.
local MESSAGES = {
	[0] = "Head into the den and grab an egg!",
	[1] = "Carry it home to an incubator!",
	[2] = "It's hatching — tap 🥚 Incubators to check the timer",
	[3] = "Collect your creature!",
	[4] = "Nice! Grab another egg — 📖 Index tracks your collection",
}

local function hasAny(dict)
	for _ in dict do
		return true
	end
	return false
end

local function computeStage(data)
	local carrying = hasAny(data.CarriedEggs)
	local incubating, ready = false, false
	for _, slot in data.Incubators do
		if slot then
			incubating = true
			if os.time() >= slot.HatchAt then
				ready = true
			end
		end
	end
	local discovered = hasAny(data.Index)

	if ready then
		return 3
	elseif discovered and not carrying and not incubating then
		return 4
	elseif incubating then
		return 2
	elseif carrying then
		return 1
	elseif discovered then
		return 4
	end
	return 0
end

-- Where should the beam point for this stage?
local function targetPartForStage(stage)
	if stage == 0 or stage == 4 then
		-- nearest nest that still has its egg
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return nil
		end
		local best, bestDist
		for _, nest in CollectionService:GetTagged("NestSlot") do
			local egg = nest:FindFirstChild("Egg")
			local available = egg and egg:IsA("Model") and #egg:GetChildren() > 0
			if available then
				local d = (nest.Position - root.Position).Magnitude
				if not bestDist or d < bestDist then
					best, bestDist = nest, d
				end
			end
		end
		return best
	elseif stage == 1 or stage == 2 or stage == 3 then
		-- the first incubator slot (empty one preferred for stage 1)
		local slots = CollectionService:GetTagged("IncubatorSlot")
		table.sort(slots, function(a, b)
			return (a:GetAttribute("SlotIndex") or 0) < (b:GetAttribute("SlotIndex") or 0)
		end)
		return slots[1]
	end
	return nil
end

local function ensureBeam()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	if originAttachment and originAttachment.Parent ~= root then
		originAttachment:Destroy()
		originAttachment = nil
	end
	if not originAttachment then
		originAttachment = Instance.new("Attachment")
		originAttachment.Name = "ObjectiveBeamOrigin"
		originAttachment.Position = Vector3.new(0, -2, 0) -- near the feet, reads as a ground trail
		originAttachment.Parent = root
	end
	if not beamHolder then
		beamHolder = Instance.new("Part")
		beamHolder.Name = "ObjectiveBeamTarget"
		beamHolder.Anchored = true
		beamHolder.CanCollide = false
		beamHolder.CanQuery = false
		beamHolder.Transparency = 1
		beamHolder.Size = Vector3.new(1, 1, 1)
		beamHolder.Parent = workspace
		targetAttachment = Instance.new("Attachment")
		targetAttachment.Parent = beamHolder
	end
	if not beam then
		beam = Instance.new("Beam")
		beam.Name = "ObjectiveBeam"
		beam.Attachment0 = originAttachment
		beam.Attachment1 = targetAttachment
		beam.Width0 = 1.6
		beam.Width1 = 1.6
		beam.FaceCamera = true
		beam.LightEmission = 0.75
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(0.85, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.Parent = beamHolder
	end
	beam.Attachment0 = originAttachment
	return true
end

local function updateBeam(stage)
	if not ensureBeam() then
		return
	end
	local target = targetPartForStage(stage)
	if not target then
		beam.Enabled = false
		return
	end
	beamHolder.Position = target.Position + Vector3.new(0, 1.5, 0)
	beam.Enabled = true

	-- color the beam by what it's pointing at: yellow = go get an egg, cyan = go home
	local goingHome = (stage == 1 or stage == 2 or stage == 3)
	local c = goingHome and Color3.fromRGB(120, 230, 235) or Color3.fromRGB(255, 205, 80)
	beam.Color = ColorSequence.new(c)
end

function TutorialUI.Init(gui)
	local insets = UIHelpers.SafeInsets()

	banner = Instance.new("TextLabel")
	banner.Name = "TutorialPrompt"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, insets.Top)
	banner.Size = UDim2.new(1, -(insets.Side * 2 + 220), 0, 44)
	banner.BackgroundColor3 = UIHelpers.Colors.Panel
	banner.BackgroundTransparency = 0.08
	banner.TextColor3 = UIHelpers.Colors.TextOnDark
	banner.Font = Enum.Font.FredokaOne
	banner.TextScaled = true
	banner.Text = MESSAGES[0]
	banner.ZIndex = 12
	banner.AutoLocalize = false
	banner.Parent = gui
	UIHelpers.Corner(banner, 14)
	UIHelpers.Stroke(banner, UIHelpers.Colors.PanelRaised, 2)

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = banner

	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 20
	cap.MinTextSize = 11
	cap.Parent = banner

	local maxWidth = Instance.new("UISizeConstraint")
	maxWidth.MaxSize = Vector2.new(420, math.huge)
	maxWidth.Parent = banner

	local function apply(data)
		local stage = computeStage(data)
		currentStage = stage
		banner.Text = MESSAGES[stage] or MESSAGES[0]
		updateBeam(stage)
	end

	Remotes.Get("PlayerDataUpdated").OnClientEvent:Connect(apply)

	-- The beam target moves (nests respawn, the player walks), and stage 2 -> 3 flips on a
	-- timer rather than on a data push, so re-evaluate on a slow tick too.
	task.spawn(function()
		while true do
			task.wait(1)
			if currentStage >= 0 then
				updateBeam(currentStage)
			end
		end
	end)

	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		if currentStage >= 0 then
			updateBeam(currentStage)
		end
	end)
end

return TutorialUI
