# Egg Heist Arena — project rules

Roblox game. Source of truth for design is [docs/Egg_Heist_Arena_Game_Design_Document.pdf](docs/Egg_Heist_Arena_Game_Design_Document.pdf).
The condensed version of what matters *today* is [docs/GDD-summary.md](docs/GDD-summary.md).
Shared technical contracts (folder layout, module names, Remote names, data shapes) are in
[docs/CONTRACTS.md](docs/CONTRACTS.md) — every role must follow these so work doesn't collide.
Live progress board is [docs/STATUS.md](docs/STATUS.md).

The user is not an expert coder. Keep explanations short and plain. Ask before big decisions.

## Today's goal: a vertical slice

Build only this, end to end, playable in Studio:

- Player joins, drops straight into a short tutorial raid on ONE NPC den. No menus first.
- Grab an egg from a nest. Rarer eggs slow the player while carrying.
- Creature is REVEALED the moment the egg is picked up (rarity glow + silhouette).
- Carry it home, place it in an incubator.
- Incubation timers by rarity: Common 5 min, Uncommon 15 min, Rare 1 h, Epic 2 h, Legendary 4 h, Mythic 8 h.
- On hatch: get the creature (12 placeholder creatures, 2 per rarity tier — see CONTRACTS.md).
- Index screen records each creature discovered.
- Free Basic Egg every 4 hours, stockpile cap 2.
- Basic Egg odds: Common 62%, Uncommon 25%, Rare 10%, Epic 2.5%, Legendary 0.45%, Mythic 0.05%.
- Player data saves and loads (DataStore).
- Studio-only DEBUG panel: force a rarity, skip timers.

### Out of scope today — do not build

Battles, PvP raids (only one fixed NPC den today), base shields, Gem Eggs, any Robux purchase,
game passes, trading, seasons, ads. **No monetization code of any kind today.**

## Rules for all work

- Server-authoritative. Client only displays and sends requests. Validate every remote call on the server.
- All odds, timers, rarity tables, and creature data live in ONE module: `src/shared/Config.lua`.
- Raids only ever steal **unhatched eggs sitting in a nest**. Hatched creatures are never stealable.
- Nothing random is ever tied to Robux. No Robux code at all today.
- Original creature names only. Nothing resembling Pokémon.
- Mobile-first UI: big buttons, readable text, short sessions.
- DataStore saves must have error handling and retries (pcall + retry loop, never let a save silently fail).
- Keep code small, plain-English comments, easy for a beginner to follow.
- Commit to git after every working step, with a clear message.
- **File ownership**: each role owns its own files (see CONTRACTS.md). If a role needs a change in
  a file it doesn't own, it writes the request in `docs/STATUS.md` under "Blocked" instead of editing it.
- **Only the World role calls Roblox Studio MCP tools** to create/edit live instances (Workspace parts,
  creature placeholder models, etc.). Every other role only edits script files through the Rojo folder —
  this is what keeps two roles from fighting over the same live Studio state at once.

## How we work (no real slash commands in this project)

The user's usual 29 shortcut commands (`/human`, `/expert`, etc.) aren't configured in this Claude Code
project — confirmed in Phase A, nothing to install today. We just write in plain English instead.

Work runs as **one thread, one role at a time** — not parallel editing agents — narrating which hat is on.
Exception: read-only QA/Critic subagents are OK at the end (Phase C), since they can't cause edit conflicts.

### The roles

1. **Lead/Architect** — docs, CONTRACTS.md, merging, scheduling, final decisions.
2. **Data** — owns `src/shared/Config.lua` and the player-data module (load/save/schema/DataStore retries).
3. **Egg** — owns server egg logic: grant egg, roll creature at pickup, incubator timers, free-egg timer,
   hatching, Index recording.
4. **Raid** — owns the tutorial raid: NPC den, nest slots, grab, carry slowdown by rarity, drop, deliver home.
5. **UI** — owns client UI: reveal screen, incubator panel, Index screen, HUD, tutorial prompts. Mobile-first.
6. **World** — the only role that touches Workspace via MCP. Builds the blockout: base, incubator spots,
   one NPC den with nests, lighting, 12 placeholder creatures from simple parts.
7. **QA/Critic** — writes no features. Reviews everything against the GDD and the rules above, hunts for
   exploits (client trust, duplicate grants, timer cheating, save failures), writes a test checklist, plays it.

## Phases

- **A** (~45 min): setup, contracts, plan. Stop and get OK before building.
- **B** (~2–3 h): Data → Egg/Raid/World → UI, in that order (each depends on the last), against CONTRACTS.md.
- **C** (~1 h): integration, QA playtest, bug table, fix by priority.
- **D** (remaining time): polish first 60 seconds (reveal by ~45s, glow + sound), final playtest.

Checkpoint after each phase: short plain-English status — what works, what's broken, what's next.
If anything is blocked more than 15 minutes, say so immediately.
