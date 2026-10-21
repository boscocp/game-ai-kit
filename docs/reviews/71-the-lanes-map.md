# Review: wave/71-the-lanes-map

A fresh context reviewed the wave at `dde53c8`: T66 -- height in the
simulation, the three-lane map and the yards, sprint, the reload, ammunition
and the power weapon, the humanoid body, the hit zones, `AimChoice` and
`PassageChoice` with their twins and vectors, solid bodies, and the effects
test. It was not allowed to edit the checkout. It ran the readability and
modules gates, the teamwork vectors on both sides, the gdUnit suites of
`botmatch` and `ai_teamwork`, and four probe scripts of its own through
`./scripts/godot`; it read the last effects run from its log.

**Verdict: fix before merge.** One high bug took a bot out of most of a
match, the movement favoured blue, three planted cases planted nothing,
and the numbers in the docs came from a run that was not of the commit.

## What was reviewed

- `CLAUDE.md`, the T66 and T67 task files, `docs/godot/botmatch.md`, and
  `git diff origin/main...HEAD`.
- The simulation for anything that favours a side: a fixed order, a
  side-dependent direction, an id-order tie.
- Every check in the tests, for a planted case it truly rejects.
- The twins, by tracing each path in both languages.

## Findings

Each one is followed by what was done about it.

1. **A bot with a part-used power weapon walked home and stayed** (high).
   Going back weighed its spent rounds as gain, and the base gives its
   holder nothing until it is empty, so at the base the errand never ended.
   Probed: 81 to 193 s of a 240 s match in a spawn no enemy sees into.
   *Fixed*: a part-used power weapon is worth no walk; a test holds it,
   and fails with the old weighing.
2. **Bots moved in id order** (medium): with solid bodies, blue always took
   a contested door first; probed, blue 0.67 m past the line where red was
   0.31. *Fixed*: the acting order turns round every step; a test that it
   does, and a meeting at the mirror line that favours neither side.
3. **Two exact ties went to a fixed turn** (medium): a body square on the
   line of a step, and a teammate stepping aside with its way straight on
   blocked. Each turned blue and red to opposite sides. *Fixed*: both go
   south, which the mirror across x keeps; a test for each, each failing
   with the tie broken the old way.
4. **Three planted cases asked a claim of itself** (medium, invariant 4):
   aim (x >= 1.1 x), ammunition (0 > 2.5 errors) and, from wave 70, claims
   (at most 10 and at least 40 at once). None could ever pass, so none
   planted anything. *Fixed*: each puts the planted pairing in the good
   one's place. The yards' mirror has no planted case of its own: it is
   claim 0's check asked of another arena, and claim 0's sharper blue is
   its planted case -- said in the test's header.
5. **"Nobody stands blocked for long" could never fail** (medium): it read
   a counter the passage code resets at its patience. *Fixed*: the
   portability test times a bot that wants to move and stands, and bounds
   it at 5 s.
6. **The docs' numbers came from a run that was not of the commit**
   (medium). *Fixed*: `make test-botmatch-effects` was run again on the
   fixed commit, and `docs/godot/botmatch.md` quotes that run.
7. **A goal on the mirror line sent red one cell short** (low): every
   point and the power weapon sit on a cell edge, and red's cells were
   mirrored after being made. *Fixed*: the places are mirrored first; a
   test that red's path to every point is blue's mirrored, on both arenas.
8. **Ties to the lower id elsewhere** (low): two bots as near the power
   weapon, two blockers as near. *Fixed*: neither takes the weapon that
   step; of two blockers, the teammate. The push "along the lower id's
   facing" is left: it parts two bodies exactly on top of each other, which
   solid bodies make rare, and either way it is the same push.
9. **Map and side assumed in decision code** (low): red's paths were
   searched in a mirror every arena was assumed to have, and a respawn
   faced east for blue. *Fixed*: an arena says whether it is mirrored
   (`"mirrored"` in its file); a respawn faces the points. The sprint rule
   is a fixed if-rule too; it is T67's, with the priority list.
10. **A respawn left the last life's state** (low): its velocity, its
    blockers, refusals and last passage, and a reload under way. *Fixed*,
    with a test.
11. **Docs claims the numbers did not support** (low): the commander
    "shown" at 3.2 errors from zero, where against the everything pairing
    by the test's own method it is 1.1; claims "0.4 errors"; a rise of
    "half a metre" where `MAX_RISE` is 0.6. *Fixed* in
    `docs/godot/botmatch.md`, with the two-margin method throughout.
12. **Stale comments and readability** (low): "10-0" for 18-2, "x = 24" on
    the yards, `AIM_BETTER`'s old numbers, a 109-column line, the errand
    line on the panel whose sum did not add up, and a blank line splitting
    the vectors' table. *Fixed*.
13. **Unpinned comparisons in the vectors** (low): `leaving_speed > 0`
    and the spread's clamp. *Fixed* with two vectors. The second found a
    real fault: at a micrometre's spread GDScript's 32-bit `Rect2` gave a
    chance of 1.013, so the least spread is now a millimetre, in both
    languages and in `derive.py`.

## What was done about them

All of it is in `2381fa5` and `9630ff1`, after `dde53c8`.
`botmatch_effects.gd` was run on them, and every claim holds, each with a
planted case that now truly rejects:

- the mirror, 11 to 9 at -3.2 +- 32.0 s a match on the lanes, and 12 to 8
  at +26.2 +- 35.5 on the yards;
- bunched 2.0 s against 312.8, orders over 2.74 points against 1.33;
- 13849 retreating decisions, none uncovered; no shot at an unseen enemy
  or while sprinting;
- 4.71 damage a shot aiming by worth against 3.39 always the head;
- always going back for rounds 0 to 10, at -268.5 +- 18.5.

Applying finding 4 showed one more: the commander's planted case, sent
everyone to one point, passed the bar of 1.2 times at 1.29. The bar was
set in T51 for a commander that made 1.29 times; this one makes 2.0, so
the bar is now 1.5 and the plant is rejected.

The botmatch suite passes its 49 cases and the teamwork vectors their 32
files in both languages, and every new test was run once with its fault
planted, failing as it should. `make check-affected BASE=origin/main` runs
on the pull request.

## What the review found sound

The twins compute the same thing on every path; the hit zones and their
damage; the reload; ammunition, death and the streak; height, the stairs
and the slab test against physics; the arena mirror test; the sprint
check; the honesty cheats; the retreat and commander planted cases; the
detour arithmetic; and the docs' match counts.
