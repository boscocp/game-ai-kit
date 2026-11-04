# T84: the XCOM-style mode's rules one at a time, on the tactical map --
# the squads, the two-action turn, the shot, sight, cover, the side's view,
# the end -- and the seam: the tactical scene handed this ruleset plays it.
#
# The properties over 300 seeded positions are `squad_properties_test.gd`;
# the shot against the hand-checked vectors is `squad_vectors_test.gd`.
extends GdUnitTestSuite

const RED: int = TacticalScenario.RED
const BLUE: int = TacticalScenario.BLUE

var _rules := SquadRuleset.new()


# --- the squads --------------------------------------------------------------

func test_each_side_has_four_walkers_and_nothing_else() -> void:
	var state: BoardState = _rules.start()
	for side: int in [RED, BLUE]:
		var names: Array[String] = []
		for unit: Unit in state.units_of(side):
			names.append(unit.type.type_name)
			assert_bool(unit.type.mobile).is_true()
			assert_bool(state.graph_for(unit).is_blocked(unit.cell)).is_false()
		assert_array(names).contains_exactly(SquadTable.squad())
	assert_dict(state.funds).is_empty()


func test_the_squads_are_mirrored_through_the_centre() -> void:
	var state: BoardState = _rules.start()
	for unit: Unit in state.units_of(RED):
		var mirror: Unit = state.unit_at(SquadScenario.TURNED - unit.cell)
		assert_object(mirror).is_not_null()
		assert_int(mirror.faction).is_equal(BLUE)
		assert_str(mirror.type.type_name).is_equal(unit.type.type_name)


func test_a_pieces_movement_is_two_actions_and_the_wader_still_wades() -> void:
	var types: Dictionary = SquadTable.unit_types()
	for piece_name: String in SquadTable.squad():
		assert_int((types[piece_name] as UnitType).movement).is_equal(2 * SquadTable.action(piece_name))
	assert_str((types[TacticalRules.WADER] as UnitType).mover).is_equal(TacticalRules.WATER_MOVER)


# --- the two-action turn -----------------------------------------------------

func test_a_walk_within_one_action_leaves_the_piece_able_to_shoot() -> void:
	var state: BoardState = _rules.start()
	var runner: Unit = _first(state, RED, TacticalRules.RUNNER)
	var after: BoardState = _rules.walk(state, Move.new(runner.id, [runner.cell + Vector2i(0, 1)] as Array[Vector2i]))
	assert_bool(SquadCombat.can_shoot(after.unit_by_id(runner.id))).is_true()
	assert_int(after.unit_by_id(runner.id).movement_points).is_equal(runner.movement_points - 1)


func test_a_walk_past_one_action_is_a_dash_and_spends_the_piece() -> void:
	var state: BoardState = _rules.start()
	var shield: Unit = _first(state, RED, TacticalRules.SHIELD)
	var path: Array[Vector2i] = [Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5)]
	var after: BoardState = _rules.walk(state, Move.new(shield.id, path))
	assert_object(after).is_not_null()
	assert_int(after.unit_by_id(shield.id).movement_points).is_equal(0)


func test_two_walks_within_one_action_together_still_may_shoot() -> void:
	var state: BoardState = _rules.start()
	var runner: Unit = _first(state, RED, TacticalRules.RUNNER)
	state = _rules.walk(state, Move.new(runner.id, [Vector2i(2, 2)] as Array[Vector2i]))
	state = _rules.walk(state, Move.new(runner.id, [Vector2i(3, 2)] as Array[Vector2i]))
	assert_bool(SquadCombat.can_shoot(state.unit_by_id(runner.id))).is_true()


# --- the shot ------------------------------------------------------------------

func test_a_shot_spends_the_shooter_and_replays_from_the_seed() -> void:
	var state: BoardState = _facing(Vector2i(3, 4), Vector2i(7, 4))
	var strike := Attack.new(1, 2)
	assert_str(_rules.why_attack_refused(state, strike)).is_equal(BoardState.LEGAL)
	var once: BoardState = _rules.attack(state, strike)
	var again: BoardState = _rules.attack(state, strike)
	assert_int(once.unit_by_id(1).movement_points).is_equal(0)
	assert_int(once.unit_by_id(2).health).is_equal(again.unit_by_id(2).health)
	assert_int(once.dice_seed).is_not_equal(state.dice_seed)


func test_a_piece_that_dashed_may_not_shoot() -> void:
	var state: BoardState = _facing(Vector2i(3, 4), Vector2i(7, 4))
	state.unit_by_id(1).movement_points = SquadTable.action(TacticalRules.RUNNER) - 1
	assert_str(_rules.why_attack_refused(state, Attack.new(1, 2))).contains("dashed or shot")


func test_a_seen_target_out_of_range_is_refused() -> void:
	# Six steps along a clear row: the runner sees 6 and reaches 5.
	var state: BoardState = _facing(Vector2i(3, 4), Vector2i(9, 4))
	assert_str(_rules.why_attack_refused(state, Attack.new(1, 2))).contains("reaches")


