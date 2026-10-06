--[[
	NestInteractionUI.lua

	Adds a ProximityPrompt to every NestSlot part (built by World, found via CollectionService
	- never a hardcoded Workspace path). Triggering one calls GrabEgg; the server does the real
	distance/state validation regardless of what the prompt itself allowed, so this is purely
	about giving the player a mobile-friendly "hold to grab" button over each nest.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIHelpers = require(script.Parent.UIHelpers)
local RevealUI = require(script.Parent.RevealUI)

local NestInteractionUI = {}

local toastLabel

local function showToast(text: string)
	if not toastLabel then
		return
	end
	toastLabel.Text = text
	toastLabel.Visible = true
	task.delay(2, function()
		if toastLabel.Text == text then
			toastLabel.Visible = false
		end
	end)
end

local function setupPrompt(nestPart: BasePart)
	local nestIndex = nestPart:GetAttribute("NestIndex")
	if not nestIndex then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GrabEggPrompt"
	prompt.ActionText = "Grab Egg"
	prompt.ObjectText = "Nest"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = nestPart

	prompt.Triggered:Connect(function()
		prompt.Enabled = false -- avoid double-fires while the request is in flight
		local result = Remotes.Get("GrabEgg"):InvokeServer(nestIndex)
		prompt.Enabled = true

		if result.ok then
			RevealUI.Show(result.creatureId, result.rarity)
		else
			showToast(tostring(result.error))
		end
	end)
end

function NestInteractionUI.Init(gui: ScreenGui)
	toastLabel = UIHelpers.MakeLabel(gui, "", 18)
	toastLabel.Name = "NestToast"
	toastLabel.AnchorPoint = Vector2.new(0.5, 1)
	toastLabel.Position = UDim2.new(0.5, 0, 1, -100)
	toastLabel.Size = UDim2.new(0.7, 0, 0, 30)
	toastLabel.BackgroundColor3 = UIHelpers.Colors.PanelBackground
	toastLabel.BackgroundTransparency = 0.2
	toastLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
	toastLabel.Visible = false
	toastLabel.ZIndex = 15
	UIHelpers.RoundCorner(toastLabel, 8)

	for _, nestPart in CollectionService:GetTagged("NestSlot") do
		setupPrompt(nestPart)
	end
end

return NestInteractionUI
