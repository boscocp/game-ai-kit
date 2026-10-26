# Every example, opened headless, stepped through its first decisions, and
# asked what the AI is reasoning with.
#
# It cannot look at the screen -- `--headless` rasterises nothing, measured on
# the pinned engine -- so it holds the half a command can, for each example:
#
#   * it loads, offers `step_decision` and `decision_overlay`, and stepping it
#     raises no engine error (a custom `Logger` counts them; a step that
#     crashed every time used to pass with three SCRIPT ERRORs printed);
#   * after a few steps every field of the overlay holds something, the field
#     its task names is there (the search's frontier, the learned policy's
#     probability as a number), and the overlay has *changed* -- a constant
#     one used to pass, and showed no decision at all;
#   * its legend says something on every line, and fits on the screen.
#
# Each rule first rejects a planted example built in memory below, because
# `lint-selftests` only reaches `scripts/` and nothing else would notice one
# going blind. The planted crash prints its own backtrace on every run: that
# is the rule being shown a crash, not a failure. `check_demos.py` refuses a
# `make demo-*` missing from SCENES.
#
# The examples are stepped in one language, English unless `--locale=pt_BR`
# follows `--`, and never in the machine's: the engine starts in the system's
# locale (T78), and a Portuguese legend line is longer -- one ran off the
# window in pt-BR only. `make test-demo-overlays` runs it in both.
#
#     ./scripts/godot --headless --path godot -s res://test/menu/demo_overlays.gd -- --locale=pt_BR
extends SceneTree

const SCENES: Array[String] = [
	"res://game/checkers/checkers.tscn",
	"res://game/main.tscn",
	"res://demos/search/search_demo.tscn",
	"res://demos/behaviour/behaviour_demo.tscn",
	"res://demos/steering/steering_demo.tscn",
	"res://demos/racing/racing_demo.tscn",
	"res://game/stealth/stealth.tscn",
	"res://game/tactical/tactical.tscn",
	"res://game/tictactoe/tictactoe.tscn",
	"res://game/fighting/fighting.tscn",
	"res://game/rts/rts.tscn",
	"res://game3d/botmatch/botmatch.tscn",
	"res://game3d/racing/racing3d.tscn",
	"res://game3d/infiltration/infiltration.tscn",
]

## The field each example's task says its overlay must carry, and whether it
## must be a number. Found anywhere in the overlay, at any depth. An example
## whose tasks ask for several lists each pair.
const REQUIRED: Dictionary = {
	"res://game/checkers/checkers.tscn": ["value", true],
	"res://game/main.tscn": ["p_win", true],
	"res://demos/search/search_demo.tscn": ["frontier", false],
	"res://demos/behaviour/behaviour_demo.tscn": [["thinking", false], ["suspicion", true]],
	"res://demos/steering/steering_demo.tscn": ["force", true],
	"res://demos/racing/racing_demo.tscn": [["target_speed", true], ["braking_in", true]],
	"res://game/stealth/stealth.tscn": ["suspicion", true],
	"res://game/tactical/tactical.tscn": ["why", false],
	"res://game/tictactoe/tictactoe.tscn": ["probability", true],
	"res://game/fighting/fighting.tscn": [["phase", false], ["seen_frame", true]],
	"res://game/rts/rts.tscn": [["plan", false], ["ore", true]],
	"res://game3d/botmatch/botmatch.tscn": [["candidates", false], ["confidence", true]],
	"res://game3d/racing/racing3d.tscn": [["target_speed", true], ["heat_ball", true]],
	"res://game3d/infiltration/infiltration.tscn": [["awareness", true], ["action", false]],
}

## Decisions each example takes before it is asked. More than one, so an
## overlay that is only filled in on the opening frame does not pass.
const STEPS: int = 3

## The window's width, from `project.godot`; a legend line past it is cut off.
const SCREEN_WIDTH: float = 1280.0


