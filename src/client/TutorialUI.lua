--[[
	TutorialUI.lua

	One-line prompt near the top of the screen, guiding a brand-new player through their
	first egg. The "stage" is derived fresh from the current PlayerData snapshot every time
	(not tracked step-by-step) - see the comment below for why that's safe and simpler.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIHelpers = require(script.Parent.UIHelpers)

local TutorialUI = {}

local label
local hasShownComplete = false

local function hasAny(dict)
	for _ in dict do
		return true
	end
	return false
end

-- Each stage's condition stays true forever once reached (collecting fills the Index,
-- which satisfies every earlier stage's "OR" too) - so recomputing from scratch each time
-- naturally never regresses, even though CarriedEggs/Incubators empty out again later.
local function computeStage(data)
	local carrying = hasAny(data.CarriedEggs)
	local incubating = false
	for _, slot in data.Incubators do
		if slot then
			incubating = true
			break
		end
	end
	local discovered = hasAny(data.Index)

	if discovered then
		return 3
	elseif incubating then
		return 2
	elseif carrying then
		return 1
	end
	return 0
end

local MESSAGES = {
	[0] = "Walk to the nest and grab an egg!",
	[1] = "Carry it home to an incubator!",
	[2] = "Wait for it to hatch (or use \xF0\x9F\x9B\xA0 Debug to skip)!",
	[3] = "Nice! Check your \xF0\x9F\x93\x96 Index, then grab more eggs.",
}

function TutorialUI.Init(gui: ScreenGui)
	label = Instance.new("TextLabel")
	label.Name = "TutorialPrompt"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 16)
	label.Size = UDim2.new(0.85, 0, 0, 36)
	label.BackgroundColor3 = UIHelpers.Colors.PanelBackground
	label.BackgroundTransparency = 0.15
	label.TextColor3 = UIHelpers.Colors.Text
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.ZIndex = 15
	label.Text = MESSAGES[0]
	label.Parent = gui
	UIHelpers.RoundCorner(label, 10)

	Remotes.Get("PlayerDataUpdated").OnClientEvent:Connect(function(data)
		local stage = computeStage(data)
		label.Text = MESSAGES[stage]

		if stage == 3 and not hasShownComplete then
			hasShownComplete = true
			task.delay(6, function()
				label.Visible = false
			end)
		elseif stage < 3 then
			label.Visible = true
		end
	end)
end

return TutorialUI
