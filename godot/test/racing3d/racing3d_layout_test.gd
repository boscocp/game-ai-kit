# T108: the 3D racer's status, which follows the legend down by the pad's
# lines, still ends 8 px above the trace under it.
#
# `test-demo-overlays` holds the legend clear of the status, by construction
# now -- the status is placed under the legend's last line. Where the
# status's words *end* is what moved, and what this measures: in English and
# in pt-BR, with the pad planted, measuring and racing, watching each car,
# under each of the eight settings of the three switches (their lines differ
# in length). Racing is reached by setting `race.racing`, not by driving the
# twenty seconds of measuring: the panel reads only that flag to choose its
# lines. A wrapped Label's minimum height is the height of its words (T102).
extends GdUnitTestSuite

const SCENE: String = "res://game3d/racing/racing3d.tscn"
const LOCALES: Array[String] = ["en", "pt_BR"]
## What the status keeps clear above the trace: `demo_overlays.gd`'s margin
## between a legend and what is below it.
const MARGIN: float = 8.0
const SCREEN_HEIGHT: float = 720.0
## The three switches' eight settings, times measuring or racing.
const SWITCH_SETTINGS: int = 8

var _locale_before: String
var _planted_before: bool


func before() -> void:
	_locale_before = TranslationServer.get_locale()
	_planted_before = PadAsKeys.planted
	PadAsKeys.planted = true


func after() -> void:
	TranslationServer.set_locale(_locale_before)
	PadAsKeys.planted = _planted_before


func test_the_status_ends_above_the_trace_in_every_state_and_language() -> void:
	for locale: String in LOCALES:
		var demo: Node3D = _mounted(locale)
		var race: Race3D = demo.get("race")
		for state: int in range(2 * SWITCH_SETTINGS * race.cars.size()):
			race.racing = state % 2 == 1
			_set_switches(demo, (state / 2) % SWITCH_SETTINGS)
			demo.set("watched", state / (2 * SWITCH_SETTINGS))
			demo.call("step_decision")
			var why: String = _why_too_low(demo)
			assert_str(why).override_failure_message("%s, state %d: %s" % [locale, state, why]).is_empty()


func test_the_status_starts_under_the_legend_s_last_line() -> void:
	for locale: String in LOCALES:
		var demo: Node3D = _mounted(locale)
		var legend: Legend = demo.get_node("Interface/Legend")
		var legend_end: float = legend.global_position.y + legend.drawn_height()
		var status: Label = demo.get_node("Interface/Status")
		assert_float(status.global_position.y).is_greater_equal(legend_end + MARGIN)


# The planted case: a status too long for the room above the trace must be
# reported, or the measure above could pass anything.
func test_a_status_too_long_is_caught() -> void:
	var demo: Node3D = _mounted("en")
	var status: Label = demo.get_node("Interface/Status")
	status.text = "\n".join(PackedStringArray(range(20).map(func(line: int) -> String: return "line %d" % line)))
	assert_str(_why_too_low(demo)).contains("ends at y=")


# Each of the three switches on or off, from the bits of `setting`.
func _set_switches(demo: Node3D, setting: int) -> void:
	demo.set("full_pid", setting & 1 == 0)
	demo.set("heat_vision", setting & 2 == 0)
	demo.set("measured_grip", setting & 4 == 0)


# Why the status's words end too close to the trace, or the trace below the
# window's gutter; "" when both fit.
func _why_too_low(demo: Node3D) -> String:
	var status: Label = demo.get_node("Interface/Status")
	var trace: Control = demo.get_node("Interface/Trace")
	var bottom: float = status.get_global_rect().position.y + status.get_combined_minimum_size().y
	var limit: float = trace.get_global_rect().position.y - MARGIN
	if bottom > limit:
		return "the status ends at y=%.0f, past %.0f (%.0f px above the trace)" % [bottom, limit, MARGIN]
	if trace.get_global_rect().end.y > SCREEN_HEIGHT - BoardLayout.GUTTER:
		return "the trace ends at y=%.0f, below the gutter" % trace.get_global_rect().end.y
	return ""


func _mounted(locale: String) -> Node3D:
	TranslationServer.set_locale(locale)
	var demo: Node3D = auto_free((load(SCENE) as PackedScene).instantiate())
	add_child(demo)
	return demo
