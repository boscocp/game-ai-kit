# T102: the tactical match's header and status fit the window, in English
# and in pt-BR, whichever controller plays the computer's side.
#
# T80's width check found the header one line 2,000 px wide, and its review
# found the status's words ending at y=719 of 720 in pt-BR. The header now
# wraps above the board; these tests hold where the words end, measured as
# the screen lays them out: a wrapped Label's minimum height is the height of
# its wrapped words.
#
# `test-locale-screen` measures every example once, in one state, and wave
# 100's first version of this measured only the opening screen: its review
# played whole games and found the status 75 px past the window by round 3.
# So the status is measured over a seeded game under every controller, at
# every decision of the computer's and with each of the person's units in
# hand. The line naming the controllers C cycles through has a line of its
# own under the board, `Interface/Keys`.
extends GdUnitTestSuite

const LOCALES: Array[String] = ["en", "pt_BR"]
## Space kept between the header's last line and the board's top edge.
const HEADER_GAP: float = 8.0
## Rounds of a seeded game played under each controller: the planner's
## longest status came in round 3 (wave 100's review), the attacks' news once
## the two sides meet.
const ROUNDS: int = 10
## A bound on one computer turn's decisions, so a turn that never ends fails
## here rather than hanging the suite.
const STEPS_A_TURN: int = 200

var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func test_the_header_wraps_above_the_board_under_every_controller() -> void:
	for locale: String in LOCALES:
		var scene: TacticalGame = _mounted_scene(locale)
		for row_name: String in TacticalRoster.names():
			_assert_header_fits(scene, "%s, %s" % [locale, row_name])
			scene.swap_controller()


func test_the_status_keeps_a_margin_over_a_played_game_under_every_controller() -> void:
	for locale: String in LOCALES:
		var scene: TacticalGame = _mounted_scene(locale)
		for row_name: String in TacticalRoster.names():
			_assert_status_fits_over_two_games(scene, "%s, %s" % [locale, row_name], row_name)


# The keys line under the board names every controller C cycles through: a
# row added to the roster makes it longer, and it must still end above the
# gutter, below the buttons.
func test_the_keys_line_sits_between_the_buttons_and_the_window_s_bottom() -> void:
	for locale: String in LOCALES:
		var scene: TacticalGame = _mounted_scene(locale)
		var keys: Label = scene.get_node("Interface/Keys")
		var buttons_end: float = (scene.get_node("Interface/EndTurn") as Control).get_global_rect().end.y
		assert_str(keys.text).is_equal(TacticalGame.controllers_to_come())
		assert_float(keys.get_global_rect().position.y).is_greater(buttons_end)
		assert_float(_bottom_of(keys)).override_failure_message("%s: the keys line ends at y=%.0f\n%s" % [
			locale, _bottom_of(keys), keys.text]).is_less_equal(_status_limit())


# The header ends inside the window's width, and its last wrapped line
# HEADER_GAP above the board. It shares the top of the window with the
# status, which runs the whole left column, so it must start right of it.
func _assert_header_fits(scene: TacticalGame, what: String) -> void:
	var header: Label = scene.get_node("Interface/Header")
	var words: String = header.atr(header.text)
	var status: Rect2 = (scene.get_node("Interface/Status") as Control).get_global_rect()
	assert_float(header.get_global_rect().position.x).override_failure_message(
		"%s: the header starts at x=%.0f, over the status column ending at %.0f" % [
			what, header.get_global_rect().position.x, status.end.x]).is_greater_equal(status.end.x)
	assert_float(_right_of(header)).override_failure_message(
		"%s: the header ends at x=%.0f\n%s" % [what, _right_of(header), words]).is_less_equal(_window().x)
	assert_float(_bottom_of(header)).override_failure_message(
		"%s: the header's words end at y=%.0f, the board starts at %.0f\n%s" % [
			what, _bottom_of(header), scene.position.y, words]).is_less_equal(scene.position.y - HEADER_GAP)


# The status's words end the gutter above the window's bottom: the margin
# `BoardLayout` gives the panel. Its own rectangle ends there, and a Label
# whose words are taller grows past it.
func _status_limit() -> float:
	return _window().y - BoardLayout.GUTTER


