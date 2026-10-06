-- Config.lua
-- The ONLY place tunable numbers, rarity tiers, and creature data live.
-- Every other script reads from here instead of hardcoding numbers.
-- Changing game balance = changing this file, nothing else. See docs/CONTRACTS.md.

local Config = {}

-- Rarity tiers, ordered Common -> Mythic. Order matters for the roll logic in EggService.
Config.Rarities = {
	{ Id = "Common", IncubationSeconds = 5 * 60, BasicEggOdds = 0.62 },
	{ Id = "Uncommon", IncubationSeconds = 15 * 60, BasicEggOdds = 0.25 },
	{ Id = "Rare", IncubationSeconds = 60 * 60, BasicEggOdds = 0.10 },
	{ Id = "Epic", IncubationSeconds = 2 * 60 * 60, BasicEggOdds = 0.025 },
	{ Id = "Legendary", IncubationSeconds = 4 * 60 * 60, BasicEggOdds = 0.0045 },
	{ Id = "Mythic", IncubationSeconds = 8 * 60 * 60, BasicEggOdds = 0.0005 },
}

-- 12 placeholder creatures for the prototype, 2 per rarity tier.
-- Id must match a model name under ReplicatedStorage.CreatureModels EXACTLY (World builds those).
Config.Creatures = {
	{ Id = "pip_mallow", Name = "Pip Mallow", Rarity = "Common" },
	{ Id = "gutterfox", Name = "Gutterfox", Rarity = "Common" },
	{ Id = "lantern_moth", Name = "Lantern Moth", Rarity = "Uncommon" },
	{ Id = "burrowl", Name = "Burrowl", Rarity = "Uncommon" },
	{ Id = "thornback_boar", Name = "Thornback Boar", Rarity = "Rare" },
	{ Id = "mistling", Name = "Mistling", Rarity = "Rare" },
	{ Id = "mirrorpaw", Name = "Mirrorpaw", Rarity = "Epic" },
	{ Id = "echo_heron", Name = "Echo Heron", Rarity = "Epic" },
	{ Id = "stormhide_elk", Name = "Stormhide Elk", Rarity = "Legendary" },
	{ Id = "hollow_wyrm", Name = "Hollow Wyrm", Rarity = "Legendary" },
	{ Id = "eclipse_fawn", Name = "Eclipse Fawn", Rarity = "Mythic" },
	{ Id = "gilded_magpie", Name = "The Gilded Magpie", Rarity = "Mythic" },
}

Config.FreeEgg = {
	CooldownSeconds = 4 * 60 * 60,
	StockpileCap = 2,
}

Config.IncubatorSlotCount = 2 -- matches World's two IncubatorSpot parts

-- Walkspeed multiplier while carrying a revealed egg, by rarity.
Config.CarrySlowdown = {
	Common = 0.95,
	Uncommon = 0.90,
	Rare = 0.80,
	Epic = 0.70,
	Legendary = 0.60,
	Mythic = 0.50,
}

Config.NestRespawnSeconds = 20 -- how long a raided NPC nest stays empty before a new egg appears
Config.NestGrabRange = 8 -- studs - RaidService checks the player is actually this close

-- UserIds allowed to use the Studio debug panel OUTSIDE of Studio (e.g. testing on a phone
-- against the published place). Empty by default - add your own UserId here to test live.
-- REMOVE WHITELIST BEFORE PUBLIC LAUNCH.
Config.DebugWhitelist = {}

Config.DebugShortTimerSeconds = 10 -- what "shorten all timers" sets incubation/free-egg cooldown to

-- ---- Lookup tables, built once below from the lists above. Don't edit these by hand. ----

Config.RarityById = {}
for _, rarity in Config.Rarities do
	Config.RarityById[rarity.Id] = rarity
end

Config.CreatureById = {}
Config.CreaturesByRarity = {}
for _, rarity in Config.Rarities do
	Config.CreaturesByRarity[rarity.Id] = {}
end
for _, creature in Config.Creatures do
	Config.CreatureById[creature.Id] = creature
	table.insert(Config.CreaturesByRarity[creature.Rarity], creature)
end

return Config
