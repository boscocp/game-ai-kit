# T102: the tactical match's header and status fit the window, in English
# and in pt-BR, whichever controller plays the computer's side.
#
# T80's width check found the header one line 2,000 px wide, and its review
# found the status's words ending at y=719 of 720 in pt-BR. The header now
# wraps above the board and the status has a smaller font; these tests hold
# where their words end, measured as the screen lays them out: a wrapped
# Label's minimum height is the height of its wrapped words.
#
# `test-locale-screen` measures every example once, in one state. This
# measures the two longest the tactical screen has -- the person's turn and
# the computer's, whose status carries the next decision and the planner's
# plan -- under every controller, whose description is the header's last
# line. The line naming the controllers C cycles through left the status for
# a line of its own under the board, `Interface/Keys`.
extends GdUnitTestSuite

const LOCALES: Array[String] = ["en", "pt_BR"]
## Space kept between the header's last line and the board's top edge.
const HEADER_GAP: float = 8.0

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


func test_the_status_keeps_a_margin_on_either_turn_under_every_controller() -> void:
	for locale: String in LOCALES:
		var scene: TacticalGame = _mounted_scene(locale)
		for row_name: String in TacticalRoster.names():
			_assert_status_fits(scene, "%s, %s, the person's turn" % [locale, row_name])
			scene.end_turn()
			scene.end_turn()   # the second press answers "end with units unspent?"
			_assert_status_fits(scene, "%s, %s, the computer's turn" % [locale, row_name])
			scene.swap_controller()


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
			locale, _bottom_of(keys), keys.text]).is_less_equal(_window().y - BoardLayout.GUTTER)


func test_the_header_and_the_status_leave_the_buttons_alone() -> void:
	for locale: String in LOCALES:
		var scene: TacticalGame = _mounted_scene(locale)
		var header: Label = scene.get_node("Interface/Header")
		var status: Label = scene.get_node("Interface/Status")
		for button_path: String in ["Interface/EndTurn", "Interface/Undo"]:
			var button: Rect2 = (scene.get_node(button_path) as Control).get_global_rect()
			assert_float(_bottom_of(header)).is_less(button.position.y)
			assert_float(status.get_global_rect().end.x).is_less_equal(button.position.x)


# The header ends inside the window's width, and its last wrapped line
# HEADER_GAP above the board.
func _assert_header_fits(scene: TacticalGame, what: String) -> void:
	var header: Label = scene.get_node("Interface/Header")
	var words: String = header.atr(header.text)
	assert_float(_right_of(header)).override_failure_message(
		"%s: the header ends at x=%.0f\n%s" % [what, _right_of(header), words]).is_less_equal(_window().x)
	assert_float(_bottom_of(header)).override_failure_message(
		"%s: the header's words end at y=%.0f, the board starts at %.0f\n%s" % [
			what, _bottom_of(header), scene.position.y, words]).is_less_equal(scene.position.y - HEADER_GAP)


# The status's words end the gutter above the window's bottom: the margin
# `BoardLayout` gives the panel. Its own rectangle ends there, and a Label
# whose words are taller grows past it.
func _assert_status_fits(scene: TacticalGame, what: String) -> void:
	var status: Label = scene.get_node("Interface/Status")
	var limit: float = _window().y - BoardLayout.GUTTER
	assert_float(_bottom_of(status)).override_failure_message(
		"%s: the status's words end at y=%.0f, past %.0f\n%s" % [what, _bottom_of(status), limit, status.atr(status.text)]).is_less_equal(limit)


func _mounted_scene(locale: String) -> TacticalGame:
	TranslationServer.set_locale(locale)
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	add_child(scene)
	return scene


func _bottom_of(shown: Label) -> float:
	return shown.get_global_rect().position.y + shown.get_combined_minimum_size().y


func _right_of(shown: Label) -> float:
	return shown.get_global_rect().end.x


func _window() -> Vector2:
	return BoardLayout.window_size()
