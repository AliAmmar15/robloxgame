--[[
	RaidService.lua

	Owns: the NPC den, nest slots, grabbing an egg, carry slowdown, and nest respawn.
	Connects the GrabEgg remote (grabbing is a raid action). See docs/CONTRACTS.md for the
	full "Egg <-> Raid boundary" - this file validates the request, empties the nest FIRST,
	then calls EggService.RollAndGrantEgg(player) to actually roll and grant the egg.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EggService = require(script.Parent.EggService)
local EventLog = require(script.Parent.EventLog)

local RaidService = {}

local DEFAULT_WALK_SPEED = 16
local SPEED_TICK_SECONDS = 1

-- Speed-hack DETECTION only (not enforcement): WalkSpeed is a normal replicated Humanoid
-- property, not something the server can stop a modified client from overriding locally -
-- there's no PvP or other player-vs-player stakes today for that to actually exploit
-- against, so a full server-authority movement system is out of scope for this prototype.
-- This just logs if someone is moving implausibly fast, so it's visible if it ever matters.
local SPEED_TOLERANCE_MULTIPLIER = 2.5 -- generous, to avoid false positives from jumps/falls/lag
local lastPosition = {} -- userId -> Vector3, for the distance-per-tick check below

-- nestIndex -> Part. Built once at Start() from World's tagged instances - never hardcode
-- a Workspace path, World might reshuffle the layout.
local nestParts = {}

-- nestIndex -> { Available: boolean, RespawnAt: number }. World-shared (not per-player)
-- state, kept only in memory - resets if the server restarts, which is fine: NPC dens
-- always have a target again on a fresh server, per the GDD.
local nestState = {}

local function buildNestLookup()
	nestParts = {}
	nestState = {}
	for _, part in CollectionService:GetTagged("NestSlot") do
		local index = part:GetAttribute("NestIndex")
		if index then
			nestParts[index] = part
			nestState[index] = { Available = true, RespawnAt = 0 }
		else
			warn("[RaidService] A NestSlot-tagged part has no NestIndex attribute: " .. part:GetFullName())
		end
	end
end

local function refreshNestAvailability(nestIndex)
	local state = nestState[nestIndex]
	if state and not state.Available and os.time() >= state.RespawnAt then
		state.Available = true
	end
end

-- The slowest (smallest) carry-speed multiplier among everything currently in
-- data.CarriedEggs, or 1 (no slowdown) if nothing is being carried.
local function worstCarryMultiplier(data)
	local worst = 1
	for _, egg in data.CarriedEggs do
		local multiplier = Config.CarrySlowdown[egg.Rarity]
		if multiplier and multiplier < worst then
			worst = multiplier
		end
	end
	return worst
end

local function applyCarrySpeed(player, data)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.WalkSpeed = DEFAULT_WALK_SPEED * worstCarryMultiplier(data)
end

local function handleGrabEgg(player, nestIndex)
	if type(nestIndex) ~= "number" then
		return { ok = false, error = "Bad request." }
	end
	nestIndex = math.floor(nestIndex)

	local nestPart = nestParts[nestIndex]
	if not nestPart then
		return { ok = false, error = "That nest doesn't exist." }
	end

	refreshNestAvailability(nestIndex)
	local state = nestState[nestIndex]
	if not state.Available then
		return { ok = false, error = "That nest is empty right now - try again in a bit." }
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return { ok = false, error = "Can't find your character." }
	end

	local distance = (rootPart.Position - nestPart.Position).Magnitude
	if distance > Config.NestGrabRange then
		return { ok = false, error = "You're too far from the nest." }
	end

	-- Mark the nest empty FIRST, before granting anything. This is what stops two GrabEgg
	-- requests landing close together (e.g. a player spamming the button) from both
	-- passing validation and duplicating an egg from one nest.
	state.Available = false
	state.RespawnAt = os.time() + Config.NestRespawnSeconds

	local ok, eggId, creatureId, rarity = EggService.RollAndGrantEgg(player)
	if not ok then
		-- Grant failed after we'd already emptied the nest - give the nest back rather
		-- than punishing the player for a server-side failure that wasn't their fault.
		state.Available = true
		state.RespawnAt = 0
		return { ok = false, error = "Could not grant an egg right now." }
	end

	local data = PlayerDataService.Get(player)
	if data then
		applyCarrySpeed(player, data)
	end

	EventLog.FirstGrab(player)
	EventLog.FirstReveal(player, creatureId, rarity)

	return { ok = true, eggId = eggId, creatureId = creatureId, rarity = rarity }
end

local function setupCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.WalkSpeed = DEFAULT_WALK_SPEED

	humanoid.Died:Connect(function()
		-- Same spirit as the GDD's "a caught raider drops the egg back into the nest"
		-- (section 7): whatever this player was carrying is lost. This also has to happen
		-- or the speed tick below would just see CarriedEggs still full and re-slow them
		-- the moment they respawn.
		local data = PlayerDataService.Get(player)
		if data then
			data.CarriedEggs = {}
			Remotes.Get("PlayerDataUpdated"):FireClient(player, data)
		end
		humanoid.WalkSpeed = DEFAULT_WALK_SPEED
	end)
end

function RaidService.Start()
	buildNestLookup()

	Remotes.Get("GrabEgg").OnServerInvoke = function(player, nestIndex)
		return handleGrabEgg(player, nestIndex)
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			setupCharacter(player, character)
		end)
		if player.Character then
			setupCharacter(player, player.Character)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastPosition[player.UserId] = nil
	end)

	-- Keep everyone's WalkSpeed matching what they're currently carrying. This is what
	-- makes speed recover after PlaceInIncubator (Egg's remote) empties CarriedEggs,
	-- without EggService needing to call into RaidService directly. Also runs the speed
	-- anomaly detection above.
	local maxPlausibleDistance = DEFAULT_WALK_SPEED * SPEED_TICK_SECONDS * SPEED_TOLERANCE_MULTIPLIER
	task.spawn(function()
		while true do
			task.wait(SPEED_TICK_SECONDS)
			for _, player in Players:GetPlayers() do
				local data = PlayerDataService.Get(player)
				if data then
					applyCarrySpeed(player, data)
				end

				local character = player.Character
				local rootPart = character and character:FindFirstChild("HumanoidRootPart")
				if rootPart then
					local previous = lastPosition[player.UserId]
					if previous then
						local distance = (rootPart.Position - previous).Magnitude
						if distance > maxPlausibleDistance then
							warn(
								"[RaidService] "
									.. player.Name
									.. " moved "
									.. math.floor(distance)
									.. " studs in "
									.. SPEED_TICK_SECONDS
									.. "s - faster than should be possible (detection only, not blocked)."
							)
						end
					end
					lastPosition[player.UserId] = rootPart.Position
				end
			end
		end
	end)
end

return RaidService
