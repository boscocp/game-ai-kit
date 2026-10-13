# Search: four ways to choose the next cell

<!-- doc-meta
half_life: concept
verified_on: 2026-10-13
tier: 0
source: https://en.wikipedia.org/wiki/A*_search_algorithm
invalidated_if: GridGraph starts charging a cost per edge rather than per cell entered, or the kit's heuristic stops being Manhattan distance
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
| breadth-first | the oldest | fewest **steps**, if every step costs the same |
| depth-first | the newest | a route, if one exists -- nothing about its length |
| Dijkstra | the cheapest so far, `g` | the cheapest route, whatever the costs |
| A\* | the cheapest `f = g + h` | the cheapest route, *if `h` never overestimates* |

`g` is what it cost to get to a cell; `h` is a guess at what is left. The
names are the literature's and the code keeps them.

## Why A\* is right, and when it is not

Hart, Nilsson and Raphael published A\* in 1968. Its guarantee has a
condition: the guess `h` must never be **more** than the real remaining cost.
A guess with that property is called *admissible*, and with one A\* returns a
route exactly as cheap as Dijkstra's -- while looking at far fewer cells,
because cells pointing away from the goal get a large `h` and wait.

The guess here is Manhattan distance: how many cardinal steps lie between two
cells, ignoring what is in the way. It is admissible **because no cell costs
less than one to enter**. A route cannot have fewer steps than the Manhattan
distance, and each step costs at least one, so the guess cannot exceed the
truth. That is why `GridGraph.set_cost` clamps any cost below one: the board
that would break the heuristic cannot be built.

Break the condition and A\* does not fail loudly. It returns a route quickly,
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
pessimistic `h` can be expanded after a dearer one, and arrive at a shared
neighbour with a better offer. So A\* improves cells, re-queues them, and needs
a guard against expanding the same cell twice.

Measured, so it is not only an argument:

| | improvements over the boards |
|---|---|
| Dijkstra, the kit's cost rule (250 boards, in GDScript) | 0 |
| A\*, the kit's cost rule (same boards) | 165 |
| Dijkstra with a binary heap, the kit's cost rule (300 boards, a Python model) | 0 |
| the same heap, cost charged per **edge** (same 300 boards) | 1533 |

The last row is the condition this page names in its `invalidated_if`: give
the board edge costs -- a river that is dearer to cross one way -- and
Dijkstra needs the branch back.

## What the demo shows

`make demo-search` runs all four on one board -- a band of mud across the
middle, a wall with one gap -- and draws each expansion in the order it
happened. Breadth-first walks through the mud, because it does not see costs.
Dijkstra goes round, having spread out in rings to be sure. A\* goes round too,
having leaned towards the goal and stopped early. The difference between the
last two is the whole value of `h`.

## When not to use any of these

When you need throughput. These are written to be read: the frontier is a
list scanned for its cheapest entry, not a heap. For hundreds of units a
frame, Godot's own `AStarGrid2D` is C++ with four heuristics and four diagonal
modes, and is the right tool. Come back here to see what it is doing.
