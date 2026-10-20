# What the policy does with the numbers, which is a separate question from
# whether the numbers are right.
#
# The models here are hand-made and mostly absurd -- a model that always
# answers 0.9, a model that cannot read the row it is given -- because every
# claim below is about the decision rule and not about the fit. The published
# weights get their own say in test/ai_learning/decision_scenarios.gd, where the question
# is whether a trained model plays sensibly.
extends GdUnitTestSuite

const CONVENTIONS: Dictionary = {
	"nearby_radius": 2,
	"reinforcement_distance_when_alone": 15,
	"cheapest_ground": 1,
	"dearest_ground": 3,
}

const COMBAT_FEATURES: Array = [
	"health_difference", "numeric_advantage",
	"defender_terrain", "reinforcement_distance",
]

const CAPTURE_FEATURES: Array = [
	"distance_to_node", "own_units", "enemy_units", "terrain_on_the_way",
]

const NODES: Array[Vector2i] = [Vector2i(0, 0), Vector2i(9, 6)]


func test_a_policy_over_a_missing_file_says_so_and_holds() -> void:
	# The opponent that stands still and looks thoughtful is the failure this
	# avoids: a file that did not load has to arrive as a sentence.
	var policy := LearnedPolicy.new(
		ModelFile.load_from("res://game/tactical/nothing.json"), NODES)

	assert_str(policy.why_unusable()).contains("M1")
	var decision: LearnedDecision = policy.decide(_two_sides(), 2)
	assert_str(decision.action).is_equal(LearnedDecision.HOLD)
	assert_str(decision.reason).contains("M1")
	assert_array(decision.move.path).is_empty()


func test_a_policy_over_a_file_with_one_model_missing_says_which() -> void:
	var half: ModelFile = ModelFile.from_dictionary({
		"feature_conventions": CONVENTIONS,
		"models": {"combat": _always(0.9)},
	}, "the test")

	assert_str(LearnedPolicy.new(half, NODES).why_unusable()).contains("capture")


func test_a_policy_given_nothing_at_all_holds_rather_than_crashing() -> void:
	assert_str(LearnedPolicy.new(null, NODES).why_unusable()).is_not_empty()


func test_a_unit_that_is_not_on_the_board_is_a_hold() -> void:
	var decision: LearnedDecision = _policy(0.9).decide(_two_sides(), 99)

	assert_str(decision.action).is_equal(LearnedDecision.HOLD)
	assert_str(decision.reason).contains("no unit")


func test_a_unit_of_the_side_that_is_not_to_move_is_a_hold() -> void:
	# The interface requires the move to belong to a unit of the side to
	# move. Answering for the other side would produce a move the board then
	# refuses, which reads as a broken policy rather than a misuse of one.
	var decision: LearnedDecision = _policy(0.9).decide(_two_sides(), 1)

	assert_str(decision.action).is_equal(LearnedDecision.HOLD)
	assert_str(decision.reason).contains("side to move")


func test_a_confident_model_closes_with_the_enemy() -> void:
	var state: BoardState = _two_sides()
	var decision: LearnedDecision = _policy(0.9).decide(state, 2)

	assert_str(decision.action).is_equal(LearnedDecision.ATTACK)
	assert_int(decision.opponent_id).is_equal(1)
	assert_vector(decision.move.destination(Vector2i(7, 3))).is_equal(Vector2i(5, 3))


func test_a_doubtful_model_breaks_off() -> void:
	var state: BoardState = _two_sides()
	var decision: LearnedDecision = _policy(0.1).decide(state, 2)

	assert_str(decision.action).is_equal(LearnedDecision.RETREAT)
	var went: Vector2i = decision.move.destination(Vector2i(7, 3))
	assert_int(BoardFeatures.distance_between(went, Vector2i(4, 3))).is_greater(3)


func test_the_threshold_is_the_only_thing_that_decides_it() -> void:
	# The same board and the same model, with the number a designer turns.
	var state: BoardState = _two_sides()
	var brave := LearnedPolicy.new(_file(_always(0.4)), NODES, 0.3)
	var timid := LearnedPolicy.new(_file(_always(0.4)), NODES, 0.5)

	assert_str(brave.decide(state, 2).action).is_equal(LearnedDecision.ATTACK)
	assert_str(timid.decide(state, 2).action).is_equal(LearnedDecision.RETREAT)


func test_a_probability_exactly_at_the_threshold_attacks() -> void:
	# `>=` rather than `>`, pinned because both read the same in prose and a
	# flipped comparison would show up only on the one board that lands on it.
	var policy := LearnedPolicy.new(_file(_always(0.5)), NODES, 0.5)

	assert_str(policy.decide(_two_sides(), 2).action).is_equal(LearnedDecision.ATTACK)


