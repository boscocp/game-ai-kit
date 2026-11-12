# T127: an unseen shooter stays unseen in the news.
#
# In the XCOM-style mode a blue mortar (sight 6, reach 7) can shoot a red
# shield (sight 5) that cannot see it back. The news named the mortar and
# its cell -- "blue mortar at (7, 4) shot red shield at (1, 4): 10% (cover
# 40), missed" -- though red had no way to know either (wave 124's review,
# "For the owner", item 1). The owner chose, on 2026-11-11, to word the news
# from the person's fog: a shooter the person cannot see is "a piece you
# cannot see", with no kind and no cell. The rules and the line the game
# keeps stay whole; only the words on the person's screen change.
extends GdUnitTestSuite

const RED: int = TacticalScenario.RED
const BLUE: int = TacticalScenario.BLUE
const SHIELD_CELL := Vector2i(1, 4)
const MORTAR_CELL := Vector2i(7, 4)
const LOCALES: Array[String] = ["pt_BR", "en"]

var _rules := SquadRuleset.new()
var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func test_the_board_is_the_review_s_red_cannot_see_the_mortar_that_can_shoot_it() -> void:
	var state: BoardState = _facing(BLUE)
	var rows: Array[String] = SquadScenario.rows()
	assert_bool(SideView.is_seen(state, rows, RED, MORTAR_CELL)).is_false()
	assert_str(_rules.why_attack_refused(state, Attack.new(2, 1))).is_equal(BoardState.LEGAL)


func test_red_s_news_of_the_shot_names_no_piece_it_cannot_see() -> void:
	for locale: String in LOCALES:
		var scene: TacticalGame = _shot_by_the_unseen_mortar(locale)
		scene.play_rest_of_computer_turn()
		assert_bool(scene._persons_turn()).is_true()
		for shown: String in LOCALES:
			TranslationServer.set_locale(shown)
			scene._refresh()
			_assert_names_no_unseen_piece(scene, "%s -> %s, red's turn" % [locale, shown])


func test_while_blue_plays_on_red_s_view_the_shot_is_unseen_too() -> void:
	# V off, as play opens it (T124): the person's own view of the computer's
	# turn (T85).
	for locale: String in LOCALES:
		var scene: TacticalGame = _shot_by_the_unseen_mortar(locale)
		_assert_names_no_unseen_piece(scene, "%s, blue's turn, V off" % locale)


func test_on_blue_s_own_view_and_in_the_kept_line_the_shot_is_whole() -> void:
	# V on: the computer's own view, which sees its mortar. And the line the
	# game keeps -- the rules' `told` -- is not the screen's, and stays whole.
	var scene: TacticalGame = _shot_by_the_unseen_mortar("en", true)
	assert_str(scene._status.text).contains("blue mortar at %s shot" % MORTAR_CELL)
	assert_str(scene.news_in_english()).contains("blue mortar at %s shot red shield at %s" % [MORTAR_CELL, SHIELD_CELL])
	scene.play_rest_of_computer_turn()
	assert_str(scene.news_in_english()).contains("blue mortar at %s shot red shield at %s" % [MORTAR_CELL, SHIELD_CELL])


func test_a_shot_by_a_seen_piece_is_worded_whole() -> void:
	# A red shield near enough to see the mortar: nothing to hide.
	var state: BoardState = _facing(BLUE, Vector2i(3, 4))
	var strike := Attack.new(2, 1)
	var told: Array = _rules.told(state, strike, _rules.attack(state, strike))
	var fog: TacticalFog = _rules.mode_view().fog(state, RED, null)
	TranslationServer.set_locale("en")
	assert_str(_rules.mode_view().news_said(told, fog)).contains("blue mortar at %s shot" % MORTAR_CELL)


func test_every_key_a_shot_is_told_by_hides_an_unseen_shooter() -> void:
	# Wave 190's review: with the flanked key left out of `as_seen`, every
	# squad test stayed green. So each key `told` may return -- flanked or
	# not, and any added later to `SHOT_KEYS` -- is run through it here,
	# with the review's shot's values, in both languages.
	var state: BoardState = _facing(BLUE)
	var strike := Attack.new(2, 1)
	var told: Array = _rules.told(state, strike, _rules.attack(state, strike))
	assert_array(SquadCombat.SHOT_KEYS).contains([told[0]])
	var fog: TacticalFog = _rules.mode_view().fog(state, RED, null)
	for key: String in SquadCombat.SHOT_KEYS:
		var line: Array = Sentence.of(key, told[1])
		assert_str(SquadStatus.as_seen(line, fog)[0]).override_failure_message("not hidden: %s" % key).is_equal(SquadStatus.UNSEEN_SHOT)
		for locale: String in LOCALES:
			TranslationServer.set_locale(locale)
			var said: String = _rules.mode_view().news_said(line, fog)
			assert_str(said).override_failure_message("%s: %s" % [locale, said]).not_contains(str(MORTAR_CELL)).not_contains(TranslationServer.translate(TacticalRules.MORTAR))
			_assert_no_chance_nor_cover(said, "%s, %s" % [locale, key])


