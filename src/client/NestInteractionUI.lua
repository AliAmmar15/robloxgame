--[[
	NestInteractionUI.lua

	Puts a ProximityPrompt on every NestSlot-tagged part and wires it to GrabEgg.

	Nests are found by TAG and the script also listens for tags added later, so changing
	how many nests exist (3 -> 6 -> whatever) needs no code change here. The server does
	the real distance/state validation regardless of what the prompt allowed.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIHelpers = require(script.Parent.UIHelpers)
local RevealUI = require(script.Parent.RevealUI)

local NestInteractionUI = {}

local toast
local wired = {} -- nest part -> true

local function showToast(text)
	if not toast then
		return
	end
	toast.Text = text
	toast.Visible = true
	task.delay(2.2, function()
		if toast.Text == text then
			toast.Visible = false
		end
	end)
end

-- A quick client-side sparkle at the nest, so a successful grab feels physical even
-- though the egg itself is removed by the server.
local function sparkle(position)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.Position = position
	p.Parent = workspace

	local att = Instance.new("Attachment")
	att.Parent = p

	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Rate = 0
	e.Speed = NumberRange.new(6, 11)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.1),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Color = ColorSequence.new(Color3.fromRGB(255, 232, 150))
	e.LightEmission = 0.8
	e.Parent = att
	e:Emit(26)

	task.delay(1.4, function()
		p:Destroy()
	end)
end

local function wireNest(nestPart)
	if wired[nestPart] then
		return
	end
	local nestIndex = nestPart:GetAttribute("NestIndex")
	if not nestIndex then
		warn("[NestInteractionUI] NestSlot part with no NestIndex: " .. nestPart:GetFullName())
		return
	end
	wired[nestPart] = true

	local existing = nestPart:FindFirstChild("GrabEggPrompt")
	if existing then
		existing:Destroy()
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GrabEggPrompt"
	prompt.ActionText = "Grab Egg"
	prompt.ObjectText = "Nest"
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = nestPart

	prompt.Triggered:Connect(function()
		prompt.Enabled = false -- block double-fire while the request is in flight
		local okCall, result = pcall(function()
			return Remotes.Get("GrabEgg"):InvokeServer(nestIndex)
		end)
		prompt.Enabled = true

		if not okCall then
			showToast("Something went wrong — try again")
			return
		end
		if result and result.ok then
			sparkle(nestPart.Position + Vector3.new(0, 2, 0))
			RevealUI.Show(result.creatureId, result.rarity)
		else
			showToast(tostring(result and result.error or "Could not grab that egg"))
		end
	end)
end

function NestInteractionUI.Init(gui)
	local insets = UIHelpers.SafeInsets()

	toast = UIHelpers.Label(gui, "", { bold = true, maxTextSize = 16 })
	toast.Name = "NestToast"
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -(insets.Bottom + 76))
	toast.Size = UDim2.new(0, 300, 0, 38)
	toast.BackgroundColor3 = UIHelpers.Colors.Panel
	toast.BackgroundTransparency = 0.05
	toast.TextColor3 = UIHelpers.Colors.Primary
	toast.Visible = false
	toast.ZIndex = 15
	UIHelpers.Corner(toast, 12)
	UIHelpers.Stroke(toast, UIHelpers.Colors.PanelRaised, 2)

	for _, nestPart in CollectionService:GetTagged("NestSlot") do
		wireNest(nestPart)
	end
	-- nests added after the client booted (map rebuild, streaming) get wired too
	CollectionService:GetInstanceAddedSignal("NestSlot"):Connect(wireNest)
	CollectionService:GetInstanceRemovedSignal("NestSlot"):Connect(function(nestPart)
		wired[nestPart] = nil
	end)
end

return NestInteractionUI
