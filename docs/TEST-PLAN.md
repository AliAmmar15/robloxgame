# Test plan — 10 minutes with a friend

Give your friend the published link (see README.md for how to publish/share) and this sheet.
Don't explain anything first — the GDD's whole point is that the first 60 seconds should
explain themselves. Just watch.

## The script (~10 minutes)

1. **(0:00) Join.** Time how long until they grab their first egg and see the reveal. Target
   is under ~45 seconds. If they're confused about what to do, that's a real finding — write
   down exactly where they hesitated.
2. **(~1:00) Let them carry the egg home.** Don't tell them where "home" is — see if the
   tutorial prompt and the 🥚 Incubators button are enough.
3. **(~2:00) Place the egg in an incubator.** Ask them to read the countdown out loud once.
   Does it make sense to them?
4. **Tell them about the 🛠 debug button** and have them tap **Skip Slot 1/2** to speed past
   the real wait. (Without this the real timer could be minutes to hours — fine for your own
   long-session testing, not for a 10-minute friend test.)
5. **(~3:00) Collect the hatch.** Does the result feel satisfying? Do they understand what
   just happened?
6. **(~4:00) Open the 📖 Index.** Ask if it's clear what the grid is showing (discovered vs.
   "???" undiscovered).
7. **(~5:00) Send them back to raid again** — second nest, then third. Does the loop still
   make sense without prompting the second time?
8. **(~7:00) Have them try the free egg** — tap 🛠 → **Give Free Egg Now** (stands in for the
   real 4-hour timer).
9. **(~8:00) Ask them to leave and rejoin** (leave the game, rejoin the link). Confirm their
   carried eggs / incubators / Index came back.
10. **(~9:00) Let them free-play the last minute.** Just watch what they do unprompted — that's
    often the most useful signal.

## 5 feedback questions (ask after, not during)

1. In one sentence, what is this game? (Tests whether the loop explained itself.)
2. What was confusing or felt broken?
3. What did you want to do that you couldn't?
4. Did the egg reveal feel exciting, or just like a loading screen?
5. Would you play this again later today? Why or why not?

## Known issues (tell your friend these up front, don't let them "find" and get stuck on them)

| Issue | What they'll see | Why it's OK for tonight |
|---|---|---|
| No real creature art | Flat-colored shapes (balls/blocks) instead of real creatures | Placeholders — see README "what works" |
| No battles | Nothing to fight, ever | Out of scope for this build (see CLAUDE.md) |
| Reveal sound is silent | Glow/animation plays, no sound yet | Placeholder sound IDs in Config.lua — need real asset IDs |
| Debug button visible to everyone | A 🛠 icon always shows, even though only you can actually use it | Fine for a private unlisted test; every tap from a non-whitelisted player just fails harmlessly |
| Incubator panel opens from anywhere | No need to physically walk to your base to place/collect | Deliberate scope simplification — see CONTRACTS.md |

If your friend finds something NOT on this list, that's the valuable part — write it down
with what they were doing right before it happened.