func test_a_model_that_cannot_read_the_row_holds_rather_than_retreating() -> void:
	# A feature renamed on one side of the two languages. The prediction is
	# NAN, NAN clears no threshold, and a policy that read that as "retreat"
	# would show up as an opponent that had quietly become very timid --
	# which is a bug that plays.
	var misnamed: Dictionary = _always(0.9)
	misnamed["features"] = ["health_diference"]
	misnamed["weights"] = [0.0]
	var decision: LearnedDecision = LearnedPolicy.new(
		_file(misnamed), NODES).decide(_two_sides(), 2)

	assert_str(decision.action).is_equal(LearnedDecision.HOLD)
	assert_str(decision.reason).contains("cannot read")


func test_an_enemy_too_far_to_reach_is_not_a_fight_worth_weighing() -> void:
	# Otherwise a unit on the far side of the board spends its turn retreating
	# from a fight it could not have had.
	var state := BoardState.new(GridGraph.new(14, 7), [
		Unit.new(1, 0, Vector2i(0, 3), 10, 4),
		Unit.new(2, 1, Vector2i(13, 3), 10, 4),
	] as Array[Unit], 1)

	assert_str(_policy(0.1).decide(state, 2).action).is_equal(LearnedDecision.ADVANCE)


func test_two_enemies_the_same_distance_away_are_decided_by_id() -> void:
	# Which fight gets weighed when two are tied was pinned by nothing:
	# review flipped the comparison and every gate stayed green. The higher
	# id is first in the array on purpose, so array order cannot pass this.
	var state := BoardState.new(GridGraph.new(9, 7), [
		Unit.new(5, 0, Vector2i(6, 3), 10, 4),
		Unit.new(1, 0, Vector2i(2, 3), 10, 4),
		Unit.new(2, 1, Vector2i(4, 3), 10, 4),
	] as Array[Unit], 1)

	assert_int(_policy(0.9).decide(state, 2).opponent_id).is_equal(1)


func test_an_enemy_exactly_in_reach_is_weighed_and_one_step_further_is_not() -> void:
	# `movement_points + 1` -- the points it has, plus the step that puts it
	# in contact. Review dropped the `+ 1` and nothing went red, because no
	# board sat on the boundary.
	var in_reach: BoardState = _with_enemy_at(Vector2i(11, 3))
	var out_of_reach: BoardState = _with_enemy_at(Vector2i(12, 3))

	assert_str(_policy(0.1).decide(in_reach, 2).action).is_equal(LearnedDecision.RETREAT)
	assert_str(_policy(0.1).decide(out_of_reach, 2).action).is_equal(LearnedDecision.ADVANCE)


func test_the_node_with_the_lower_prediction_is_the_one_walked_at() -> void:
	var state := BoardState.new(GridGraph.new(14, 7), [
		Unit.new(1, 0, Vector2i(0, 3), 10, 4),
		Unit.new(2, 1, Vector2i(13, 3), 10, 4),
	] as Array[Unit], 1)
	# A capture model that answers the distance it is given, so the nearer
	# node is the lower prediction and the expected answer is readable.
	var policy := LearnedPolicy.new(_file(_always(0.1), _distance_model()),
		[Vector2i(0, 0), Vector2i(12, 5)] as Array[Vector2i])

	var decision: LearnedDecision = policy.decide(state, 2)

	assert_str(decision.action).is_equal(LearnedDecision.ADVANCE)
	assert_vector(decision.target).is_equal(Vector2i(12, 5))
	assert_float(decision.predicted_turns).is_equal_approx(0.75, 1e-12)
	assert_str(decision.reason).contains("against 4.0 at (0, 0)")


func test_a_policy_with_nowhere_to_go_holds_and_says_why() -> void:
	var policy := LearnedPolicy.new(_file(_always(0.1)), [] as Array[Vector2i])
	var state := BoardState.new(GridGraph.new(9, 7), [
		Unit.new(2, 1, Vector2i(4, 3), 10, 4),
	] as Array[Unit], 1)

	var decision: LearnedDecision = policy.decide(state, 2)

	assert_str(decision.action).is_equal(LearnedDecision.HOLD)
	assert_str(decision.reason).contains("no node")


