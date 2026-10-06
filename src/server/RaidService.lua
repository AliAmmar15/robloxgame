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
local SPEED_WARN_STREAK = 3 -- consecutive bad ticks before we say anything
local SPEED_WARN_COOLDOWN = 30 -- seconds between warnings per player, so it can't flood the log
local lastPosition = {} -- userId -> Vector3, for the distance-per-tick check below
local speedStreak = {} -- userId -> consecutive implausible ticks
local lastSpeedWarn = {} -- userId -> os.time() of the last warning

-- Respawns, spawn-point placement, and admin/Studio teleports all legitimately move a
-- character a long way in one tick. Skipping one tick after the character appears (and
-- requiring a STREAK below) keeps those out of the log - a real speed hack is sustained,
-- a teleport is a single spike.
local skipNextSpeedCheck = {} -- userId -> true

-- nestIndex -> Part. Built once at Start() from World's tagged instances - never hardcode
-- a Workspace path, World might reshuffle the layout.
local nestParts = {}

-- nestIndex -> { Available: boolean, RespawnAt: number }. World-shared (not per-player)
-- state, kept only in memory - resets if the server restarts, which is fine: NPC dens
-- always have a target again on a fresh server, per the GDD.
local nestState = {}

local function registerNest(part)
	local index = part:GetAttribute("NestIndex")
	if not index then
		warn("[RaidService] A NestSlot-tagged part has no NestIndex attribute: " .. part:GetFullName())
		return
	end
	nestParts[index] = part
	nestState[index] = nestState[index] or { Available = true, RespawnAt = 0 }
end

local function buildNestLookup()
	nestParts = {}
	nestState = {}
	for _, part in CollectionService:GetTagged("NestSlot") do
		registerNest(part)
	end
end

-- Shows/hides the egg sitting in a nest. The egg is a Model child named "Egg" that World
-- builds; we toggle transparency rather than destroying it, so the nest can refill without
-- the server needing to know how the egg was put together.
local function setNestEggVisible(nestIndex, visible)
	local nestPart = nestParts[nestIndex]
	local egg = nestPart and nestPart:FindFirstChild("Egg")
	if not egg then
		return
	end
	for _, d in egg:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = visible and 0 or 1
		end
	end
end

-- A little burst when a nest refills, so a player standing nearby sees it come back
-- instead of an egg silently blinking into existence.
local function respawnPuff(nestIndex)
	local nestPart = nestParts[nestIndex]
	if not nestPart then
		return
	end
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.Position = nestPart.Position + Vector3.new(0, 2, 0)
	holder.Parent = workspace

	local att = Instance.new("Attachment")
	att.Parent = holder

	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Lifetime = NumberRange.new(0.35, 0.7)
	e.Rate = 0
	e.Speed = NumberRange.new(4, 8)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Color = ColorSequence.new(Color3.fromRGB(255, 250, 235))
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Parent = att
	e:Emit(18)

	task.delay(1.5, function()
		holder:Destroy()
	end)
end

local function refreshNestAvailability(nestIndex)
	local state = nestState[nestIndex]
	if state and not state.Available and os.time() >= state.RespawnAt then
		state.Available = true
		setNestEggVisible(nestIndex, true)
		respawnPuff(nestIndex)
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

-- The rarest egg currently carried, or nil. Used to decide what the player visibly holds.
local function rarestCarried(data)
	local bestEgg, bestIndex
	for _, egg in data.CarriedEggs do
		for i, rarity in Config.Rarities do
			if rarity.Id == egg.Rarity then
				if not bestIndex or i > bestIndex then
					bestEgg, bestIndex = egg, i
				end
				break
			end
		end
	end
	return bestEgg
end

-- rarer = bigger, so "this one is heavy" reads at a glance as well as in the walkspeed
local CARRY_SCALE_BY_RARITY = {
	Common = 0.9, Uncommon = 1.0, Rare = 1.1, Epic = 1.2, Legendary = 1.35, Mythic = 1.5,
}

