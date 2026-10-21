# Three games the learned opponent is given, and what it has to do with them.
#
# T6's acceptance asks for a fight the AI should take and one it should run
# from, asserted rather than watched. The third is here because choosing
# between two nodes is the other half of what the weights are for, and a
# scenario that is never run is a claim nobody is making.
#
# Every scenario checks two things, and the second is the one worth having:
# that the decision came out with the right *name*, and that the move actually
# goes that way. A policy whose "attack" walks backwards passes a check on the
# label alone, and that is the shape of the bug this file exists to catch.
#
# What these do NOT catch, measured rather than assumed: a wrong feature. All
# three stayed green under five separate mutations of `BoardFeatures` -- a
# sign flipped on `numeric_advantage`, terrain read from the attacker's cell,
# reinforcement measured from the defender, the nearest unit swapped for the
# first, the terrain clamp deleted. These boards are lopsided enough that the
# decision survives a mangled row. That coverage is the conformance vectors'
# job, and the two should not be read as one.
#
#     ./scripts/godot --headless --path godot -s res://test/tactical/decision_scenarios.gd
#
# Exit codes: 0 every scenario went the way it had to, 1 one did not, 2 the
# published weights could not be read -- which is a different failure and must
# not be reported as a timid opponent.
extends SceneTree

const POINTS: int = 4
const RED: int = 0
const BLUE: int = 1

# Two corners, far from every fight below, so that a unit deciding to walk at
# one of them has decided to and not drifted there.
const NODES: Array[Vector2i] = [Vector2i(0, 0), Vector2i(8, 6)]


func _init() -> void:
	var published: ModelFile = ModelFile.load_from(LearnedPolicy.WEIGHTS_PATH)
	if not published.is_loaded():
		printerr("decision_scenarios: %s" % published.error)
		quit(2)
		return

	var failures: Array[String] = []
	failures += _the_fight_it_should_take(published)
	failures += _the_fight_it_should_refuse(published)
	failures += _the_node_it_should_prefer(published)
	for failure: String in failures:
		print(failure)
	print("decision scenarios: 3 played, %d failure(s)" % failures.size())
	quit(1 if not failures.is_empty() else 0)


# A healthy unit three cells from a badly hurt enemy on open ground, with a
# friend close enough to the *defender* to count. Every feature points one
# way, and an opponent that will not take this fight will not take any.
#
# The friend was at (7,4) and that claim was false: four cells from the
# defender is outside `nearby_radius`, so it moved `reinforcement_distance`
# and left `numeric_advantage` at zero. Measured, and moved to (5,4).
func _the_fight_it_should_take(published: ModelFile) -> Array[String]:
	var state := BoardState.new(GridGraph.new(9, 7), [
		Unit.new(1, RED, Vector2i(4, 3), 4, POINTS),
		Unit.new(2, BLUE, Vector2i(7, 3), 16, POINTS),
		Unit.new(3, BLUE, Vector2i(5, 4), 12, POINTS),
	] as Array[Unit], BLUE)

	var decision: LearnedDecision = _policy(published).decide(state, 2)
	var failures: Array[String] = _expect("the fight it should take", decision,
		LearnedDecision.ATTACK, state)
	if decision.win_probability < LearnedPolicy.DEFAULT_THRESHOLD:
		failures.append("the fight it should take: p(win) is %.3f, under the threshold"
			% decision.win_probability)
	failures += _expect_the_move_goes(state, decision, Vector2i(4, 3), true)
	return failures


# The same board turned around: one hurt unit, no friends left, and a healthy
# enemy standing in cover. The model has to be able to say no.
func _the_fight_it_should_refuse(published: ModelFile) -> Array[String]:
	var graph := GridGraph.new(9, 7)
	graph.set_cost(Vector2i(4, 3), 3)
	var state := BoardState.new(graph, [
		Unit.new(1, RED, Vector2i(4, 3), 16, POINTS),
		Unit.new(2, BLUE, Vector2i(5, 3), 5, POINTS),
	] as Array[Unit], BLUE)

	var decision: LearnedDecision = _policy(published).decide(state, 2)
	var failures: Array[String] = _expect("the fight it should refuse", decision,
		LearnedDecision.RETREAT, state)
	if decision.win_probability >= LearnedPolicy.DEFAULT_THRESHOLD:
		failures.append("the fight it should refuse: p(win) is %.3f, at or over the threshold"
			% decision.win_probability)
	failures += _expect_the_move_goes(state, decision, Vector2i(4, 3), false)
	return failures


# Nobody in reach, and two nodes: one three cells away, one across the board
# and behind a band of rough ground. The capture model has to prefer the near
# one, and the decision has to say what it preferred it to.
func _the_node_it_should_prefer(published: ModelFile) -> Array[String]:
	var graph := GridGraph.new(12, 9)
	for row: int in range(0, 9):
		graph.set_cost(Vector2i(3, row), 3)
	var state := BoardState.new(graph, [
		Unit.new(1, RED, Vector2i(0, 0), 10, POINTS),
		Unit.new(2, BLUE, Vector2i(9, 7), 10, POINTS),
		Unit.new(3, BLUE, Vector2i(10, 7), 10, POINTS),
	] as Array[Unit], BLUE)
	var nodes: Array[Vector2i] = [Vector2i(1, 1), Vector2i(8, 5)]

	var policy := LearnedPolicy.new(
		published, nodes, LearnedPolicy.DEFAULT_THRESHOLD, GridPathfinder.new(AStarSearch.new()))
	var decision: LearnedDecision = policy.decide(state, 2)
	var failures: Array[String] = _expect("the node it should prefer", decision,
		LearnedDecision.ADVANCE, state)
	if decision.target != Vector2i(8, 5):
		failures.append("the node it should prefer: it walked at %s" % decision.target)
	if not decision.reason.contains("against"):
		failures.append("the node it should prefer: the reason does not say what it "
			+ "was preferred to -- `%s`" % decision.reason)
	return failures


# The decision has the name it should, and a move the board would allow.
func _expect(label: String, decision: LearnedDecision, wanted: String,
		state: BoardState) -> Array[String]:
	var failures: Array[String] = []
	if decision.action != wanted:
		failures.append("%s: it chose to %s -- %s" % [label, decision.action, decision.reason])
	var refusal: String = state.why_refused(decision.move)
	if refusal != BoardState.LEGAL:
		failures.append("%s: the move it chose is not legal -- %s" % [label, refusal])
	return failures


# The move closes with the pivot cell, or breaks off from it.
#
# Checked rather than assumed, because the label and the walk are produced by
# different code: one reads a probability, the other reads a board, and a
# decision that says "retreat" while stepping in is the one failure a reader
# watching the game would not notice until it had cost them.
func _expect_the_move_goes(state: BoardState, decision: LearnedDecision,
		pivot: Vector2i, closer: bool) -> Array[String]:
	var unit: Unit = state.unit_by_id(decision.unit_id)
	var before: int = BoardFeatures.distance_between(unit.cell, pivot)
	var after: int = BoardFeatures.distance_between(decision.move.destination(unit.cell), pivot)
	var contact: bool = closer and before == 1 and after == 1
	var went_the_right_way: bool = (after < before) if closer else (after > before)
	if went_the_right_way or contact:
		return []
	return ["%s: it was %d cells from %s and ended %d away" % [
		decision.action, before, pivot, after,
	]]


# A policy over the published weights, with a real search behind it.
func _policy(published: ModelFile) -> LearnedPolicy:
	return LearnedPolicy.new(
		published, NODES, LearnedPolicy.DEFAULT_THRESHOLD, GridPathfinder.new(AStarSearch.new()))
