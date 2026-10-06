-- Remotes.lua
-- Single source of truth for every RemoteEvent/RemoteFunction name. See docs/CONTRACTS.md
-- for what each one does. Server creates them on boot; client just asks for them by name.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

-- Every remote name that exists in this game. Keep this list and docs/CONTRACTS.md in sync.
local REMOTE_FUNCTION_NAMES = {
	"GrabEgg",
	"PlaceInIncubator",
	"ClaimFreeEgg",
	"CollectHatch",
	"DebugForceRarity",
	"DebugSkipTimer",
	"DebugSetShortTimers",
	"DebugGiveFreeEgg",
	"DebugResetData",
}

local REMOTE_EVENT_NAMES = {
	"IncubatorUpdated",
	"HatchReady",
	"PlayerDataUpdated",
}

-- Call once from the server at boot. Creates every remote under ReplicatedStorage.Shared.Remotes
-- if it doesn't already exist. Safe to call more than once (won't duplicate anything).
function Remotes.CreateAll()
	local shared = ReplicatedStorage:WaitForChild("Shared")
	local folder = shared:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = shared
	end

	for _, name in REMOTE_FUNCTION_NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end

	for _, name in REMOTE_EVENT_NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end

	return folder
end

-- Call from server or client code to get a remote by name. Waits (briefly) in case the
-- server hasn't finished creating them yet (mainly matters on the client at game start).
function Remotes.Get(name: string): RemoteEvent | RemoteFunction
	local shared = ReplicatedStorage:WaitForChild("Shared")
	local folder = shared:WaitForChild("Remotes", 10)
	assert(folder, "Remotes folder never appeared under ReplicatedStorage.Shared. Did the server boot?")

	local remote = folder:WaitForChild(name, 10)
	assert(remote, "Remote '" .. name .. "' was requested but doesn't exist. Check the name against docs/CONTRACTS.md.")
	return remote
end

return Remotes
