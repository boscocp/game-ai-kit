# T2 — `ai_core` and the board

Size: M · Prereqs: T1 · Files: `godot/addons/ai_core/`, `godot/game/`

## Goal

A turn-based board with no AI in it at all: a grid with terrain costs, two
factions, one unit each, alternating turns, and movement that refuses the
illegal. Everything after this decides *on* this state, so the state comes
first and the contract it exposes is what the other addons depend on.

`ai_core` holds types and interfaces only. No search, no planning, no learning
— if logic appears here, the addons stop being independent and invariant 2 is
gone.

## Steps

1. `GridGraph`: width, height, per-cell terrain cost, `is_blocked`,
   `neighbours`. Pure data and queries, no node, no scene — so it can be built
   in a test without an engine tree.
2. `Unit`: faction, position, health, movement points.
3. `BoardState`: units, whose turn it is, `apply(move)` returning a new state or
   refusing. Immutable where it is cheap to be.
4. A `TileMapLayer` view that draws it. `TileMap` is deprecated in Godot 4.
5. The interfaces the later addons implement, each with a doc comment saying
   what an implementation must guarantee.

## Acceptance

```bash
make test-godot
python3 scripts/check_readability.py
python3 scripts/check_addon_deps.py
```

The suite must include a test that turns alternate, a test that a move beyond
movement points is refused, and a test that terrain cost changes what a move
costs. Proving the suite can fail on this task's own code:

```bash
grep -q "func apply" godot/addons/ai_core/board_state.gd
grep -c "func test_" godot/test/board_state_test.gd | grep -qvx 0
```

## Manual check

Run the game and move a unit with the mouse. The board should be legible
without reading the code: whose turn it is, where a unit may go, what it costs.