## Counts what the engine reports as an error while an example runs.
class ErrorCounter extends Logger:
	var errors: int = 0

	func _log_error(_function: String, _file: String, _line: int, _code: String,
			_rationale: String, _editor_notify: bool, _error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		errors += 1

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _counter := ErrorCounter.new()


func _initialize() -> void:
	OS.add_logger(_counter)
	TranslationServer.set_locale(chosen_locale(OS.get_cmdline_user_args()))
	_run()


## The locale named by `--locale=...` among `arguments`, or English.
static func chosen_locale(arguments: PackedStringArray) -> String:
	for argument: String in arguments:
		if argument.begins_with("--locale="):
			return argument.trim_prefix("--locale=")
	return "en"


# A coroutine, because a scene added to the tree from `_initialize` is not
# ready until the main loop has turned once: measured, `is_node_ready()` is
# false straight after `add_child`, and every legend read as empty.
func _run() -> void:
	var failures: Array[String] = _planted_values()
	failures += await _planted_examples()
	for path: String in SCENES:
		failures += await _check_scene(path)
	for failure: String in failures:
		print(failure)
	print("demo overlays: %d example(s) in %s, %d failure(s)" % [SCENES.size(), TranslationServer.get_locale(),
		failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _check_scene(path: String) -> Array[String]:
	if not ResourceLoader.exists(path):
		return ["%s: does not exist" % path]
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return ["%s: does not load" % path]
	return await _check_node(path, packed.instantiate(), REQUIRED.get(path, []))


# Mount one example, step it, ask it, and take it down again.
func _check_node(label: String, example: Node, required: Array) -> Array[String]:
	_counter.errors = 0
	root.add_child(example)
	await process_frame
	var failures: Array[String] = _check_example(label, example, required)
	if _counter.errors > 0:
		failures.append("%s: %d engine error(s) while it ran" % [label, _counter.errors])
	root.remove_child(example)
	example.free()
	return failures


func _check_example(label: String, example: Node, required: Array) -> Array[String]:
	if not example.has_method("step_decision") or not example.has_method("decision_overlay"):
		return ["%s: has no step_decision() and decision_overlay()" % label]
	var legend: String = _why_the_legend_fails(example.find_child("Legend", true, false) as Legend)
	if legend != "":
		return ["%s: %s" % [label, legend]]
	var before: String = str(example.call("decision_overlay"))
	for _step: int in range(STEPS):
		example.call("step_decision")
	var overlay: Variant = example.call("decision_overlay")
	if not (overlay is Dictionary) or (overlay as Dictionary).is_empty():
		return ["%s: decision_overlay() is empty after %d steps" % [label, STEPS]]
	var failures: Array[String] = []
	if str(overlay) == before:
		failures.append("%s: the overlay did not change in %d decisions" % [label, STEPS])
	for field: Variant in overlay:
		var empty: String = _why_empty(overlay[field])
		if empty != "":
			failures.append("%s: overlay field %s is %s" % [label, field, empty])
	return failures + _check_required(label, overlay, required)


func _check_required(label: String, overlay: Dictionary, required: Array) -> Array[String]:
	if required.is_empty():
		return []
	if required[0] is Array:
		var failures: Array[String] = []
		for pair: Array in required:
			failures += _check_required(label, overlay, pair)
		return failures
	var found: Array = []
	_collect(overlay, required[0], found)
	if found.is_empty():
		return ["%s: the overlay carries no %s" % [label, required[0]]]
	for value: Variant in found:
		if required[1] and not (value is float or value is int):
			return ["%s: %s is %s, not a number" % [label, required[0], value]]
	return []


# Every value stored under `key`, anywhere inside `value`.
func _collect(value: Variant, key: String, found: Array) -> void:
	if value is Dictionary and value.has(key):
		found.append(value[key])
	var inside: Array = value.values() if value is Dictionary else (value if value is Array else [])
	for item: Variant in inside:
		_collect(item, key, found)


func _why_the_legend_fails(legend: Legend) -> String:
	if legend == null or legend.entries.is_empty():
		return "has no legend, or an empty one"
	for entry: Array in legend.entries:
		var words: String = str(entry[1])
		if words.strip_edges() == "":
			return "a legend line says nothing"
		var right: float = _right_edge_of(legend, words)
		if right > SCREEN_WIDTH:
			return "the legend line \"%s\" runs off the screen, to x=%.0f" % [words.strip_edges(), right]
	return ""


func _right_edge_of(legend: Legend, words: String) -> float:
	var width: float = ThemeDB.fallback_font.get_string_size(
			words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, Legend.TEXT_SIZE).x
	return legend.get_global_rect().position.x + Legend.SWATCH + 8.0 + width


# Why a value tells a person nothing, or "" when it tells them something.
# Containers are looked inside, because a list of three empty reasons is as
# empty as no list at all. Every packed array counts as a container: a route
# stored as `PackedVector2Array()` used to pass as something.
func _why_empty(value: Variant) -> String:
	if value == null:
		return "null"
	if (value is float or value is int) and not is_finite(float(value)):
		return "not a finite number"
	var kind: int = typeof(value)
	var sized: Array[int] = [TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH, TYPE_ARRAY, TYPE_DICTIONARY]
	if (kind in sized or kind >= TYPE_PACKED_BYTE_ARRAY) and value.is_empty():
		return "empty"
	var inside: Array = value.values() if value is Dictionary else []
	if kind == TYPE_ARRAY or kind >= TYPE_PACKED_BYTE_ARRAY:
		inside = Array(value)
	for item: Variant in inside:
		if _why_empty(item) != "":
			return "holding something empty"
	return ""


# --- the planted cases ------------------------------------------------------

# The emptiness rule, against values whose answer is known.
func _planted_values() -> Array[String]:
	var planted: Dictionary = {
		"null": [null, true], "nan": [NAN, true], "an empty list": [[], true],
		"a list of one empty word": [[""], true], "an empty table inside": [{"a": {}}, true],
		"an empty word": ["", true], "an empty name": [&"", true], "an empty path": [NodePath(""), true],
		"no points": [PackedVector2Array(), true], "no names": [PackedStringArray(), true],
		"a number": [0.0, false], "a word": ["patrol", false], "a full table": [{"a": [1]}, false],
		"some points": [PackedVector2Array([Vector2.ONE]), false],
	}
	var failures: Array[String] = []
	for label: String in planted:
		var flagged: bool = _why_empty(planted[label][0]) != ""
		if flagged != planted[label][1]:
			failures.append("planted value %s: flagged %s" % [label, flagged])
	return failures


# Examples built in memory, each broken one way, each of which must fail with
# the sentence its rule writes -- and one sound one, which must pass.
func _planted_examples() -> Array[String]:
	var counting: String = "var count := 0\nfunc step_decision():\n\tcount += 1\n"
	var cases: Dictionary = {
		"sound": [counting + "func decision_overlay():\n\treturn {\"p_win\": 0.5, \"n\": count}", true, ""],
		"no functions": ["func advance():\n\tpass", true, "has no step_decision"],
		"no legend": [counting + "func decision_overlay():\n\treturn {\"p_win\": 0.5, \"n\": count}", false, "has no legend"],
		"a constant overlay": ["func step_decision():\n\tpass\nfunc decision_overlay():\n\treturn {\"p_win\": 0.5}", true, "did not change"],
		"an empty field": [counting + "func decision_overlay():\n\treturn {\"p_win\": 0.5, \"n\": count, \"why\": []}", true, "is empty"],
		"a crashing step": [counting.replace("count += 1\n", "count += 1\n\tvar nothing: Object = null\n\tnothing.free()\n") + "func decision_overlay():\n\treturn {\"p_win\": 0.5, \"n\": count}", true, "engine error"],
		"a word for a number": [counting + "func decision_overlay():\n\treturn {\"p_win\": \"0.5\", \"n\": count}", true, "not a number"],
		"the required field missing": [counting + "func decision_overlay():\n\treturn {\"n\": count}", true, "carries no p_win"],
	}
	var failures: Array[String] = []
	for label: String in cases:
		var spec: Array = cases[label]
		var found: Array[String] = await _check_node("planted", _planted_node(spec[0], spec[1]), ["p_win", true])
		failures += _judge_planted(label, found, spec[2])
	# Of two required fields, the second missing: a list of pairs that only
	# looked at its first would pass this.
	var second_missing: Array[String] = await _check_node("planted", _planted_node(
			counting + "func decision_overlay():\n\treturn {\"p_win\": 0.5, \"n\": count}", true),
			[["p_win", true], ["seen_frame", true]])
	failures += _judge_planted("the second of two required fields missing", second_missing, "carries no seen_frame")
	return failures


func _judge_planted(label: String, found: Array[String], wanted: String) -> Array[String]:
	if wanted == "" and found.is_empty():
		return []
	for line: String in found:
		if wanted != "" and wanted in line:
			return []
	return ["planted example %s: got %s" % [label, found]]


func _planted_node(body: String, with_legend: bool) -> Node:
	var script := GDScript.new()
	script.source_code = "extends Node2D\n" + body + "\n"
	script.reload()
	var example := Node2D.new()
	example.set_script(script)
	if with_legend:
		var legend := Legend.new()
		legend.name = "Legend"
		legend.entries = [[Color.WHITE, "something"]] as Array[Array]
		example.add_child(legend)
	return example
