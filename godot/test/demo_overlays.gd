# Every example, opened headless, stepped through its first decisions, and
# asked what the AI is reasoning with.
#
# It cannot look at the screen -- `--headless` rasterises nothing, measured on
# the pinned engine -- so it holds the half a command can: each scene loads,
# offers `step_decision`, and after a few steps `decision_overlay` hands back
# something real for every field, and its legend says something. Whether a
# person can read it is each example's manual check.
#
# `check_demos.py` refuses a `make demo-*` whose scene is missing from SCENES,
# so a new example cannot skip this by not being listed.
#
#     ./scripts/godot --headless --path godot -s res://test/demo_overlays.gd
extends SceneTree

const SCENES: Array[String] = [
	"res://game/main.tscn",
	"res://demos/search/search_demo.tscn",
	"res://game/stealth/stealth.tscn",
]

## Decisions each example takes before it is asked. More than one, so an
## overlay that is only filled in on the opening frame does not pass.
const STEPS: int = 3


func _initialize() -> void:
	_run()


# A coroutine, because a scene added to the tree from `_initialize` is not
# ready until the main loop has turned once: measured, `is_node_ready()` is
# false straight after `add_child`, and every legend read as empty.
func _run() -> void:
	var failures: Array[String] = _planted_cases()
	for path: String in SCENES:
		failures += await _check_scene(path)
	for failure: String in failures:
		print(failure)
	print("demo overlays: %d example(s), %d failure(s)" % [SCENES.size(), failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _check_scene(path: String) -> Array[String]:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return ["%s: does not load" % path]
	var example: Node = packed.instantiate()
	root.add_child(example)
	await process_frame
	var failures: Array[String] = _check_example(path, example)
	root.remove_child(example)
	example.free()
	return failures


func _check_example(path: String, example: Node) -> Array[String]:
	if not example.has_method("step_decision") or not example.has_method("decision_overlay"):
		return ["%s: has no step_decision() and decision_overlay()" % path]
	var legend: Legend = example.find_child("Legend", true, false) as Legend
	if legend == null or legend.entries.is_empty():
		return ["%s: has no legend, or an empty one" % path]
	for _step: int in range(STEPS):
		example.call("step_decision")
	var overlay: Variant = example.call("decision_overlay")
	if not (overlay is Dictionary) or (overlay as Dictionary).is_empty():
		return ["%s: decision_overlay() is empty after %d steps" % [path, STEPS]]
	var failures: Array[String] = []
	for field: Variant in overlay:
		var empty: String = _why_empty(overlay[field])
		if empty != "":
			failures.append("%s: overlay field %s is %s" % [path, field, empty])
	return failures


# The emptiness rule, against values whose answer is known. `lint-selftests`
# only reaches `scripts/`, so this is the only thing that would notice the
# rule below going blind: every real overlay is full, and a rule that never
# finds anything empty would pass all of them.
func _planted_cases() -> Array[String]:
	var planted: Dictionary = {
		"null": [null, true], "nan": [NAN, true], "an empty list": [[], true],
		"a list of one empty word": [[""], true], "an empty table inside": [{"a": {}}, true],
		"an empty word": ["", true], "a number": [0.0, false], "a word": ["patrol", false],
		"a full table": [{"a": [1]}, false],
	}
	var failures: Array[String] = []
	for label: String in planted:
		var flagged: bool = _why_empty(planted[label][0]) != ""
		if flagged != planted[label][1]:
			failures.append("planted case %s: flagged %s" % [label, flagged])
	return failures


# Why a value tells a person nothing, or "" when it tells them something.
# Containers are looked inside, because a list of three empty reasons is as
# empty as no list at all.
func _why_empty(value: Variant) -> String:
	if value == null:
		return "null"
	if (value is float or value is int) and not is_finite(float(value)):
		return "not a finite number"
	if value is String or value is PackedStringArray or value is Array or value is Dictionary:
		if value.is_empty():
			return "empty"
	var inside: Array = value.values() if value is Dictionary else []
	if value is Array or value is PackedStringArray:
		inside = Array(value)
	for item: Variant in inside:
		if _why_empty(item) != "":
			return "holding something empty"
	return ""
