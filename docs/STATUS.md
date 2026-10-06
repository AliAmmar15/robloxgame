# STATUS — live board

Each role logs here: what's done, what's in progress, what's blocked. Lead checks this regularly.
If something's blocked more than 15 minutes, the Lead tells the user immediately — don't just sit on it.

Update format per entry: `- [role] message (timestamp or phase)`

## Done

- [Lead] Phase A setup: CLAUDE.md, docs/GDD-summary.md, docs/CONTRACTS.md, this file, Rojo folder
  structure (`src/shared`, `src/server`, `src/client`), git init, MCP connection verified.

## In progress

*(nothing yet — Phase B hasn't started)*

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
