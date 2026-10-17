## The numbers the models were fitted on, read off a live board.
##
## This is the half of inference that drifts. Weights are published and cannot;
## features are computed twice -- once in the Python simulator that made the
## data, once here -- so a radius counted differently gives a sound-looking
## prediction about a situation that never happened. Nothing here invents a
## number: every convention comes out of the weights file, and the vectors in
## `spec/vectors/learning/` hold both languages to the same rows.
##
## Only walkers count -- a unit that moves, or an untyped one. The dataset's
## boards have no buildings, so a tower beside a fight counted as a friend
## would hand the model a number it was never shown, and the tactical board's
## own fight does not count it either (`TacticalCombat`).
##
## When not to use it: any board but this kit's. Five features, one grid.
class_name BoardFeatures
extends RefCounted

## The combat features, in the order the published weights expect. Named here
## only so a caller can see them; `LearnedModel.predict_named` matches by name.
const HEALTH_DIFFERENCE: String = "health_difference"
const NUMERIC_ADVANTAGE: String = "numeric_advantage"
const DEFENDER_TERRAIN: String = "defender_terrain"
const REINFORCEMENT_DISTANCE: String = "reinforcement_distance"
## +1, 0 or -1: which way the counter table leans on this fight (T44).
const COUNTER: String = "counter"

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
		# The defender's own ground: a wader in the river stands on open
		# water, which is a wall on the board's own cost map.
		DEFENDER_TERRAIN: terrain_at(state.graph_for(defender), defender.cell, published),
		REINFORCEMENT_DISTANCE: _nearest_friend(state, attacker, published),
		COUNTER: counter(attacker.type, defender.type),
	}


## +1 when `attacker` is strong against `defender` by the counter table, -1
## the other way round, 0 for neither, both, or an untyped unit -- the
## dataset's `combat.counter`, read off `UnitType.strong_against`.
static func counter(attacker: UnitType, defender: UnitType) -> int:
	if attacker == null or defender == null:
		return 0
	return (1 if attacker.beats(defender) else 0) - (1 if defender.beats(attacker) else 0)


## True for a unit that can join a fight: one that moves, or an untyped one.
static func is_walker(unit: Unit) -> bool:
	return unit.type == null or unit.type.mobile


## What a model gets to see about a side's run at a node.
##
## Measured from whichever of the faction's units is nearest, which is the one
## the training data measured from -- not from the unit being decided for. A
## row built per unit would be a different feature wearing the same name.
##
## **`enemy_units` assumes two sides.** Python counts `living(1 - faction)`,
## which is "the other side" and has no meaning with three; this counts
## everyone who is not mine. On a two-faction board they are the same number
## and every vector is two-faction, so nothing holds them together on a board
## with three -- measured: one own unit, one of faction 1 and two of faction
## 2 gives 3 here and 1 there. `ai_core` allows three sides, so this is a
## limit of what the model was fitted on rather than of the board.
static func capture_row(state: BoardState, faction: int, node: Vector2i,
		published: ModelFile) -> Dictionary:
	var own: Array[Unit] = _walkers(state.units_of(faction))
	if own.is_empty():
		return {}
	var nearest: Unit = _nearest_to(own, node)
	return {
		DISTANCE_TO_NODE: distance_between(nearest.cell, node),
		OWN_UNITS: own.size(),
		ENEMY_UNITS: _walkers(state.units).size() - own.size(),
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
	for other: Unit in _walkers(state.units_of(unit.faction)):
		if other != unit and distance_between(other.cell, cell) <= radius:
			found += 1
	return found


# Those of `units` that can join a fight.
static func _walkers(units: Array[Unit]) -> Array[Unit]:
	var found: Array[Unit] = []
	for unit: Unit in units:
		if is_walker(unit):
			found.append(unit)
	return found


# How far this unit's closest friend is, or the sentinel for having none.
#
# The sentinel is the *fallback*, never a cap, and the first version of this
# function seeded the accumulator with it -- which quietly made "I am alone"
# and "my nearest friend is sixteen cells away" the same number. It survived
# review and both conformance vectors, because the vector boards are five and
# six cells wide and the sentinel is fifteen. The board `make run` ships is
# twelve by eight, where Manhattan distance reaches eighteen.
#
# A real distance above the sentinel is **not** clamped. It is out of the
# range the model was fitted on and there is no honest number to replace it
# with: terrain has one, because the worst ground is a real category, and
# this has none -- reporting fifteen would tell the model nobody is coming
# while a friend is on the way.
static func _nearest_friend(state: BoardState, unit: Unit,
		published: ModelFile) -> int:
	var closest: int = -1
	for other: Unit in _walkers(state.units_of(unit.faction)):
		var apart: int = distance_between(other.cell, unit.cell)
		if other != unit and (closest < 0 or apart < closest):
			closest = apart
	if closest < 0:
		return published.convention("reinforcement_distance_when_alone")
	return closest


# Whichever of these units stands closest to a cell.
#
# A tie goes to the earliest in `state.units`, which is deterministic and is
# also what Python's `min(...)` does over `board.living(faction)` -- the two
# languages agree by both taking the first. An earlier version of this comment
# claimed the tie went to the lowest id, which the code has never done and no
# vector pins either way.
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
