## A turn decided by two fitted models: fight this, or walk at that.
##
## *Will this attack work* comes back as a probability, compared against one
## threshold -- the whole of the attack-or-retreat decision, and a number a
## designer can turn. *How long will this node take* comes back as turns, and
## the lower of two is where the unit walks. Ahead of both sits one rule that
## is not learned, and says so: a node an enemy stands on is walked at first
## (T41 -- the owner stood on one and the models, which were never told who
## stands where, looked straight past it). Nothing here trains: that is
## invariant 6, and `make lint-no-training` is the gate on it.
##
## When not to use it: a decision these weights were not fitted for. They
## describe fights between two units on a grid, and nothing else.
class_name LearnedPolicy
extends DecisionPolicy

## The two models this policy expects a weights file to publish.
const COMBAT_MODEL: String = "combat"
const CAPTURE_MODEL: String = "capture"

## The probability at which the decision flips. A half is the honest default:
## it is the same threshold the Python side scores accuracy at, so a policy
## left at this value attacks exactly when the model says "more likely than
## not". A braver opponent takes less, a cautious one more, and T12 is where
## that becomes a difficulty setting.
const DEFAULT_THRESHOLD: float = 0.5

var _published: ModelFile
var _combat: LearnedModel
var _capture: LearnedModel
var _nodes: Array[Vector2i]
var _threshold: float
var _router: Pathfinder


func _init(published: ModelFile, nodes: Array[Vector2i],
		threshold: float = DEFAULT_THRESHOLD, router: Pathfinder = null) -> void:
	_published = published
	_nodes = nodes.duplicate()
	_threshold = threshold
	# Optional, and null is the useful default rather than an oversight: a
	# route is a search, a search lives in another addon, and no addon may
	# depend on another. Given one, this policy walks the route it is handed;
	# given none, it steps towards what it wants and stops when it cannot get
	# closer -- which is the same thing the fixed policy that produced the
	# training data did.
	_router = router
	_combat = published.model(COMBAT_MODEL) if published != null else null
	_capture = published.model(CAPTURE_MODEL) if published != null else null


## Why this policy cannot decide anything, or "" when it can.
##
## Asked by the game before the first turn, so a missing or malformed weights
## file is a sentence on the screen rather than an opponent that stands still
## and looks thoughtful.
func why_unusable() -> String:
	if _published == null:
		return "no weights file was given to the policy"
	if not _published.is_loaded():
		return _published.error
	for name: String in [COMBAT_MODEL, CAPTURE_MODEL]:
		if _published.model(name) == null:
			return "the weights file publishes no `%s` model" % name
	return ""


## The move this policy would make. `DecisionPolicy`'s side of the contract.
func choose(state: BoardState, unit_id: int) -> Move:
	return decide(state, unit_id).move


## The same decision, with the numbers that produced it.
##
## This is the call the game makes, because a move on its own cannot be shown
## to anybody. `choose` is the interface; this is the lesson.
func decide(state: BoardState, unit_id: int) -> LearnedDecision:
	var unusable: String = why_unusable()
	if unusable != "":
		return LearnedDecision.hold(unit_id, unusable)
	var unit: Unit = state.unit_by_id(unit_id)
	if unit == null:
		return LearnedDecision.hold(unit_id, "no unit with that id is on the board")
	if unit.faction != state.current_faction:
		return LearnedDecision.hold(unit_id, "it is not this unit's side to move")
	var contested: Dictionary = _node_an_enemy_stands_on(state, unit)
	if not contested.is_empty():
		return LearnedDecision.contest(unit.id, _move_at(state, unit, contested["cell"]),
			contested["cell"], contested["holder"])
	var opponent: Unit = _fight_within_reach(state, unit)
	if opponent == null:
		return _advance_on_a_node(state, unit)
	return _fight_or_break_off(state, unit, opponent)


