# Egg Heist Arena — prototype

A vertical slice of "Egg Heist Arena" (see [docs/Egg_Heist_Arena_Game_Design_Document.pdf](docs/Egg_Heist_Arena_Game_Design_Document.pdf)
for the full game, [docs/GDD-summary.md](docs/GDD-summary.md) for what this build covers).

## How to run it

**In Studio:**
1. Open `Place1.rbxl` (or your renamed place) in Roblox Studio.
2. In this folder, run `rojo serve` if it isn't already running (check with `ps aux | grep rojo`).
3. In Studio: Plugins tab → Rojo → Connect (if it shows "Connect" instead of your project name).
4. Press Play.

**On your phone** (needed for real testing — see "Publishing for phone testing" below).

## What works

The full core loop, end to end, server-validated, playtested via MCP with real concurrent-spam
testing (see [docs/QA-REPORT.md](docs/QA-REPORT.md) and [docs/STATUS.md](docs/STATUS.md) for
the full evidence trail):

- Join → spawn directly at the den (no menus)
- Walk to a nest, grab an egg (ProximityPrompt) → instant reveal (rarity glow + silhouette → name)
- Carry it — rarer eggs slow you down more, recovers automatically once delivered
- Place in either of 2 incubators, real countdown by rarity (5 min – 8 hr)
- Hatch → added to your Index (discovered-creatures grid)
- Free Basic Egg every 4 hours (stockpile cap 2), correctly catches up after being offline
- Data saves/loads via DataStore, survives leaving and rejoining (verified via a full stop/restart)
- Debug panel (🛠 button): force rarity, skip a timer, shorten all timers to 10s, give a free
  egg instantly, reset your data — Studio-only by default, or whitelist your UserId to use it
  in the published game too (see below)
- Nest respawns 20s after being raided; can't be re-grabbed while empty
- Dying drops whatever you were carrying and resets your speed

## What's missing (by design — see CLAUDE.md "out of scope")

Battles, PvP raids, base shields, Gem Eggs, any Robux purchase, game passes, trading, seasons,
ads. **Zero monetization code exists in this build.**

## Known issues

| Issue | Detail |
|---|---|
| No real creature art | 12 placeholder shapes (colored balls/blocks by rarity), not final models |
| Reveal sound is silent | `Config.RaritySound` has placeholder `rbxassetid://0` for all 6 tiers — needs real uploaded sound IDs |
| `ProximityPrompt → reveal` chain untested end-to-end | Every piece is independently verified, but the literal "hold E at a nest" path couldn't be synthetically triggered in this dev environment — check this first when you playtest (see docs/STATUS.md) |
| Mobile layout unverified in an emulator | No device-emulation tool was available here; layout follows standard Roblox mobile patterns (scale-based sizing, large touch targets) but your phone test tonight is the real check |
| Carry-speed is client-trusted | A modified client could in theory ignore the slowdown; no PvP exists today so there's nothing to exploit against — see docs/QA-REPORT.md for the full reasoning. Server logs a warning if it sees implausible movement, but doesn't block it |
| Debug button visible to all players | Harmless — every tap from a non-whitelisted player just fails with an error message |

## Using the debug panel

Tap the 🛠 icon (top-right). Works automatically in Studio. **To use it in the published game**
(needed for phone testing), add your UserId to the whitelist — see "Setup you need to do" below.

- **Force rarity**: next egg you grab will be that rarity
- **Skip Slot 1/2**: instantly finishes that incubator's timer (only works on an occupied slot)
- **Shorten All Timers**: toggles 10-second incubation/free-egg timers instead of the real numbers
- **Give Free Egg Now**: instant roll, bypasses the stockpile entirely
- **Reset My Data**: wipes you back to a fresh profile

## Where the tuning numbers live

Everything — rarity odds, incubation times, the 12 creatures, free-egg cadence, carry
slowdown, nest respawn/range, rarity colors/sounds, the debug whitelist — is in
**`src/shared/Config.lua`**. Nothing else hardcodes these numbers. Change balance there only.

## Project structure

```
src/shared/   -> ReplicatedStorage.Shared     Config, Remotes (both server+client read these)
src/server/   -> ServerScriptService.Server   all gameplay logic, DataStore, debug tools
src/client/   -> StarterPlayer.StarterPlayerScripts.Client   all UI
docs/         design doc, contracts, status log, QA report, test plan
```

Full technical contract (Remote names, data shapes, module ownership): [docs/CONTRACTS.md](docs/CONTRACTS.md).

## Setup you need to do

1. **Enable DataStores in Studio**: Game Settings → Security → "Enable Studio Access to API
   Services" → On. Without this, saving silently falls back to in-memory-only each session
   (the game still works, your progress just won't survive closing Studio).
2. **Whitelist yourself for the live debug panel**: open `src/shared/Config.lua`, find
   `Config.DebugWhitelist = {}`, change it to `Config.DebugWhitelist = { 11769407326 }` (that's
   your UserId, read from this Studio session). Commit that change before publishing if you
   want debug tools on your phone tonight. **Remove it again before any public launch** —
   there's already a boot-time server warning if you forget and publish with it non-empty.
3. **Publish the place as Private, test on your phone**: see the next section.

## Publishing for phone testing

1. In Studio: **File → Publish to Roblox** (or **Publish** if already published once).
2. Go to the place on the Roblox website (create.roblox.com → your place → **Basic Info**) →
   set **Playability** to **Private** (not Public) — this keeps it unlisted; you'll still be
   able to open it yourself.
3. Confirm **API Services** is on for the live place too: create.roblox.com → your experience
   → **Settings** → **Security** → "Enable Studio Access to API Services" (note: for a
   *published* place this setting controls API access generally, separate from the Studio-only
   toggle in step "Setup you need to do" above — both need to be on).
4. On your phone: open the **Roblox app**, sign in with **the same account** you publish from
   (private places are only visible to accounts with access), search your name or use **Recent**
   / a direct share link from the website's **Share** button on the place page.
5. **Every time you make a code change and want to test it on your phone**: Studio → **File →
   Publish to Roblox** again. Rojo syncing to your *local* Studio session does NOT update the
   published place — that's a separate, manual step you have to repeat.

## Next 5 tasks, in priority order

1. Playtest the real `ProximityPrompt → grab → reveal` flow yourself first (the one thing this
   session couldn't verify end-to-end) — confirm it actually triggers walking up to a nest.
2. Add real creature art (replacing the 12 placeholder shapes) — biggest visible-quality jump.
3. Upload real reveal sounds per rarity, drop the asset IDs into `Config.RaritySound`.
4. Run the 10-minute friend test (`docs/TEST-PLAN.md`) and fold their 5 feedback answers back
   into design decisions.
5. Decide whether the carry-speed client-trust gap (see Known Issues) needs real server-side
   movement validation before any multiplayer/PvP feature — revisit once that's on the roadmap.
