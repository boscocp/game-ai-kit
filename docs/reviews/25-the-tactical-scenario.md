# Review: wave/25-the-tactical-scenario

Two fresh contexts reviewed it, each in its own git worktree. One read the
rules and `ai_core` and attacked the tests. The other never read the code:
it played the scene through screenshots, both sides, for several turns. Both
found the same bug first. A build refused for want of funds told the player
the workshop had no room.

## What was reviewed

Commit 73f6d9c on this branch:
- `UnitType`, `Upgrade` and `ProductionOrder` in `ai_core`;
- funds, upgrades and per-mover cost maps in `BoardState`;
- `godot/game/tactical/`: the rules, the map, the scene, its status and its
  legend;
- `BoardLayout`, taken out of `main.gd`;
- the T26 task for combat, and the reordering of T9.

## Findings

### Must fix

- **Out of funds read as "no room".** The scene chose a cell by asking the
  whole order, heard "cannot afford" about every cell, fell back to the
  workshop's own cell, and reported "(1, 7) is not next to unit 1". A player
  never learned they were broke.
- **The counter test did not hold "a cycle".**
  - "No two types beat each other" holds for a ladder too.
  - "Beaten by something" counted the bolt tower.
  - Dropping the runner from the shield's list made the runner top of a
    ladder, and every test passed.
- **The bridge test did not hold "only".** It checked one A\* route, which
  still went over the bridge with a second gap opened in the river.
- **`apply`'s bill for a wader was untested.** Billed on the board's map,
  water is `BLOCKED` (-1), so a wader would *gain* a point per water step,
  and the suite stayed green.
- **Produced units reused dead units' ids.** The next id was counted from
  the living, against the promise `Unit.id` makes.
- **The forge was offered after it was owned**, right under a status line
  that said it was owned.
- **Refusals said "faction 0" and "faction 1"** on a screen that says red
  and blue everywhere else.

### Could be better

- **The highlight undersold speed.** It lit only the four neighbours, so a
  runner that moves 6 looked like a ram that moves 2.
- **Unhelpful refusals.**
  - Water and rock both said only "is blocked".
  - Clicking an enemy piece got a lecture about diagonals.
- **The bridge looked like a gap** in the river.
- **A just-built unit looked broken**: "no movement left".
- **The turn counter counted half-turns**, so red's third turn read "turn 4".
- **Sight was claimed and not used.** The legend said trees block sight, and
  the status printed a sight number nothing reads.
- **Ids hidden.** Type labels hid the ids that refusals name.
- **No build confirmation** beyond a smaller number.
- **T11 and ADR 0008 out of date.** T11 lists attacks but did not depend on
  T26, and ADR 0008 still said T10 brings combat.
- **A duplicated lookup.** The per-type map lookup was written twice.
- **No guard for an order with no type.**
- **Placement symmetry** was untested.
- **Scene tests covered only the happy path.**
- **Readability items.** An orphaned comment, a comment describing one type
  out of five, and magic indices in the placements.
- **`ai_learning` reads `state.graph`.** Fine for today's untyped boards, and
  wrong for a wader the day T11 hands it a tactical board.

## What was done about them

Fixed on this branch:

- **Picking a build cell.**
  - `BoardState.why_no_room` is public, and the scene picks a build cell by
    asking about room only.
  - A scene test builds with no funds and reads "runner costs 1 and the side
    to move has 0".
- **The counter test** now requires every buildable type to be answered by
  another *buildable* type. The ladder mutation fails it.
- **The bridge test** blocks the bridge and requires the far bank to be
  unreachable. A second gap in the river fails it.
- **The wader test** checks the movement left after a water step.
  Reverting `apply` to the board's map fails it.
- **Ids.** `BoardState.next_id` is a counter carried from state to state,
  started from every unit the state was built from, dead ones included. A
  test builds twice with a dead unit holding the highest id.
- **Production and upgrade refusals** say "the side to move".
- **The forge prompt** goes once the forge is owned. A test holds it.
- **The highlight** covers everywhere the piece can walk this turn, from a
  uniform-cost flood (`TacticalReach`). A click on any lit cell walks the
  cheapest route. Each route is put to `why_refused` before it is offered,
  and a test holds that for every red piece.
- **Refusals and messages.**
  - Water and rock refusals say what the cell is.
  - Clicking an enemy says whose piece it is.
  - A build is confirmed, and a new unit says it moves next turn.
- **The board.**
  - The bridge has its own tile and legend line.
  - The status counts rounds.
  - Pieces show their ids in a corner.
- **Sight** is gone from the legend and the status, and the rules say it
  waits for fog (T20).
- **Housekeeping.**
  - T11 depends on T26, and ADR 0008 points to T26.
  - `graph_for_type` is shared.
  - A missing unit type is refused in words.
  - Placement symmetry is tested.
  - New scene tests cover ending the turn, refusals and the forge.
  - The readability items are fixed, and placements are built from one side
    and mirrored.

Each strengthened test was mutation-checked: the reviewer's surviving
mutations, and three new ones, all go red.

Not fixed, on purpose:
- **Combat** is T26, as before. Until then shield, mortar and ram differ on
  screen only by speed and the "beats" line. The play review judged the
  manual check passed for terrain and *waiting on T26* for how the types
  feel, and that is how it is recorded.
- **`ai_learning` reading `state.graph`** is left for T11, which is the first
  task to hand it a board with waders on it. T11's notes say so.
- **Negative prices and negative income** are accepted. No caller produces
  them, and guarding every number is not this task. Recorded here, so it is
  not a surprise.

The fixes were not re-reviewed by a third context. They were re-screenshotted
and every gate is green.
