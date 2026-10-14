# T29 — A search board you can edit

Size: M · Prereqs: T8 · Files: `godot/demos/search/`

## Goal

The search demo works, and its one board teaches one lesson. The owner wants
to try the four searches on boards of their own: a maze, an open field, a
wall with no gap. The demo should be a place to ask "what does A\* do
*here*?" and see.

## Steps

1. **Paint the board.**
   - Left-click and drag paints the chosen terrain; right-click erases it.
   - Keys or a small palette choose wall, mud or open ground.
   - Mud's cost can be changed.
2. **Drag the start and the goal** to any open cell.
3. **Search again on every change.** The chosen algorithm replays from
   nothing, and the comparison line updates for all four.
4. **"No route" is a result, not a crash.** A goal walled off shows how much
   each search explored before giving up.
5. **A few named boards to start from**: the current one, a maze, an open
   field, and a trap for depth-first. Plus clear, and R to rebuild.
6. Say on screen how to edit, and keep the legend.

## Acceptance

```bash
make test-godot
make test-demo-overlays
python3 scripts/check_readability.py
```

The suite must include:
- painting a wall over the only gap makes every search report no route;
- moving the goal re-runs the search;
- erasing a painted cell makes it open ground, at `GridGraph.DEFAULT_COST`;
- each named board carries its own expectation (for example "A\* expands
  fewer cells than Dijkstra", or "depth-first's route costs more than
  Dijkstra's"), and a test loads every board and checks its expectation.

## Manual check

Somebody who has not read the code builds a maze in under a minute and can
say why depth-first wandered and A\* did not.
