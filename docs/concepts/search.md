# Search: four ways to choose the next cell

<!-- doc-meta
half_life: concept
verified_on: 2026-10-21
tier: 0
source: https://en.wikipedia.org/wiki/A*_search_algorithm
invalidated_if: SearchGraph starts charging a cost per edge rather than per node entered, or GridSearchGraph's estimate stops being Manhattan distance
teaches: search
-->

> Why breadth-first, depth-first, Dijkstra and A\* find the routes they find,
> and why on this kit's boards only one of them ever changes its mind. Needs
> nothing but reading. The code is in
> [`godot/addons/ai_search/`](../../godot/addons/ai_search/), and
> [the Godot page](../godot/search.md) is how to call it.

## One loop, one choice

Every search here is the same loop:

1. put the start on the **frontier** -- the cells known about and not yet
   looked at;
2. take one cell off it and **expand** it: note each neighbour, and where it
   was reached from;
3. stop when the cell taken off is the goal, then walk the "reached from"
   chain back to the start.

The four algorithms differ in one line, the one that picks which cell comes
off the frontier next:

| algorithm | takes off | guarantees |
|---|---|---|
| breadth-first | the oldest | fewest **steps** -- the cheapest route only if every step costs the same |
| depth-first | the newest | a route, if one exists -- nothing about its length |
| Dijkstra | the cheapest so far, `g` | the cheapest route, as long as no step costs less than nothing |
| A\* | the cheapest `f = g + h` | the cheapest route, *if `h` never overestimates* |

`g` is what it cost to get to a cell; `h` is a guess at what is left. The
names are the literature's and the code keeps them.

## What a search asks of a graph

Read the four files top to bottom and they ask a graph four things, and
nothing else. That list, named, is the **port** -- `SearchGraph` -- and the
searches are written against it rather than against a grid:

| the search asks | `SearchGraph` | a grid answers (`GridSearchGraph`) | six waypoints answer (`waypoint_test.gd`) |
|---|---|---|---|
| is this somewhere I can start? | `contains(node)` | the cell is on the board | it is one of the six |
| where can I go from here? | `neighbours(node)` | the four cardinal cells, walls dropped | where its roads lead |
| what does going there cost? | `cost_at(node)` | the cell's cost to enter | 9 for the ford, 1 elsewhere |
| how far is the goal, at best? (A\* only) | `estimate(node, goal)` | Manhattan distance | fewest hops left, times the cheapest hop |

The last row is why the port exists rather than only tidiness. A\*'s guess
is safe or not because of what the *graph* can cost, so the graph owns it:
Manhattan distance is right on a grid whose cheapest cell costs one, and
would be meaningless on waypoints. On the waypoint graph the route with fewest
hops crosses the ford for 10 and the cheapest goes round for 4; breadth-first
takes the first, Dijkstra and A\* the second, and an A\* handed a guess that
calls the long way dear takes the ford too -- which the same test shows
happening.

A node is still a `Vector2i`. A grid names cells that way and waypoints can be
named by position, and the files keep reading like the pseudocode. The
general answer, an opaque id, costs every reader a lookup. A game holding
`ai_core`'s `GakPathfinder` gets any of the four through `GridPathfinder`, which
is the only file in `ai_search` that knows both a grid and that interface.

## Why A\* is right, and when it is not

Hart, Nilsson and Raphael published A\* in 1968. Its guarantee has a
condition: the guess `h` must never be **more** than the real remaining cost.
A guess with that property is called *admissible*, and with one A\* returns a
route exactly as cheap as Dijkstra's -- while looking at fewer cells, because
cells pointing away from the goal get a large `h` and wait. How many fewer
depends on the board: 90 against 125 on the demo's, and never more on any of
the random boards `make test-search-properties` draws -- which is the claim
that command checks, rather than a ratio nothing prints.