func test_a_mortar_may_not_shoot_in_its_range_what_it_cannot_see() -> void:
	# Wave 113's review, planted: a mortar reaches 7 and sees 6, and the row
	# from (3, 4) to (10, 4) is clear. Without the sight rule this shot was
	# legal, listed by `actions`, at an enemy red's view did not hold.
	var state: BoardState = _facing(Vector2i(3, 4), Vector2i(10, 4), TacticalRules.MORTAR, TacticalRules.RUNNER)
	assert_array(_rules.view(state, RED).seen_enemies()).is_empty()
	var refusal: String = _rules.why_attack_refused(state, Attack.new(1, 2))
	assert_str(refusal).is_equal(SquadCombat.unseen(1, 2))
	assert_array(_rules.shots_of(state, state.unit_by_id(1))).is_empty()


func test_a_refusal_at_an_unseen_enemy_says_nothing_a_missing_one_would_not() -> void:
	var state: BoardState = _facing(Vector2i(3, 4), Vector2i(10, 4), TacticalRules.MORTAR, TacticalRules.RUNNER)
	assert_str(_rules.why_attack_refused(state, Attack.new(1, 2))).is_equal(
		_rules.why_attack_refused(state, Attack.new(1, 99)).replace("99", "2"))
	assert_str(_rules.why_attack_refused(state, Attack.new(1, 2))).not_contains("(10, 4)")


func test_trees_two_deep_block_the_shot() -> void:
	# (8, 5) and (8, 6) are trees on the tactical map; a line from (8, 4) to
	# (8, 8) crosses both, and only (8, 5) is beside an end.
	var state: BoardState = _facing(Vector2i(8, 4), Vector2i(8, 8))
	assert_str(_rules.why_attack_refused(state, Attack.new(1, 2))).is_equal(SquadCombat.unseen(1, 2))


func test_the_shot_is_told_with_its_chance_and_cover() -> void:
	var state: BoardState = _facing(Vector2i(5, 4), Vector2i(1, 4))
	var said: String = Sentence.english(_rules.told(state, Attack.new(1, 2), _rules.attack(state, Attack.new(1, 2))))
	assert_str(said).contains("cover 40")
	assert_str(said).contains("%d%%" % SquadCombat.chance_of(SquadScenario.rows(), state.unit_by_id(1), state.unit_by_id(2)))


func test_the_shot_s_news_is_kept_as_keys_and_worded_where_shown() -> void:
	# T110: the news is a `Sentence`, so the panel rewords it when the
	# language changes after the shot -- the side, the piece and the
	# outcome are values, each worded on its own.
	var state: BoardState = _facing(Vector2i(5, 4), Vector2i(1, 4))
	var told: Array = _rules.told(state, Attack.new(1, 2), _rules.attack(state, Attack.new(1, 2)))
	var locale_before: String = TranslationServer.get_locale()
	TranslationServer.set_locale("pt_BR")
	var in_portuguese: String = TacticalStatus.said(told)
	TranslationServer.set_locale(locale_before)
	assert_str(Sentence.english(told)).contains("red ").contains("cover 40")
	assert_str(in_portuguese).contains("40").not_contains("cover").not_contains("shot").not_contains("missed")


# --- cover on the tactical map ----------------------------------------------

func test_the_rock_beside_reds_shield_is_full_cover_from_the_river() -> void:
	var rows: Array[String] = SquadScenario.rows()
	assert_dict(SquadCover.of(rows, Vector2i(8, 4), Vector2i(1, 4))).is_equal({"cover": 40, "flanked": false})
	assert_dict(SquadCover.of(rows, Vector2i(1, 8), Vector2i(1, 4))).is_equal({"cover": 0, "flanked": true})


# --- sight -------------------------------------------------------------------

func test_sight_is_mutual_between_every_two_cells_of_the_map() -> void:
	var rows: Array[String] = SquadScenario.rows()
	var cells: Array[Vector2i] = []
	for index: int in range(rows.size() * rows[0].length()):
		cells.append(Vector2i(index % rows[0].length(), index / rows[0].length()))
	var one_way: Array[String] = []
	for one: Vector2i in cells:
		one_way.append_array(_seen_one_way(rows, one, cells))
	assert_array(one_way).is_empty()


func test_cover_beside_either_end_does_not_block_the_line() -> void:
	var rows: Array[String] = ["......", ".T..T.", "......"]
	assert_bool(SquadSight.line_clear(rows, Vector2i(0, 1), Vector2i(5, 1))).is_true()
	assert_bool(SquadSight.line_clear(["......", "..TT..", "......"] as Array[String], Vector2i(0, 1), Vector2i(5, 1))).is_false()


# --- the side's view ---------------------------------------------------------

