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

## Visual pass (branch `visual-pass`) — Part A results

Branch created from a clean tree at `bf4e615` so the whole pass can be reverted in one step.

**A1 world** — rebuilt IN PLACE (Den / PlayerBase folders, NestSlot / IncubatorSlot tags, and
NestIndex / SlotIndex attributes all preserved):
- 230×220 grass ground replacing the bare baseplate; dirt path from the Den gate to the base.
- Den: fenced yard with a 14-stud gate, barn, 5 trees, hay bales, bushes, 4 lanterns, and a
  34-stud banner + beacon landmark.
- Nests 3 → 6. Verified RaidService / NestInteractionUI / TutorialUI find nests **by tag** with
  no hardcoded counts or paths; both services now also listen to `GetInstanceAddedSignal` so a
  future change in nest count needs no code edit.
- Player base 72 studs from the Den (brief asked 60–80): picket fence, HOME sign, welcome mat,
  2 glowing incubator stands with SLOT billboards. Spawn kept at the Den gate as instructed.
- Verified programmatically: **no ground gaps** (raycast grid over the whole play area all hit
  solid), **all 6 spawn→nest walk lines clear**, **spawn→base clear**, **beacon visible from
  spawn** (47 studs, unoccluded), **no parts at the origin**.
- Bug found and fixed during this: Roblox `Cylinder` parts run their length along **X**, so the
  nest discs, incubator bowls and halos were malformed until their size tuples were corrected.

**A2 eggs + creatures**:
- Nest eggs are deliberately **rarity-neutral** (identical cream egg in every nest) so the nest
  never leaks what's inside — the roll happens at pickup, per the GDD.
- All 12 creatures rebuilt from parts, 10–26 parts each, distinct silhouettes/palettes. Names
  still match Config IDs exactly; every model has a PrimaryPart.
- The models are now actually **visible in game** for the first time, via ViewportFrames in the
  Index, the reveal card, and the incubator cards. Before this they existed but were never shown.

**A3 UI** — the headline complaint was dark text on a dark bar:
- New design system allows only two pairings: Ink-on-bright and White-on-dark.
- **Measured in a live session: 45 text items, 0 below 4.5:1** (worst 4.67:1 — the Epic rarity
  button). The bottom bar went from unreadable to **11.5:1** (Incubators) and **9.0:1** (Index).
- **17 buttons, 0 below 44×44.** Nothing off-screen at 1386×721.
- Debug panel visibility now driven by a server-set `DebugAllowed` player attribute (documented
  in CONTRACTS.md as **display-only** — every remote still re-checks authorization server-side).

**A4 guidance/feel**: objective beam (yellow → nest, cyan → home) using Attachments + Beam,
pickup sparkle, nest respawn puff, carry-egg-on-head scaled and tinted by rarity (built
server-side so everyone sees it), button pressed states, camera nudge on reveal.

**A5 stretch (guard NPC): NOT BUILT** — explicitly the first thing to cut per the brief, and
Part B matters more.

### Two real bugs caught from the live Output during this pass
- Placeholder `rbxassetid://0` was logging "Failed to load sound" on **every** reveal. RevealUI
  now skips any sound still set to the placeholder, so the console stays clean until real IDs land.
- The speed detector was flooding the log on legitimate respawns/teleports. It now requires a
  3-tick streak, has a 30s per-player cooldown, and skips the tick right after a character spawns.

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

- [Lead] Handoff: docs/TEST-PLAN.md (10-min friend test script, 5 questions, known-issues
  table) and README.md (run instructions, what works, known issues, debug panel guide, tuning
  location, publish-for-phone steps, next 5 tasks) written.

## In progress

*(nothing — vertical slice complete, QA'd, documented. Ready for the user's own phone test.)*

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
