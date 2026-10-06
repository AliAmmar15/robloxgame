# GDD summary — today's slice only

Full doc: [Egg_Heist_Arena_Game_Design_Document.pdf](Egg_Heist_Arena_Game_Design_Document.pdf).
This page only covers what the prototype needs. Battles, PvP, shields, monetization: not here, not today.

## The loop (today's version)

Raid the one NPC den → grab an egg from a nest → see the creature revealed instantly → carry it home
(slowed while carrying, more for rarer eggs) → place it in an incubator → wait out the timer (or use the
debug skip) → hatch → creature added to your collection → shows up in the Index.

## Rarity tiers (today's 12 placeholder creatures, 2 per tier)

| Tier | Incubation time | Our 2 placeholders |
|---|---|---|
| Common | 5 min | Pip Mallow, Gutterfox |
| Uncommon | 15 min | Lantern Moth, Burrowl |
| Rare | 1 hour | Thornback Boar, Mistling |
| Epic | 2 hours | Mirrorpaw, Echo Heron |
| Legendary | 4 hours | Stormhide Elk, Hollow Wyrm |
| Mythic | 8 hours | Eclipse Fawn, The Gilded Magpie |

Rarity only changes *how a creature looks and how it's obtained* — not power. Today there's no battle
system, so stats don't matter yet; placeholders just need a distinct shape/color per creature.

## Basic Egg odds (free egg only — the only egg type today)

| Tier | Odds |
|---|---|
| Common | 62% |
| Uncommon | 25% |
| Rare | 10% |
| Epic | 2.5% |
| Legendary | 0.45% |
| Mythic | 0.05% |

Free Basic Egg: every 4 hours, stockpile cap 2. (GDD section 5 — this is the "incubator timer" free source,
the fastest of several in the full design; today we only build this one.)

## The reveal-then-incubate rule (important)

The GDD is explicit: **a picked-up egg reveals its creature immediately.** The incubation timer is a known
wait for a known outcome — not a mystery box. This is why the debug panel can "skip the timer" without it
being a loot-box problem: nothing random happens at skip time, the result was already decided at pickup.

## Raid theft rule (important — security-relevant)

Only **unhatched eggs sitting in a den's nest slot** can be stolen. Once hatched, a creature is bound to
the account forever and can never be raided. Today there's only one NPC den (no player-vs-player raids),
but the egg/nest logic should still follow this rule so it's correct later.

## What's explicitly cut today

Battles (3v3), PvP raids on other players' dens, base shields, Gem Eggs, Essence, Sand, quests, login
streaks, season track, Index milestone rewards, any Robux purchase or game pass. All of that is real in the
full GDD (sections 4–11) — just not in this slice.
