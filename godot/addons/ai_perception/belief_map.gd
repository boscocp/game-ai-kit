## Where the guards believe the target is: a share of the certainty on
## every node of the level's graph, summing to one.
##
## An occupancy map holds the target's position "as a discrete probability
## distribution over space"; each unobserved step diffuses it, and places
## the guards can see are zeroed [Isla 2013]. The Last of Us's search map is
## the same: cells "bleed into their neighbors over time" and any cell an
## enemy can see is cleared [McIntosh 2015]. So, over a graph given as a
## neighbour list -- node i's neighbours are `neighbours[i]` -- with no
## level in it:
##
## - while the target is perceived, or a guard reports it, all the belief
##   sits on that node (`collapse`);
## - while it is not, each step keeps `1 - spread` of every node where it
##   is, hands `spread` out equally along its edges, zeroes every node a
##   guard sees, and renormalises (`step_unseen`);
## - if that would clear it all, the target has been searched for
##   everywhere it could be and was not found: the belief is reseeded evenly
##   over the nodes no guard sees, and `reseeded` says so for the overlay.
##
## Nothing writes it but a percept or a report, and nothing in it knows
## where the target really is. O(V + E) a step.
##
## When not to use it: a level of thousands of nodes stepped every frame.
## Step it a few times a second, or over rooms rather than cells.
class_name BeliefMap
extends RefCounted

var neighbours: Array[PackedInt32Array] = []
## One share per node, summing to one (or all zero on a graph every guard sees).
var shares: PackedFloat64Array = PackedFloat64Array()
## True when the last step had to reseed the belief.
var reseeded: bool = false


## A belief spread evenly over a graph of `graph_neighbours`: nothing is
## known yet, so every node is as likely as another.
func _init(graph_neighbours: Array[PackedInt32Array]) -> void:
	neighbours = graph_neighbours
	shares.resize(neighbours.size())
	shares.fill(1.0 / maxf(neighbours.size(), 1.0))


## All of the belief on `node`: the target was perceived there, or a guard
## reported it there.
func collapse(node: int) -> void:
	shares.fill(0.0)
	shares[node] = 1.0
	reseeded = false


## One step with the target unperceived: spread `spread` of every node
## along its edges, zero the nodes in `seen`, renormalise -- or reseed over
## the unseen nodes when nothing is left.
func step_unseen(seen: PackedInt32Array, spread: float) -> void:
	shares = spread_along_edges(shares, neighbours, clampf(spread, 0.0, 1.0))
	for node: int in seen:
		shares[node] = 0.0
	var total: float = _sum(shares)
	reseeded = total <= 0.0
	if reseeded:
		_reseed(seen)
	else:
		for node: int in range(shares.size()):
			shares[node] /= total


## `from` after one step of diffusion: each node keeps `1 - spread` and
## gives `spread` to its neighbours in equal parts; a node with none keeps
## all of it. The total is unchanged.
static func spread_along_edges(from: PackedFloat64Array, graph_neighbours: Array[PackedInt32Array],
		spread: float) -> PackedFloat64Array:
	var to := PackedFloat64Array()
	to.resize(from.size())
	for node: int in range(from.size()):
		var edges: PackedInt32Array = graph_neighbours[node]
		var given: float = spread if not edges.is_empty() else 0.0
		to[node] += from[node] * (1.0 - given)
		for next: int in edges:
			to[next] += from[node] * given / edges.size()
	return to


# Even over the nodes not in `seen`, which is made a set first: asking the
# array `has` for every node would be O(V x |seen|), not O(V + E).
func _reseed(seen: PackedInt32Array) -> void:
	var is_seen: Dictionary[int, bool] = {}
	for node: int in seen:
		is_seen[node] = true
	var unseen: Array[int] = []
	for node: int in range(shares.size()):
		if not is_seen.has(node):
			unseen.append(node)
	shares.fill(0.0)
	for node: int in unseen:
		shares[node] = 1.0 / unseen.size()


static func _sum(values: PackedFloat64Array) -> float:
	var total: float = 0.0
	for value: float in values:
		total += value
	return total
