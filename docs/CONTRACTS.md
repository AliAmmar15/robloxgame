# CONTRACTS — read before writing any code

This is the shared agreement between roles. If you need something that isn't here, or need to change a
file you don't own, write it in `docs/STATUS.md` under Blocked and ask the Lead — don't just edit it.

## Folder structure (Rojo)

```
src/
  shared/   -> ReplicatedStorage.Shared       (visible to both server and client)
  server/   -> ServerScriptService.Server     (server-only)
  client/   -> StarterPlayer.StarterPlayerScripts.Client   (client-only)
```

`rojo serve` is already running against `default.project.json` in this folder. Save a file here, it
shows up live in Studio (if the Rojo Studio plugin is connected — Plugins tab → Rojo → Connect).

### File ownership (who writes what)

```
src/shared/
  Config.lua          DATA    — rarities, odds, incubation times, free-egg cadence, the 12 creatures
  Remotes.lua          DATA   — creates/fetches every RemoteEvent/RemoteFunction by name (below)

src/server/
  Main.server.lua       LEAD  — boots everything, requires the modules below (Lead merges here)
  PlayerDataService.lua DATA  — profile load/save/schema, DataStore retries
  EggService.lua         EGG  — grant egg, roll creature, incubator timers, free-egg timer, hatch, Index
  RaidService.lua       RAID  — NPC den, nest slots, grab, carry slowdown, drop, deliver home
  DebugService.lua       EGG  — Studio-only: force rarity, skip timer (built by Egg, since it only
                                 touches Egg's own timers — Raid can add its own debug hooks later if needed)

src/client/
  Main.client.lua        LEAD — boots UI, requires the modules below
  RevealUI.lua             UI — rarity glow + silhouette reveal screen
  IncubatorUI.lua          UI — incubator panel with live timers
  IndexUI.lua               UI — discovered-creatures screen
  HUD.lua                   UI — simple always-on HUD
  TutorialUI.lua             UI — first-60-seconds prompts
  DebugPanelUI.lua           UI — Studio-only panel, calls the Debug remotes
```

Nobody edits another role's file directly. If Egg needs a new Remote, Data adds it to `Remotes.lua`
(two-line add, low conflict risk) — or Egg adds it and flags it in STATUS.md for Data to review.

### Workspace / live instances (MCP) — World role only

World is the only role that calls Roblox Studio MCP tools to create or move instances. Everyone else only
touches files. World builds:

- `Workspace.Map` — baseplate layout: player base area, one NPC den with nest slots, basic lighting
- `Workspace.Map.IncubatorSpots` — Parts, each tagged `"IncubatorSlot"` (CollectionService tag) with an
  `IntAttribute "SlotIndex"` (1 or 2 — matches the incubator slot cap)
- `Workspace.Map.Den.Nests` — Parts, each tagged `"NestSlot"` with an `IntAttribute "NestIndex"`
- `ReplicatedStorage.CreatureModels` — 12 simple placeholder models (basic parts, distinct colors/shapes),
  each named exactly by its `CreatureId` (see Config shape below) — World creates these via MCP too, since
  it's still "editing the live instance tree," just under ReplicatedStorage instead of Workspace.

Server/client code finds these at runtime with `CollectionService:GetTagged(...)` — never hardcode a
Workspace path like `workspace.Map.Den.Nests.Nest1`, since World might reshuffle the layout.

## Remotes (all created by `Remotes.lua`, all names below are final — don't invent new ones without updating this file)

All remotes live under `ReplicatedStorage.Shared.Remotes`. Server validates every input — never trust
what the client sends (e.g. a nest ID must be checked to actually exist and actually have an egg in it).

| Name | Type | Direction | Payload | Returns |
|---|---|---|---|---|
| `GrabEgg` | RemoteFunction | Client → Server | `nestIndex: number` | `{ ok: boolean, eggId: string?, creatureId: string?, rarity: string?, error: string? }` |
| `PlaceInIncubator` | RemoteFunction | Client → Server | `eggId: string, slotIndex: number` | `{ ok: boolean, error: string? }` |
| `ClaimFreeEgg` | RemoteFunction | Client → Server | *(none)* | `{ ok: boolean, eggId: string?, error: string? }` |
| `IncubatorUpdated` | RemoteEvent | Server → Client | `incubators: table` (full current state, see schema) | — |
| `HatchReady` | RemoteEvent | Server → Client | `{ slotIndex: number, creatureId: string }` | — (fires when a timer completes, so UI can show "ready") |
| `CollectHatch` | RemoteFunction | Client → Server | `slotIndex: number` | `{ ok: boolean, creatureId: string?, isNewToIndex: boolean?, error: string? }` |
| `PlayerDataUpdated` | RemoteEvent | Server → Client | full `PlayerData` (schema below) | — (fires after any change, UI just re-renders) |
| `DebugForceRarity` | RemoteFunction | Client → Server | `rarity: string` | `{ ok: boolean, error: string? }` — **Studio-only, server must check `RunService:IsStudio()` and refuse otherwise** |
| `DebugSkipTimer` | RemoteFunction | Client → Server | `slotIndex: number` | `{ ok: boolean, error: string? }` — **Studio-only, same check** |