# The node an enemy stands on that is nearest this unit, with the enemy, or
# an empty dictionary when no enemy stands on any. Nearest so that two held
# nodes split blue's attention by distance rather than send everyone to the
# first in the list; ties go to the earlier node.
func _node_an_enemy_stands_on(state: BoardState, unit: Unit) -> Dictionary:
	var found: Dictionary = {}
	for node: Vector2i in _nodes:
		var holder: Unit = state.unit_at(node)
		if holder == null or holder.faction == unit.faction:
			continue
		var apart: int = BoardFeatures.distance_between(unit.cell, node)
		if found.is_empty() or apart < found["apart"]:
			found = {"cell": node, "holder": holder, "apart": apart}
	return found


# Ask the combat model about this fight, and act on the answer.
func _fight_or_break_off(state: BoardState, unit: Unit,
		opponent: Unit) -> LearnedDecision:
	var row: Dictionary = BoardFeatures.combat_row(state, unit, opponent, _published)
	var chance: float = _combat.predict_named(row)
	# NAN, which is what the model answers for a row it cannot read. It is not
	# a low probability and must not be acted on as one: a feature renamed on
	# one side of the two languages would otherwise show up as an opponent
	# that has become very timid.
	if not is_finite(chance):
		return LearnedDecision.hold(
			unit.id, "the combat model was handed a row it cannot read")
	if chance >= _threshold:
		return LearnedDecision.attack(
			unit.id, _move_at(state, unit, opponent.cell),
			opponent, chance, _threshold)
	return LearnedDecision.retreat(
		unit.id, _move_away_from(state, unit, opponent.cell),
		opponent, chance, _threshold)


# Walk at whichever node the capture model puts first.
#
# That model was fitted on *opening* positions paired with the turn the node
# fell, and this asks it every turn, on boards with fewer units and shorter
# distances than it ever saw. The number it answers is therefore a comparison
# between two nodes rather than a count of turns anybody should quote: the
# ordering is what the policy uses, and the ordering is the part that
# survives being asked out of population. Terrain extrapolation gets a clamp
# a few lines away; this one has no honest correction, so it is said instead.
func _advance_on_a_node(state: BoardState, unit: Unit) -> LearnedDecision:
	if _nodes.is_empty():
		return LearnedDecision.hold(unit.id, "no node was given to walk at")
	var ranked: Array[Dictionary] = _nodes_by_predicted_turns(state, unit.faction)
	if ranked.is_empty():
		return LearnedDecision.hold(
			unit.id, "the capture model was handed a row it cannot read")
	var best: Dictionary = ranked[0]
	return LearnedDecision.advance(
		unit.id, _move_at(state, unit, best["cell"]),
		best["cell"], best["turns"], _runner_up(ranked))


# Every node with what the capture model says it costs, quickest first.
#
# Ties are broken by coordinate rather than left to the sort, because two
# nodes the model cannot separate are exactly the case where an arbitrary
# order would make the same board play differently on two machines.
func _nodes_by_predicted_turns(state: BoardState, faction: int) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = []
	for node: Vector2i in _nodes:
		var row: Dictionary = BoardFeatures.capture_row(state, faction, node, _published)
		var turns: float = _capture.predict_named(row) if not row.is_empty() else NAN
		if is_finite(turns):
			ranked.append({"cell": node, "turns": turns})
	ranked.sort_custom(_quicker_node)
	return ranked


# True when the first node is the one to walk at.
static func _quicker_node(one: Dictionary, other: Dictionary) -> bool:
	if one["turns"] != other["turns"]:
		return one["turns"] < other["turns"]
	return Vector2i(one["cell"]) < Vector2i(other["cell"])


# The phrase naming what the chosen node was chosen over, or "" for one node.
static func _runner_up(ranked: Array[Dictionary]) -> String:
	if ranked.size() < 2:
		return ""
	return ", against %.1f at %s" % [ranked[1]["turns"], ranked[1]["cell"]]