# The status on screen says a piece the person cannot see shot, and neither
# the mortar's kind nor its cell -- in the language on screen.
func _assert_names_no_unseen_piece(scene: TacticalGame, where: String) -> void:
	var status: String = scene._status.text
	var unseen: String = TranslationServer.translate("a piece you cannot see shot {target_side} {target} at {target_cell}: {outcome}")
	var opening: String = unseen.substr(0, unseen.find("{"))
	var mortar: String = TranslationServer.translate(TacticalRules.MORTAR)
	assert_str(status).override_failure_message("%s: the shot is not told\n%s" % [where, status]).contains(opening)
	assert_str(status).override_failure_message("%s: the unseen mortar is named\n%s" % [where, status]).not_contains(mortar)
	assert_str(status).override_failure_message("%s: the unseen mortar's cell is told\n%s" % [where, status]).not_contains(str(MORTAR_CELL))
	for line: String in status.split("\n"):
		if line.contains(opening):
			_assert_no_chance_nor_cover(line, where)


# A mortar's 10% is its aim, and the cover says which side it faces: an
# unseen shot's line gives neither, in either language (wave 190's review).
func _assert_no_chance_nor_cover(line: String, where: String) -> void:
	for giveaway: String in ["%", "cover", "cobertura"]:
		assert_str(line).override_failure_message("%s: the unseen shot says \"%s\"\n%s" % [where, giveaway, line]).not_contains(giveaway)


# The review's board, mounted: blue's turn, and blue's first decision -- the
# mortar's shot at the shield -- played on screen in `locale`. A blue runner
# far off in the corner is still to act after it, so the computer is still
# thinking and V still chooses whose fog is on screen: with blue's turn
# over, the scene shows the person's. Opened in play, V off, unless
# `teaching` opens it in the teaching view, V on (T124).
func _shot_by_the_unseen_mortar(locale: String, teaching: bool = false) -> TacticalGame:
	TranslationServer.set_locale(locale)
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	scene.teaching = teaching
	scene.play_in_modes([AdvanceWarsRuleset.new(), SquadRuleset.new()], 1)
	add_child(scene)
	scene.state = _facing(RED)
	var runner: UnitType = SquadTable.unit_types()[TacticalRules.RUNNER]
	scene.state.units.append(Unit.new(3, BLUE, Vector2i(12, 8), SquadTable.number(runner.type_name, "health"), runner.movement, runner))
	scene._person_fog = null
	scene._computer_fog = null
	scene._refresh()
	scene.end_turn()
	scene.end_turn()
	assert_bool(scene._computer_thinking()).is_true()
	_play_the_shot(scene)
	assert_bool(scene._computer_thinking()).override_failure_message("blue's turn ended with the shot").is_true()
	return scene


# The mortar's shot at the shield played on screen as blue's next decision.
# Handed to the turn rather than left to the controller, which walks the
# mortar first and so would not test the review's board: what this checks
# is how the shot is told, not whether blue chooses it.
func _play_the_shot(scene: TacticalGame) -> void:
	var shield: Unit = scene.state.unit_by_id(1)
	scene._computer_turn.next = TacticalDecision.strike(2, shield, Sentence.of("the test's shot"))
	scene.step_decision()
	var played: Array[TacticalDecision] = scene._computer_turn.played
	assert_bool(not played.is_empty() and played[0].attack != null).override_failure_message("the shot was refused").is_true()


# A red shield on `shield_cell` and a blue mortar on (7, 4), nobody else,
# `to_move` to move: wave 124's review's board.
func _facing(to_move: int, shield_cell: Vector2i = SHIELD_CELL) -> BoardState:
	var types: Dictionary = SquadTable.unit_types()
	var shield: UnitType = types[TacticalRules.SHIELD]
	var mortar: UnitType = types[TacticalRules.MORTAR]
	var units: Array[Unit] = [
		Unit.new(1, RED, shield_cell, SquadTable.number(shield.type_name, "health"), shield.movement, shield),
		Unit.new(2, BLUE, MORTAR_CELL, SquadTable.number(mortar.type_name, "health"), mortar.movement, mortar),
	]
	var start: BoardState = _rules.start()
	var state := BoardState.new(start.graph, units, to_move)
	state.movement_graphs = start.movement_graphs
	return state
