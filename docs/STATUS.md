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

- [World] `Workspace.Map.Den` — floor + 3 Parts tagged `NestSlot` (NestIndex 1-3).
- [World] `Workspace.Map.PlayerBase` — floor + 2 Parts tagged `IncubatorSlot` (SlotIndex 1-2).
- [World] Default `SpawnLocation` relocated to the den entrance (drops player straight into the
  raid area, no teleport code needed for today's slice).
- [World] `ReplicatedStorage.CreatureModels` — 12 placeholder Models, Name = CreatureId exactly
  matching Config.lua, colored/sized by rarity tier. Verified via MCP: tag counts (3 nests, 2
  incubator spots) and all 12 model names/rarities match Config exactly.
- Built live via MCP in Edit mode — **this only exists in the local .rbxl file, not git. Please
  save the place (Cmd+S) now.**

- [Egg] `EggService.lua` — RollAndGrantEgg (called only by Raid), PlaceInIncubator, CollectHatch,
  ClaimFreeEgg handlers, free-egg accrual from elapsed time, hatch-ready tick/notify loop.
- [Egg] `DebugService.lua` — DebugForceRarity, DebugSkipTimer, both gated on `RunService:IsStudio()`.
- [Egg] Playtested via MCP (InvokeServer from a real client context): claim -> place -> debug-skip
  -> collect -> Index round trip all correct; double-collect on an emptied slot correctly
  rejected ("That incubator is empty."). New profiles start with a full free-egg stockpile
  (LastClaimedAt=0 reads as "infinitely overdue") - matches the GDD's "minute 0-1: collect the
  free egg" onboarding goal, confirmed intentional not a bug.

- [Raid] `RaidService.lua` — GrabEgg handler (distance + nest-state validation, empties nest
  before granting), carry-speed tick (worst-of-all-carried, recovers automatically once
  PlaceInIncubator empties CarriedEggs), death clears carried eggs + resets speed, nest respawn.
  Playtested via MCP: too-far correctly rejected, successful grab applies correct slowdown,
  immediate re-grab on emptied nest correctly rejected.
- [Lead] Expanded debug panel per updated instructions: `Config.DebugWhitelist` (empty,
  "REMOVE WHITELIST BEFORE PUBLIC LAUNCH"), `DebugSetShortTimers`, `DebugGiveFreeEgg`,
  `DebugResetData` remotes added to CONTRACTS.md and implemented. All 5 debug remotes now
  check Studio-or-whitelisted instead of Studio-only. Playtested via MCP: reset correctly wipes
  stale CarriedEggs, give-free-egg works, short-timers correctly override 15min Uncommon down
  to ~10s on placement.

- [UI] All client screens built: RevealUI (silhouette-then-name, rarity glow), IncubatorUI
  (2 slots, live countdowns, place/collect), IndexUI (12-creature grid), HUD (toggle buttons,
  carry count), TutorialUI (one-line prompts derived from data snapshot, never regresses),
  NestInteractionUI (ProximityPrompts on nests -> GrabEgg -> reveal), DebugPanelUI (all 5
  debug tools, always visible but server-gated). Also added `UIHelpers.lua` (shared button/
  label/formatting helpers) and `Config.RarityColor` (centralizes colors World and UI both use).
- [Lead] Fixed a real gap found while designing UI: `PlayerDataService.Load()` never pushed
  initial state to the client, so a rejoining player's UI would start blank until their first
  action. Now fires `PlayerDataUpdated` once right after load - documented in CONTRACTS.md.
- [Lead] Playtested via MCP using real mouse clicks (not just InvokeServer) on the actual
  rendered buttons: HUD toggle, in-panel Place Egg, debug toggle, and Reset My Data all
  confirmed working end-to-end (click -> remote -> data change -> correct re-render).
- **Known MCP tooling quirk**: `screen_capture` renders shallow ScreenGui children (HUD bar,
  tutorial banner) correctly, but fails to visually render deeply-nested runtime-created
  frames (e.g. the Incubator panel's slot rows) even though every property (color, text,
  size, Visible) is correct on inspection and the buttons are fully clickable/functional.
  Verified this is capture-only, not a real bug, by checking live property values and
  functional clicks directly. Use property inspection + real clicks to verify UI, not
  screenshots alone, if this comes up again.

- [Lead] QA pass: 3 parallel read-only audits (exploits/data-safety/GDD-compliance), merged
  into docs/QA-REPORT.md. Fixed the 1 blocker, addressed the 1 major as a scoped detection
  (documented why full enforcement is out of scope), fixed the cheap minors, documented the
  deferred ones. See QA-REPORT.md for full detail.
- [Lead] Found and fixed one more real bug during full-playthrough testing (below): the
  free-egg accrual tick updated Stockpile server-side but never pushed the change to the
  client, risking a stale displayed number. Fixed, verified, committed.

## Full playthrough (with evidence) — all via MCP against the real running server

| Step | Result | Evidence |
|---|---|---|
| Join | ✅ | Console: `[EVENT] ... joined` |
| Tutorial raid / grab egg | ✅ | `GrabEgg` → `{ok:true, rarity:"Common", creatureId:"gutterfox"}` from real nest proximity |
| Reveal | ✅ | Same response feeds `RevealUI.Show` directly (rarity+creatureId never guessed client-side) |
| Carry (slowed) | ✅ | WalkSpeed 16→15.2 after a Common grab (16×0.95 exactly); 16→11.2 for an Epic grab (16×0.70 exactly) |
| Deliver / place in incubator | ✅ | `PlaceInIncubator` ok:true; WalkSpeed returned to 16 within 1 tick of placing the only carried egg |
| Skip timer (debug) | ✅ | `DebugSkipTimer` ok:true, `HatchAt` moved to now without a new roll |
| Hatch | ✅ | `CollectHatch` → `{ok:true, isNewToIndex:true, creatureId:...}` |
| Creature in Index | ✅ | Confirmed `Index[creatureId] = true` in the pushed `PlayerDataUpdated` payload |
| Leave and rejoin, data intact | ✅ | Set a carried Epic egg + 1 Index entry, stopped Play (BindToClose), restarted (fresh `Load()`) — both survived exactly |
| Free Basic Egg timer/cap after rejoin | ✅ | Post-rejoin stockpile correctly re-accrued to the cap (2) from the restored `LastClaimedAt` |
| Death drops carried egg | ✅ | Grabbed (WalkSpeed slowed) → `Humanoid.Health = 0` → carried-egg count back to 0 |
| Nest respawn | ✅ | Re-grabbing the same nest immediately after a successful grab correctly failed ("nest is empty right now") |
| Remote spam — GrabEgg (far away) | ✅ | 20 concurrent calls, 0 succeeded (distance check holds under spam) |
| Remote spam — GrabEgg (valid, near nest) | ✅ | 15 concurrent calls on one nest, **exactly 1** succeeded — no duplication |
| Remote spam — ClaimFreeEgg | ✅ | 20 concurrent calls on a freshly-capped stockpile, **exactly 2** succeeded — matches `StockpileCap`, no duplication |
| Remote spam — PlaceInIncubator | ✅ | 15 concurrent calls with the same egg/slot, **exactly 1** succeeded |
| Remote spam — CollectHatch | ✅ | 15 concurrent calls on one ready slot, **exactly 1** succeeded |

No blockers found in the full playthrough beyond the accrual-push bug (fixed above).

- [Lead] Polish pass: `Config.RaritySound` added (placeholder `rbxassetid://0` per tier, real
  IDs needed from user — volume/pitch already vary by tier), wired into `RevealUI.lua`. First-
  60-seconds structure was already in place (spawn point sits at the den, no menus before the
  raid) — distance from spawn to the nearest nest is ~17 studs, comfortably under a few
  seconds of walk time once a real player is in control.
- **Known test gap**: `NestInteractionUI`'s `ProximityPrompt → GrabEgg → RevealUI.Show` chain
  could not be exercised end-to-end via MCP — there's no way to synthetically trigger a real
  `ProximityPrompt` hold in this environment, and calling `GrabEgg` directly (as all my other
  tests do) bypasses the prompt entirely. Every piece of that chain is independently verified
  (`GrabEgg` exhaustively tested; `RevealUI.Show`'s internals are plain property assignment,
  same pattern verified working elsewhere) and `ProximityPrompt` itself is a simple, standard
  Roblox API — but the literal "walk up and hold E / tap the prompt" path has only been
  verified by code review, not a live test. **Please check this yourself first** when you playtest.
- No mobile-device-emulation tool exists for Roblox Studio in this environment (only the
  Browser pane has one, not applicable here). Layout follows Roblox's standard
  mobile-responsive pattern throughout (Scale-based UDim2 sizing, `TextScaled` text, 44px+
  touch targets) but wasn't verified in an actual narrow/portrait emulated viewport — check
  this on your phone tonight, that's the real test anyway.

## In progress

*(nothing — full playthrough and polish pass complete. Moving to handoff docs.)*

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
