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
gui.Parent = playerGui

RevealUI.Init(gui)
IncubatorUI.Init(gui)
IndexUI.Init(gui)
DebugPanelUI.Init(gui)
TutorialUI.Init(gui)
NestInteractionUI.Init(gui)
HUD.Init(gui)

print("[Egg Heist Arena] Client booted:", os.date("%X"))
