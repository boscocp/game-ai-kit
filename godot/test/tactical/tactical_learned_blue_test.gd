# T44: the learned policy plays the tactical board. The control points, the
# combat model's fifth feature, and `LearnedBlue` deciding by the two models
# -- each model replaced here by one that answers a known number, so a test
# about the decision rule is about the rule and not about the weights.
extends GdUnitTestSuite

const RED: int = TacticalScenario.RED
const BLUE: int = TacticalScenario.BLUE
const COMBAT_FEATURES: Array[String] = ["health_difference", "numeric_advantage",
	"defender_terrain", "reinforcement_distance", "counter"]
const CAPTURE_FEATURES: Array[String] = ["distance_to_node", "own_units", "enemy_units", "terrain_on_the_way"]
const CONVENTIONS: Dictionary = {"nearby_radius": 2, "reinforcement_distance_when_alone": 15,
	"cheapest_ground": 1, "dearest_ground": 3}


# These tests read the English words. The engine starts in the system's
# locale, so on a Portuguese system they would read the pt-BR ones (T79);
# the Portuguese screen is test/locale's. The locale found is put back.
var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after() -> void:
	TranslationServer.set_locale(_locale_before)


# --- the counter, shared and seen ------------------------------------------

func test_the_rules_file_s_counter_table_is_the_game_s() -> void:
	var table: Dictionary = TacticalCombat.rules()["strong_against"]
	var types: Dictionary = TacticalRules.unit_types()
	for name: String in TacticalRules.BUILDABLE:
		assert_array(Array(types[name].strong_against)).override_failure_message(name).is_equal(table[name])
	assert_int(table.size()).is_equal(TacticalRules.BUILDABLE.size())


func test_the_combat_row_carries_the_counter_from_the_attacker_s_side() -> void:
	var state: BoardState = _board([[BLUE, TacticalRules.RUNNER, Vector2i(3, 3)], [RED, TacticalRules.MORTAR, Vector2i(4, 3)]])
	var published: ModelFile = _file(_always(0.5))

	assert_int(BoardFeatures.combat_row(state, state.unit_by_id(1), state.unit_by_id(2), published)["counter"]).is_equal(1)
	assert_int(BoardFeatures.combat_row(state, state.unit_by_id(2), state.unit_by_id(1), published)["counter"]).is_equal(-1)


func test_a_tower_beside_a_fight_is_not_a_friend_in_it() -> void:
	# The dataset has no buildings, and the board's own fight does not count
	# a tower either (`TacticalCombat._near`).
	var state: BoardState = _board([[BLUE, TacticalRules.SHIELD, Vector2i(3, 3)], [RED, TacticalRules.SHIELD, Vector2i(4, 3)],
		[BLUE, TacticalRules.BOLT_TOWER, Vector2i(3, 4)]])

	assert_int(BoardFeatures.combat_row(state, state.unit_by_id(1), state.unit_by_id(2), _file(_always(0.5)))["numeric_advantage"]).is_equal(0)


func test_a_wader_in_the_river_is_asked_about_its_own_ground() -> void:
	# On the board's cost map the river is a wall, which the row clamps to the
	# dearest ground; the wader stands on open water.
	var state: BoardState = TacticalScenario.build()
	var wader := Unit.new(50, RED, Vector2i(6, 2), 10, 4, TacticalRules.unit_types()[TacticalRules.WADER])
	var shield := Unit.new(51, BLUE, Vector2i(5, 2), 10, 3, TacticalRules.unit_types()[TacticalRules.SHIELD])
	var units: Array[Unit] = state.units.duplicate()
	units.append_array([wader, shield] as Array[Unit])
	var both := BoardState.new(state.graph, units, BLUE)
	both.movement_graphs = state.movement_graphs

	assert_int(BoardFeatures.combat_row(both, both.unit_by_id(51), both.unit_by_id(50), _file(_always(0.5)))["defender_terrain"]).is_equal(1)


# --- the points --------------------------------------------------------------

func test_a_point_pays_its_holder_and_not_a_contested_one() -> void:
	var point: Vector2i = TacticalScenario.POINTS[0]
	var held: BoardState = _board([[BLUE, TacticalRules.RUNNER, point]])
	var contested: BoardState = _board([[BLUE, TacticalRules.RUNNER, point], [RED, TacticalRules.RUNNER, point + Vector2i(0, 1)]])

	assert_int(ControlPoints.holder(held, point)).is_equal(BLUE)
	assert_int(ControlPoints.holder(contested, point)).is_equal(ControlPoints.NOBODY)
	assert_int(ControlPoints.pay(held)[0].funds_of(BLUE)).is_equal(TacticalRules.POINT_INCOME)
	assert_int(ControlPoints.pay(contested)[0].funds_of(BLUE)).is_equal(0)


