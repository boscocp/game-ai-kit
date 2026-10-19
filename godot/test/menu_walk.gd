# The menu, opened headless and walked through every example in its
# catalogue: select it, play it, step it through its first decision, press
# Escape, and find the menu back with the example gone (T24).
#
# For each card it holds that:
#
#   * the example it opens is the scene the card names, and is the tree's
#     current scene while it plays -- the tactical board decides its dice by
#     that, and the skirmish's R reloads it;
#   * one decision runs with no engine error;
#   * Escape brings the menu back, visible and current, with the example
#     freed, and the node count where it was before the example opened: an
#     example that cannot be left, or leaves nodes behind, fails here.
#
# Each rule first rejects a planted example built in memory: one that eats
# Escape before the menu sees it, one that leaves a node behind, and a sound
# one that must pass. `lint-selftests` reaches only `scripts/`, so nothing
# else would notice this walk going blind.
#
#     ./scripts/godot --headless --path godot -s res://test/menu_walk.gd
extends SceneTree

const MENU: String = "res://menu/menu.tscn"


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
var _menu: ExampleMenu


func _initialize() -> void:
	OS.add_logger(_counter)
	_run()


# A coroutine: a scene added to the tree is not ready until the loop turns.
func _run() -> void:
	_menu = (load(MENU) as PackedScene).instantiate() as ExampleMenu
	root.add_child(_menu)
	current_scene = _menu
	await process_frame
	var failures: Array[String] = await _planted_examples()
	if _menu.catalogue.cards.is_empty():
		failures.append("the menu lists no example: %s" % _menu.catalogue.problem)
	for index: int in range(_menu.catalogue.cards.size()):
		failures += await _walk(index)
	for failure: String in failures:
		print(failure)
	print("menu walk: %d example(s), %d failure(s)" % [_menu.catalogue.cards.size(), failures.size()])
	_menu.free()
	quit(1 if not failures.is_empty() else 0)


# Select card `index`, play it, decide once, leave, and look.
func _walk(index: int) -> Array[String]:
	var card: Dictionary = _menu.catalogue.cards[index]
	var label: String = card.get("title", "?")
	_menu.select(index)
	var nodes_before: int = _node_count()
	_counter.errors = 0
	_menu.play()
	await process_frame
	var example: Node = current_scene
	if example == _menu or example == null:
		return ["%s: playing it left the menu as the current scene" % label]
	var failures: Array[String] = []
	if example.scene_file_path != card.get("scene", ""):
		failures.append("%s: opened %s, the card names %s" % [label, example.scene_file_path, card.get("scene")])
	if example.has_method("step_decision"):
		example.call("step_decision")
	if _counter.errors > 0:
		failures.append("%s: %d engine error(s) while it ran" % [label, _counter.errors])
	return failures + await _leave(label, example, nodes_before)


# Press Escape, as a person would, and check what is left.
func _leave(label: String, example: Node, nodes_before: int) -> Array[String]:
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await process_frame
	await process_frame
	var failures: Array[String] = []
	if current_scene != _menu or not _menu.visible:
		failures.append("%s: Escape did not bring the menu back" % label)
		_menu.back()
		await process_frame
	if is_instance_valid(example):
		failures.append("%s: still alive after Escape" % label)
	var left_behind: int = _node_count() - nodes_before
	if left_behind != 0:
		failures.append("%s: %d node(s) left behind after Escape" % [label, left_behind])
	return failures


func _node_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


# --- the planted cases ------------------------------------------------------

## Each planted example's script body, and the words its failure must use
## ("" for the sound one, which must pass).
const PLANTED: Dictionary = {
	"sound": ["", ""],
	"eats Escape": ["func _input(event):\n\tget_viewport().set_input_as_handled()", "did not bring the menu back"],
	"leaves a node": ["var kept := Node.new()\nfunc _ready():\n\tget_tree().root.add_child.call_deferred(kept)",
		"left behind"],
}


func _planted_examples() -> Array[String]:
	var failures: Array[String] = []
	for label: String in PLANTED:
		var nodes_before: int = _node_count()
		var example := Node2D.new()
		var script := GDScript.new()
		script.source_code = "extends Node2D\n" + PLANTED[label][0] + "\n"
		script.reload()
		example.set_script(script)
		_menu.open(example)
		await process_frame
		var found: Array[String] = await _leave("planted", example, nodes_before)
		failures += _judge(label, found, PLANTED[label][1])
		await _sweep()
	return failures


func _judge(label: String, found: Array[String], wanted: String) -> Array[String]:
	if wanted == "" and found.is_empty():
		return []
	for line: String in found:
		if wanted != "" and wanted in line:
			return []
	return ["planted example %s: got %s" % [label, found]]


# A planted leak is a node the planted example left under the root; take it
# away so the real walk starts from a clean tree.
func _sweep() -> void:
	for child: Node in root.get_children():
		if child != _menu:
			child.queue_free()
	await process_frame