func test_a_unit_with_no_way_out_still_names_its_decision() -> void:
	# Boxed in by walls: the move is empty, which is "hold your ground", and
	# the decision is still a retreat. An empty move with no decision beside
	# it is the case `DecisionPolicy` warns about.
	var graph := GridGraph.new(3, 3)
	for cell: Vector2i in [Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 2)]:
		graph.block(cell)
	var state := BoardState.new(graph, [
		Unit.new(1, 0, Vector2i(1, 0), 10, 4),
		Unit.new(2, 1, Vector2i(1, 1), 10, 4),
	] as Array[Unit], 1)

	var decision: LearnedDecision = _policy(0.1).decide(state, 2)

	assert_str(decision.action).is_equal(LearnedDecision.RETREAT)
	assert_array(decision.move.path).is_empty()


func test_a_route_the_unit_cannot_pay_for_is_cut_to_what_it_can() -> void:
	# Review found that deleting the whole of `_affordable` left 203 tests,
	# three scenarios and twelve vectors green: every route the other tests
	# produce was affordable already. Rough ground everywhere and three
	# points buys exactly one step of it.
	var graph := GridGraph.new(9, 7, 3)
	var state := BoardState.new(graph, [
		Unit.new(1, 0, Vector2i(4, 3), 10, 3),
		Unit.new(2, 1, Vector2i(7, 3), 10, 3),
	] as Array[Unit], 1)

	var move: Move = _policy(0.9).choose(state, 2)

	assert_array(move.path).has_size(1)
	assert_int(move.cost_on(graph)).is_equal(3)
	assert_str(state.why_refused(move)).is_equal(BoardState.LEGAL)


func test_two_nodes_the_model_cannot_separate_are_ordered_by_coordinate() -> void:
	# A determinism rule, and review found nothing holding it: reducing the
	# comparison to the prediction alone left every gate green. Two nodes the
	# same distance away get the same number out of the model below, so the
	# only thing deciding is the tie-break.
	var state := BoardState.new(GridGraph.new(9, 9), [
		Unit.new(1, 0, Vector2i(0, 0), 10, 4),
		Unit.new(2, 1, Vector2i(4, 4), 10, 4),
	] as Array[Unit], 1)
	var far: Array[Vector2i] = [Vector2i(8, 4), Vector2i(0, 4)]
	var near: Array[Vector2i] = [Vector2i(0, 4), Vector2i(8, 4)]

	var one: LearnedPolicy = LearnedPolicy.new(_file(_always(0.1), _distance_model()), far)
	var other: LearnedPolicy = LearnedPolicy.new(_file(_always(0.1), _distance_model()), near)

	assert_vector(one.decide(state, 2).target).is_equal(Vector2i(0, 4))
	assert_vector(other.decide(state, 2).target).is_equal(Vector2i(0, 4))


func test_every_move_a_policy_returns_is_one_the_board_allows() -> void:
	# The interface's own requirement, over every decision these tests make.
	var state: BoardState = _two_sides()
	# Not 0.0 or 1.0: those are an infinite bias, the weights file refuses
	# one, and the policy would then be holding for a reason that has
	# nothing to do with what this test is about.
	for chance: float in [0.1, 0.5, 0.9]:
		var move: Move = _policy(chance).choose(state, 2)
		assert_str(state.why_refused(move)).is_equal(BoardState.LEGAL)
		assert_int(move.unit_id).is_equal(2)


func test_choose_plays_what_decide_explained() -> void:
	# Two entry points, one decision. If they could differ, the overlay would
	# be describing a move the game did not make.
	var state: BoardState = _two_sides()
	var policy: LearnedPolicy = _policy(0.9)

	assert_array(policy.choose(state, 2).path).is_equal(policy.decide(state, 2).move.path)


func test_without_a_pathfinder_it_still_gets_closer() -> void:
	# The fallback is a step at a time, which is what the fixed policy that
	# produced the training data did. It is worse than a route and it must
	# not be nothing.
	var state: BoardState = _two_sides()
	var decision: LearnedDecision = LearnedPolicy.new(
		_file(_always(0.9)), NODES).decide(state, 2)

	assert_vector(decision.move.destination(Vector2i(7, 3))).is_equal(Vector2i(5, 3))


# Blue at (7,3) with three points, and one enemy wherever this needs it.
func _with_enemy_at(cell: Vector2i) -> BoardState:
	return BoardState.new(GridGraph.new(14, 7), [
		Unit.new(1, 0, cell, 10, 3),
		Unit.new(2, 1, Vector2i(7, 3), 10, 3),
	] as Array[Unit], 1)


