# T108: the 2D racer's status, which follows the legend down by the pad's
# lines, still ends above the window's gutter.
#
# `test-demo-overlays` holds the legend clear of the status, and that holds
# by construction now -- the status is placed under the legend's last line.
# Where the status's words *end* is what moved, and what this measures: in
# English and in pt-BR, with the pad planted, in every state the panel has
# -- racing each level and watching each, paused or not -- over a stretch
# of the race, so the speeds and places have their digits. A wrapped Label's
# minimum height is the height of its wrapped words (T102), so that is where
# they end. The minimap moved to the view's corner to leave it the room.
extends GdUnitTestSuite

const SCENE: String = "res://demos/racing/racing_demo.tscn"
const LOCALES: Array[String] = ["en", "pt_BR"]
## The window's height and the gutter every panel keeps above its bottom.
const SCREEN_HEIGHT: float = 720.0
## Steps of the race each state is watched for, read every ten (the panel's
## own pace).
const STEPS: int = 300

var _locale_before: String
var _planted_before: bool


func before() -> void:
	_locale_before = TranslationServer.get_locale()
	_planted_before = PadAsKeys.planted
	PadAsKeys.planted = true


func after() -> void:
	TranslationServer.set_locale(_locale_before)
	PadAsKeys.planted = _planted_before


func test_the_status_ends_above_the_gutter_in_every_state_and_language() -> void:
	for locale: String in LOCALES:
		var demo: RacingDemo = _mounted(locale)
		for state: int in range(12):
			_assert_fits(demo, "race" if state < 6 else "watch", state % 3, (state / 3) % 2 == 1, locale)


func test_the_status_starts_under_the_legend_s_last_line() -> void:
	for locale: String in LOCALES:
		var demo: RacingDemo = _mounted(locale)
		var legend: Legend = demo.get_node("Interface/Legend")
		var status: Label = demo.get_node("Interface/Status")
		var legend_end: float = legend.global_position.y + legend.drawn_height()
		assert_float(status.global_position.y).is_equal_approx(legend_end + RacingDemo.BELOW_LEGEND, 0.5)


# The planted case: a status too long for the column must be reported, or
# the measure above could pass anything.
func test_a_status_too_long_is_caught() -> void:
	var demo: RacingDemo = _mounted("en")
	var status: Label = demo.get_node("Interface/Status")
	status.text = "\n".join(PackedStringArray(range(30).map(func(line: int) -> String: return "line %d" % line)))
	assert_str(_why_too_low(status)).contains("ends at y=")


func _assert_fits(demo: RacingDemo, mode: String, level: int, paused: bool, locale: String) -> void:
	demo.mode = mode
	demo.chosen = level
	demo.restart()
	demo.paused = paused
	var status: Label = demo.get_node("Interface/Status")
	var worst: String = ""
	for step: int in range(STEPS):
		demo.step_decision()
		if worst == "" and demo.race.steps % 10 == 0:
			worst = _why_too_low(status)
	assert_str(worst).override_failure_message("%s, %s, level %d, paused %s: %s" % [
		locale, mode, level + 1, paused, worst]).is_empty()


# Why the status's words end too low, or "" when they end above the gutter.
func _why_too_low(status: Label) -> String:
	var bottom: float = status.get_global_rect().position.y + status.get_combined_minimum_size().y
	var lowest: float = SCREEN_HEIGHT - BoardLayout.GUTTER
	if bottom > lowest:
		return "the status ends at y=%.0f, below %.0f" % [bottom, lowest]
	return ""


func _mounted(locale: String) -> RacingDemo:
	TranslationServer.set_locale(locale)
	var demo: RacingDemo = auto_free((load(SCENE) as PackedScene).instantiate())
	add_child(demo)
	return demo
