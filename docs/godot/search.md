# Wiring ai_search into a game

<!-- doc-meta
half_life: practice
verified_on: 2026-10-21
tier: 2
source: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html ; https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html
invalidated_if: Godot changes how class_name registers a class, or the kit's Search, SearchGraph or GridGraph signatures change
teaches: search
-->

> How to build a board, run a search on it and read what came back. Every
> snippet here was run on the pinned Godot 4.7.2 on 2026-10-21, and the outputs
> shown are what it printed. Why the searches behave as they do is
> [the concept page](../concepts/search.md).

## What to copy

Two folders: `addons/ai_core/` (the grid, the `GakPathfinder` interface) and
`addons/ai_search/`. No editor plugin to enable -- every class here is
registered by `class_name`, and named classes are globally registered, usable
from any script without `load` or `preload`. Run the project once (or
`--import` headless) after copying, so the class list is rebuilt.

From a release, unzip `ai_core-<version>.zip` and `ai_search-<version>.zip`
into `res://addons/`.

## A board, and a search on it

`GakGridGraph` is a grid of costs: what it costs to **enter** each cell. One is
open ground, more is harder ground, `GakGridGraph.BLOCKED` is a wall. A cost
below one is clamped to one, because A\*'s heuristic is only right if no step
is cheaper than that.

```gdscript
var graph := GakGridGraph.new(8, 5)
for row: int in range(0, 4):
	graph.set_cost(Vector2i(4, row), 5)   # mud, with a gap at the bottom

var result: SearchResult = AStarSearch.new().search(GridSearchGraph.new(graph), Vector2i(0, 0), Vector2i(7, 0))
print(result.reached, " ", result.cost, " ", result.path.size(), " ", result.expanded.size())
# true 11 7 16
```

A search does not take the grid itself. It takes a `GakSearchGraph` -- the four
questions a search asks of any graph -- and `GridSearchGraph` is the grid
answering them. It wraps, it does not copy: block a cell afterwards and the
next search sees the wall.

Crossing the mud costs 11; the way round the gap costs 15, so the route goes
through. `path` does not include the starting cell -- seven steps for a walk
from column 0 to column 7.

## What a SearchResult carries

| field | what it is |
|---|---|
| `reached` | whether the goal was found |
| `path` | the cells to walk, start excluded; empty when not reached |
| `cost` | the sum of the costs of entering each cell on `path` |
| `expanded` | every cell taken off the frontier, **in order** |
| `frontier` | what was still waiting when the search stopped |

`expanded` and `frontier` are there to be drawn: `make demo-search` replays
`expanded` a cell at a time rather than re-running anything. That is how a
search shows its decision rather than only its outcome.

## When all you want is the route

`GridPathfinder` holds any of the four as `ai_core`'s `GakPathfinder`, whose one
method is `find_path`:

```gdscript
var route: Array[Vector2i] = GridPathfinder.new(DijkstraSearch.new()).find_path(graph, Vector2i(0, 0), Vector2i(7, 0))
# 7 cells
```

Hold it as a `GakPathfinder` and you can swap the algorithm without touching the
caller. The game does this: it hands a `GridPathfinder` to the learned policy,
which only knows it has *a* pathfinder, because no addon may depend on another.
With no argument, `GridPathfinder.new()` answers with A\*.

## A graph that is not a grid

Waypoints, rooms, a navigation mesh's polygons: write a `GakSearchGraph` with
four methods and every search here works on it unchanged.

A sketch, with the bodies left out; `waypoint_test.gd` is the whole one,
and it runs:

```gdscript
class_name Waypoints
extends GakSearchGraph

func contains(node: Vector2i) -> bool: ...          # is this a waypoint?
func neighbours(node: Vector2i) -> Array[Vector2i]: ...  # the ones a road leads to
func cost_at(node: Vector2i) -> int: ...            # what entering it costs, at least one
func estimate(node: Vector2i, goal: Vector2i) -> int: ...  # A*'s guess
```

A node is still a `Vector2i`, so name waypoints by position. The guess must be
**consistent**: zero at the goal, and never dropping by more than the next
node costs to enter. Zero everywhere is always safe and makes A\* Dijkstra.
`godot/test/ai_search/waypoint_test.gd` is a whole one, six waypoints where the
fewest hops and the cheapest route disagree. A cost per *road* rather than per
waypoint entered is the one thing the port cannot say, and the concept page
explains why.

## When to reach for the engine instead

Godot ships `AStarGrid2D`, "a variant of AStar2D that is specialized for
partial 2D grids", with Euclidean, Manhattan, octile and Chebyshev heuristics
and four diagonal modes. It is C++ and will beat everything here. Use it for
throughput; use this addon to see what it is doing.
