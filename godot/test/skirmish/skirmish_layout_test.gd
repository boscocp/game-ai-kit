# T107: the skirmish's status keeps a margin above the window's bottom, in
# English and in pt-BR, over a played game.
#
# T102's measure of a wrapped Label found its words ending at y=716 of 720
# in pt-BR on the opening screen. That screen is not the longest the status
# gets: blue's reasons stay on it into red's next turn, a refused click adds
# a line, and a held node adds one more. Measured at 18 px before this wave,
# red's turn in round 2 with a refusal ended at y=861 in pt-BR. So, as the
# tactical match's layout test does, the status is measured over played
# games: red waiting, red trying a click too far each turn, and red walking
# its units onto the nodes (a hold's line, and blue's fights), while blue
# plays every decision a press at a time.
extends GdUnitTestSuite

const LOCALES: Array[String] = ["en", "pt_BR"]
## How red plays its turns.
const WAITS: String = "red waiting"
const REFUSED: String = "red refused"
const WALKS: String = "red walking to the nodes"
## Rounds played: the units meet by the third, and a hold takes
## `SkirmishVictory.HOLD_TURNS` of them.
const ROUNDS: int = 12
## A bound on blue's decisions, and on red's steps, in a turn, so a turn
## that never ends fails here rather than hanging the suite.
const STEPS_A_TURN: int = 20
## A cell more than a step from any of red's units: the longest refusal red
## can be told.
const FAR_AWAY := Vector2i(9, 7)

var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func test_the_status_keeps_a_margin_over_a_played_game() -> void:
	for locale: String in LOCALES:
		for how: String in [WAITS, REFUSED, WALKS]:
			_assert_keeps_the_margin("%s, %s" % [locale, how], _worst_status_over_a_game(locale, how))


# Prints the lowest the words went, for the review's record, and holds it
# to the gutter.
func _assert_keeps_the_margin(what: String, worst: Dictionary) -> void:
	var said: String = "%s, %s" % [what, worst["when"]]
	print("worst status: %s: y=%.0f" % [said, worst["bottom"]])
	assert_float(worst["bottom"]).override_failure_message("%s: the status's words end at y=%.0f, past %.0f\n%s" % [
		said, worst["bottom"], _limit(), worst["words"]]).is_less_equal(_limit())


# A wrapped Label ends where its rectangle does: inside the window's width.
func test_the_status_ends_inside_the_window_s_width() -> void:
	for locale: String in LOCALES:
		var main: BoardGame = _mounted_scene(locale)
		var status: Label = main.get_node("Interface/Status")
		assert_float(status.get_global_rect().end.x).is_less_equal(BoardLayout.window_size().x)


# Play ROUNDS rounds -- red's turn as `how` says, then blue's a decision at
# a time -- and return where the status's words ended lowest, when, and
# what they said.
func _worst_status_over_a_game(locale: String, how: String) -> Dictionary:
	var main: BoardGame = _mounted_scene(locale)
	var worst: Dictionary = {"bottom": 0.0, "when": "", "words": ""}
	for round_number: int in range(1, ROUNDS + 1):
		var when: String = "round %d" % round_number
		_keep_lower(worst, main, when + ", red's turn")
		if how == WALKS:
			_walk_red_to_the_nodes(main, worst, when)
		if how != WAITS:
			main._click_cell(FAR_AWAY)
			_keep_lower(worst, main, when + ", red refused")
		main.step_decision()
		var steps: int = 0
		while main._state.current_faction == BoardGame.AI_FACTION and steps < STEPS_A_TURN:
			_keep_lower(worst, main, when + ", blue's turn")
			main.step_decision()
			steps += 1
	_keep_lower(worst, main, "after round %d" % ROUNDS)
	return worst


# Each of red's units in hand in turn, stepping onto whichever highlighted
# cell is nearest a node while it can get nearer.
func _walk_red_to_the_nodes(main: BoardGame, worst: Dictionary, when: String) -> void:
	for unit: Unit in main._state.units_of(BoardGame.RED):
		main._click_cell(unit.cell)
		var steps: int = 0
		var here: Vector2i = unit.cell
		while steps < STEPS_A_TURN and _nearer_step(main, here) != here:
			here = _nearer_step(main, here)
			main._click_cell(here)
			steps += 1
		_keep_lower(worst, main, when + ", red walked")


# The highlighted cell nearest a node, or `here` when none is nearer.
func _nearer_step(main: BoardGame, here: Vector2i) -> Vector2i:
	var best: Vector2i = here
	for step: Vector2i in main._affordable_steps():
		if _to_a_node(step) < _to_a_node(best):
			best = step
	return best


func _to_a_node(cell: Vector2i) -> int:
	var nearest: int = 1 << 30
	for node: Vector2i in BoardGame.NODES:
		nearest = mini(nearest, absi(cell.x - node.x) + absi(cell.y - node.y))
	return nearest


func _keep_lower(worst: Dictionary, main: BoardGame, when: String) -> void:
	var status: Label = main.get_node("Interface/Status")
	if _bottom_of(status) > worst["bottom"]:
		worst["bottom"] = _bottom_of(status)
		worst["when"] = when
		worst["words"] = status.atr(status.text)


# The gutter `BoardLayout` leaves between a panel and the window's edge.
func _limit() -> float:
	return BoardLayout.window_size().y - BoardLayout.GUTTER


# A wrapped Label's minimum height is the height of its wrapped words
# (docs/godot/localisation.md, T102), so that is where they end.
func _bottom_of(shown: Label) -> float:
	return shown.get_global_rect().position.y + shown.get_combined_minimum_size().y


func _mounted_scene(locale: String) -> BoardGame:
	TranslationServer.set_locale(locale)
	var main: BoardGame = auto_free((load("res://game/main.tscn") as PackedScene).instantiate())
	add_child(main)
	return main