func test_the_points_are_paid_at_the_start_of_the_holder_s_turn() -> void:
	var state: BoardState = _board([[BLUE, TacticalRules.RUNNER, TacticalScenario.POINTS[0]]], RED)

	var opened: Array = TurnStart.open(state)

	assert_int(opened[0].funds_of(BLUE)).is_equal(TacticalRules.INCOME + TacticalRules.POINT_INCOME)
	assert_str(" ".join(opened[1])).contains("holding the point")


func test_the_scene_pays_a_point_when_it_opens_the_holder_s_turn() -> void:
	# The scene must open turns through `TurnStart`: put back the old opening,
	# with no points, and only this test notices (wave 47's review).
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	add_child(scene)
	var runner: Unit = _first_of(scene.state, BLUE, TacticalRules.RUNNER)
	runner.cell = TacticalScenario.POINTS[1]
	var before: int = scene.state.funds_of(BLUE)

	scene.end_turn()
	scene.end_turn()   # the second press, past "units have not moved"

	assert_int(scene.state.current_faction).is_equal(BLUE)
	assert_int(scene.state.funds_of(BLUE)).is_equal(before + TacticalRules.INCOME + TacticalRules.POINT_INCOME)


func test_the_points_are_the_same_turned_half_round() -> void:
	var far_corner := Vector2i(TacticalScenario.MAP[0].length() - 1, TacticalScenario.MAP.size() - 1)
	for point: Vector2i in TacticalScenario.POINTS:
		assert_bool(TacticalScenario.POINTS.has(far_corner - point)).override_failure_message(str(point)).is_true()
		assert_str(TacticalScenario.MAP[point.y][point.x]).is_equal(TacticalRules.PLAIN)


# --- the learned blue ----------------------------------------------------------

func test_the_learned_blue_attacks_when_the_combat_model_clears_the_threshold() -> void:
	var state: BoardState = _board([[BLUE, TacticalRules.SHIELD, Vector2i(3, 3)], [RED, TacticalRules.RUNNER, Vector2i(5, 3)]])
	var blue := LearnedBlue.new(_file(_always(0.9)))

	var walk: TacticalDecision = blue.decide_move(state, 1)
	var after: BoardState = walk.played_on(state)
	var strike: TacticalDecision = blue.decide_attack(after, 1)

	assert_int(TacticalCombat.distance(after.unit_by_id(1).cell, Vector2i(5, 3))).is_equal(1)
	assert_str(walk.reason).contains("p(win) 0.90")
	assert_object(strike).is_not_null()
	assert_int(strike.attack.target_id).is_equal(2)


func test_the_learned_blue_retreats_when_it_does_not() -> void:
	var state: BoardState = _board([[BLUE, TacticalRules.SHIELD, Vector2i(3, 3)], [RED, TacticalRules.RUNNER, Vector2i(5, 3)]])
	var blue := LearnedBlue.new(_file(_always(0.1)))
	# The bar alone; retreating on strength is held below (T46).
	blue.retreat_on_strength = false

	var walk: TacticalDecision = blue.decide_move(state, 1)
	var after: BoardState = walk.played_on(state)

	assert_str(walk.reason).contains("retreats")
	assert_int(TacticalCombat.distance(after.unit_by_id(1).cell, Vector2i(5, 3))).is_greater(2)
	assert_object(blue.decide_attack(after, 1)).is_null()


func test_the_learned_blue_does_not_attack_a_fight_below_the_threshold() -> void:
	var state: BoardState = _board([[BLUE, TacticalRules.SHIELD, Vector2i(3, 3)], [RED, TacticalRules.RUNNER, Vector2i(4, 3)]])

	assert_object(LearnedBlue.new(_file(_always(0.1))).decide_attack(state, 1)).is_null()
	assert_object(LearnedBlue.new(_file(_always(0.9))).decide_attack(state, 1)).is_not_null()