func test_at_the_start_no_side_sees_the_other() -> void:
	var state: BoardState = _rules.start()
	for side: int in [RED, BLUE]:
		var view: SideView = _rules.view(state, side)
		assert_array(view.seen_enemies()).is_empty()
		assert_int(view.state.units.size()).is_equal(SquadTable.squad().size())
		assert_int(view.state.dice_seed).is_equal(0)


func test_an_enemy_walked_out_of_sight_is_remembered_where_it_was_seen() -> void:
	var state: BoardState = _facing(Vector2i(3, 4), Vector2i(7, 4))
	state.dice_seed = 1234
	var seen: SideView = _rules.view(state, RED)
	assert_array(seen.seen_enemies()).contains_exactly([2])
	state.unit_by_id(2).cell = Vector2i(13, 8)
	var later: SideView = _rules.view(state, RED, seen)
	assert_array(later.seen_enemies()).is_empty()
	assert_int(later.last_seen.size()).is_equal(1)
	assert_vector(later.last_seen[2]).is_equal(Vector2i(7, 4))


# --- the end -----------------------------------------------------------------

func test_a_squad_with_no_piece_left_has_lost() -> void:
	var state: BoardState = _facing(Vector2i(3, 4), Vector2i(7, 4))
	assert_int(_rules.winner(state)).is_equal(TacticalVictory.NOBODY)
	state.unit_by_id(2).health = 0
	assert_int(_rules.winner(state.duplicate_state())).is_equal(RED)


func test_at_the_round_limit_more_health_wins() -> void:
	var state: BoardState = _facing(Vector2i(3, 4), Vector2i(7, 4))
	state.turn_number = SquadVictory.round_limit() * TacticalScenario.FACTIONS
	assert_int(_rules.winner(state)).is_equal(BLUE)  # the shield's 10 to the runner's 8
	state.unit_by_id(2).health = state.unit_by_id(1).health
	assert_int(_rules.winner(state)).is_equal(TacticalVictory.DRAW)


# --- the seam ------------------------------------------------------------------

func test_the_roster_is_its_own_and_builds_what_it_names() -> void:
	assert_array(_rules.roster_names()).contains_exactly(["weighed", "random"])
	assert_str(_rules.build_controller("random", 7).controller_name()).is_equal("random")
	assert_str(_rules.build_controller("weighed", 7).controller_name()).is_equal("weighed")
	assert_str(_rules.controller_after("weighed")).is_equal("random")
	assert_str(_rules.controller_after("random")).is_equal("weighed")


func test_the_tactical_scene_handed_this_ruleset_plays_it() -> void:
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	scene.ruleset = _rules
	scene.computer = RandomSquad.new(3)
	scene.recording = true
	add_child(scene)
	assert_bool(scene._records()).is_false()
	assert_int(scene.state.units.size()).is_equal(2 * SquadTable.squad().size())
	assert_dict(scene.threat()).is_empty()
	assert_str(scene._header.text).contains(SquadVictory.rule())


func test_the_status_offers_the_targets_this_mode_allows() -> void:
	var seen: BoardState = _facing(Vector2i(3, 4), Vector2i(7, 4))
	assert_str(TacticalStatus.text(seen, seen.unit_by_id(1), "", "", true, _rules)).contains("click an enemy")
	var unseen: BoardState = _facing(Vector2i(3, 4), Vector2i(10, 4), TacticalRules.MORTAR, TacticalRules.RUNNER)
	assert_str(TacticalStatus.text(unseen, unseen.unit_by_id(1), "", "", true, _rules)).not_contains("click an enemy")


# "a to b" for each of `cells` that `one` sees and is not seen by, or the
# other way round.
func _seen_one_way(rows: Array[String], one: Vector2i, cells: Array[Vector2i]) -> Array[String]:
	var found: Array[String] = []
	for other: Vector2i in cells:
		if SquadSight.line_clear(rows, one, other) != SquadSight.line_clear(rows, other, one):
			found.append("%s to %s" % [one, other])
	return found


# A red piece (a runner unless named) on `red_cell` facing a blue one (a
# shield) on `blue_cell`, nobody else, red to move: the smallest board a
# shot can be asked about.
func _facing(red_cell: Vector2i, blue_cell: Vector2i, red_piece: String = TacticalRules.RUNNER,
		blue_piece: String = TacticalRules.SHIELD) -> BoardState:
	var types: Dictionary = SquadTable.unit_types()
	var runner: UnitType = types[red_piece]
	var shield: UnitType = types[blue_piece]
	var units: Array[Unit] = [
		Unit.new(1, RED, red_cell, SquadTable.number(runner.type_name, "health"), runner.movement, runner),
		Unit.new(2, BLUE, blue_cell, SquadTable.number(shield.type_name, "health"), shield.movement, shield),
	]
	var start: BoardState = _rules.start()
	var state := BoardState.new(start.graph, units, RED)
	state.movement_graphs = start.movement_graphs
	return state


func _first(state: BoardState, side: int, piece_name: String) -> Unit:
	for unit: Unit in state.units_of(side):
		if unit.type.type_name == piece_name:
			return unit
	return null