# One game waiting and one striking under the controller `row_name`, seeded
# -- unlike C's swap -- so a level's noise, and the game, is the same every
# run. Prints the lowest the words went in each, for the review's record.
func _assert_status_fits_over_two_games(scene: TacticalGame, what: String, row_name: String) -> void:
	for strikes: bool in [false, true]:
		scene.computer = TacticalRoster.build(row_name, 0)
		scene.new_game()
		var worst: Dictionary = _worst_status_over_a_game(scene, strikes)
		var said: String = "%s, %s, %s" % [what, "striking" if strikes else "waiting", worst["when"]]
		print("worst status: %s: y=%.0f" % [said, worst["bottom"]])
		assert_float(worst["bottom"]).override_failure_message("%s: the status's words end at y=%.0f, past %.0f\n%s" % [
			said, worst["bottom"], _status_limit(), worst["words"]]).is_less_equal(_status_limit())


# Play ROUNDS rounds of the scenario's seeded game, a turn of each side a
# round, and return where the status's words ended lowest, when, and what
# they said. The person never walks, so the computer walks in and fights;
# two games, one waiting and one striking, reach different boards.
func _worst_status_over_a_game(scene: TacticalGame, strikes: bool) -> Dictionary:
	var worst: Dictionary = {"bottom": 0.0, "when": "", "words": ""}
	for round_number: int in range(1, ROUNDS + 1):
		_play_the_persons_turn(scene, worst, "round %d, the person's turn" % round_number, strikes)
		_play_the_computers_turn(scene, worst, "round %d, the computer's turn" % round_number)
		if scene.winner != TacticalVictory.NOBODY:
			_keep_lower(worst, scene, "round %d, the game is over" % round_number)
			break
	return worst


# Pick up each of the person's units in turn -- the status describes the one
# in hand, under the news of the computer's attacks -- and, when `strikes`,
# send it at the nearest enemy; then end the turn.
func _play_the_persons_turn(scene: TacticalGame, worst: Dictionary, when: String, strikes: bool) -> void:
	_keep_lower(worst, scene, when + " opens")
	for unit_id: int in scene._turn.unspent(scene.state):
		scene.click_cell(scene.state.unit_by_id(unit_id).cell)
		_keep_lower(worst, scene, when + ", a unit in hand")
		if strikes:
			_strike_the_nearest_enemy(scene, unit_id)
			_keep_lower(worst, scene, when + ", a strike or its refusal")
	scene.step_decision()


# Play the computer's turn a decision at a time, as space does, measuring
# the status before each.
func _play_the_computers_turn(scene: TacticalGame, worst: Dictionary, when: String) -> void:
	var steps: int = 0
	while not scene._persons_turn() and scene.winner == TacticalVictory.NOBODY and steps < STEPS_A_TURN:
		_keep_lower(worst, scene, when)
		scene.step_decision()
		steps += 1


# The unit in hand goes for the enemy piece nearest it: a fight told in the
# status when it is in reach, a refusal when it is not -- both longer than a
# quiet turn's words.
func _strike_the_nearest_enemy(scene: TacticalGame, unit_id: int) -> void:
	var unit: Unit = scene.state.unit_by_id(unit_id)
	if unit == null:
		return
	var nearest: Unit = null
	for enemy: Unit in scene.state.units_of(TacticalScenario.FACTIONS - 1 - scene.person_side):
		if nearest == null or _steps(unit.cell, enemy.cell) < _steps(unit.cell, nearest.cell):
			nearest = enemy
	if nearest != null:
		scene.click_cell(nearest.cell)


func _steps(from: Vector2i, to: Vector2i) -> int:
	return absi(from.x - to.x) + absi(from.y - to.y)


func _keep_lower(worst: Dictionary, scene: TacticalGame, when: String) -> void:
	var status: Label = scene.get_node("Interface/Status")
	if _bottom_of(status) > worst["bottom"]:
		worst["bottom"] = _bottom_of(status)
		worst["when"] = when
		worst["words"] = status.atr(status.text)


func _mounted_scene(locale: String) -> TacticalGame:
	TranslationServer.set_locale(locale)
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	add_child(scene)
	return scene


func _bottom_of(shown: Label) -> float:
	return shown.get_global_rect().position.y + shown.get_combined_minimum_size().y


# Where a Label's words end on the right: a Label that does not wrap is as
# wide as its longest line, whatever size it was given; one that wraps has a
# minimum width of a character, and ends where its rectangle does.
func _right_of(shown: Label) -> float:
	return shown.get_global_rect().position.x + maxf(shown.size.x, shown.get_combined_minimum_size().x)


func _window() -> Vector2:
	return BoardLayout.window_size()