The guess here is Manhattan distance: how many cardinal steps lie between two
cells, ignoring what is in the way. It is admissible **because no cell costs
less than one to enter**. A route cannot have fewer steps than the Manhattan
distance, and each step costs at least one, so the guess cannot exceed the
truth. That is why `GakGridGraph.set_cost` clamps any cost below one: the board
that would break the heuristic cannot be built. The guess is
`GridSearchGraph.estimate`, beside the grid it is safe for, not in `astar.gd`.

There is a second, stronger property, and this kit's A\* relies on it. It
refuses to expand a cell twice, and that shortcut is only safe when the
heuristic is *consistent*: the guess never drops by more than one step costs.
Manhattan distance here is. Neighbouring cells differ in `h` by exactly one,
and entering a cell costs at least one, so a cell taken off the frontier
already has its cheapest cost. Admissible alone would not be enough for an A\*
written this way.

Break either condition and A\* does not fail loudly. It returns a route quickly,
and the route is more expensive than it needed to be. Fast and quietly wrong
is the worst of the outcomes, which is why the condition lives in code rather
than in a warning.

## Why only A\* ever improves a cell

The textbook versions of Dijkstra and A\* both carry a branch that improves a
cell already seen: a long way round can turn out cheaper. On these boards
**Dijkstra never takes that branch**, and the reason is worth having, because
it is about the board rather than the algorithm.

A cost here belongs to the cell you *enter*. So every route into a cell pays
the same last step, and the only thing that can differ is what it cost to
reach the cell before it. Dijkstra expands cells in order of `g`, never
decreasing, so the first cell to reach a neighbour is one no dearer than any
it will expand later -- and that first offer is already the best one.

A\* expands in order of `g + h`, not `g`. A cell with a cheap `g` and a
pessimistic `h` can be expanded after a dearer one, and arrive at a neighbour
still waiting on the frontier with a better offer. So A\* improves cells -- only
ones not yet expanded, which is what consistency buys -- and queues them again.
The old entry stays in the list, and the guard against expanding a cell twice
is there to skip that stale copy, not because an expanded cell was wrong.

Measured, so it is not only an argument:

| | improvements over the boards |
|---|---|
| Dijkstra, the kit's cost rule (250 boards, in GDScript) | 0 |
| A\*, the kit's cost rule (same boards) | 165 |
| Dijkstra with a binary heap, the kit's cost rule (300 boards, a Python model) | 0 |
| the same heap, cost charged per **edge** (same 300 boards) | 1674 |

The last two rows are [`cost_models.py`](cost_models.py), beside this page:
`python3 docs/concepts/cost_models.py` prints them.

The last row is the condition this page names in its `invalidated_if`: give
the board edge costs -- a river that is dearer to cross one way -- and
Dijkstra needs the branch back.

## What the demo shows

`make demo-search` runs any of the four, one at a time, on one board -- a band
of mud across the middle, a wall with one gap -- and draws each expansion in
the order it happened. Breadth-first walks through the mud, because it does
not see costs: a route costing 98. Dijkstra goes round for 21, having expanded
125 cells to be sure. A\* goes round for the same 21, having expanded 90. The
difference between the last two is the whole value of `h`.

That board teaches one lesson, so the board can be edited. Paint walls and
mud, drag the start and the goal, or press B for three more, each with the
lesson it was drawn for written under it:

- **a maze** with one way through: all four find the same route, cost 36,
  and only the work differs -- A\* 41 cells, Dijkstra 51. In a corridor the
  heuristic points through walls, and buys little;
- **an open field**: A\* expands 14 cells to Dijkstra's 130;
- **a trap for depth-first**: the goal two cells to the right. Depth-first
  pushes its neighbours up, right, down, left and takes the last one pushed,
  so it sets off left, sweeps the board, and arrives by a route costing 40.

Edit one, and the screen says whether it still shows what it was for. Wall
the goal off and every search answers "no route", having expanded the whole
region the start could reach -- which is what "no route" costs.

## When not to use any of these

When you need throughput. These are written to be read: the frontier is a
list scanned for its cheapest entry, not a heap. For hundreds of units a
frame, Godot's own `AStarGrid2D` is C++ with four heuristics and four diagonal
modes, and is the right tool. Come back here to see what it is doing.