RemoteFunctions are used where the client needs an immediate yes/no (grab, place, claim, collect, debug).
RemoteEvents are used for server-initiated pushes (state changed, timer finished).

## Egg ↔ Raid boundary (server-to-server call, not a Remote)

The `GrabEgg` RemoteFunction is connected by **RaidService** (grabbing is a raid action), not EggService.
RaidService and EggService then talk to each other with a plain function call — no Remote involved, both
run on the server:

1. Client fires `GrabEgg(nestIndex)`.
2. **RaidService** validates the request: is the player actually near that nest (server-side distance
   check, using `Config.NestGrabRange`), does that nest slot still have an egg, is it off cooldown/not
   respawning. Any failure → return `{ ok = false, error = "..." }` immediately, call nothing else.
3. If valid, **RaidService marks the nest slot empty first** (and starts its respawn timer), *before*
   granting anything — this is what stops a player from firing `GrabEgg` twice in the same frame and
   getting two eggs from one nest.
4. **RaidService then calls `EggService.RollAndGrantEgg(player)`** — a plain Luau function, defined and
   owned by EggService:

   ```lua
   -- EggService.lua
   -- Rolls a creature by Basic Egg odds, creates a new entry in player.CarriedEggs, and returns it.
   -- Only ever called by RaidService, after RaidService has already validated the nest and emptied it.
   -- Does its own roll — the caller never picks the rarity.
   function EggService.RollAndGrantEgg(player: Player): (boolean, string?, string?, string?)
       -- returns: ok, eggId, creatureId, rarity  (last three are nil if ok == false)
   end
   ```

