## Which objective each squad goes to: weighed objectives, each with an ideal
## number of bots, filled greedily by the cheapest squad first.
##
## Killzone 3's commander weighs objectives, each with an ideal number of
## bots, and assigns squads to them [Straatman et al. 2013]; Halo 3 writes the
## same as "pour squads in at the top, allow them to filter down", greedily by
## a cost [Isla, Halo 3 objectives]. Here an objective's priority is what it
## is worth -- taking one is worth more than holding one, less where the enemy
## is strong (Killzone's influence map, read as "attack where they are not"),
## and a held one with enemies on it is worth defending -- and a squad's cost for it is its
## distance over that priority. The cheapest pair is assigned, the objective's
## room shrinks by the squad's size, and again, until every squad has one.
## Squads times objectives per assignment, so cubic in the worst case and
## nothing at a match's sizes.
##
## The influence it reads is `TeamInfluence`, at each objective: below zero,
## the enemy holds the ground there.
##
## When not to use it: with one squad, or objectives that do not compete for
## bots. Then nearest-first is the same answer with less to explain.
class_name TeamCommander
extends RefCounted

## Who holds an objective, from the commanding team's side.
const NOBODY: int = 0
const US: int = 1
const THEM: int = -1


## One objective, as the commander sees it.
class Objective extends RefCounted:
	var id: String = ""
	var position: Vector2 = Vector2.ZERO
	## NOBODY, US or THEM.
	var held_by: int = NOBODY
	## How many bots it should have.
	var ideal: int = 2
	## The team's influence there: below zero, the enemy is stronger.
	var influence: float = 0.0


## One squad, as the commander sees it: what it reports up, where it is and
## how many it has.
class SquadReport extends RefCounted:
	var id: String = ""
	var position: Vector2 = Vector2.ZERO
	var size: int = 1


## What each objective is worth.
class Weights extends RefCounted:
	## Taking a point nobody holds, or the enemy's.
	var take: float = 3.0
	## Holding one of ours with nobody near it.
	var hold: float = 1.0
	## Added to a held point per unit of enemy influence on it.
	var defend: float = 2.0
	## A cost's distance is at least this, so a squad standing on an
	## objective does not cost zero and win every tie.
	var nearest_metres: float = 1.0


## Every objective's priority, in the objectives' order.
static func priorities(objectives: Array[Objective], weights: Weights) -> PackedFloat64Array:
	var result := PackedFloat64Array()
	for objective: Objective in objectives:
		result.append(priority_of(objective, weights))
	return result


## What `objective` is worth now.
static func priority_of(objective: Objective, weights: Weights) -> float:
	if objective.held_by != US:
		return weights.take / (1.0 + maxf(0.0, -objective.influence))
	return weights.hold + weights.defend * maxf(0.0, -objective.influence)


## The objective id each squad is sent to, by squad id. While an objective
## has room, squads fill it cheapest first; once none has, the rest go to
## the cheapest of all -- distance over priority, room or not -- so no squad
## is left without an order.
static func assign(squads: Array[SquadReport], objectives: Array[Objective], weights: Weights) -> Dictionary:
	var orders: Dictionary = {}
	if objectives.is_empty():
		return orders
	var worth: PackedFloat64Array = priorities(objectives, weights)
	var room: PackedInt32Array = PackedInt32Array()
	for objective: Objective in objectives:
		room.append(objective.ideal)
	var waiting: Array[SquadReport] = squads.duplicate()
	while not waiting.is_empty():
		var pair: Vector2i = _cheapest(waiting, objectives, worth, room, weights)
		var squad: SquadReport = waiting[pair.x]
		orders[squad.id] = objectives[pair.y].id
		room[pair.y] -= squad.size
		waiting.remove_at(pair.x)
	return orders


## Without a commander: each squad goes to the nearest objective not ours,
## or the nearest of all when every one is ours. The toggle's other side.
static func nearest(squads: Array[SquadReport], objectives: Array[Objective]) -> Dictionary:
	var orders: Dictionary = {}
	for squad: SquadReport in squads:
		var best: int = _nearest_index(squad.position, objectives, true)
		if best == -1:
			best = _nearest_index(squad.position, objectives, false)
		if best != -1:
			orders[squad.id] = objectives[best].id
	return orders


# The (squad, objective) pair of least distance over priority, among the
# objectives with room; when none has room, among all of them. The first of
# equal costs wins, so the answer does not depend on float noise in order.
static func _cheapest(waiting: Array[SquadReport], objectives: Array[Objective],
		worth: PackedFloat64Array, room: PackedInt32Array, weights: Weights) -> Vector2i:
	var open: Array[int] = []
	for index: int in range(objectives.size()):
		if room[index] > 0:
			open.append(index)
	if open.is_empty():
		open.assign(range(objectives.size()))
	var best := Vector2i(-1, -1)
	var best_cost: float = INF
	for squad_index: int in range(waiting.size()):
		var costs: PackedFloat64Array = PackedFloat64Array()
		for index: int in open:
			costs.append(_cost(waiting[squad_index], objectives[index], worth[index], weights))
		var least: int = _index_of_least(costs)
		if costs[least] < best_cost:
			best_cost = costs[least]
			best = Vector2i(squad_index, open[least])
	return best


# The first index holding the smallest value; `values` is never empty.
static func _index_of_least(values: PackedFloat64Array) -> int:
	var least: int = 0
	for index: int in range(1, values.size()):
		if values[index] < values[least]:
			least = index
	return least


static func _cost(squad: SquadReport, objective: Objective, worth: float, weights: Weights) -> float:
	var distance: float = maxf(squad.position.distance_to(objective.position), weights.nearest_metres)
	return distance / worth


static func _nearest_index(place: Vector2, objectives: Array[Objective], skip_ours: bool) -> int:
	var best: int = -1
	var best_distance: float = INF
	for index: int in range(objectives.size()):
		var distance: float = place.distance_to(objectives[index].position)
		if not (skip_ours and objectives[index].held_by == US) and distance < best_distance:
			best_distance = distance
			best = index
	return best
