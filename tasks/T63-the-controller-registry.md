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
