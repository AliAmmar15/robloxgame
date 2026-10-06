--[[
	DebugService.lua

	Studio-only test tools: force the next egg's rarity, and skip an incubator's timer.
	Both remote handlers refuse to do anything unless RunService:IsStudio() is true - this
	is what keeps these from ever working in a published/live game, so they can never ship
	by accident. See docs/CONTRACTS.md for the DebugForceRarity / DebugSkipTimer remotes.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local EggService = require(script.Parent.EggService)

local DebugService = {}

function DebugService.Start()
	Remotes.Get("DebugForceRarity").OnServerInvoke = function(player, rarity)
		if not RunService:IsStudio() then
			return { ok = false, error = "Debug tools are Studio-only." }
		end
		if type(rarity) ~= "string" or not Config.RarityById[rarity] then
			return { ok = false, error = "Unknown rarity." }
		end

		EggService.SetForcedRarity(player, rarity)
		return { ok = true }
	end

	Remotes.Get("DebugSkipTimer").OnServerInvoke = function(player, slotIndex)
		if not RunService:IsStudio() then
			return { ok = false, error = "Debug tools are Studio-only." }
		end

		return EggService.SkipIncubatorTimer(player, slotIndex)
	end
end

return DebugService
