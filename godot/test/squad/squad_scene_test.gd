# T85: the XCOM-style mode played in the tactical scene -- opened in both
# modes as the menu opens it, M between them, the fog, the dash, the hit
# chance before a shot with its reasons, T's chance under the cursor, and
# the enemy's weighing drawn before it acts (V hides it).
extends GdUnitTestSuite

const RED: int = TacticalScenario.RED
const BLUE: int = TacticalScenario.BLUE

var _rules := SquadRuleset.new()


func test_opened_in_both_modes_it_starts_in_the_one_chosen_and_m_moves_between_them() -> void:
	var scene: TacticalGame = _opened(1)
	assert_str(scene.ruleset.mode_name()).is_equal("squad")
	assert_str(scene.computer.controller_name()).is_equal("weighed")
	assert_str(scene._header.text).contains("M plays Advance Wars")
	scene._press(KEY_M)
	assert_str(scene.ruleset.mode_name()).is_equal(AdvanceWarsRuleset.MODE)
	assert_str(scene.computer.controller_name()).is_equal(TacticalRoster.names()[0])
	assert_bool(scene.state.units.size() == 2 * SquadTable.squad().size()).is_false()
	scene._press(KEY_M)
	assert_str(scene.ruleset.mode_name()).is_equal("squad")
	assert_str(scene.computer.controller_name()).is_equal("weighed")


func test_c_cycles_this_modes_roster() -> void:
	var scene: TacticalGame = _opened(1)
	scene._press(KEY_C)
	assert_str(scene.computer.controller_name()).is_equal("random")
	scene._press(KEY_C)
	assert_str(scene.computer.controller_name()).is_equal("weighed")


func test_the_board_shows_only_what_the_persons_side_sees() -> void:
	var scene: TacticalGame = _opened(1)
	var seen: BoardState = _rules.view(scene.state, RED).state
	assert_int(scene._units._state.units.size()).is_equal(seen.units.size())
	assert_int(seen.units.size()).is_less(scene.state.units.size())  # blue starts out of sight
	assert_object(scene._intent._fog).is_not_null()
	assert_bool(scene._intent._fog.hidden.is_empty()).is_false()


func test_the_piece_in_hand_shows_its_dash_and_its_shots_with_their_reasons() -> void:
	var scene: TacticalGame = _opened(1)
	assert_bool(scene._intent._dashes.is_empty()).is_false()
	scene.state = _facing()
	scene._selected_id = 1
	scene._refresh()
	assert_dict(scene._intent._odds).contains_keys([Vector2i(7, 4)])
	var chance: int = SquadCombat.chance_of(SquadScenario.rows(), scene.state.unit_by_id(1), scene.state.unit_by_id(2))
	assert_str(scene._intent._odds[Vector2i(7, 4)]).is_equal("%d%%" % chance)
	assert_str(scene._status.text).contains("%d%% = aim" % chance)


func test_t_shows_each_seen_enemys_chance_against_the_cell_under_the_cursor() -> void:
	var state: BoardState = _facing()
	var chances: Dictionary[Vector2i, int] = _rules.tint_at(state, BLUE, Vector2i(4, 4), RED, 1)
	var shield: Unit = state.unit_by_id(2)
	var expected: int = SquadCombat.hit_chance(SquadTable.number(shield.type.type_name, "aim"),
		SquadTable.number(TacticalRules.RUNNER, "defence"), SquadCover.of(SquadScenario.rows(), shield.cell, Vector2i(4, 4))["cover"])
	assert_dict(chances).is_equal({Vector2i(7, 4): expected})
	assert_dict(_rules.tint_at(state, BLUE, Vector2i(13, 0), RED, 1)).is_empty()


func test_the_enemys_weighing_is_drawn_before_it_acts_and_v_hides_it() -> void:
	var scene: TacticalGame = _opened(1)
	scene._press(KEY_S)  # the computer plays red, and moves first
	assert_bool(scene._computer_thinking()).is_true()
	var overlay: Dictionary = scene.decision_overlay()
	assert_bool(overlay.has("weighed")).is_true()
	assert_bool(scene._intent._weighed.is_empty()).is_false()
	assert_object(scene._intent._fog).is_same(scene._computer_fog)
	scene._press(KEY_V)
	assert_bool(scene._intent._weighed.is_empty()).is_true()
	assert_object(scene._intent._fog).is_same(scene._person_fog)


func test_a_walk_that_shows_an_enemy_cannot_be_taken_back() -> void:
	var hidden: BoardState = _board([[RED, TacticalRules.RUNNER, Vector2i(1, 4)], [BLUE, TacticalRules.SHIELD, Vector2i(8, 4)]])
	var walked: BoardState = _rules.walk(hidden, Move.new(1, [Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5)] as Array[Vector2i]))
	assert_bool(_rules.reveals(hidden, hidden, RED)).is_false()
	assert_bool(_rules.reveals(hidden, walked, RED)).is_true()


func test_no_game_of_this_mode_is_recorded() -> void:
	var scene: TacticalGame = _opened(1)
	scene.recording = true
	assert_bool(scene._records()).is_false()


# The tactical scene opened as the menu opens it: both modes, the one at
# `chosen` first.
func _opened(chosen: int) -> TacticalGame:
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	scene.play_in_modes([AdvanceWarsRuleset.new(), SquadRuleset.new()], chosen)
	add_child(scene)
	return scene


# A red runner on (3, 4) facing a blue shield on (7, 4) across open ground,
# red to move.
func _facing() -> BoardState:
	return _board([[RED, TacticalRules.RUNNER, Vector2i(3, 4)], [BLUE, TacticalRules.SHIELD, Vector2i(7, 4)]])


# A board with only `pieces` -- `[side, piece, cell]` each, ids from 1 in
# order, at full health -- red to move.
func _board(pieces: Array) -> BoardState:
	var types: Dictionary = SquadTable.unit_types()
	var units: Array[Unit] = []
	for piece: Array in pieces:
		var kind: UnitType = types[piece[1]]
		units.append(Unit.new(units.size() + 1, piece[0], piece[2], SquadTable.number(kind.type_name, "health"), kind.movement, kind))
	var start: BoardState = _rules.start()
	var state := BoardState.new(start.graph, units, RED)
	state.movement_graphs = start.movement_graphs
	return state
