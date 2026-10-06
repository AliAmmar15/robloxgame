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

-- SOLID/FILL color per rarity - creature placeholder models, the reveal banner background,
-- the debug rarity buttons. Anything where the rarity color is a FILL behind dark text.
Config.RarityColor = {
	Common = Color3.fromRGB(165, 165, 165),
	Uncommon = Color3.fromRGB(85, 170, 127),
	Rare = Color3.fromRGB(85, 140, 255),
	Epic = Color3.fromRGB(170, 85, 255),
	Legendary = Color3.fromRGB(255, 170, 0),
	Mythic = Color3.fromRGB(255, 85, 170),
}

-- TEXT color per rarity - brighter variants, used whenever the rarity color is the TEXT
-- rather than the fill (incubator card titles, Index names, the reveal name).
-- The fill colors above are too dark as text on the raised card background: measured
-- 3.82:1 for Rare and 3.16:1 for Epic, both under the 4.5:1 minimum. These all clear
-- 5.4:1 on PanelRaised and better on Panel. Don't use RarityColor for text.
Config.RarityTextColor = {
	Common = Color3.fromRGB(200, 200, 205),
	Uncommon = Color3.fromRGB(130, 225, 170),
	Rare = Color3.fromRGB(130, 185, 255),
	Epic = Color3.fromRGB(205, 150, 255),
	Legendary = Color3.fromRGB(255, 195, 70),
	Mythic = Color3.fromRGB(255, 145, 200),
}

-- PLACEHOLDER sound IDs for the reveal screen, by rarity - these are NOT real purchased/
-- uploaded sounds, just a format example ("rbxassetid://0" = silent, valid SoundId, won't
-- error). Replace each with a real uploaded asset ID before this matters for real testing.
-- Pitch/volume still vary by tier below even with placeholder silence, so the reveal isn't
-- totally inert - swap SoundId first, tune Pitch/Volume to taste after.
Config.RaritySound = {
	Common = { SoundId = "rbxassetid://0", Volume = 0.5, Pitch = 1.0 },
	Uncommon = { SoundId = "rbxassetid://0", Volume = 0.5, Pitch = 1.05 },
	Rare = { SoundId = "rbxassetid://0", Volume = 0.6, Pitch = 1.1 },
	Epic = { SoundId = "rbxassetid://0", Volume = 0.7, Pitch = 1.15 },
	Legendary = { SoundId = "rbxassetid://0", Volume = 0.8, Pitch = 1.2 },
	Mythic = { SoundId = "rbxassetid://0", Volume = 0.9, Pitch = 1.3 },
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
