## Dijkstra to every node within a cost, rather than to one goal.
##
## The same search as `DijkstraSearch` -- take the cheapest node off the
## frontier, give each unseen neighbour its cost so far -- with the goal
## taken away and a ceiling put in: stop expanding past `limit`. What comes
## back is every node reached and what it cost to get there. That is how far
## a sound travels along a level, round its walls rather than through them
## [Walsh 2015; Miles 2013], and it is the same flood Dishonored 2 runs from
## a last known position [Couvidou 2021].
##
## The costs are the graph's, paid on entering a node, so the start costs 0
## and `dijkstra.gd`'s argument holds here too: no node is ever improved,
## because every route into a node pays the same last step.
##
## Complexity: O(V²) for the V nodes within the limit -- the frontier scan
## of `GakSearch._cheapest`, kept for the same reason `dijkstra.gd` keeps it.
##
## When not to use it: one listener and one sound far apart. A single A*
## from the listener answers that without flooding the level around it.
class_name CostFlood
extends RefCounted


## Every node `graph` reaches from `from` at a cost of `limit` or less, and
## what it cost: node -> cost. Empty when `from` is not in the graph.
static func within(graph: GakSearchGraph, from: Vector2i, limit: int) -> Dictionary[Vector2i, int]:
	var reached: Dictionary[Vector2i, int] = {}
	if not graph.contains(from) or limit < 0:
		return reached
	# Cost so far: `g`, the literature's name, as in dijkstra.gd.
	var g: Dictionary = {from: 0}
	var frontier: Array[Vector2i] = [from]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_at(GakSearch._cheapest(frontier, g))
		reached[current] = int(g[current])
		_relax(graph, current, g, frontier, limit)
	return reached


# Give each neighbour not seen before its cost so far, if that is within
# the limit. A node past it is never queued, so the flood stops there.
static func _relax(graph: GakSearchGraph, current: Vector2i, g: Dictionary,
		frontier: Array[Vector2i], limit: int) -> void:
	for step: Vector2i in graph.neighbours(current):
		if g.has(step):
			continue
		var through_here: int = int(g[current]) + graph.cost_at(step)
		if through_here > limit:
			continue
		g[step] = through_here
		frontier.append(step)