func test_a_retreat_stops_at_the_edge_of_the_threat_s_reach() -> void:
	# A mortar reaches 2 + 3 = 5. Running as far as it could, a shield ended 7
	# away and walked back the next turn; it should stop at 6, the nearest
	# cell out of reach on its way to red's workshop.
	var state: BoardState = _board([[BLUE, TacticalRules.SHIELD, Vector2i(6, 4)], [RED, TacticalRules.MORTAR, Vector2i(2, 4)],
		[RED, TacticalRules.WORKSHOP, Vector2i(0, 4)]])

	var blue := LearnedBlue.new(_file(_always(0.1)))
	blue.retreat_on_strength = false
	var walk: TacticalDecision = blue.decide_move(state, 1)

	assert_str(walk.reason).contains("retreats")
	assert_int(TacticalCombat.distance(walk.target, Vector2i(2, 4))).is_equal(6)


# --- T46: two bars, a commitment, a fight joined, strength -------------------

func test_a_walker_that_set_out_strikes_above_the_give_up_bar() -> void:
	# It sets out at 0.6; on arrival the model says 0.45, under the commit
	# bar and over the give-up bar, so it still strikes -- the same red walker.
	var state: BoardState = _board([[BLUE, TacticalRules.SHIELD, Vector2i(3, 3)], [RED, TacticalRules.RUNNER, Vector2i(5, 3)]])
	var blue := LearnedBlue.new(_file(_always(0.6)))
	blue.begin_turn(state)
	var after: BoardState = blue.decide_move(state, 1).played_on(state)
	blue.policy = LearnedBlue.new(_file(_always(0.45))).policy

	var strike: TacticalDecision = blue.decide_attack(after, 1)

	assert_object(strike).is_not_null()
	assert_str(strike.reason).contains("give-up bar")


func test_a_walker_that_did_not_set_out_does_not_strike_under_the_commit_bar() -> void:
	var state: BoardState = _board([[BLUE, TacticalRules.SHIELD, Vector2i(3, 3)], [RED, TacticalRules.RUNNER, Vector2i(4, 3)]])

	assert_object(LearnedBlue.new(_file(_always(0.45))).decide_attack(state, 1)).is_null()


func test_a_walker_that_set_out_gives_up_at_the_give_up_bar() -> void:
	# At 0.3 exactly it gives up: "at or below", as T46 says.
	var state: BoardState = _board([[BLUE, TacticalRules.SHIELD, Vector2i(3, 3)], [RED, TacticalRules.RUNNER, Vector2i(5, 3)]])
	var blue := LearnedBlue.new(_file(_always(0.6)))
	blue.begin_turn(state)
	var after: BoardState = blue.decide_move(state, 1).played_on(state)
	blue.policy = LearnedBlue.new(_file(_always(0.3))).policy

	assert_object(blue.decide_attack(after, 1)).is_null()


func test_the_lower_bar_is_for_the_red_walker_it_set_out_for_and_no_other() -> void:
	# It set out for the runner at (5, 3); another red walker is no part of
	# that, and at 0.45 is not attacked.
	var state: BoardState = _board([[BLUE, TacticalRules.SHIELD, Vector2i(3, 3)], [RED, TacticalRules.RUNNER, Vector2i(5, 3)],
		[RED, TacticalRules.RUNNER, Vector2i(3, 4)]])
	var blue := LearnedBlue.new(_file(_always(0.45)))
	blue.begin_turn(state)
	blue._committed[1] = 2

	var strike: TacticalDecision = blue.decide_attack(state, 1)

	assert_object(strike).is_null()


func test_a_blow_ends_the_commitment() -> void:
	var state: BoardState = _board([[BLUE, TacticalRules.SHIELD, Vector2i(3, 3)], [RED, TacticalRules.RUNNER, Vector2i(5, 3)]])
	var blue := LearnedBlue.new(_file(_always(0.6)))
	blue.begin_turn(state)
	var after: BoardState = blue.decide_move(state, 1).played_on(state)

	blue.decide_attack(after, 1)

	assert_bool(blue._committed.has(1)).is_false()


func test_commitments_carry_from_turn_to_turn_within_a_game() -> void:
	# A walker that set out and was not asked to strike -- its walk refused,
	# say -- is still on its way next turn.
	var state: BoardState = _board([[BLUE, TacticalRules.SHIELD, Vector2i(3, 3)], [RED, TacticalRules.RUNNER, Vector2i(5, 3)]])
	var blue := LearnedBlue.new(_file(_always(0.6)))
	blue.begin_turn(state)
	blue.decide_move(state, 1)
	var later: BoardState = state.duplicate_state()
	later.turn_number = state.turn_number + TacticalScenario.FACTIONS

	blue.begin_turn(later)

	assert_int(blue._committed.get(1, -1)).is_equal(2)


