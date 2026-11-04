# T85: the XCOM-style mode played in the tactical scene -- opened in both
# modes as the menu opens it, M between them, the fog, the dash, the hit
# chance before a shot with its reasons, T's chance under the cursor, and
# the enemy's weighing drawn before it acts (V hides it).
extends GdUnitTestSuite

const RED: int = TacticalScenario.RED
const BLUE: int = TacticalScenario.BLUE

var _rules := SquadRuleset.new()
var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()


func after() -> void:
	TranslationServer.set_locale(_locale_before)


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


# Wave 119's review, blocker 1: a walk refused because of a piece the
# person cannot see named its cell and its id. The refusal now names
# nothing of it.
func test_a_walk_into_a_hidden_piece_is_refused_in_words_that_name_nothing() -> void:
	var scene: TacticalGame = _opened(1)
	scene.state = _board([[RED, TacticalRules.RUNNER, Vector2i(0, 0)], [BLUE, TacticalRules.SHIELD, Vector2i(2, 2)]])
	scene._selected_id = 1
	scene._person_fog = null
	scene._refresh()
	assert_bool(scene._persons_board().unit_by_id(2) == null).is_true()  # red does not see it
	scene.click_cell(Vector2i(2, 2))
	assert_object(scene.state.unit_by_id(1).cell).is_equal(Vector2i(0, 0))
	assert_str(scene._status.text).contains(SquadStatus.words(SquadRuleset.blocked(1)))
	for hidden: String in ["(2, 2)", "unit 2", "occupied", "shield"]:
		assert_str(scene._status.text).not_contains(hidden)


# Wave 119's review, blocker 2: with nothing in hand the status was blank
# (a typed ternary failed). Read it with nothing in hand, after a shot, and
# after Z.
func test_the_status_says_something_with_nothing_in_hand_after_a_shot_and_after_z() -> void:
	var scene: TacticalGame = _opened(1)
	scene.state = _facing()
	scene._selected_id = -1
	scene._refresh()
	assert_str(scene._status.text).is_not_empty()
	scene._selected_id = 1
	scene.attack(scene.state.unit_by_id(2))
	assert_str(scene._status.text).is_not_empty()
	scene._press(KEY_Z)
	assert_str(scene._status.text).is_not_empty()
	scene.state = _board([[RED, TacticalRules.RUNNER, Vector2i(1, 4)], [BLUE, TacticalRules.SHIELD, Vector2i(8, 4)]])
	scene._selected_id = 1
	scene.click_cell(Vector2i(3, 5))
	scene._press(KEY_Z)
	assert_str(scene._status.text).is_not_empty()


func test_z_after_a_walk_that_showed_an_enemy_says_why_it_cannot() -> void:
	var scene: TacticalGame = _opened(1)
	scene.state = _board([[RED, TacticalRules.RUNNER, Vector2i(1, 4)], [BLUE, TacticalRules.SHIELD, Vector2i(8, 4)]])
	scene._person_fog = null
	scene._selected_id = 1
	scene._refresh()
	scene.click_cell(Vector2i(3, 5))
	assert_object(scene.state.unit_by_id(1).cell).is_equal(Vector2i(3, 5))
	scene._press(KEY_Z)
	assert_object(scene.state.unit_by_id(1).cell).is_equal(Vector2i(3, 5))
	assert_str(scene._status.text).contains("a walk that showed an enemy cannot be taken back")


func test_a_piece_that_dashed_is_not_told_it_can_still_shoot() -> void:
	var scene: TacticalGame = _opened(1)
	scene.state = _board([[RED, TacticalRules.RUNNER, Vector2i(1, 4)], [BLUE, TacticalRules.SHIELD, Vector2i(12, 8)]])
	scene._person_fog = null
	scene._selected_id = 1
	scene._refresh()
	var runner: Unit = scene.state.unit_by_id(1)
	var walks: Dictionary = TacticalReach.walks_for(scene._persons_board(), runner)
	var dash: Array[Vector2i] = _rules.dashes(scene._persons_board(), runner, walks)
	assert_bool(dash.is_empty()).is_false()
	scene.click_cell(dash[0])
	scene.click_cell(dash[0])
	assert_str(scene._last_refusal).contains("has moved this turn")
	assert_str(scene._last_refusal).not_contains("can still")


