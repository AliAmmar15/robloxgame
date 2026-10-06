# STATUS — live board

Each role logs here: what's done, what's in progress, what's blocked. Lead checks this regularly.
If something's blocked more than 15 minutes, the Lead tells the user immediately — don't just sit on it.

Update format per entry: `- [role] message (timestamp or phase)`

## Done

- [Lead] Phase A setup: CLAUDE.md, docs/GDD-summary.md, docs/CONTRACTS.md, this file, Rojo folder
  structure (`src/shared`, `src/server`, `src/client`), git init, MCP connection verified.
- [Data] `src/shared/Config.lua` — rarities, 12 creatures, free-egg/incubator/carry-slowdown numbers.
- [Data] `src/shared/Remotes.lua` — creates/fetches all 9 Remotes from CONTRACTS.md by name.
- [Data] `src/server/PlayerDataService.lua` — schema, load/save, retries, autosave (60s),
  PlayerRemoving + BindToClose saves. Playtested through MCP (see Decisions log for 2 bugs
  found and fixed during that test).
- [Lead] CONTRACTS.md updated with the Egg↔Raid call boundary (`EggService.RollAndGrantEgg`) and
  the PlayerData access pattern (live mutable table, `os.time()` timers) before Data wrote code.

## In progress

*(nothing — Data role complete, waiting to start World/Egg/Raid)*

## Blocked

*(nothing yet)*

## Decisions log

*(cross-role decisions that don't fit CONTRACTS.md go here, so nobody re-litigates them)*

- 12 placeholder creatures confirmed by user: Pip Mallow, Gutterfox, Lantern Moth, Burrowl, Thornback
  Boar, Mistling, Mirrorpaw, Echo Heron, Stormhide Elk, Hollow Wyrm, Eclipse Fawn, The Gilded Magpie —
  2 per rarity tier, simple placeholder shapes (not final art).
- Roles run one at a time in a single thread (no parallel file-editing agents). QA/Critic may use
  read-only subagents in Phase C only.
- No custom slash commands exist in this project; working in plain English instead.
- `DataStoreService:GetDataStore()` throws immediately if Studio API access is off — must wrap in
  pcall, not just the individual GetAsync/UpdateAsync calls, or the whole server script crashes.
  Found via MCP playtest before moving past Data.
- `Players.PlayerAdded` doesn't fire for a player already connected when `.Start()` runs (hits every
  time in Studio Play Solo) — must also loop `Players:GetPlayers()` once at startup. Found via MCP
  playtest before moving past Data.
- MCP's `execute_luau` (datamodel_type "Server") does not share `_G` or `require()` module cache
  with the actual running server simulation during Play — different sandbox. Use Instance
  Attributes (or other real DataModel state) to verify server-side state through MCP, not `_G`.
- No MCP tool can trigger Studio's own Cmd+S save (keyboard input tool only reaches in-game
  UserInputService, not Studio's UI chrome) — user saves the place manually, Lead reminds them.