# One enemy three cells away on open ground, blue to move.
func _two_sides() -> BoardState:
	return BoardState.new(GridGraph.new(9, 7), [
		Unit.new(1, 0, Vector2i(4, 3), 10, 4),
		Unit.new(2, 1, Vector2i(7, 3), 10, 4),
	] as Array[Unit], 1)


# A policy whose combat model always answers the same thing.
func _policy(chance: float) -> LearnedPolicy:
	return LearnedPolicy.new(_file(_always(chance)), NODES,
		LearnedPolicy.DEFAULT_THRESHOLD, AStarSearch.new())


# A published file holding these two models.
func _file(combat: Dictionary, capture: Dictionary = _flat_model()) -> ModelFile:
	return ModelFile.from_dictionary({
		"feature_conventions": CONVENTIONS,
		"models": {"combat": combat, "capture": capture},
	}, "the test")


# A combat model that answers the same probability whatever it is shown.
#
# Every weight is zero and the bias is whatever logit produces `chance`, so
# the number comes out of the file rather than out of the board -- which is
# what makes a test about the decision rule a test about the decision rule.
func _always(chance: float) -> Dictionary:
	return {
		"kind": "logistic",
		"features": COMBAT_FEATURES,
		"weights": [0.0, 0.0, 0.0, 0.0],
		"bias": log(chance / (1.0 - chance)),
	}


# A capture model that answers nothing in particular, for tests about fights.
func _flat_model() -> Dictionary:
	return {
		"kind": "linear",
		"features": CAPTURE_FEATURES,
		"weights": [0.0, 0.0, 0.0, 0.0],
		"bias": 1.0,
	}


# A capture model that answers a quarter of the distance to the node, so the
# expected prediction can be read off the board.
func _distance_model() -> Dictionary:
	return {
		"kind": "linear",
		"features": CAPTURE_FEATURES,
		"weights": [0.25, 0.0, 0.0, 0.0],
		"bias": 0.0,
	}


# --- the contest rule (T41) -------------------------------------------------
#
# Not learned: a unit with no fight in reach walks at a node an enemy stands
# on before it asks the capture model. The review found it first tested only
# through the game scene, where reversing "nearest" or dropping the faction
# check passed everything.

func test_a_unit_with_no_fight_in_reach_contests_a_node_an_enemy_stands_on() -> void:
	var state: BoardState = _held_nodes([Vector2i(9, 6)], Vector2i(0, 3))

	var decision: LearnedDecision = _policy(0.9).decide(state, 2)

	assert_str(decision.action).is_equal(LearnedDecision.CONTEST)
	assert_vector(decision.target).is_equal(Vector2i(9, 6))
	assert_str(decision.reason).contains("a rule, not the model")


func test_of_two_held_nodes_the_nearer_is_contested() -> void:
	# Six cells from (0, 0) and nine from (9, 6): both just out of reach.
	var state: BoardState = _held_nodes([Vector2i(0, 0), Vector2i(9, 6)], Vector2i(6, 0))

	assert_vector(_policy(0.9).decide(state, 2).target).is_equal(Vector2i(0, 0))


func test_a_node_a_friend_stands_on_is_not_contested() -> void:
	var state := BoardState.new(GridGraph.new(14, 7), [
		Unit.new(2, 1, Vector2i(0, 3), 10, 4),
		Unit.new(3, 1, Vector2i(9, 6), 10, 4),
	] as Array[Unit], 1)

	assert_str(_policy(0.9).decide(state, 2).action).is_equal(LearnedDecision.ADVANCE)


func test_a_unit_on_a_node_does_not_leave_it_to_contest_another() -> void:
	var state: BoardState = _held_nodes([Vector2i(9, 6)], Vector2i(0, 0))

	assert_str(_policy(0.9).decide(state, 2).action).is_not_equal(LearnedDecision.CONTEST)


func test_a_fight_in_reach_is_weighed_before_any_contest() -> void:
	var state: BoardState = _held_nodes([Vector2i(9, 6)], Vector2i(0, 3))
	state.units.append(Unit.new(7, 0, Vector2i(1, 3), 10, 4))

	assert_str(_policy(0.1).decide(state, 2).action).is_equal(LearnedDecision.RETREAT)


# Blue's unit 2 at `blue_at`, and a red unit standing on each of `held`.
func _held_nodes(held: Array[Vector2i], blue_at: Vector2i) -> BoardState:
	var units: Array[Unit] = [Unit.new(2, 1, blue_at, 10, 4)]
	for cell: Vector2i in held:
		units.append(Unit.new(10 + units.size(), 0, cell, 10, 4))
	return BoardState.new(GridGraph.new(14, 7), units, 1)
