--[[
	UIHelpers.lua

	The UI design system: colors, buttons, cards, progress bars, and the creature
	ViewportFrame used by the Index / Reveal / Incubator screens.

	CONTRAST RULE: every text color here is paired with a background that clears 4.5:1
	(WCAG AA). The old bar failed this badly - dark grey text on a dark panel - so the
	palette below is built around two safe pairings and nothing else:
	  * INK text on a BRIGHT button  (yellow / sky / coral / mint)  -> 6:1 or better
	  * WHITE text on the DARK PANEL                                -> ~16:1
	Never put Ink on Panel, or White on a bright button.

	TOUCH TARGETS: nothing interactive is built smaller than 44x44 px (Apple/Android
	minimum). The button factory enforces a 56 px default height.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local UIHelpers = {}

UIHelpers.MIN_TOUCH = 44
UIHelpers.BUTTON_HEIGHT = 56

UIHelpers.Colors = {
	-- dark surfaces (pair with TextOnDark)
	Panel = Color3.fromRGB(30, 34, 51),
	PanelRaised = Color3.fromRGB(44, 50, 72),
	Scrim = Color3.fromRGB(8, 9, 14),

	-- bright buttons (pair with Ink)
	Primary = Color3.fromRGB(255, 198, 61), -- sunny yellow
	Secondary = Color3.fromRGB(79, 195, 247), -- sky
	Success = Color3.fromRGB(107, 212, 126),
	Danger = Color3.fromRGB(255, 107, 107),
	Neutral = Color3.fromRGB(206, 212, 226),

	-- text
	Ink = Color3.fromRGB(22, 22, 31), -- on bright buttons
	TextOnDark = Color3.fromRGB(245, 247, 250), -- on Panel
	TextMutedOnDark = Color3.fromRGB(188, 196, 214), -- still ~9:1 on Panel
}

-- How far in from the screen edge to keep everything, so nothing lands under a notch,
-- a home indicator, or the Roblox top bar.
function UIHelpers.SafeInsets()
	local topInset, bottomInset = GuiService:GetGuiInset()
	return {
		Top = math.max(topInset.Y, 12) + 8,
		Bottom = math.max(bottomInset.Y, 0) + 24,
		Side = 16,
	}
end

function UIHelpers.Corner(instance, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 14)
	c.Parent = instance
	return c
end

function UIHelpers.Pad(instance, px)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = instance
	return p
end

function UIHelpers.Stroke(instance, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = instance
	return s
end

--[[
	Big, tappable, high-contrast button. Always Ink text on a bright fill.
	`opts`: { color, text, icon, height, layoutOrder, width }
]]
function UIHelpers.Button(parent, opts)
	local fill = opts.color or UIHelpers.Colors.Primary
	local height = math.max(opts.height or UIHelpers.BUTTON_HEIGHT, UIHelpers.MIN_TOUCH)

	local b = Instance.new("TextButton")
	b.Name = opts.name or "Button"
	b.BackgroundColor3 = fill
	b.AutoButtonColor = false -- we animate the pressed state ourselves, below
	b.Text = (opts.icon and (opts.icon .. "  ") or "") .. (opts.text or "")
	b.TextColor3 = UIHelpers.Colors.Ink
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.Size = opts.width and UDim2.new(0, opts.width, 0, height) or UDim2.new(1, 0, 0, height)
	b.LayoutOrder = opts.layoutOrder or 0
	b.AutoLocalize = false
	b.Parent = parent

	UIHelpers.Corner(b, 14)
	-- a slightly darker lip under the fill makes it read as a physical, chunky button
	UIHelpers.Stroke(b, Color3.new(fill.R * 0.62, fill.G * 0.62, fill.B * 0.62), 2.5)

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.PaddingTop = UDim.new(0, 9)
	padding.PaddingBottom = UDim.new(0, 9)
	padding.Parent = b

	local sizeConstraint = Instance.new("UITextSizeConstraint")
	sizeConstraint.MaxTextSize = 26
	sizeConstraint.MinTextSize = 13
	sizeConstraint.Parent = b

	-- VISIBLE pressed state: shrink + darken, so a tap feels like it registered even
	-- before the server answers.
	local function press()
		TweenService:Create(b, TweenInfo.new(0.07), {
			BackgroundColor3 = Color3.new(fill.R * 0.82, fill.G * 0.82, fill.B * 0.82),
			Size = b.Size - UDim2.fromOffset(0, 4),
		}):Play()
	end
	local function release()
		TweenService:Create(b, TweenInfo.new(0.12), {
			BackgroundColor3 = fill,
			Size = opts.width and UDim2.new(0, opts.width, 0, height) or UDim2.new(1, 0, 0, height),
		}):Play()
	end
	b.MouseButton1Down:Connect(press)
	b.MouseButton1Up:Connect(release)
	b.MouseLeave:Connect(release)
	b.TouchLongPress:Connect(release)

	if opts.onClick then
		b.Activated:Connect(opts.onClick)
	end
	return b
end

-- Text that always sits on the dark panel.
function UIHelpers.Label(parent, text, opts)
	opts = opts or {}
	local l = Instance.new("TextLabel")
	l.Name = opts.name or "Label"
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = opts.muted and UIHelpers.Colors.TextMutedOnDark or UIHelpers.Colors.TextOnDark
	l.Font = opts.bold and Enum.Font.FredokaOne or Enum.Font.GothamMedium
	l.TextScaled = true
	l.TextXAlignment = opts.align or Enum.TextXAlignment.Center
	l.Size = opts.size or UDim2.new(1, 0, 0, 28)
	l.LayoutOrder = opts.layoutOrder or 0
	l.AutoLocalize = false
	l.Parent = parent

	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = opts.maxTextSize or 22
	c.MinTextSize = 11
	c.Parent = l
	return l
end

-- Rounded progress bar. Returns a function(alpha 0..1) to drive it.
function UIHelpers.ProgressBar(parent, fillColor)
	local track = Instance.new("Frame")
	track.Name = "ProgressTrack"
	track.BackgroundColor3 = UIHelpers.Colors.Scrim
	track.BackgroundTransparency = 0.25
	track.Size = UDim2.new(1, 0, 0, 12)
	track.Parent = parent
	UIHelpers.Corner(track, 6)

	local fill = Instance.new("Frame")
	fill.Name = "ProgressFill"
	fill.BackgroundColor3 = fillColor or UIHelpers.Colors.Success
	fill.Size = UDim2.fromScale(0, 1)
	fill.BorderSizePixel = 0
	fill.Parent = track
	UIHelpers.Corner(fill, 6)

	return track, function(alpha)
		fill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
	end
end

--[[
	A ViewportFrame showing one creature model. This is how the 12 models actually
	become visible to the player - they live in ReplicatedStorage and are never in
	the world otherwise.

	`silhouette = true` paints every part flat black (used for undiscovered Index
	entries and for the first beat of the reveal).
]]
function UIHelpers.CreatureViewport(parent, creatureId, silhouette)
	local vp = Instance.new("ViewportFrame")
	vp.Name = "CreatureView"
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.Ambient = silhouette and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(190, 190, 200)
	vp.LightColor = Color3.fromRGB(255, 255, 255)
	vp.LightDirection = Vector3.new(-0.4, -1, -0.6)
	vp.Parent = parent

	local template = ReplicatedStorage:FindFirstChild("CreatureModels")
	template = template and template:FindFirstChild(creatureId)
	if not template then
		-- Model missing (e.g. Config ID and model name drifted apart) - fail visibly in
		-- the UI rather than silently showing an empty box.
		UIHelpers.Label(vp, "?", { bold = true })
		return vp, nil
	end

	local model = template:Clone()
	if silhouette then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Color = Color3.fromRGB(16, 16, 22)
				d.Material = Enum.Material.SmoothPlastic
				d.Transparency = d.Transparency > 0.5 and 0.4 or 0
			end
		end
	end
	model.Parent = vp

	-- Frame the camera so the whole model fits, whatever its proportions.
	local cf, size = model:GetBoundingBox()
	local maxExtent = math.max(size.X, size.Y, size.Z)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 50
	local distance = (maxExtent * 1.5) / math.tan(math.rad(cam.FieldOfView * 0.5))
	cam.CFrame = CFrame.new(cf.Position + Vector3.new(distance * 0.42, maxExtent * 0.42, distance * 0.78), cf.Position)
	cam.Parent = vp
	vp.CurrentCamera = cam

	return vp, model
end

-- Formats seconds as H:MM:SS / M:SS.
function UIHelpers.FormatDuration(totalSeconds)
	totalSeconds = math.max(0, math.floor(totalSeconds))
	local h = math.floor(totalSeconds / 3600)
	local m = math.floor((totalSeconds % 3600) / 60)
	local s = totalSeconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

return UIHelpers
