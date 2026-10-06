-- Entry point for all server code. Boots every service in order.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)

Remotes.CreateAll()
PlayerDataService.Start()

print("[Egg Heist Arena] Server booted:", os.date("%X"))
