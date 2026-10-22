## The ways out of where the player is likely to be, found on the walk
## graph, and one given to each searcher left without a spot.
##
## Blacklist's designers marked a level's chokes by hand [Walsh 2015]; a
## level the generator made has no such marks, so they are computed. The
## likely region is the cells whose belief is at least twice an even share;
## its ways out are the cells just outside it, and a way out with at most
## two walkable neighbours -- a door, a gap between shelves -- is a choke,
## preferred over open ground. Each searcher without a spot is given the
## nearest way out no other searcher was given.
##
## Linear in the cells and their edges.
##
## When not to use it: a belief spread evenly over the level. Every cell
## is then "likely", there is no edge, and nothing is given.
class_name GuardWaysOut
extends RefCounted


## Give each of `searchers` with no spot the nearest free way out of
## `belief`'s likely region.
static func assign(level: InfiltrationLevel, belief: BeliefMap, searchers: Array[InfiltrationGuard]) -> void:
	var exits: Array[Vector2] = ways_out(level, belief)
	var taken: Dictionary[int, bool] = {}
	for guard: InfiltrationGuard in searchers:
		if guard.spot != -1:
			continue
		var best: int = _nearest_free(exits, guard.position, taken)
		if best != -1:
			guard.way_out = exits[best]
			taken[best] = true


## The ways out of the likely region: chokes when there are any, else every
## cell on its edge.
static func ways_out(level: InfiltrationLevel, belief: BeliefMap) -> Array[Vector2]:
	var likely: float = 2.0 / maxf(belief.shares.size(), 1.0)
	var edge: Dictionary[int, bool] = {}
	for cell: int in range(belief.shares.size()):
		if belief.shares[cell] >= likely:
			_add_unlikely_neighbours(level, belief, cell, likely, edge)
	var chokes: Array[Vector2] = []
	var open: Array[Vector2] = []
	for cell: int in edge:
		(chokes if level.neighbours[cell].size() <= 2 else open).append(BotArena.centre_of(level.cells[cell]))
	return chokes if not chokes.is_empty() else open


static func _add_unlikely_neighbours(level: InfiltrationLevel, belief: BeliefMap, cell: int, likely: float,
		edge: Dictionary[int, bool]) -> void:
	for next: int in level.neighbours[cell]:
		if belief.shares[next] < likely:
			edge[next] = true


static func _nearest_free(exits: Array[Vector2], from: Vector2, taken: Dictionary[int, bool]) -> int:
	var best: int = -1
	for index: int in range(exits.size()):
		if taken.has(index):
			continue
		if best == -1 or exits[index].distance_to(from) < exits[best].distance_to(from):
			best = index
	return best
