# T63 — The controller registry: one table, not an `if` chain

Size: M · Prereqs: T58 · Files: `godot/game/tactical/`, `godot/game/league/`, `godot/test/tactical/`, `godot/test/league/`, `godot/menu/catalogue.json`, `scripts/check_demos.py`, `modules/`

## Goal

T58's D5: adding a controller edits the game. The tactical board's C key
cycles its computer through `next_controller` (`tactical.gd:395`), a chain of
`if playing is X: return Y.new()` -- seven branches and a default, each naming
the next class. The league already has the answer, written for itself:
`League.roster()` (`league.gd:35`) is a table of name, description,
delegation and a `Callable(seed) -> BlueController`. Two lists of the same
controllers, kept in step by hand, in two modules that depend on each other.

## Steps

1. **The controllers live with the board they play.** `MachineTeam`,
   `TreeTeam`, `GoapTeam`, `HtnTeam` (and the shared code they stand on in
   `game/league/`, measured first) are tactical controllers -- each a
   `BlueController` -- kept in the league's folder only because the league
   came first. They move to `game/tactical/`; the league keeps what it is,
   the tournament and its table of results. Without this a table in
   `tactical` still names four league classes, and the dependency it is
   meant to remove stays.
2. **One table.** The roster moves to `game/tactical/`, as a `class_name`
   with a `static func` (Godot's advice: a static helper library over an
   autoload's global state; dependencies handed in by the parent, *Scene
   organization*). The C order
   is the table's order; the league reads the same rows. The levels
   (`LeveledBlue` at easy, normal, hard) are rows too, each with its seed.
3. **The game asks the table**: `next_controller` becomes "the row after
   the one playing", and knows no class by name. A controller added is a
   row added.
4. **The menu says which controllers an example offers.** Each
   `catalogue.json` example with a controller choice gains a `controllers`
   list of row names; `check_demos.py` gains a rule that every name is a
   row of that game's table and every row is listed, with a planted case
   for each direction.
5. **The other games, measured, not assumed**: the RTS's levels, racing's,
   the fighting opponents. If one has the same chain, it gets its table in
   this task; if it has one already, the task says so and leaves it.
6. `tactical` stops depending on `league` (`modules/tactical.json`); `make
   lint-modules` holds it.

## Done (wave 68): what was measured and decided

- **Step 1, measured:** of `game/league/`'s nine files, six are the four
  teams and what they stand on -- `MachineTeam`, `TreeTeam`, `GoapTeam`,
  `HtnTeam`, `TechniqueTeam`, `TeamFacts`. They moved to `game/tactical/`,
  and their tests with them (`test/tactical/technique_teams_test.gd`). The
  league keeps `League` (the schedule), `LeagueRating` and `MeteredTeam`,
  which only the league's runner uses.
- **The list lived three times, not two.** Beside the chain and the league's
  roster, `tactical.gd` had `CONTROLLERS_TO_COME`, the sentence on screen
  naming all ten. It is built from the table now.
- **The table: `TacticalRoster.rows()`**, ten rows in C's old order (rules,
  planner, learned, easy, normal, hard, the four T15 teams). A row is the
  league's old shape plus one field, whether it plays in the league: only
  `hard` of the levels does, as before. The game finds the row it is on by
  `controller_name()`, which a test holds every row to; a controller from
  outside the table is followed by the first row.
- **Three things changed on purpose.** A controller from outside the table
  is followed by the first row, the rules; the chain sent it to the planner,
  and a level it did not know to `easy`. The game never meets one -- it
  starts on the rules -- so nothing a player sees changes. The league's lookahead team is named
  `hard`, its row's name, where it printed `lookahead (hard)`; and the league
  lists teams in table order. The planner the C key builds no longer prints
  each plan to the console (`verbose`): the row builds the league's planner,
  and the plan is on the panel and in the overlay already; `verbose` itself
  went, since nothing set it any more.
- **The league's numbers moved, and nothing in a game did.** The schedule
  seats teams by their place in the list, so C's order played the same
  pairings on other dice. Measured both ways (the author, then the review):
  the new code with the old order reproduces `main`'s table exactly.
  `docs/concepts/the-league.md` shows the new run and says why.
- **Step 4, scoped to the one example with a table:** the tactical card
  gains `controllers` and `roster`, and `check_demos.py` rule C9 holds them
  to each other -- every name a row, every row listed, in order, once -- with
  eight planted cases.
- **Step 5, measured, no other chain:** the RTS cycles `RtsLevels.presets()`
  by index (C) and toggles two planners (H); racing indexes its `levels`;
  fighting steps through `MODES`; the behaviour demo indexes a list of four
  brains. Each is already one table read by index, so none gets a roster
  here, and their cards gain no `controllers` -- C9 would need a reader per
  table shape for lists that cannot drift from a chain they do not have.
- **Step 6:** `tactical` no longer depends on `league`, and gains
  `ai_behaviour` (the teams' trees and planners); `league` drops
  `ai_behaviour`, `ai_core` and `ai_planning`, which only the teams used.

## Acceptance

```bash
make check-affected BASE=origin/main
```

```bash
! grep -nE 'if playing is [A-Z]' godot/game/tactical/tactical.gd
```

```bash
python3 scripts/check_demos.py --self-test && python3 scripts/check_demos.py
```

```bash
python3 -c "import json,sys; sys.exit('league' in json.load(open('modules/tactical.json'))['depends_on'])"
```

## Manual check

In `make demo-tactical`, press C through every controller and back: the
same order as before, each named on the board.

## Out of scope

- The Python registry by decorator (`@technique`) and entry points (T64).
- A controller picked from the menu instead of the C key.
