# T63 — The controller registry: one table, not an `if` chain

Size: S · Prereqs: T58 · Files: `godot/game/tactical/`, `godot/game/league/`, `godot/menu/catalogue.json`, `scripts/check_demos.py`

## Goal

T58's D5: adding a controller edits the game. The tactical board's C key
cycles its computer through `next_controller` (`tactical.gd:395`), a chain of
`if playing is X: return Y.new()` -- eight branches, each naming the next
class. The league already has the answer, written for itself:
`League.roster()` (`league.gd:36`) is a table of name, description,
delegation and a `Callable(seed) -> BlueController`. Two lists of the same
controllers, kept in step by hand, in two modules that depend on each other.

## Steps

1. **One table.** The roster moves to where both can read it without the
   cycle: `game/tactical/`, as a `class_name` with a `static func` (Godot's
   advice: a static helper library over an autoload's global state;
   dependencies handed in by the parent, *Scene organization*). The C order
   is the table's order; the league reads the same rows. The levels
   (`LeveledBlue` at easy, normal, hard) are rows too, each with its seed.
2. **The game asks the table**: `next_controller` becomes "the row after
   the one playing", and knows no class by name. A controller added is a
   row added.
3. **The menu says which controllers an example offers.** Each
   `catalogue.json` example with a controller choice gains a `controllers`
   list of row names; `check_demos.py` gains a rule that every name is a
   row of that game's table and every row is listed, with a planted case
   for each direction.
4. **The other games, measured, not assumed**: the RTS's levels, racing's,
   the fighting opponents. If one has the same chain, it gets its table in
   this task; if it has one already, the task says so and leaves it.
5. `tactical` stops depending on `league` (`modules/tactical.json`); `make
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
