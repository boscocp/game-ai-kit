## The numbers the models were fitted on, read off a live board.
##
## This is the half of inference that gets quietly wrong. The weights are
## published and cannot drift; the *features* are computed twice, once in the
## Python simulator that made the data and once here, and a radius counted
## differently or a terrain read from the wrong cell produces a sound-looking
## prediction about a situation that never happened.
##
## So nothing here invents a number. Every convention -- how near is near, what
## a unit with no friends reports, what range of ground the data covered --
## comes out of the weights file, and the vectors in `spec/vectors/learning/`
## hold these functions to the same rows the Python side produces.
##
## When not to use it: a board that is not this kit's. These four features
## describe a fight between two units on a grid, and that is all.
class_name BoardFeatures
extends RefCounted

## The combat features, in the order the published weights expect. Named here
## only so a caller can see them; `LearnedModel.predict_named` matches by name.
const HEALTH_DIFFERENCE: String = "health_difference"
const NUMERIC_ADVANTAGE: String = "numeric_advantage"
const DEFENDER_TERRAIN: String = "defender_terrain"
const REINFORCEMENT_DISTANCE: String = "reinforcement_distance"

## The capture features.
const DISTANCE_TO_NODE: String = "distance_to_node"
const OWN_UNITS: String = "own_units"
const ENEMY_UNITS: String = "enemy_units"
const TERRAIN_ON_THE_WAY: String = "terrain_on_the_way"


## What a model gets to see about a fight, before it happens.
##
## The attacker's side of every asymmetric number: `health_difference` is the
## attacker's advantage, and `reinforcement_distance` is how far *its* nearest
## friend is. Swapping either reverses what the model is being asked.
##
## Both units must be `state`'s own. A unit tells its friends apart from
## itself by identity, as the simulator does, so one copied out of an earlier
## state would count itself among the friends standing next to it.
static func combat_row(state: BoardState, attacker: Unit, defender: Unit,
		published: ModelFile) -> Dictionary:
	var radius: int = published.convention("nearby_radius")
	return {
		HEALTH_DIFFERENCE: attacker.health - defender.health,
		NUMERIC_ADVANTAGE: (
			_friends_near(state, attacker, defender.cell, radius)
			- _friends_near(state, defender, attacker.cell, radius)
		),
		DEFENDER_TERRAIN: terrain_at(state.graph, defender.cell, published),
		REINFORCEMENT_DISTANCE: _nearest_friend(state, attacker, published),
	}


## What a model gets to see about a side's run at a node.
##
## Measured from whichever of the faction's units is nearest, which is the one
## the training data measured from -- not from the unit being decided for. A
## row built per unit would be a different feature wearing the same name.
static func capture_row(state: BoardState, faction: int, node: Vector2i,
		published: ModelFile) -> Dictionary:
	var own: Array[Unit] = state.units_of(faction)
	if own.is_empty():
		return {}
	var nearest: Unit = _nearest_to(own, node)
	return {
		DISTANCE_TO_NODE: distance_between(nearest.cell, node),
		OWN_UNITS: own.size(),
		ENEMY_UNITS: state.units.size() - own.size(),
		TERRAIN_ON_THE_WAY: _terrain_between(state.graph, nearest.cell, node, published),
	}


## Manhattan distance, which is the only one a cardinal grid can walk.
static func distance_between(one: Vector2i, other: Vector2i) -> int:
	return absi(one.x - other.x) + absi(one.y - other.y)


## What the model should be told this cell costs.
##
## Clamped into the range the data covered, and a wall counts as the dearest
## ground rather than as the -1 the board uses for it. Both are extrapolation
## dressed as a number: the simulator never generated a wall and never
## generated ground above `dearest_ground`, so the honest answer for either is
## "the worst ground the model has seen", and the clamp says it out loud
## instead of feeding a logistic regression a -1 it will happily multiply.
static func terrain_at(graph: GridGraph, cell: Vector2i, published: ModelFile) -> int:
	var dearest: int = published.convention("dearest_ground")
	if graph.is_blocked(cell):
		return dearest
	return clampi(graph.cost_at(cell), published.convention("cheapest_ground"), dearest)


# How many of this unit's other units stand within `radius` of a cell.
static func _friends_near(state: BoardState, unit: Unit, cell: Vector2i,
		radius: int) -> int:
	var found: int = 0
	for other: Unit in state.units_of(unit.faction):
		if other != unit and distance_between(other.cell, cell) <= radius:
			found += 1
	return found


# How far this unit's closest friend is, or the sentinel for having none.
static func _nearest_friend(state: BoardState, unit: Unit,
		published: ModelFile) -> int:
	var closest: int = published.convention("reinforcement_distance_when_alone")
	for other: Unit in state.units_of(unit.faction):
		if other != unit:
			closest = mini(closest, distance_between(other.cell, unit.cell))
	return closest


# Whichever of these units stands closest to a cell, ties going to the lowest
# id so two runs of the same board decide the same way.
static func _nearest_to(units: Array[Unit], cell: Vector2i) -> Unit:
	var best: Unit = units[0]
	for unit: Unit in units:
		var closer: bool = distance_between(unit.cell, cell) < distance_between(best.cell, cell)
		if closer:
			best = unit
	return best


# Mean terrain along one Manhattan route: along x, then along y.
#
# One route, not the cheapest. Working out the cheapest here would put a
# pathfinder inside a feature -- which makes a model look clever and makes the
# dataset impossible to rebuild from its description. The Python side walks
# the same two axes in the same order.
static func _terrain_between(graph: GridGraph, start: Vector2i, target: Vector2i,
		published: ModelFile) -> float:
	var costs: Array[int] = []
	var walker: Vector2i = start
	while walker.x != target.x:
		walker.x += signi(target.x - walker.x)
		costs.append(terrain_at(graph, walker, published))
	while walker.y != target.y:
		walker.y += signi(target.y - walker.y)
		costs.append(terrain_at(graph, walker, published))
	if costs.is_empty():
		return float(published.convention("cheapest_ground"))
	var total: int = 0
	for cost: int in costs:
		total += cost
	return float(total) / float(costs.size())