# Wave 119's review, should-fix 3: with V off the computer's turn told the
# person about a piece they could not see.
func test_with_v_off_an_unseen_piece_acts_unseen() -> void:
	var scene: TacticalGame = _opened(1)
	scene.state = _board([[RED, TacticalRules.RUNNER, Vector2i(0, 0)], [BLUE, TacticalRules.SHIELD, Vector2i(12, 8)]])
	scene._person_fog = null
	scene._refresh()
	scene.end_turn()
	scene.end_turn()
	assert_bool(scene._computer_thinking()).is_true()
	scene._press(KEY_V)
	assert_str(scene._status.text).contains("a piece you cannot see acts")
	assert_str(scene._status.text).not_contains("unit 2")
	assert_object(scene._intent._decision).is_null()


func test_a_walk_into_the_fog_is_drawn_only_as_far_as_it_is_seen() -> void:
	var state: BoardState = _board([[RED, TacticalRules.RUNNER, Vector2i(0, 0)], [BLUE, TacticalRules.SHIELD, Vector2i(5, 0)]])
	var fog: TacticalFog = _rules.fog(state, RED, null)
	var path: Array[Vector2i] = [Vector2i(5, 1), Vector2i(5, 2), Vector2i(5, 3), Vector2i(5, 4)]
	var walk := TacticalDecision.walk(2, path, [], Vector2i(5, 4))
	assert_bool(path.any(fog.hides)).is_true()
	var drawn: TacticalDecision = TacticalFog.clipped(fog, walk)
	var drawn_path: Array[Vector2i] = []
	if drawn != null:
		drawn_path = drawn.move.path
	assert_int(drawn_path.size()).is_less(path.size())
	for cell: Vector2i in drawn_path:
		assert_bool(fog.hides(cell)).is_false()


func test_no_game_of_this_mode_is_recorded() -> void:
	var scene: TacticalGame = _opened(1)
	scene.recording = true
	assert_bool(scene._records()).is_false()


# T110: a shot's news on the panel follows a language switched after it,
# both ways -- the XCOM mode's line reaches the same news as the board's.
func test_a_shot_s_news_follows_a_language_switched_after_it() -> void:
	for locale: String in ["pt_BR", "en"]:
		TranslationServer.set_locale(locale)
		var scene: TacticalGame = _on_board(_facing())
		scene.click_cell(Vector2i(7, 4))
		_assert_the_news_follows_the_language(scene, locale, "red runner at (3, 4) shot blue shield at (7, 4)")


# T110: the line a revealing walk leaves follows a switch too.
func test_a_reveal_s_news_follows_a_language_switched_after_it() -> void:
	for locale: String in ["pt_BR", "en"]:
		TranslationServer.set_locale(locale)
		var scene: TacticalGame = _on_board(_board([[RED, TacticalRules.RUNNER, Vector2i(1, 4)], [BLUE, TacticalRules.SHIELD, Vector2i(8, 4)]]))
		scene.click_cell(Vector2i(3, 5))
		_assert_the_news_follows_the_language(scene, locale, "an enemy came into sight")


# The XCOM scene on `state`, piece 1 in hand and the fog drawn afresh.
func _on_board(state: BoardState) -> TacticalGame:
	var scene: TacticalGame = _opened(1)
	scene.state = state
	scene._selected_id = 1
	scene._person_fog = null
	scene._refresh()
	return scene


# As `tactical_news_test.gd` holds it: the news is English underneath, and
# the panel shows it in the language switched to, and none of the other.
func _assert_the_news_follows_the_language(scene: TacticalGame, locale: String, english_words: String) -> void:
	var english: String = scene.news_in_english()
	assert_str(english).override_failure_message("in %s the news is \"%s\"" % [locale, english]).contains(english_words)
	TranslationServer.set_locale("pt_BR")
	var portuguese: String = "\n".join(scene._last_event.map(TacticalStatus.said))
	assert_str(portuguese).is_not_equal(english)
	for shown: String in ["en" if locale == "pt_BR" else "pt_BR", locale]:
		TranslationServer.set_locale(shown)
		var expected: String = english if shown == "en" else portuguese
		var stale: String = portuguese if shown == "en" else english
		assert_str(scene._status.text).override_failure_message("%s -> %s:\n%s" % [locale, shown, scene._status.text]).contains(expected).not_contains(stale)


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
