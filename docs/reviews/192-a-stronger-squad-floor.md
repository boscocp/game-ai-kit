# Review: wave/192-a-stronger-squad-floor

PR #152 -- T125, a greedy shooter as the squad mode's second floor (wave 192).
Reviewer: a fresh context that did not write the code (invariant 12).

## What was reviewed

- `git diff origin/main...origin/wave/192-a-stronger-squad-floor` (18 files), the
  PR body, and `tasks/T125-a-stronger-floor-for-the-squad-mode.md`.
- `GreedySquad` read input by input against `SideView`, `WeighedSquad`,
  `SquadCombat`, `TacticalReach` and `rules.json`.
- In a throwaway worktree of the branch (removed afterwards; main checkout untouched):
  - `make test-squad-floor`: 137 of 200, planted 112, 0 failures, ~27 s, the same
    numbers as the PR (deterministic: match `n` on dice seed `n`, the weighed
    enemy on `1000 + n`, the greedy shooter has no dice).
  - The runner's output over a short run: no `SCRIPT ERROR`, no engine error.
  - Empty / bad arguments: `-- 0 0` exits 2 with its usage line.
  - Four other seed sets (seeds offset by 100, 200, 300, 400): weighed
    139, 141, 137, 132; planted 107, 109, 107, 108. Every set passes and refuses
    the plant. Over five sets the weighed enemy ranges 132-141, the plant 107-112.
  - The bar at 110 with the plant check intact: 1 failure (the plant is
    refused). The plant check disabled (`if false and ...`) at the same bar:
    0 failures, green.
  - Mutant "greedy shoots at 0%" (`best_expected` starting at -1.0 in
    `decide_attack`): `greedy_squad_test.gd` 8 of 8 pass, and the floor still
    137 / 112. Survives.
  - `make test-godot-some SUITES="test/squad/greedy_squad_test.gd
    test/squad/squad_rules_test.gd test/squad/squad_scene_test.gd"`: 58 cases,
    0 failures, no `SCRIPT ERROR` (the C cycle reaches `greedy`, then `random`).
  - `check_readability.py`, `check_modules.py`: ok. `lint-translations-game`:
    only the known `tactical.gd:147` line that #151 fixed on main; nothing from
    the squad strings.
  - `squad_mcts_measure.gd` with an unknown opponent row: refused with its usage line.

## Findings

1. **should-fix -- "never one at 0%" is claimed and not held.** The mutant that
   shoots at 0% survives every test and the floor. A 0% shot is possible on this
   table: a shield (aim 60) at a shield (defence 20) in full cover (40) is
   `60 - 20 - 40 = 0`. One test on such a board (`decide_attack` returns null,
   or never a 0% target) would hold the property the class header, the task's
   decision 1 and the PR all state.
2. **should-fix -- the margin is stated from one seed set; the spread is wider
   on the low side.** "12 under 137" holds for seeds 0-99; over five seed sets
   the weighed enemy ranges 132-141 (worst margin 7) and the plant 107-112
   (worst margin 13). The gate is deterministic, so it does not flake run to
   run, but any legitimate change that reshuffles the dice stream (a new rule,
   a reordered roll) draws a new sample, and the bar sits closer to the
   weighed enemy's spread than to the plant's. Either move the bar to about
   122 (the middle of 112..132, 10 clear of both worst cases), or keep 125 and
   write the five-set spread beside it in the runner's header and
   `docs/godot/squad.md`, so a later 124 is read as a seed sample before it
   is read as a regression. Binomial sd at ~68% over 200 is ~6.6, so 12 is
   under two sd either way: 100 games a seat is the minimum that works, not a
   comfortable one.
3. **nit -- the task's "while passing the old one" is measured, not held.**
   The plant must fail the new bar *and* still beat `RandomSquad`; the runner
   checks only the first. A plant that broke into something weaker than
   random would still be "refused" and the gate's teeth would be unproven.
   A cheap guard: the runner also requires the plant to win more than the
   mirror's even line (100 of 200), which it does (107-112).
4. **nit -- the plant check lives only inside the runner.** With it disabled
   the gate goes green at a bar the plant clears; nothing outside reads that
   the planted case is still refused. That is invariant 4's known
   "read by a person" half, not new to this wave; noted so the next reader of
   the runner knows the `failures.append` for the plant is load-bearing.
5. **nit -- two helpers are near copies of `WeighedSquad`'s.**
   `_closest_to_the_known` is `_routes_to_the_known` plus a pick, and
   `_best_expected_from` is `_best_shot_from` without the chance. Decision 1
   chose one readable file on purpose, which is defensible under invariant 1;
   a one-line comment naming the twin would let a reader who changes one
   find the other.

Checked and found sound: every input `GreedySquad` reads goes through
`_look` (its side's `SideView`), except `state.turn_number`,
`state.current_faction` and its own workshop's cell, which are public; the
start cells come from the map; seen enemies' health is in the view by
`SideView`'s design, as for `WeighedSquad`. `SquadUnseenCheck` passes on 40
positions and catches the sees-everything plant. The roster row, catalogue
list, locale strings, C cycle test and module manifest are in step. The
branch needs a rebase onto origin/main for `lint-translations-game` (#151).

## What was done about them

1. **Fixed.** `greedy_squad_test.gd` gained
   `test_it_never_takes_a_shot_at_zero`: a red shield at (2, 0) and a blue
   shield at (1, 3) in full cover, a legal shot at 0% (both asserted), and
   `decide_attack` must return null. The review's mutant (`best_expected`
   starting at -1.0) now fails it:
   `make test-godot-some SUITES="test/squad/greedy_squad_test.gd"` -- 1
   failure with the mutant, 9 of 9 without.
2. **Fixed, the bar moved to 122.** The runner's default, the Makefile
   line, `docs/godot/squad.md`, the task file (decision 2) and the STATUS
   row now say 122 of 200, with the five seed sets' spread beside it
   (weighed 132-141, plant 107-112, 10 clear of both). `make
   test-squad-floor`: 137 and 112, 0 failures.
3. **Fixed.** The runner also fails when the plant wins no more than the
   even line (half its games over both seats): "fails the new bar while
   passing the old one" is now a command. Shown with the plant swapped for
   `RandomSquad` (20 games a seat): "the planted weighing won 0 of 40, no
   more than the even line: it is broken, not worse", exit 1.
4. **Done.** A comment above the two plant checks in `_run` says they are
   load-bearing (invariant 4). The half a person reads stays a person's.
5. **Done.** `_best_expected_from` and `_closest_to_the_known` each name
   their twin in `WeighedSquad` (`_best_shot_from`, `_routes_to_the_known`).

The branch was rebased on origin/main first (#150, #151): the
`lint-translations-game` finding on `tactical.gd:147` is gone with it.
