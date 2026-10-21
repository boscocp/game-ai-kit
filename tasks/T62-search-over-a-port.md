# T62 — Search over a port, not over a grid

Size: M · Prereqs: T61 · Files: `godot/addons/ai_search/`, `godot/test/ai_search/`, `spec/vectors/search/`, `docs/concepts/`

## Goal

The second technique to gain a port, after the pattern `ai_adversarial`
already follows (`AdversarialGame`: the addon owns the conversation, the game
writes the adapter -- Cockburn's "a port identifies a purposeful
conversation"). A\*, Dijkstra, breadth- and depth-first are graph
algorithms; ours take a `GridGraph`. A reader with waypoints, a navigation
mesh's polygons or a dungeon of rooms cannot use them without becoming a
grid first.

## Diagnosis (measured 2026-10-20 on `5129bfc`)

`search.gd` and its four algorithms ask a graph three things: whether a
node is in it (`contains`, `search.gd:38`), its neighbours
(`neighbours(cell)`) and the cost of entering one (`cost_at`). A\*'s
estimate does not come from the graph: `AStarSearch.heuristic`
(`astar.gd:99`) is Manhattan distance, right for a 4-connected grid whose
cheapest cell costs 1 and **wrong** for waypoints with arbitrary costs, where
it can overestimate and A\* stops being optimal. Every signature takes
`graph: GridGraph, from: Vector2i, to: Vector2i`. `Pathfinder` in `ai_core`
has the same signature, and only `ai_search` implements it.

## Steps

1. **Read the algorithm files top to bottom first.** The port is what they
   already ask, named; if a method appears that no algorithm calls, it is
   not part of the port.
2. **Decide two things, in the task file, before code:**
   - *Where the port lives.* Recommended: `SearchGraph` in `ai_search`
     (`@abstract`, like `AdversarialGame`), with `GridSearchGraph`, the
     adapter over `ai_core`'s `GridGraph`, in `ai_search` too -- so "someone
     who wants only A\* copies two folders" stays true. Putting the port in
     `ai_core` would grow the kernel T61 just shrank for a port one technique
     uses.
   - *Where A\*'s estimate comes from.* Recommended: the port has an
     `estimate(from, to)` the graph owns, with the promise written on it --
     never more than the true cheapest cost (admissible). The grid adapter
     returns today's Manhattan; the waypoint graph straight-line distance
     times its cheapest cost per unit length.
   - *What a node is.* Recommended: keep `Vector2i`. A waypoint graph names
     its nodes by position, and the algorithms' text -- which reads like the
     book's -- does not change. An opaque `int` id is the general answer and
     costs every reader a lookup; say so in the header's "when not to use it".
3. **The port, the adapter, the algorithms over the port.** The existing
   vectors replay unchanged through `GridSearchGraph`; that is the proof the
   refactor changed nothing.
4. **A graph that is not a grid**, in a test: a handful of waypoints with
   costs, where the shortest path by cost differs from the fewest hops, run
   through all four algorithms with what each one promises -- A\*'s cost
   equal to Dijkstra's on it, which is what an inadmissible estimate breaks.
5. **The concept page** shows the port and the two adapters side by side.
6. Whether `Pathfinder` still earns its place in `ai_core` after this, or
   is `SearchGraph`'s caller's interface and moves -- measured by who uses
   it, decided in this task; if it moves, `modules/ai_core.json` and the
   README's addon table follow.

## Decided (wave 68, before code)

Read first, as step 1 asks: the five files call `contains` (once, on the
start), `neighbours` and `cost_at`, and A\* adds its own `heuristic`. No other
method of `GridGraph` is called. So the port is those three plus the estimate.

- **Where the port lives: `SearchGraph`, `@abstract`, in `ai_search`**, with
  `GridSearchGraph` beside it -- the recommendation. Someone who wants only
  A\* still copies two folders.
- **A\*'s estimate: `SearchGraph.estimate(node, goal)`, owned by the graph.**
  The recommendation said *admissible*; the promise written on it is
  **consistent**, which is stronger, because `astar.gd` refuses to expand a
  node twice and that is only safe with a consistent guess
  (`docs/concepts/search.md` already said so for Manhattan). The waypoint
  test's estimate is fewest hops left times the cheapest hop, not
  straight-line distance: the port charges per node entered, and a distance
  along a road is a per-edge cost it cannot express.
- **A node stays `Vector2i`** -- the recommendation; the "when not to use it"
  in `search_graph.gd` says so, and adds the one thing the port cannot say, a
  cost per edge (Dijkstra's missing improvement branch).
- **Found in reading, not in the plan: `Search` stops being a `Pathfinder`.**
  `Pathfinder.find_path` takes a `GridGraph`, so a `Search` that implemented
  it would name the grid in `search.gd`, which the acceptance forbids. One
  adapter, `GridPathfinder` (a `Search` held as a `Pathfinder`), is the only
  file in `ai_search` that knows both. Its callers -- stealth, the behaviour
  demo, the RTS budget, the tactical game's router -- now build
  `GridPathfinder.new(AStarSearch.new())`.
- **Step 6: `Pathfinder` stays in `ai_core`.** Measured by who uses it: one
  holder, `game/tactical/learned_policy.gd`'s router, and it is what keeps
  `tactical` free of `ai_search` (`modules/tactical.json` lists `ai_search`
  only under `tests_depend_on`). Moved to `ai_search`, that dependency would
  become real. `SearchResult.NO_ROUTE` replaces `GridGraph.BLOCKED` as the
  cost of no route, the same `-1`, so `search_result.gd` names no grid either.
- **What the extra layer costs, measured:** `make test-rts-budget` times 200
  A\* searches on the RTS map. Three runs each: 288-290 ms on `af35c9d`,
  302-308 ms through `GridSearchGraph` -- about 5%, one more call per
  neighbour asked. Kept: the files are teaching material first, and the
  throughput answer was always `AStarGrid2D`.

## Acceptance

```bash
make check-affected BASE=origin/main
```

```bash
make test-search-vectors
```

The algorithms name no grid:

```bash
! grep -vE '^\s*#' godot/addons/ai_search/astar.gd godot/addons/ai_search/dijkstra.gd godot/addons/ai_search/breadth_first.gd godot/addons/ai_search/depth_first.gd godot/addons/ai_search/search.gd | grep -w GridGraph
```

The waypoint test lives in `godot/test/ai_search/`; it is the planted case
for the port: a search that silently counted hops instead of cost, or an A\*
with an estimate that overshoots, fails it.

```bash
make test-godot-some SUITES=test/ai_search
```

## Manual check

Read `astar.gd` beside the book's pseudocode, as before: does it still read
like it?

## Out of scope

- Ports for `ai_perception` or `ai_rts_core` (both use `GridGraph`, for
  sight and flow fields, which are grid techniques).
- A navigation-mesh adapter for Godot's `NavigationServer`.
