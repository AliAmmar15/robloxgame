--[[
	EggService.lua

	Owns: rolling a creature for a new egg, incubator timers, the free Basic Egg timer,
	hatching, and recording discoveries in the Index. See docs/CONTRACTS.md for the full
	Remote table and the Egg<->Raid call boundary.

	IMPORTANT: EggService does NOT connect the GrabEgg remote - RaidService does, because
	grabbing is a raid action (it needs to check the player is near a nest first). RaidService
	calls EggService.RollAndGrantEgg(player) as a plain function after it has already validated
	the nest and emptied it. Don't call RollAndGrantEgg from anywhere except RaidService.
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)

local EggService = {}

local TICK_SECONDS = 5 -- how often we check timers. The timers themselves are os.time()
-- based (see docs/CONTRACTS.md), so this only affects how quickly we NOTICE a timer
-- finished - never how the timer itself is calculated.

-- userId -> rarity string. Set by DebugService (Studio only) to force the NEXT roll for
-- that player to a specific rarity, instead of the normal weighted random. Consumed once.
local forcedRarity = {}

-- userId -> { [slotIndex] = true }. Tracks which hatch-ready notifications we've already
-- sent, so the tick loop doesn't fire HatchReady over and over while a player leaves an
-- incubator sitting there finished. Cleared on collect and on the player leaving.
local notifiedHatchReady = {}

-- ---------------------------------------------------------------------------------------
-- Rolling
-- ---------------------------------------------------------------------------------------

local function rollRarity(player)
	local forced = forcedRarity[player.UserId]
	if forced then
		forcedRarity[player.UserId] = nil
		return forced
	end

	local roll = math.random()
	local cumulative = 0
	for _, rarity in Config.Rarities do
		cumulative += rarity.BasicEggOdds
		if roll <= cumulative then
			return rarity.Id
		end
	end
	-- Floating point rounding can leave `roll` just above the summed total - fall back to
	-- the last tier (Mythic) rather than returning nothing.
	return Config.Rarities[#Config.Rarities].Id
end

local function pickCreatureForRarity(rarityId)
	local pool = Config.CreaturesByRarity[rarityId]
	if not pool or #pool == 0 then
		return nil
	end
	return pool[math.random(1, #pool)]
end

-- Called ONLY by RaidService, after it has validated a grab and emptied the nest slot.
-- Rolls a creature, adds it to the player's carried eggs, and returns the result.
-- Returns: ok, eggId, creatureId, rarity (last three nil if ok == false)
function EggService.RollAndGrantEgg(player: Player)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, nil, nil, nil
	end

	local rarityId = rollRarity(player)
	local creature = pickCreatureForRarity(rarityId)
	if not creature then
		warn("[EggService] No creature configured for rarity '" .. tostring(rarityId) .. "'")
		return false, nil, nil, nil
	end

	local eggId = HttpService:GenerateGUID(false)
	data.CarriedEggs[eggId] = {
		CreatureId = creature.Id,
		Rarity = rarityId,
		RevealedAt = os.time(),
	}

	Remotes.Get("PlayerDataUpdated"):FireClient(player, data)

	return true, eggId, creature.Id, rarityId
end

-- ---------------------------------------------------------------------------------------
-- Free Basic Egg accrual
-- ---------------------------------------------------------------------------------------

-- Tops up FreeEgg.Stockpile based on real elapsed time since the last check, capped at
-- Config.FreeEgg.StockpileCap. Advances LastClaimedAt by only the whole cooldown periods
-- actually consumed, so partial progress toward the next tick isn't lost once the
-- stockpile is full. This is what makes the stockpile "catch up" correctly after being
-- offline - whether that's running on a timer or the first check after rejoining.
local function accrueFreeEggs(data)
	local freeEgg = data.FreeEgg
	local elapsed = os.time() - freeEgg.LastClaimedAt
	local periodsPassed = math.floor(elapsed / Config.FreeEgg.CooldownSeconds)
	if periodsPassed <= 0 then
		return
	end

	freeEgg.Stockpile = math.min(Config.FreeEgg.StockpileCap, freeEgg.Stockpile + periodsPassed)
	freeEgg.LastClaimedAt += periodsPassed * Config.FreeEgg.CooldownSeconds
end

-- ---------------------------------------------------------------------------------------
-- Remote handlers
-- ---------------------------------------------------------------------------------------

local function handlePlaceInIncubator(player, eggId, slotIndex)
	local data = PlayerDataService.Get(player)
	if not data then
		return { ok = false, error = "No data loaded yet." }
	end
	if type(eggId) ~= "string" or type(slotIndex) ~= "number" then
		return { ok = false, error = "Bad request." }
	end
	slotIndex = math.floor(slotIndex)
	if slotIndex < 1 or slotIndex > Config.IncubatorSlotCount then
		return { ok = false, error = "Invalid incubator slot." }
	end

	local carried = data.CarriedEggs[eggId]
	if not carried then
		return { ok = false, error = "You aren't carrying that egg." }
	end
	if data.Incubators[slotIndex] then
		return { ok = false, error = "That incubator slot is already occupied." }
	end

	local rarity = Config.RarityById[carried.Rarity]
	if not rarity then
		return { ok = false, error = "Unknown rarity - this shouldn't happen." }
	end

	local now = os.time()
	data.Incubators[slotIndex] = {
		EggId = eggId,
		CreatureId = carried.CreatureId,
		Rarity = carried.Rarity,
		StartedAt = now,
		HatchAt = now + rarity.IncubationSeconds,
	}
	data.CarriedEggs[eggId] = nil

	Remotes.Get("IncubatorUpdated"):FireClient(player, data.Incubators)
	Remotes.Get("PlayerDataUpdated"):FireClient(player, data)

	return { ok = true }
end

local function handleCollectHatch(player, slotIndex)
	local data = PlayerDataService.Get(player)
	if not data then
		return { ok = false, error = "No data loaded yet." }
	end
	if type(slotIndex) ~= "number" then
		return { ok = false, error = "Bad request." }
	end
	slotIndex = math.floor(slotIndex)
	if slotIndex < 1 or slotIndex > Config.IncubatorSlotCount then
		return { ok = false, error = "Invalid incubator slot." }
	end

	local incubating = data.Incubators[slotIndex]
	if not incubating then
		return { ok = false, error = "That incubator is empty." }
	end
	if os.time() < incubating.HatchAt then
		return { ok = false, error = "Not ready yet." }
	end

	local isNew = not data.Index[incubating.CreatureId]
	data.Index[incubating.CreatureId] = true
	data.Incubators[slotIndex] = false

	if notifiedHatchReady[player.UserId] then
		notifiedHatchReady[player.UserId][slotIndex] = nil
	end

	Remotes.Get("IncubatorUpdated"):FireClient(player, data.Incubators)
	Remotes.Get("PlayerDataUpdated"):FireClient(player, data)

	return { ok = true, creatureId = incubating.CreatureId, isNewToIndex = isNew }
end

local function handleClaimFreeEgg(player)
	local data = PlayerDataService.Get(player)
	if not data then
		return { ok = false, error = "No data loaded yet." }
	end

	accrueFreeEggs(data) -- make sure the stockpile reflects elapsed time right now

	if data.FreeEgg.Stockpile <= 0 then
		return { ok = false, error = "No free egg available yet." }
	end

	data.FreeEgg.Stockpile -= 1
	local ok, eggId = EggService.RollAndGrantEgg(player)
	if not ok then
		data.FreeEgg.Stockpile += 1 -- refund - the grant failed, don't lose the stockpile slot
		return { ok = false, error = "Could not grant an egg right now." }
	end

	Remotes.Get("PlayerDataUpdated"):FireClient(player, data)

	return { ok = true, eggId = eggId }
end

-- ---------------------------------------------------------------------------------------
-- Debug hooks (used by DebugService.lua, which checks RunService:IsStudio() before calling
-- these - EggService itself doesn't re-check, so never wire these to anything except
-- DebugService's already-guarded remote handlers)
-- ---------------------------------------------------------------------------------------

function EggService.SetForcedRarity(player: Player, rarityId: string)
	forcedRarity[player.UserId] = rarityId
end

function EggService.SkipIncubatorTimer(player: Player, slotIndex: number)
	local data = PlayerDataService.Get(player)
	if not data then
		return { ok = false, error = "No data loaded yet." }
	end
	if type(slotIndex) ~= "number" then
		return { ok = false, error = "Bad request." }
	end
	slotIndex = math.floor(slotIndex)

	local incubating = data.Incubators[slotIndex]
	if not incubating then
		return { ok = false, error = "That incubator is empty." }
	end

	-- Only moves HatchAt to now - the creature was already rolled and revealed back when
	-- the egg was grabbed, so this just reveals a known outcome sooner. No new roll happens.
	incubating.HatchAt = os.time()

	Remotes.Get("IncubatorUpdated"):FireClient(player, data.Incubators)
	Remotes.Get("PlayerDataUpdated"):FireClient(player, data)

	return { ok = true }
end

-- ---------------------------------------------------------------------------------------
-- Boot
-- ---------------------------------------------------------------------------------------

function EggService.Start()
	Remotes.Get("PlaceInIncubator").OnServerInvoke = function(player, eggId, slotIndex)
		return handlePlaceInIncubator(player, eggId, slotIndex)
	end

	Remotes.Get("CollectHatch").OnServerInvoke = function(player, slotIndex)
		return handleCollectHatch(player, slotIndex)
	end

	Remotes.Get("ClaimFreeEgg").OnServerInvoke = function(player)
		return handleClaimFreeEgg(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		forcedRarity[player.UserId] = nil
		notifiedHatchReady[player.UserId] = nil
	end)

	-- Periodically: top up everyone's free-egg stockpile, and notify the client once when
	-- an incubator becomes ready (so the UI can show "ready to collect" without polling).
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			for _, player in Players:GetPlayers() do
				local data = PlayerDataService.Get(player)
				if data then
					accrueFreeEggs(data)

					for slotIndex = 1, Config.IncubatorSlotCount do
						local incubating = data.Incubators[slotIndex]
						if incubating and os.time() >= incubating.HatchAt then
							notifiedHatchReady[player.UserId] = notifiedHatchReady[player.UserId] or {}
							if not notifiedHatchReady[player.UserId][slotIndex] then
								notifiedHatchReady[player.UserId][slotIndex] = true
								Remotes.Get("HatchReady"):FireClient(player, {
									slotIndex = slotIndex,
									creatureId = incubating.CreatureId,
								})
							end
						end
					end
				end
			end
		end
	end)
end

return EggService
