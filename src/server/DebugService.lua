--[[
	DebugService.lua

	Test tools: force the next egg's rarity, skip an incubator's timer, shorten all timers,
	give an instant free egg, reset my data. Every handler below is gated by isDebugAllowed()
	- Studio OR a whitelisted UserId. See docs/CONTRACTS.md "Debug remote authorization".

	REMOVE WHITELIST BEFORE PUBLIC LAUNCH: Config.DebugWhitelist must be emptied (or this
	whole file disabled) before the game is ever made public, or anyone whose UserId ends up
	in that list could use these tools in the live game forever.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local EggService = require(script.Parent.EggService)

local DebugService = {}

local function isDebugAllowed(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	return table.find(Config.DebugWhitelist, player.UserId) ~= nil
end

function DebugService.Start()
	Remotes.Get("DebugForceRarity").OnServerInvoke = function(player, rarity)
		if not isDebugAllowed(player) then
			return { ok = false, error = "Debug tools are not enabled for you." }
		end
		if type(rarity) ~= "string" or not Config.RarityById[rarity] then
			return { ok = false, error = "Unknown rarity." }
		end

		EggService.SetForcedRarity(player, rarity)
		return { ok = true }
	end

	Remotes.Get("DebugSkipTimer").OnServerInvoke = function(player, slotIndex)
		if not isDebugAllowed(player) then
			return { ok = false, error = "Debug tools are not enabled for you." }
		end

		return EggService.SkipIncubatorTimer(player, slotIndex)
	end

	Remotes.Get("DebugSetShortTimers").OnServerInvoke = function(player, enabled)
		if not isDebugAllowed(player) then
			return { ok = false, error = "Debug tools are not enabled for you." }
		end
		if type(enabled) ~= "boolean" then
			return { ok = false, error = "Bad request." }
		end

		return EggService.SetDebugShortTimers(player, enabled)
	end

	Remotes.Get("DebugGiveFreeEgg").OnServerInvoke = function(player)
		if not isDebugAllowed(player) then
			return { ok = false, error = "Debug tools are not enabled for you." }
		end

		return EggService.DebugGiveFreeEgg(player)
	end

	Remotes.Get("DebugResetData").OnServerInvoke = function(player)
		if not isDebugAllowed(player) then
			return { ok = false, error = "Debug tools are not enabled for you." }
		end

		return EggService.DebugResetData(player)
	end
end

return DebugService
