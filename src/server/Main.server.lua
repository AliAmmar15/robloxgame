-- Entry point for all server code. Boots every service in order.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EggService = require(script.Parent.EggService)
local RaidService = require(script.Parent.RaidService)
local DebugService = require(script.Parent.DebugService)

Remotes.CreateAll()
PlayerDataService.Start()
EggService.Start()
RaidService.Start()
DebugService.Start()

print("[Egg Heist Arena] Server booted:", os.date("%X"))
