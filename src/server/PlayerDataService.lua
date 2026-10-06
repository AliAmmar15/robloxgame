--[[
	PlayerDataService.lua

	Owns loading, saving, and the in-memory copy of each player's save data.
	Other server scripts read/write through PlayerDataService.Get(player) and mutate the
	table it returns directly (see docs/CONTRACTS.md "PlayerData access pattern") - nothing
	else in the game should touch DataStoreService directly.

	STUDIO SETUP NEEDED: DataStores only work in Studio if
	Game Settings > Security > "Enable Studio Access to API Services" is turned ON.
	Without it, every load/save below fails and this silently falls back to a fresh
	profile each time you press Play - so saving will look broken even though the code
	is fine. Turn that setting on once per place.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local PlayerDataService = {}

local STORE_NAME = "EggHeistArena_PlayerData_v1"
local AUTOSAVE_INTERVAL_SECONDS = 60
local RETRY_ATTEMPTS = 3
local RETRY_WAIT_SECONDS = 2

-- GetDataStore() itself throws immediately if API access isn't available (Studio with the
-- setting off, or an unpublished place) - wrap it so that alone doesn't crash the whole
-- server. If it fails, dataStore stays nil and Load/Save below just always "fail" and
-- fall back to in-memory-only profiles, instead of taking the whole game down with them.
local dataStoreOk, dataStore = pcall(function()
	return DataStoreService:GetDataStore(STORE_NAME)
end)
if not dataStoreOk then
	warn(
		"[PlayerDataService] DataStoreService unavailable: "
			.. tostring(dataStore)
			.. " - saving is OFF this session. In Studio, turn on Game Settings > Security > "
			.. "'Enable Studio Access to API Services' and press Play again."
	)
	dataStore = nil
end

-- userId -> live data table. This table IS the save data - services mutate it directly,
-- then it gets written out on the next autosave / on leave / on server shutdown.
local cache = {}

-- userId -> true while a save for that player is already running, so two saves for the
-- same player (e.g. autosave + PlayerRemoving landing at the same moment) can't overlap.
local saveInFlight = {}

local function newProfile()
	return {
		Version = 1,
		CarriedEggs = {},
		Incubators = table.create(Config.IncubatorSlotCount, false),
		Index = {},
		FreeEgg = { LastClaimedAt = 0, Stockpile = 0 },
		CreatedAt = os.time(),
		LastLoginAt = os.time(),
	}
end

-- If we ever add a new field to the schema later, old saves won't have it yet.
-- This fills in anything missing from a loaded save, using newProfile() as the template,
-- so old saves keep working without a separate migration step.
local function fillMissingFields(data)
	local template = newProfile()
	for key, value in template do
		if data[key] == nil then
			data[key] = value
		end
	end
	return data
end

-- Runs fn() up to `attempts` times, waiting between tries. Returns (true, result) on
-- success, or (false, lastError) if every attempt failed.
local function attempt(fn, attempts)
	local lastError
	for i = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = result
		warn(("[PlayerDataService] attempt %d/%d failed: %s"):format(i, attempts, tostring(lastError)))
		if i < attempts then
			task.wait(RETRY_WAIT_SECONDS)
		end
	end
	return false, lastError
end

-- Loads a player's data into the cache. Called from PlayerAdded. If loading fails after
-- all retries, starts a fresh profile rather than blocking the player from playing -
-- this is a prototype tradeoff, not something we'd ship (see docs/STATUS.md if we revisit).
function PlayerDataService.Load(player: Player)
	if not dataStore then
		-- Already warned once at startup about why. Don't burn 3 retries x 2s per player
		-- join for a call we know will fail - just start them with an in-memory profile.
		local data = newProfile()
		data.LastLoginAt = os.time()
		cache[player.UserId] = data
		return
	end

	local key = "Player_" .. player.UserId

	local ok, result = attempt(function()
		return dataStore:GetAsync(key)
	end, RETRY_ATTEMPTS)

	local data
	if ok and result then
		data = fillMissingFields(result)
	else
		if not ok then
			warn(
				"[PlayerDataService] Could not load data for "
					.. player.Name
					.. " - starting a fresh profile. If this keeps happening, check that "
					.. "'Enable Studio Access to API Services' is ON in Game Settings > Security."
			)
		end
		data = newProfile()
	end

	data.LastLoginAt = os.time()
	cache[player.UserId] = data
end

-- Returns the live data table for a player (nil if they haven't loaded yet, or already
-- left). Mutate fields on it directly - PlayerDataService handles saving it later.
function PlayerDataService.Get(player: Player)
	return cache[player.UserId]
end

-- Saves one player's current cached data. Safe to call any time; does nothing if a save
-- for that player is already running, or if they have no cached data to save.
function PlayerDataService.Save(player: Player)
	if not dataStore then
		return -- already warned once at startup; nothing to try
	end

	local userId = player.UserId
	local data = cache[userId]
	if not data or saveInFlight[userId] then
		return
	end
	saveInFlight[userId] = true

	local key = "Player_" .. userId
	local ok, err = attempt(function()
		-- UpdateAsync (not SetAsync): if this throws partway through, nothing gets
		-- written at all, so the last successfully-saved copy in the DataStore is
		-- never partially overwritten by a failed attempt.
		dataStore:UpdateAsync(key, function()
			return data
		end)
	end, RETRY_ATTEMPTS)

	if not ok then
		-- Never overwrite good data: we simply didn't write. The last successful save
		-- (and our local cache) are untouched; the next autosave tick tries again.
		warn(
			"[PlayerDataService] Save FAILED for "
				.. player.Name
				.. " after "
				.. RETRY_ATTEMPTS
				.. " attempts: "
				.. tostring(err)
		)
	end

	saveInFlight[userId] = false
end

-- Drops a player's data from memory. Call this AFTER their final save on the way out,
-- never before - otherwise Save() would find nothing to write.
function PlayerDataService.Release(player: Player)
	cache[player.UserId] = nil
	saveInFlight[player.UserId] = nil
end

function PlayerDataService.Start()
	-- Connect PlayerAdded FIRST, then separately load anyone already connected. PlayerAdded
	-- only fires for players who join AFTER this line - in Studio Play Solo (and in rare
	-- live-server races), a player can already be in Players:GetPlayers() by the time this
	-- runs, and would silently never get their data loaded if we only listened for the event.
	Players.PlayerAdded:Connect(function(player)
		PlayerDataService.Load(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataService.Save(player)
		PlayerDataService.Release(player)
	end)

	for _, player in Players:GetPlayers() do
		PlayerDataService.Load(player)
	end

	-- Autosave everyone currently online, on a timer. This is what keeps incubator /
	-- free-egg timestamps safe even if the server crashes or nobody leaves cleanly.
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL_SECONDS)
			for _, player in Players:GetPlayers() do
				PlayerDataService.Save(player)
			end
		end
	end)

	-- Server shutting down (Studio stop, deploy, etc.) - save everyone before we go.
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			PlayerDataService.Save(player)
		end
	end)
end

return PlayerDataService