func test_a_walker_beside_a_fight_its_side_started_joins_it_instead_of_retreating() -> void:
	var state: BoardState = _board([[BLUE, TacticalRules.SHIELD, Vector2i(3, 3)], [RED, TacticalRules.RUNNER, Vector2i(5, 3)],
		[BLUE, TacticalRules.SHIELD, Vector2i(3, 5)], [RED, TacticalRules.RUNNER, Vector2i(4, 5)]])
	var blue := LearnedBlue.new(_file(_always(0.9)))
	blue.retreat_on_strength = false
	blue.begin_turn(state)
	blue.decide_attack(state, 3)
	blue.policy = LearnedBlue.new(_file(_always(0.1))).policy

	var walk: TacticalDecision = blue.decide_move(state, 1)

	assert_str(walk.reason).contains("joins in")
	# Joining is not setting out: no lower bar for it later.
	assert_bool(blue._committed.has(1)).is_false()


func test_an_attack_far_off_does_not_stop_a_retreat() -> void:
	var state: BoardState = _board([[BLUE, TacticalRules.SHIELD, Vector2i(3, 3)], [RED, TacticalRules.RUNNER, Vector2i(5, 3)],
		[BLUE, TacticalRules.SHIELD, Vector2i(12, 8)], [RED, TacticalRules.RUNNER, Vector2i(13, 8)]])
	var blue := LearnedBlue.new(_file(_always(0.9)))
	blue.retreat_on_strength = false
	blue.begin_turn(state)
	blue.decide_attack(state, 3)
	blue.policy = LearnedBlue.new(_file(_always(0.1))).policy

	assert_str(blue.decide_move(state, 1).reason).contains("retreats")


func test_attacks_of_last_turn_are_not_fights_beside_it_now() -> void:
	var state: BoardState = _board([[BLUE, TacticalRules.SHIELD, Vector2i(3, 3)], [RED, TacticalRules.RUNNER, Vector2i(5, 3)],
		[BLUE, TacticalRules.SHIELD, Vector2i(3, 5)], [RED, TacticalRules.RUNNER, Vector2i(4, 5)]])
	var blue := LearnedBlue.new(_file(_always(0.9)))
	blue.retreat_on_strength = false
	blue.begin_turn(state)
	blue.decide_attack(state, 3)
	var later: BoardState = state.duplicate_state()
	later.turn_number = state.turn_number + TacticalScenario.FACTIONS
	blue.begin_turn(later)
	blue.policy = LearnedBlue.new(_file(_always(0.1))).policy

	assert_str(blue.decide_move(later, 1).reason).contains("retreats")


func test_a_retreat_names_the_bar_it_fell_under() -> void:
	var state: BoardState = _board([[BLUE, TacticalRules.SHIELD, Vector2i(3, 3)], [RED, TacticalRules.RUNNER, Vector2i(5, 3)]])
	var blue := LearnedBlue.new(_file(_always(0.1)))
	blue.retreat_on_strength = false

	assert_str(blue.decide_move(state, 1).reason).contains("below the commit bar 0.50")


func test_standing_its_ground_says_so_and_names_the_bar() -> void:
	var state: BoardState = _board([[BLUE, TacticalRules.SHIELD, Vector2i(3, 3)], [RED, TacticalRules.RUNNER, Vector2i(5, 3)]])

	var walk: TacticalDecision = LearnedBlue.new(_file(_always(0.1))).decide_move(state, 1)

	assert_str(walk.reason).contains("did not retreat")
	assert_str(walk.reason).contains("under its bar 0.50")


