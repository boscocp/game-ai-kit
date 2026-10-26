# ai_search — finding a route

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: book:Stuart Russell and Peter Norvig, "Artificial Intelligence: A Modern Approach", 4th edition, Pearson, 2020 -- chapter 3 ; https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html
invalidated_if: the kit's Search, SearchGraph, GridPathfinder or GridGraph signatures change, or the demos that use them are renamed
teaches: search
-->

> Português: [ai_search.pt-BR.md](ai_search.pt-BR.md). The words that stay
> in English are in the [glossary](glossary.pt-BR.md).

## What it decides {#what}

Which cells to walk through to get from here to there, and what that walk
costs. Four searches answer it -- breadth-first, depth-first, Dijkstra and
A\* -- and a fifth, `CostFlood`, answers "everything I can reach for this
much", which is how far a sound carries round a wall. Each search also hands
back *what it looked at* (`expanded`), which is the part worth watching.
The book: Russell and Norvig, *AIMA*, chapter 3.

## When not to use it {#when-not}

When you need throughput. Godot's own `AStarGrid2D` is C++ and beats every
search here; these are written to be read. And when you cannot guess how far
the goal is -- a graph of abstract states rather than a map -- A\* has
nothing to lean on and is Dijkstra with extra steps.

## Where to watch it {#watch}

- `make demo-search` -- the four searches on a board you can paint. **1-4**
  choose the search, **space** reveals one more expanded cell, **enter** the
  rest: you watch the frontier grow, not only the route.
- `make demo-behaviour`, `make demo-stealth` and `make demo-skirmish` use it
  underneath to move a guard or a unit; so do two of the 3D examples,
  `make demo-infiltration` (where a guard walks, how far a sound carries)
  and `make demo-botmatch` (where a bot walks).
- Which demo uses which technique, both ways: the catalogue (T76, coming).

## In this kit {#in-this-kit}

`godot/demos/search/search_demo.gd` builds a `GridGraph` from a named board,
wraps it as `GridSearchGraph.new(grid)` -- the adapter that lets a search
read a grid -- and runs all four searches on it, then replays
`SearchResult.expanded` a cell at a time. The knobs that matter:

| knob | where | what it changes |
|---|---|---|
| which search | `AStarSearch`, `DijkstraSearch`, `BreadthFirstSearch`, `DepthFirstSearch` | the order the frontier is taken in -- and so the route and the work |
| a cell's cost | `GridGraph.set_cost(cell, cost)` | what entering it costs; at least 1, `GridGraph.BLOCKED` is a wall |
| the guess | `SearchGraph.estimate` | A\*'s heuristic; must be *consistent*, zero makes A\* Dijkstra |
| the limit | `CostFlood.within(GridSearchGraph.new(grid), from, limit)` | how far a flood spreads |

## In your own project {#your-project}

### What to copy {#copy}

Two folders, nothing else: `godot/addons/ai_core/` (the grid and the
`Pathfinder` port) and `godot/addons/ai_search/`. No plugin to enable --
every class registers itself by `class_name`. Open the project once, or run
`godot --headless --import`, so Godot rebuilds its class list.

### A minimal example {#example}

A node of yours that finds a route as it enters the scene. Attach it to any
node; `route` holds the cells to walk. This file is run by
`route_example_test.gd`, and the gate holds the page equal to it.

<!-- example: godot/test/ai_search/route_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_search.md, run by
# route_example_test.gd. A node of your own that finds a route across a
# board of its own as it enters the scene tree.
extends Node

## The route it found: the start left out, the goal included.
var route: Array[Vector2i] = []


func _ready() -> void:
	# Six by four, open ground, and a wall down column 3 with a gap at the
	# bottom -- the route has to find the gap.
	var board := GridGraph.new(6, 4)
	for row: int in range(0, 3):
		board.block(Vector2i(3, row))
	# Held as ai_core's Pathfinder, so the caller does not care which search
	# answers: swap AStarSearch for DijkstraSearch and nothing else changes.
	var pathfinder: Pathfinder = GridPathfinder.new(AStarSearch.new())
	route = pathfinder.find_path(board, Vector2i(0, 0), Vector2i(5, 0))
```

### What you implement {#implement}

Nothing, on a square grid: fill a `GridGraph` from your `TileMapLayer` (one
`set_cost` per tile). For the route alone, hand it to a `Pathfinder` as the
example does. For what the search looked at too, wrap it:
`AStarSearch.new().search(GridSearchGraph.new(grid), from, to)` returns a
`SearchResult` with `path`, `cost`, `expanded` and `frontier` -- a search
takes a `SearchGraph`, and a `GridGraph` is not one. On anything else --
waypoints, rooms, a navigation mesh's polygons -- extend `SearchGraph` with
four methods (`contains`, `neighbours`, `cost_at`, `estimate`) and call
`search(graph, from, to)` on any of the four; `godot/test/ai_search/waypoint_test.gd` is a whole one.

## Deeper {#deeper}

- Why each search behaves as it does: [concepts/search.md](../concepts/search.md).
- Every field of `SearchResult`, and a graph that is not a grid:
  [godot/search.md](../godot/search.md).
- The grid itself: [ai_core](ai_core.md).
