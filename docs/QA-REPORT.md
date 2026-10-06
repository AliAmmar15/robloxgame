# QA Report

Three read-only subagent reviews (exploits, data safety, GDD compliance), run in parallel
against the full codebase after Data/World/Egg/Raid/UI/Debug were all built and playtested.
Findings below, merged, with what was actually done about each one.

## Blockers — fixed

| File | Issue | Fix |
|---|---|---|
| `src/server/PlayerDataService.lua` | `Save()` had a `saveInFlight` guard that made it **silently no-op** if another save for the same player was already running. If `PlayerRemoving` or `BindToClose` fired while the 60s autosave was mid-retry, the player's final save could be skipped entirely — not corrupted, just **lost** (their last few minutes of progress never written). | `Save()` now waits (`while saveInFlight[userId] do task.wait(0.1) end`) for any in-flight save to finish, then always performs its own fresh save with the current cache, instead of skipping itself. Verified `BindToClose` and `PlayerRemoving` both now go through this correctly. |

## Major — addressed as a scoped detection, not full enforcement

| File | Issue | Decision |
|---|---|---|
| `src/server/RaidService.lua` | Carry slowdown is enforced by the server repeatedly setting `Humanoid.WalkSpeed`, but a modified client can override `WalkSpeed` locally (character movement isn't server-authoritative by default in Roblox) and ignore the slowdown. | **No PvP or other adversarial multiplayer exists today** (explicitly out of scope — see CLAUDE.md), so the only person a speed-hack could affect is the cheater's own single-player test session. A full server-side movement-authority system (position-delta validation, rubber-banding, tuning for false positives) is a real feature add, not a one-line fix, and isn't justified by today's stakes. Added a cheap, proportionate **detection-only** check instead: the existing 1s tick now also tracks each player's position and `warn()`s in the server log if they moved further than physically plausible (2.5x generous tolerance) — visible if it ever matters, enforces nothing, zero false-positive risk to real players. Revisit with real enforcement before any PvP/competitive feature ships. |

## Minor — fixed

| File | Issue | Fix |
|---|---|---|
| `src/server/EggService.lua` | `SkipIncubatorTimer` didn't bounds-check `slotIndex` before indexing `data.Incubators` (happened to fail safely today, but inconsistent with the other two handlers). | Added the same `slotIndex < 1 or slotIndex > Config.IncubatorSlotCount` check used elsewhere. |
| `src/server/DebugService.lua` | `Config.DebugWhitelist` has a "remove before launch" code comment, but nothing would actually surface a forgotten non-empty whitelist in a published game. | `DebugService.Start()` now `warn()`s loudly on boot if the server isn't Studio and the whitelist is non-empty. |
| `src/server/PlayerDataService.lua` | `RETRY_WAIT_SECONDS` / surrounding comments implied real backoff; it's actually a fixed 2s delay between attempts. | Renamed/commented accurately. |
| `src/server/PlayerDataService.lua` | The `UpdateAsync` comment overstated what "never overwrite good data" protects against — it always writes the local cache regardless of `oldValue`, which is fine (this server is the only one with this player loaded) but wasn't explained. | Clarified the comment; kept `UpdateAsync` as explicitly requested (not switched to `SetAsync`) — it's still correct for its actual purpose (atomic write, never a partial one). |

## Minor — deferred (documented, not fixed tonight)

| File | Issue | Why deferred |
|---|---|---|
| `src/server/PlayerDataService.lua` | `fillMissingFields` can't handle `Config.IncubatorSlotCount` ever *shrinking* (an old save's slot 3 would become permanently unreachable). | `IncubatorSlotCount` is fixed at 2 and isn't changing today; building migration logic for a value that isn't changing is premature. Flag if the slot count ever changes. |
| `src/shared/Config.lua` schema | `PlayerData.Version` exists but nothing reads/increments it — `fillMissingFields` is the only "migration" today, and only handles additions. | No real migration need yet (single schema version in existence). Start using it when the schema actually changes. |
| `src/server/EggService.lua` | No cap on how many eggs a player can carry simultaneously. | Not exploitable (no benefit to stacking carried eggs beyond permanent slowdown), and not specified as a requirement today. |

## Clean — no issues found

- **Remote spam / TOCTOU races** (GrabEgg, PlaceInIncubator, ClaimFreeEgg, CollectHatch): every handler's check-then-mutate sequence has zero yield points before mutating state, so Lua's cooperative scheduling prevents interleaving from concurrent/rapid fires. Nest-emptying-before-granting closes the duplicate-egg gap as designed.
- **Distance cheating**: range check uses server-read character position only, computed and consumed synchronously.
- **Timer cheating**: all timestamps are server `os.time()`; accrual math verified correct including the debug short-timer override, with no overflow/negative-number risk at realistic time scales.
- **Debug remote gating**: all 5 `Debug*` remotes correctly check `IsStudio() or whitelist` server-side, never trusting the client for the gate itself.
- **Client trust**: client never sends rarity/creatureId/amount — all server-derived.
- **Rarity odds**: sum to exactly 1.0, match the GDD exactly, roll logic has a safe fallback.
- **Incubation timers**: match the GDD exactly in seconds.
- **Creature IDs**: consistent snake_case, map 1:1 to the GDD's 12 names.
- **Free egg cadence**: matches the GDD exactly (4h cooldown, cap 2).
- **Hatched creatures never stealable**: `RaidService.handleGrabEgg` only ever touches nest state and `CarriedEggs` — never reads or writes `Incubators` or `Index`.
- **Zero monetization code**: grepped the whole `src/` tree for Robux/MarketplaceService/DeveloperProducts/GamePasses/PromptPurchase — zero hits.
- **Zero out-of-scope systems**: grepped for battle/PvP/shield/GemEgg code — zero hits.
- **Both previously-fixed bugs** (GetDataStore throwing at module load, PlayerAdded missing already-connected players) verified still correctly in place, not regressed by later edits.

## Full-playthrough evidence

See the "Full playthrough" section of `docs/STATUS.md` for the step-by-step evidence trail
(join → raid → reveal → carry → deliver → incubate → skip → hatch → Index → rejoin →
free-egg-after-rejoin → remote spam), each verified via MCP with real server responses.