func test_a_walker_retreats_on_strength_only_when_red_s_far_outweighs_blue_s() -> void:
	# One shield against one runner: 0.25 x 10 is not more than 10, so it
	# does not run -- and four more runners six and seven cells off are
	# outside the radius and change nothing. Against five runners near it,
	# 0.25 x 50 is more than 10, and it does.
	var even: BoardState = _board([[BLUE, TacticalRules.SHIELD, Vector2i(3, 3)], [RED, TacticalRules.RUNNER, Vector2i(5, 3)],
		[RED, TacticalRules.RUNNER, Vector2i(9, 3)], [RED, TacticalRules.RUNNER, Vector2i(9, 4)],
		[RED, TacticalRules.RUNNER, Vector2i(9, 2)], [RED, TacticalRules.RUNNER, Vector2i(10, 3)]])
	var outweighed: BoardState = _board([[BLUE, TacticalRules.SHIELD, Vector2i(3, 3)], [RED, TacticalRules.RUNNER, Vector2i(5, 3)],
		[RED, TacticalRules.RUNNER, Vector2i(5, 4)], [RED, TacticalRules.RUNNER, Vector2i(5, 2)],
		[RED, TacticalRules.RUNNER, Vector2i(6, 3)], [RED, TacticalRules.RUNNER, Vector2i(6, 4)]])

	assert_str(LearnedBlue.new(_file(_always(0.1))).decide_move(even, 1).reason).not_contains("retreats to")
	assert_str(LearnedBlue.new(_file(_always(0.1))).decide_move(outweighed, 1).reason).contains("retreats to")


func test_a_new_game_forgets_who_was_committed() -> void:
	var state: BoardState = _board([[BLUE, TacticalRules.SHIELD, Vector2i(3, 3)], [RED, TacticalRules.RUNNER, Vector2i(5, 3)]])
	state.turn_number = 5
	var blue := LearnedBlue.new(_file(_always(0.6)))
	blue.begin_turn(state)
	blue.decide_move(state, 1)
	var again: BoardState = state.duplicate_state()
	again.turn_number = 1

	blue.begin_turn(again)

	assert_bool(blue._committed.is_empty()).is_true()


func test_the_learned_blue_walks_at_the_point_the_capture_model_ranks_first() -> void:
	# One model that says nearer is quicker, one that says the opposite: the
	# walk follows the model, not the distance.
	var state: BoardState = _board([[BLUE, TacticalRules.RUNNER, Vector2i(6, 4)], [RED, TacticalRules.RUNNER, Vector2i(0, 8)]])
	var nearer: Vector2i = TacticalScenario.POINTS[0]
	var further: Vector2i = TacticalScenario.POINTS[1]
	state.unit_by_id(1).cell = Vector2i(6, 2)

	var to_nearer: TacticalDecision = LearnedBlue.new(_file(_always(0.5), _by_distance(1.0))).decide_move(state, 1)
	var to_further: TacticalDecision = LearnedBlue.new(_file(_always(0.5), _by_distance(-1.0))).decide_move(state, 1)

	assert_str(to_nearer.reason).contains(str(nearer))
	assert_str(to_further.reason).contains(str(further))


func test_learned_against_rules_games_all_end_and_nothing_is_refused() -> void:
	for dice: int in range(3):
		var result: Dictionary = TacticalMatch.play(RuleBasedBlue.new(), LearnedBlue.new(), dice)
		assert_int(result["winner"]).is_not_equal(TacticalVictory.NOBODY)
		assert_array(result["refused"]).is_empty()


# --- helpers -------------------------------------------------------------------

func _first_of(state: BoardState, faction: int, type_name: String) -> Unit:
	for unit: Unit in state.units_of(faction):
		if unit.type.type_name == type_name:
			return unit
	return null


# A plain 14x9 board -- the scenario's size, so its points are on it -- with
# these `[side, type, cell]` pieces, ids from 1, `to_move` to move.
func _board(pieces: Array, to_move: int = BLUE) -> BoardState:
	var types: Dictionary = TacticalRules.unit_types()
	var units: Array[Unit] = []
	for piece: Array in pieces:
		var kind: UnitType = types[piece[1]]
		units.append(Unit.new(units.size() + 1, piece[0], piece[2], 10, kind.movement, kind))
	return BoardState.new(GridGraph.new(14, 9), units, to_move)


func _file(combat: Dictionary, capture: Dictionary = _by_distance(1.0)) -> ModelFile:
	return ModelFile.from_dictionary({"feature_conventions": CONVENTIONS,
		"models": {"combat": combat, "capture": capture}}, "the test")


# A combat model that answers `chance` whatever it is shown.
func _always(chance: float) -> Dictionary:
	return {"kind": "logistic", "features": COMBAT_FEATURES, "weights": [0.0, 0.0, 0.0, 0.0, 0.0],
		"bias": log(chance / (1.0 - chance))}


# A capture model that answers `per_cell` turns per cell to the point.
func _by_distance(per_cell: float) -> Dictionary:
	return {"kind": "linear", "features": CAPTURE_FEATURES, "weights": [per_cell, 0.0, 0.0, 0.0], "bias": 20.0}