5. RaidService takes the `rarity` from that result and applies the carry slowdown
   (`Config.CarrySlowdown[rarity]` on the player's `Humanoid.WalkSpeed`) — carry mechanics belong to Raid,
   not Egg.
6. RaidService returns the combined result (`ok`, `eggId`, `creatureId`, `rarity`) to the client as the
   `GrabEgg` response.

**Carry slowdown reset** (RaidService's job): set `WalkSpeed` back to normal when the egg is delivered
home, dropped, or the player's character dies (`Humanoid.Died`) — always use a changed-connection or
cleanup so a dead/respawned character can't get stuck slow.

**NPC nest respawn**: after a successful grab, that nest slot stays empty for `Config.NestRespawnSeconds`,
then RaidService puts a fresh egg-grabbable state back (no player interaction needed — NPC dens always
have a target, per the GDD).

## Data shapes

### PlayerData (what DataStore saves, one record per player)

```lua
{
  Version = 1,                    -- schema version, bump if shape changes, for migration later

  CarriedEggs = {                 -- eggs picked up, revealed, not yet placed in an incubator
    [eggId] = { CreatureId = "pip_mallow", Rarity = "Common", RevealedAt = 1234567890 },
  },

  Incubators = {                  -- fixed-size array, length = IncubatorSlotCount (2 today, see Config)
    [1] = { EggId = "...", CreatureId = "...", Rarity = "...", StartedAt = 123, HatchAt = 456 } ,
    [2] = false,                  -- false/nil = empty slot
  },

  Index = {                       -- discovered creatures, set-like table
    ["pip_mallow"] = true,
  },

  FreeEgg = {
    LastClaimedAt = 0,            -- unix time, 0 = never claimed
    Stockpile = 0,                -- 0..2, cap defined in Config
  },

  CreatedAt = 1234567890,
  LastLoginAt = 1234567890,
}
```

`eggId` = a unique string per egg instance, e.g. `HttpService:GenerateGUID(false)`. Needed because two
Common eggs must stay distinguishable while carried.

### Config shapes (`src/shared/Config.lua` — DATA owns this, everyone else only reads it)

```lua
Config.Rarities = {
  -- ordered Common → Mythic, order matters for roll logic
  { Id = "Common",    IncubationSeconds = 5 * 60,      BasicEggOdds = 0.62   },
  { Id = "Uncommon",  IncubationSeconds = 15 * 60,     BasicEggOdds = 0.25   },
  { Id = "Rare",      IncubationSeconds = 60 * 60,     BasicEggOdds = 0.10   },
  { Id = "Epic",      IncubationSeconds = 2 * 60 * 60, BasicEggOdds = 0.025  },
  { Id = "Legendary", IncubationSeconds = 4 * 60 * 60, BasicEggOdds = 0.0045 },
  { Id = "Mythic",    IncubationSeconds = 8 * 60 * 60, BasicEggOdds = 0.0005 },
}

Config.Creatures = {
  -- 12 placeholders, 2 per tier, CreatureId is lowercase_snake_case and must match the
  -- ReplicatedStorage.CreatureModels model name World creates
  { Id = "pip_mallow",     Name = "Pip Mallow",     Rarity = "Common"    },
  { Id = "gutterfox",      Name = "Gutterfox",      Rarity = "Common"    },
  { Id = "lantern_moth",   Name = "Lantern Moth",   Rarity = "Uncommon"  },
  { Id = "burrowl",        Name = "Burrowl",        Rarity = "Uncommon"  },
  { Id = "thornback_boar", Name = "Thornback Boar", Rarity = "Rare"      },
  { Id = "mistling",       Name = "Mistling",       Rarity = "Rare"      },
  { Id = "mirrorpaw",      Name = "Mirrorpaw",      Rarity = "Epic"      },
  { Id = "echo_heron",     Name = "Echo Heron",     Rarity = "Epic"      },
  { Id = "stormhide_elk",  Name = "Stormhide Elk",  Rarity = "Legendary" },
  { Id = "hollow_wyrm",    Name = "Hollow Wyrm",    Rarity = "Legendary" },
  { Id = "eclipse_fawn",   Name = "Eclipse Fawn",   Rarity = "Mythic"    },
  { Id = "gilded_magpie",  Name = "The Gilded Magpie", Rarity = "Mythic" },
}

Config.FreeEgg = {
  CooldownSeconds = 4 * 60 * 60,
  StockpileCap = 2,
}

Config.IncubatorSlotCount = 2   -- matches World's two IncubatorSpot parts

Config.CarrySlowdown = {
  -- walkspeed multiplier while carrying a revealed egg, by rarity
  Common = 0.95, Uncommon = 0.90, Rare = 0.80, Epic = 0.70, Legendary = 0.60, Mythic = 0.50,
}

Config.NestRespawnSeconds = 20   -- how long a raided NPC nest stays empty before a new egg appears
Config.NestGrabRange = 8          -- studs — RaidService checks the player is actually this close
```

Roll logic (Egg owns this): pick a random tier using `BasicEggOdds` as weights, then pick uniformly among
that tier's creatures (today, 2 per tier → 50/50 within the tier).

### PlayerData access pattern

`PlayerDataService.Get(player)` returns the **live, mutable table** for that player (not a copy). Egg,
Raid, etc. read and write fields on it directly (e.g. `data.Index[creatureId] = true`). PlayerDataService
itself only handles *when* that table gets written to the DataStore (autosave timer, on leave, on
shutdown) — it doesn't provide setter functions for every field, to keep this simple for the prototype.
One consequence: always get a fresh reference with `PlayerDataService.Get(player)` right before reading/
writing — don't cache the table across a `task.wait`, in case the player left in between.

All timers (`RevealedAt`, `StartedAt`, `HatchAt`, `LastClaimedAt`) are `os.time()` on the **server** —
never a `wait()`-based countdown. This is what makes incubation and the free-egg cooldown keep progressing
while the player is offline: on login, compare `os.time()` against the stored timestamp to work out what's
already finished (an incubator may already be done hatching, a free egg stockpile may have refilled more
than once) instead of resuming a loop from where it left off.

## Naming conventions

- `CreatureId`, tag names, attribute names: as written above — don't improvise variants.
- Rarity strings are always `"Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"` — exact
  capitalization, used as table keys in Config, so typos break lookups silently. Copy-paste, don't retype.
- All times are Unix seconds (`os.time()`), not `os.clock()` or `tick()` — those don't survive a server
  restart or match across client/server, and we need `HatchAt` to still mean something after a rejoin.
