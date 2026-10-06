# Sounds needed

Every sound in the game is currently a **placeholder** (`rbxassetid://0`). Nothing is
broken by this — every moment below is carried by motion, color, and particles, so the
game reads correctly in silence. Filling these in is polish, not a fix.

## How to fill one in

1. Upload the audio on the Roblox Creator Dashboard (Creations → your experience → Audio),
   or find one in the Toolbox you have rights to use.
2. Copy its asset id.
3. Put it in `src/shared/Config.lua` under `Config.RaritySound`, as `"rbxassetid://<id>"`.

`RevealUI.lua` deliberately **skips playing** any entry still set to `rbxassetid://0`, so
the Output stays clean until a real id is in place. Nothing else needs changing.

## The list

| Where | Config key | What it should feel like | Priority |
|---|---|---|---|
| Egg reveal — Common | `Config.RaritySound.Common` | Soft, friendly pop. Low stakes. | High |
| Egg reveal — Uncommon | `Config.RaritySound.Uncommon` | Same family as Common, a touch brighter. | High |
| Egg reveal — Rare | `Config.RaritySound.Rare` | Noticeably nicer — a small chime on top of the pop. | High |
| Egg reveal — Epic | `Config.RaritySound.Epic` | A rising sparkle. The player should look up. | High |
| Egg reveal — Legendary | `Config.RaritySound.Legendary` | Big, warm, a held note. Rare enough to be an event. | High |
| Egg reveal — Mythic | `Config.RaritySound.Mythic` | Unmistakable. Longest and most dramatic of the six. | High |

`Volume` and `PlaybackSpeed` (pitch) already escalate per tier in Config, so even one
single uploaded sound reused across all six tiers would produce a usable rarity ladder —
that's a reasonable first pass if you don't want to source six clips.

## Not yet wired (deliberately out of scope tonight)

These moments currently have **visual** feedback only. If you want audio on them later,
they'd each need a new Sound instance; none of them have a Config entry yet:

| Moment | Current visual feedback | File that would own it |
|---|---|---|
| Egg pickup | Yellow sparkle burst at the nest | `src/client/NestInteractionUI.lua` |
| Nest respawn | White smoke puff at the nest | `src/server/RaidService.lua` |
| Placing an egg in an incubator | Card swaps to a countdown + progress bar | `src/client/IncubatorUI.lua` |
| Hatch / collect | Card flips to "✨ Collect", Index tile turns from silhouette to color | `src/client/IncubatorUI.lua` |
| Button taps | Shrink + darken pressed state | `src/client/UIHelpers.lua` |
