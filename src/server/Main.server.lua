-- Entry point for all server code. Boots every service in order.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EggService = require(script.Parent.EggService)
local DebugService = require(script.Parent.DebugService)

Remotes.CreateAll()
PlayerDataService.Start()
EggService.Start()
DebugService.Start()

print("[Egg Heist Arena] Server booted:", os.date("%X"))
