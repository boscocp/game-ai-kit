# T107: the behaviour demo's status keeps a margin above the window's
# bottom, in English and in pt-BR, whichever brain is playing.
#
# T102's measure of a wrapped Label found its three lines ending at y=711
# of 720 in both languages, on the opening screen: a strip pinned to the
# window's bottom edge. The lines change with the brain (when it is the
# right answer), the deed and a catch, so the status is measured over a
# played round under each of the four brains, as the tactical match's
# layout test measures its status over played games.
extends GdUnitTestSuite

const LOCALES: Array[String] = ["en", "pt_BR"]
## Turns played under each brain: the state machine and the HTN catch the
## intruder within them (behaviour_test.gd plays the same 300).
const TURNS: int = 300

var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func test_the_status_keeps_a_margin_under_every_brain() -> void:
	for locale: String in LOCALES:
		for brain: int in range(4):
			_assert_keeps_the_margin("%s, brain %d" % [locale, brain + 1], _worst_status_over_a_round(locale, brain))


# Prints the lowest the words went, for the review's record, and holds it
# to the gutter.
func _assert_keeps_the_margin(what: String, worst: Dictionary) -> void:
	var said: String = "%s, %s" % [what, worst["when"]]
	print("worst status: %s: y=%.0f" % [said, worst["bottom"]])
	assert_float(worst["bottom"]).override_failure_message("%s: the status's words end at y=%.0f, past %.0f\n%s" % [
		said, worst["bottom"], _limit(), worst["words"]]).is_less_equal(_limit())


# The status sits under the board, not over it, and inside the window's
# width: no word is drawn on the board (the demo's header says why).
func test_the_status_sits_under_the_board_inside_the_window() -> void:
	for locale: String in LOCALES:
		var demo: BehaviourDemo = _mounted_demo(locale)
		var status: Label = demo.get_node("Interface/Status")
		var board_end: float = demo.position.y + BoardView.pixel_size(demo.world.room.graph).y
		assert_float(status.get_global_rect().position.y).is_greater_equal(board_end)
		assert_float(status.get_global_rect().end.x).is_less_equal(BoardLayout.window_size().x)


# Play TURNS turns under brain `brain` and return where the status's words
# ended lowest, when, and what they said.
func _worst_status_over_a_round(locale: String, brain: int) -> Dictionary:
	var demo: BehaviourDemo = _mounted_demo(locale)
	demo.swap_brain(brain)
	var status: Label = demo.get_node("Interface/Status")
	var worst: Dictionary = {"bottom": 0.0, "when": "", "words": ""}
	for turn: int in range(TURNS + 1):
		if _bottom_of(status) > worst["bottom"]:
			worst["bottom"] = _bottom_of(status)
			worst["when"] = "turn %d" % turn
			worst["words"] = status.atr(status.text)
		demo.step_decision()
	return worst


# The gutter `BoardLayout` leaves between a panel and the window's edge.
func _limit() -> float:
	return BoardLayout.window_size().y - BoardLayout.GUTTER


# A wrapped Label's minimum height is the height of its wrapped words
# (docs/godot/localisation.md, T102), so that is where they end.
func _bottom_of(shown: Label) -> float:
	return shown.get_global_rect().position.y + shown.get_combined_minimum_size().y


func _mounted_demo(locale: String) -> BehaviourDemo:
	TranslationServer.set_locale(locale)
	var demo: BehaviourDemo = auto_free((load("res://demos/behaviour/behaviour_demo.tscn") as PackedScene).instantiate())
	add_child(demo)
	return demo
