-- Entry point for all client UI. Boots every screen, in dependency order (panels before
-- the HUD, since HUD's buttons toggle them; RevealUI before nest interaction, since a
-- successful grab shows the reveal).
local Players = game:GetService("Players")

local RevealUI = require(script.Parent.RevealUI)
local IncubatorUI = require(script.Parent.IncubatorUI)
local IndexUI = require(script.Parent.IndexUI)
local DebugPanelUI = require(script.Parent.DebugPanelUI)
local TutorialUI = require(script.Parent.TutorialUI)
local NestInteractionUI = require(script.Parent.NestInteractionUI)
local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "EggHeistGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false

-- MUST be Sibling. A new ScreenGui defaults to Global here, which compares ZIndex across
-- the WHOLE gui tree instead of among siblings - so a panel's contents (ZIndex 1) rendered
-- and received input UNDERNEATH its own full-screen scrim (ZIndex 20). Every button inside
-- every panel was unclickable, and taps fell through to the scrim and closed the panel.
-- Caught in the Part B playtest. With Sibling, children are always layered above their
-- parent's siblings, which is what all the panel code assumes.
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

gui.Parent = playerGui

RevealUI.Init(gui)
IncubatorUI.Init(gui)
IndexUI.Init(gui)
DebugPanelUI.Init(gui)
TutorialUI.Init(gui)
NestInteractionUI.Init(gui)
HUD.Init(gui)

print("[Egg Heist Arena] Client booted:", os.date("%X"))
