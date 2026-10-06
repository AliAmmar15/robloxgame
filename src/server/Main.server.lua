-- Entry point for all server code. Boots every service in order.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EggService = require(script.Parent.EggService)
local RaidService = require(script.Parent.RaidService)
local DebugService = require(script.Parent.DebugService)
local EventLog = require(script.Parent.EventLog)

Remotes.CreateAll()
PlayerDataService.Start()
EggService.Start()
RaidService.Start()
DebugService.Start()

Players.PlayerAdded:Connect(EventLog.Joined)
Players.PlayerRemoving:Connect(EventLog.Left)

print("[Egg Heist Arena] Server booted:", os.date("%X"))
