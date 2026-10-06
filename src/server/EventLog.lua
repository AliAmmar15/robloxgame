--[[
	EventLog.lua

	Minimal funnel logging: joined, first grab, first reveal, first hatch, left - each with a
	timestamp, printed to the server console only (nothing external, nothing persisted). The
	"first X" events are tracked per-session (resets on server restart) - good enough for
	watching a single playtest, not meant as real analytics infrastructure.
]]

local EventLog = {}

local firstSeen = {} -- "userId:eventName" -> true

local function log(player: Player, event: string, extra: string?)
	print(string.format(
		"[EVENT] %s | %s | %s%s",
		os.date("%Y-%m-%d %H:%M:%S"),
		player and player.Name or "?",
		event,
		extra and (" | " .. extra) or ""
	))
end

local function logOnce(player: Player, key: string, event: string, extra: string?)
	local fullKey = player.UserId .. ":" .. key
	if firstSeen[fullKey] then
		return
	end
	firstSeen[fullKey] = true
	log(player, event, extra)
end

function EventLog.Joined(player: Player)
	log(player, "joined")
end

function EventLog.Left(player: Player)
	log(player, "left")
	-- no need to clean up firstSeen entries for this player - UserId keys won't collide if
	-- they rejoin, and the table staying small for a prototype play session is a non-issue.
end

function EventLog.FirstGrab(player: Player)
	logOnce(player, "grab", "first_grab")
end

function EventLog.FirstReveal(player: Player, creatureId: string, rarity: string)
	logOnce(player, "reveal", "first_reveal", creatureId .. " (" .. rarity .. ")")
end

function EventLog.FirstHatch(player: Player, creatureId: string)
	logOnce(player, "hatch", "first_hatch", creatureId)
end

return EventLog
