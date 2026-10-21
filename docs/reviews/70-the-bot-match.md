# Review: wave/70-the-bot-match

A fresh context reviewed the wave at `a91aeb2`: T51, `ai_teamwork`, the bot
match, its first-person takeover and its effects test. It was not allowed
to edit the checkout. It ran the readability, addon, demos and modules
gates, the teamwork vectors on both sides, and the gdUnit suites of
`ai_teamwork` and `botmatch`. It read the last effects run from its log
rather than run it again.

**Verdict: fix before merge.** Five findings were high. The effects test
claimed things its numbers did not support, a bot could shoot through a
box, and `check_modules.py` failed. Applying them turned up the worst
defect of the wave: the mirror match was bent 18 to 2 for blue, and every
comparison had been measured against it.

## What was reviewed

- `CLAUDE.md`, the T51 and T65 task files, `docs/godot/botmatch.md`, and
  `git diff origin/main...HEAD`.
- The simulation for asymmetry between the sides, the takeover, the 3D
  shot, death resolution and claims.
- Every check in the tests, for a planted case it truly rejects
  (invariant 4).
- The twins, by tracing each path in both languages.

## Findings

Each one is followed by what was done about it.

1. **`check_modules.py` failed** (high): botmatch used `game3d` and
   `game_shared`, and menu used botmatch, undeclared. *Fixed* in the
   manifests.
2. **A bot could shoot through a box** (high). It checked only the sight
   table, up to a decision old, so a target that stepped behind cover was
   still hit. *Fixed*: the line is looked along again at the moment of the
   shot, and a bot holds fire when it is blocked.
3. **"0 unseen shots" was zero by construction** (medium). The target came
   from the same row the check read. *Fixed*: the honesty count reads the
   live line, and a second planted bot fires on its last decision's sight
   without looking again. It fired 32 such shots and was caught.
4. **The retreat claim rewarded giving points up** (high). The ratio
   deaths / points lost favoured a team that lost both. *Changed*: with
   retreat, blue lost the match (20 to 0 to a team that never falls back).
   The claim now covers what retreat decides: a retreating squad always
   leaves someone covering. A planted one-wave retreat is caught, 605 of
   704 decisions uncovered.
5. **"Loses to" had no number behind it** (high). The runner never printed
   red's score, and "inside the noise" was never computed. *Fixed*: both
   sides' points, wins, and each pairing's mean margin with its standard
   error are printed.

   Printing red's score showed the mirror was bent: blue won 18 to 2. The
   cause was A*'s fixed order of neighbours, which makes a path east unlike
   a path west. Red's paths are now searched in the mirrored arena and
   mirrored back, and the mirror went 9 to 11. Its fairness is now claim 0
   of the test, and a planted sharper blue fails it.

   The wave's earlier conclusion -- every technique on loses to any one off
   -- was an artefact of the bent mirror. It is withdrawn everywhere it was
   written. What holds is weaker and different: retreat costs the match,
   the commander's help is 1.8 standard errors, and claims show nothing in
   the score.
6. **The catalogue said bots without a commander "gather"** (medium). Only
   their orders bunch. *Fixed*.
7. **The commander and retreat planted cases were arithmetic** (medium):
   `x >= 1.2x` fails for any x. *Fixed*: a commander that wants every bot
   on one point (spread 1.42, rejected), and a retreat in one wave.
8. **A bot given back kept its old path** (medium), and could walk
   through a box from where it stood. *Fixed*: the path is cleared, and it
   chooses afresh.
9. **The confidence's ATTACK state changed nothing** (medium; invariant
   13). *Fixed*: on a point to take, only a squad in ATTACK steps onto it;
   one that only holds takes cover near it and contests it by fire.
10. **The test of a person's spot never put a teammate there** (low).
    *Fixed*: a teammate choosing around the spot finds it CLAIMED, and the
    bot given back is held to choose a spot of its own.
11. **The slab-against-physics test would pass with no boxes** (low).
    *Fixed*: both answers must occur in a tenth of the rays.
12. **A played bot could fire during a reload** (low). *Fixed*.
13. **Docs and code disagreed** (low): the review record did not exist,
    and the commander-off rule is "nearest point not ours". *Fixed*.
14. **Readability by hand** (low): six comments said what the code did
    not, a GDScript comment sat in the wrong place, and the Python
    dataclasses had no docstrings. *Fixed*. Not changed: `derive.py`'s
    short names, the house style of every `derive.py` in `spec/vectors/`
    (steering's has `add(a, b)`, `p`, `q`). Each is a compact third copy,
    not code a reader learns from, and no gate covers `spec/`.
15. **Near ties can differ between 32- and 64-bit floats** (low). *Said*,
    in the vectors' README. The game never compares the two languages'
    answers.

Found after the review, by the owner playing the build: a shot ending
inside the tracer's first metre made `looking_at` refuse a zero vector.
*Fixed*, with a test that draws shots of every length and counts engine
errors.

## What was done about them

All of it is in the commit after `a91aeb2`. `botmatch_effects.gd` passes
every claim, each with its planted case rejected:

- the mirror, 9 to 11 at -4.5 +- 49.1 s a match;
- bunched 0.0 s against 79.2;
- orders spanning 2.34 points against 1.81;
- 2835 retreating decisions, none uncovered;
- no unseen shot in about 515,000, and both cheats caught.

The botmatch suite passes its 10 cases, and the teamwork vectors pass in
both languages. `make check-affected BASE=origin/main` runs on the pull
request.
