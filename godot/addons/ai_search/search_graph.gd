## What the four searches ask of a graph, and nothing more: the port.
##
## A\*, Dijkstra, breadth- and depth-first are graph algorithms, and read top to
## bottom they ask a graph four things -- is this node in you, what is next to
## it, what does it cost to enter, and (A\* only) how far is the goal at best.
## This class names those four questions. A grid answers them through
## `GridSearchGraph`; a set of waypoints, a dungeon of rooms or a navigation
## mesh's polygons answer them with an adapter of their own, and the searches do
## not change.
##
## A node is a `Vector2i`. A grid names its cells that way and a waypoint graph
## can name its points by position, and the algorithms keep the text that reads
## like the book's.
##
## When not to use it: when a node has no natural `Vector2i` name, number your
## nodes and pay a lookup -- or, better, make the node type opaque in your own
## copy. And when a cost belongs to an **edge** rather than to the node
## entered: Dijkstra here never improves a node it has seen, which is true only
## because every route into a node pays the same last step (`dijkstra.gd` says
## why). Charge per edge and you need the textbook's improvement branch back.
@abstract
class_name SearchGraph
extends RefCounted


## True when the node belongs to this graph at all.
##
## Asked once, of the start: a search from somewhere that is not a node has
## nothing to search from.
@abstract func contains(node: Vector2i) -> bool


## The nodes one step from this one that may be entered.
##
## Only the passable ones, in a fixed order. Filtering is the graph's job, so
## the search can read like the pseudocode; a fixed order is what makes ties
## break the same way on every run.
@abstract func neighbours(node: Vector2i) -> Array[Vector2i]


## What it costs to enter this node, at least one.
##
## Paid on entering, never on leaving, so the start costs nothing and the goal
## is paid for.
@abstract func cost_at(node: Vector2i) -> int


## A\*'s guess: the cheapest the rest of the route from `node` to `goal` could
## possibly be.
##
## The promise written on this method is stronger than "never more than the
## truth" (admissible). It must be **consistent**: across any step from `node`
## into a neighbour, the guess drops by no more than that neighbour costs to
## enter, and it is zero at the goal. `astar.gd` refuses to expand a node twice,
## and that shortcut returns the cheapest route only when the guess is
## consistent. Break it and A\* does not fail: it returns a dearer route,
## quickly, which is why the promise belongs to the graph that can keep it.
##
## Zero is always consistent, and turns A\* into Dijkstra.
@abstract func estimate(node: Vector2i, goal: Vector2i) -> int
