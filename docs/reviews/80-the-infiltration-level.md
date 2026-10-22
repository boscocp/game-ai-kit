# Review: wave/80-the-infiltration-level

A fresh context reviewed T70 at `2602c7a`: the infiltration level -- two
hand-made levels and generated ones as data, guards as T67's agents
weighing actions on T69's percepts, `SearchCoordinator` and `RoleArbiter`
in `ai_teamwork` with twins and vectors, help as a heard event, a third
person player, the overlay and the knobs, and `make test-infiltration`.
It was not allowed to edit the worktree. It ran `make test-infiltration`
(exit 0, no SCRIPT ERROR), the teamwork (60) and perception (11) vectors,
`make test-python` (334), the gdUnit suites of `infiltration`,
`ai_teamwork` and `ai_perception` (95), and the dependency, module,
readability and demo gates -- all green; and probed two findings with
scripts outside the repo.

**Verdict: fix before merge.**

## What was reviewed

- `CLAUDE.md` (invariants 2, 3, 4, 6, 13), T70's task and Done note,
  `docs/godot/infiltration.md`, `docs/concepts/stealth-ai.md`, the owner's
  rules: guards weigh what they perceive, and help is heard, not shared.
- Whether a guard's mind reads the player's truth outside its percepts,
  and where a report's knowledge goes after it is heard.
- Each claim's planted case, run level by level; whether a claim could go
  green on a run that never exercised it.
- The leaks reported at exit, by counting objects with and without the
  tests' callables.

## Findings

1. **The quiet route's plant was caught only where the claim is not held**
   (high): guards blind to light alerted only on generated level 1, the
   level exempt from the gate; the scripted sneak never entered a zone.
2. **Guards searched from knowledge they never heard** (high): every
   searching guard took its spots and way out from the freshest guard's
   belief, and "searched" marks were global -- against "heard, not shared"
   and the Done note. The help claim checked only who a report reached.
3. **The kit's own numbers were not labelled** (medium), and GuardChoice's
   windows lived in code.
4. **Phase indices hard-coded** (low): a three-phase guard would read
   alert as searching.
5. **Halves without a planted case, and no exercise counts** (low): the
   arbiter's shoot-in-time and no-shot-below-alert, part of the search
   claim, the portable plant testing the test's seam.
6. **Leaks at exit from a test cycle** (low): world, sounds, callable,
   world; play binds a method and has none.
7. **A faint glimpse aimed at the exact position** (low).
8. `SearchCoordinator.mark` unused (info). 9. The overlay claim's plant did
   not cover an act ignoring the chosen action (info).

## What was done about them

All nine in `15efe8b`:

1. Measured and said: the quiet-route claim does not show the light term
   -- a sneak routed through dark zones made honest guards alert on two
   levels. The gated plant is a yes-or-no sight test caught on both
   hand-made levels; the light-blind runs and the generated levels are
   printed per level, not gated.
2. `guard_search.gd`: guards search together only when their memories hold
   the same place from the same report or sighting; alone, a guard searches
   from its own belief; marks and caps per guard and per place. A new claim,
   staged with two calls each heard only nearby, holds that no guard is sent
   by a belief it never heard -- its plant puts every searcher in one group
   -- and the help claim checks that a place known from a report was heard.
3. Labelled in the JSON and the docs; the windows moved to `rules.json`.
4. Phases read by name (`GuardMind.at_least`).
5. Plants for the arbiter's two halves, the search's second half and a
   guard script reading a level file; exercise counts printed and required
   nonzero (8 calls cut short, 325 group decisions, 24 shots).
6. Worlds freed: 2,945 leaked objects to 0.
7. A guard shoots at what it saw, its chest among the points, certainty at
   least 0.3.
8. Removed. 9. Planted: an act that ignores the action.

10 claims hold and 13 plants are caught; a hidden player is found in 6.9 s
with the belief, 20.8 s without, 18.4 s never spreading.

`make check-affected BASE=origin/main` after the fixes (everything) failed
only in `test-godot`, in wave 78's `effect_shards_test.gd`: "0 shard
file(s)" and sums from another run, because wave 81's check ran at the same
time and every worktree shares one `user://` (`scripts/godot` sets
`XDG_DATA_HOME` to `$toolchain/xdg`). Run alone, that suite passed 9 of 9
and `make test-godot` passed 1259 cases with 0 failures; every other target
of the check had passed. The shared `user://` is a defect of running waves
in parallel, recorded for a task of its own.
