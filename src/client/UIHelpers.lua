--[[
	UIHelpers.lua

	Small shared helpers so every UI screen looks consistent (big mobile-friendly buttons,
	rounded corners, readable text) without copy-pasting the same styling code everywhere.
	UI-internal only - no other role needs to know this file exists.
]]

local UIHelpers = {}

UIHelpers.Colors = {
	PanelBackground = Color3.fromRGB(28, 28, 34),
	ButtonBackground = Color3.fromRGB(55, 110, 200),
	ButtonBackgroundSecondary = Color3.fromRGB(70, 70, 80),
	Text = Color3.fromRGB(245, 245, 245),
	TextDim = Color3.fromRGB(180, 180, 185),
}

function UIHelpers.RoundCorner(instance: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = instance
	return corner
end

-- A big, readable, mobile-friendly button. `callback` runs on Activated (works for touch,
-- mouse, and gamepad alike).
function UIHelpers.MakeButton(parent: Instance, text: string, callback: () -> ())
	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.AutoButtonColor = true
	button.BackgroundColor3 = UIHelpers.Colors.ButtonBackground
	button.Text = text
	button.TextColor3 = UIHelpers.Colors.Text
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.Size = UDim2.new(1, 0, 0, 56) -- 56px tall: comfortably tappable on a phone
	button.Parent = parent

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = button

	UIHelpers.RoundCorner(button)

	if callback then
		button.Activated:Connect(callback)
	end

	return button
end

function UIHelpers.MakeLabel(parent: Instance, text: string, textSize: number?)
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = UIHelpers.Colors.Text
	label.Font = Enum.Font.Gotham
	label.TextScaled = true
	label.Size = UDim2.new(1, 0, 0, textSize or 32)
	label.Parent = parent
	return label
end

-- Formats whole seconds as "H:MM:SS" / "M:SS", trimming unneeded leading units.
function UIHelpers.FormatDuration(totalSeconds: number): string
	totalSeconds = math.max(0, math.floor(totalSeconds))
	local hours = math.floor(totalSeconds / 3600)
	local minutes = math.floor((totalSeconds % 3600) / 60)
	local seconds = totalSeconds % 60

	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, seconds)
	end
	return string.format("%d:%02d", minutes, seconds)
end

return UIHelpers
