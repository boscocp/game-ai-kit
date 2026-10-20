# T8 — A board you can read

Size: S · Prereqs: T2, T21 · Files: `godot/game/`, `godot/demos/search/`

## Goal

T2's `## Manual check` says the board must be legible without reading the code:
whose turn it is, where a unit may go, what it costs. The owner ran `make run`
and could not tell what he was looking at. That is the manual check doing its
job, and this task is the answer to it.

This is not a redesign. It is five measured defects.

## What is actually wrong

Measured, not guessed:

- the board is **384×256 px in a 1280×720 window**, drawn at `(80, 80)` — a
  small thing in a corner of a large empty window;
- the palette is dark and low-contrast throughout: plain ground
  `(0.21, 0.27, 0.21)`, wall `(0.10, 0.10, 0.12)`. Two dark greys and a dark
  green, at 32 px;
- there are **no grid lines**, so cells of the same terrain merge into a field;
- the status line sits at `y = 620`, roughly **620 px away from the board** it
  describes;
- a reachable cell is painted by **replacing** its terrain tile, so the one
  moment you most want to know what the ground costs is the moment it is
  hidden;
- the cost of a cell is never drawn at all, and "what it costs" is a third of
  what the manual check asks for.

The search demo was reported as better and still improvable: it has no legend,
so dark-to-bright, the yellow outline and the two dots mean nothing to a reader
who has not read `expansion_view.gd`.

## Steps

1. Tiles at 48 px or more, and the board centred in the viewport rather than
   pinned to a corner. Derive the offset; do not type a magic `Vector2`.
2. A palette a person can separate at a glance, and grid lines between cells.
3. Draw the entry cost on any cell that costs more than `GridGraph.DEFAULT_COST`.
   Rough ground that looks expensive and *says* `3` needs no legend.
4. Make the reachable highlight an **overlay** — a tint or a border over the
   terrain tile, not instead of it. `BoardView` extends `TileMapLayer`, which is
   a `CanvasItem`, so `_draw()` is available for the overlay, the grid and the
   numbers. The `REACHABLE` tile in the atlas then has no caller and should go.
5. Put the status beside the board, larger, and say what to do in it: which
   unit is selected, how much movement is left, and the sentence a first-time
   player needs ("click one of your units, then a cell next to it").
6. A legend in the search demo: what the colour ramp means, what the outline
   means, what the two dots are, and the count of cells each algorithm expanded
   so the comparison is visible without switching between them.

## Acceptance

```bash
make test-godot
python3 scripts/check_readability.py
```

The suite must gain tests that hold the parts of this that are not taste, and
each must fail if its rule is removed:

```bash
grep -q "48" godot/game/board_view.gd
grep -c "func test_" godot/test/game_shared/board_view_test.gd | grep -qvx 0
```

The tests to write, named here so they are not forgotten: the board's drawn
rectangle is centred in the viewport to within one tile; a cell that is both
reachable and rough still reports its terrain tile, not the highlight; a cell
costing more than one has its cost in the drawn text; the status line contains
the selected unit, the movement left and an instruction.

## Manual check

Run `make run` and `make demo-search` and hand them to somebody who has not read
the code. They should be able to say whose turn it is, which unit is theirs,
where it can go, what the expensive ground is, and why a refused move was
refused — without being told. If they cannot, this task is not done, and the
answer is not to explain it to them.