# The nearest enemy this unit could plausibly reach this turn, or null.
#
# Plausibly: within the points it has left, plus the step that puts it in
# contact. Terrain can make that optimistic, which costs a prediction about a
# fight that does not happen -- where the other direction costs a unit walking
# past an enemy it never considered.
func _fight_within_reach(state: BoardState, unit: Unit) -> Unit:
	var reach: int = unit.movement_points + 1
	var nearest: Unit = null
	var closest: int = reach + 1
	for other: Unit in state.units:
		var apart: int = BoardFeatures.distance_between(other.cell, unit.cell)
		if other.faction == unit.faction or apart > reach:
			continue
		if apart < closest or (apart == closest and other.id < nearest.id):
			nearest = other
			closest = apart
	return nearest


# A move towards a cell: the route, trimmed to what this unit can afford.
#
# There is no "stop one short of an enemy" rule here, and there used to be.
# It was two lines dropping the last cell of the route, and review showed it
# could be deleted with every gate green -- not for want of a test, but
# because the board already refuses a move onto an occupied cell and
# `_affordable` cuts the route there. One rule, in one place, rather than a
# belt that reads like the mechanism.
#
# So walking at a node enters it, and walking at an enemy stops in contact,
# out of the same call. Until T10 there is no attack to follow that with:
# an attack here is a unit arriving beside the enemy and waiting.
func _move_at(state: BoardState, unit: Unit, target: Vector2i) -> Move:
	return _affordable(state, unit, _route_to(state, unit, target))


# A move that puts distance between this unit and a cell.
func _move_away_from(state: BoardState, unit: Unit, pivot: Vector2i) -> Move:
	return _affordable(state, unit, _walk(state, unit, pivot, false))


# The route to a cell: the pathfinder's, when the game supplied one.
func _route_to(state: BoardState, unit: Unit, target: Vector2i) -> Array[Vector2i]:
	if _router != null:
		return _router.find_path(state.graph, unit.cell, target)
	return _walk(state, unit, target, true)


# Step after step towards a cell, or away from it, while that is possible.
#
# Bounded by the unit's movement points, which is not a guess: every cell
# costs at least one point to enter, so no affordable route is longer.
static func _walk(state: BoardState, unit: Unit, pivot: Vector2i,
		closer: bool) -> Array[Vector2i]:
	var route: Array[Vector2i] = []
	var standing: Vector2i = unit.cell
	while route.size() < unit.movement_points:
		var step: Vector2i = _best_step(state, unit, standing, pivot, closer)
		if step == standing:
			break
		route.append(step)
		standing = step
	return route


# The neighbouring cell that gets nearest to a pivot, or furthest from it.
#
# Answers `standing` when nothing is better, which is the policy's way of
# saying there is nowhere to go. Occupied cells are skipped here rather than
# left to the legality check, so that a unit blocked by a friend keeps looking
# instead of stopping at the first idea it had.
static func _best_step(state: BoardState, unit: Unit, standing: Vector2i,
		pivot: Vector2i, closer: bool) -> Vector2i:
	var best: Vector2i = standing
	var best_distance: int = BoardFeatures.distance_between(standing, pivot)
	for step: Vector2i in state.graph.neighbours(standing):
		var occupant: Unit = state.unit_at(step)
		if occupant != null and occupant != unit:
			continue
		var apart: int = BoardFeatures.distance_between(step, pivot)
		var better: bool = (apart < best_distance) if closer else (apart > best_distance)
		if better:
			best = step
			best_distance = apart
	return best


# The longest prefix of a route this unit may actually walk.
#
# The board is asked the same question a player's click asks, rather than the
# rules being worked out again here. Two answers to one question is how they
# come to disagree, and `DecisionPolicy` requires the move this returns to be
# legal.
static func _affordable(state: BoardState, unit: Unit,
		route: Array[Vector2i]) -> Move:
	var taken: Array[Vector2i] = []
	for cell: Vector2i in route:
		var candidate: Array[Vector2i] = taken.duplicate()
		candidate.append(cell)
		if state.why_refused(Move.new(unit.id, candidate)) != BoardState.LEGAL:
			break
		taken = candidate
	return Move.new(unit.id, taken)