--[[
	Shows a small egg floating above the player's head while carrying, tinted and scaled
	by rarity. Built on the SERVER so everyone sees it, not just the carrier.

	CAREFUL - this function is called on a 1s tick. Do NOT set `shell.CFrame` here.
	The shell is welded to the head, and setting CFrame on a welded part moves the whole
	assembly, which physically launched the player across the map every tick while they
	were carrying (observed: 51-240 studs/s). Position is owned entirely by `weld.C0`,
	which is a joint offset and is safe to change.
]]
local function updateCarryVisual(player, data)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end

	local existing = head:FindFirstChild("CarriedEggVisual")
	local egg = rarestCarried(data)

	if not egg then
		if existing then
			existing:Destroy()
		end
		return
	end

	-- Nothing to do if we're already showing exactly this rarity. Keeps the tick cheap and
	-- avoids touching physics state for no reason.
	if existing and existing:GetAttribute("Rarity") == egg.Rarity then
		return
	end

	local scale = CARRY_SCALE_BY_RARITY[egg.Rarity] or 1
	local shell = existing

	if not shell then
		shell = Instance.new("Part")
		shell.Name = "CarriedEggVisual"
		shell.Shape = Enum.PartType.Ball
		shell.Anchored = false
		shell.CanCollide = false
		shell.CanQuery = false
		shell.Massless = true
		shell.Material = Enum.Material.SmoothPlastic
		shell.Size = Vector3.new(1.1, 1.4, 1.1) * scale
		-- place it once, BEFORE welding, so the weld captures a sane starting offset
		shell.CFrame = head.CFrame * CFrame.new(0, 1.5 * scale, 0)
		shell.Parent = head

		-- A real Weld (not WeldConstraint) so the offset lives in C0 and can be changed
		-- later without dragging the character.
		local weld = Instance.new("Weld")
		weld.Name = "CarryWeld"
		weld.Part0 = head
		weld.Part1 = shell
		weld.C0 = CFrame.new(0, 1.5 * scale, 0)
		weld.Parent = shell
	end

	shell.Size = Vector3.new(1.1, 1.4, 1.1) * scale
	shell.Color = Config.RarityColor[egg.Rarity] or Color3.new(1, 1, 1)
	shell:SetAttribute("Rarity", egg.Rarity)

	local weld = shell:FindFirstChild("CarryWeld")
	if weld then
		weld.C0 = CFrame.new(0, 1.5 * scale, 0)
	end
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
	setNestEggVisible(nestIndex, false)

	local ok, eggId, creatureId, rarity = EggService.RollAndGrantEgg(player)
	if not ok then
		-- Grant failed after we'd already emptied the nest - give the nest back rather
		-- than punishing the player for a server-side failure that wasn't their fault.
		state.Available = true
		state.RespawnAt = 0
		setNestEggVisible(nestIndex, true)
		return { ok = false, error = "Could not grant an egg right now." }
	end

	local data = PlayerDataService.Get(player)
	if data then
		applyCarrySpeed(player, data)
		updateCarryVisual(player, data)
	end

	EventLog.FirstGrab(player)
	EventLog.FirstReveal(player, creatureId, rarity)

	return { ok = true, eggId = eggId, creatureId = creatureId, rarity = rarity }
end

local function setupCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.WalkSpeed = DEFAULT_WALK_SPEED

	-- the jump from "no character" / old corpse position to the spawn point is not a cheat
	skipNextSpeedCheck[player.UserId] = true
	lastPosition[player.UserId] = nil
	speedStreak[player.UserId] = 0

	humanoid.Died:Connect(function()
		-- Same spirit as the GDD's "a caught raider drops the egg back into the nest"
		-- (section 7): whatever this player was carrying is lost. This also has to happen
		-- or the speed tick below would just see CarriedEggs still full and re-slow them
		-- the moment they respawn.
		local data = PlayerDataService.Get(player)
		if data then
			data.CarriedEggs = {}
			Remotes.Get("PlayerDataUpdated"):FireClient(player, data)
			updateCarryVisual(player, data) -- removes the egg from the corpse's head
		end
		humanoid.WalkSpeed = DEFAULT_WALK_SPEED
	end)

	-- a freshly spawned character has no egg on its head yet; restore it if still carrying
	local data = PlayerDataService.Get(player)
	if data then
		updateCarryVisual(player, data)
	end
end

function RaidService.Start()
	buildNestLookup()

	-- Nests created/removed after boot (map rebuilds, streaming) stay in sync without any
	-- hardcoded count or path.
	CollectionService:GetInstanceAddedSignal("NestSlot"):Connect(registerNest)
	CollectionService:GetInstanceRemovedSignal("NestSlot"):Connect(function(part)
		local index = part:GetAttribute("NestIndex")
		if index and nestParts[index] == part then
			nestParts[index] = nil
			nestState[index] = nil
		end
	end)

	Remotes.Get("GrabEgg").OnServerInvoke = function(player, nestIndex)
		return handleGrabEgg(player, nestIndex)
	end

	-- Refill emptied nests on their timer, even with nobody standing nearby to trigger
	-- the lazy check inside handleGrabEgg.
	task.spawn(function()
		while true do
			task.wait(1)
			for nestIndex in nestState do
				refreshNestAvailability(nestIndex)
			end
		end
	end)

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
		speedStreak[player.UserId] = nil
		lastSpeedWarn[player.UserId] = nil
		skipNextSpeedCheck[player.UserId] = nil
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
					updateCarryVisual(player, data)
				end

				local character = player.Character
				local rootPart = character and character:FindFirstChild("HumanoidRootPart")
				if rootPart then
					local userId = player.UserId
					local previous = lastPosition[userId]

					if skipNextSpeedCheck[userId] then
						-- character just (re)spawned; this tick's "distance" is a teleport
						skipNextSpeedCheck[userId] = nil
						speedStreak[userId] = 0
					elseif previous then
						local distance = (rootPart.Position - previous).Magnitude
						if distance > maxPlausibleDistance then
							speedStreak[userId] = (speedStreak[userId] or 0) + 1
							local now = os.time()
							local quiet = (now - (lastSpeedWarn[userId] or 0)) >= SPEED_WARN_COOLDOWN
							if speedStreak[userId] >= SPEED_WARN_STREAK and quiet then
								lastSpeedWarn[userId] = now
								warn(
									"[RaidService] "
										.. player.Name
										.. " sustained implausible movement ("
										.. math.floor(distance)
										.. " studs in "
										.. SPEED_TICK_SECONDS
										.. "s, "
										.. speedStreak[userId]
										.. " ticks running) - detection only, not blocked."
								)
							end
						else
							speedStreak[userId] = 0
						end
					end
					lastPosition[userId] = rootPart.Position
				end
			end
		end
	end)
end

return RaidService
