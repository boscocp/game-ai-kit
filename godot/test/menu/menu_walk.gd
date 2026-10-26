# The menu, opened headless and walked through every example in its
# catalogue: select it, play it, step it through its first decision, reload
# it as R does, press Escape, and find the menu back with the example gone
# (T24).
#
# For each card it holds that:
#
#   * the example it opens is the scene the card names, the tree's current
#     scene, with the menu hidden;
#   * one decision runs with no engine error;
#   * a reload of the current scene -- the skirmish's R -- leaves an example
#     Escape can still leave (wave 59's review: it could not);
#   * Escape brings the menu back, visible, current and holding the
#     keyboard, with the example freed and the node count where it was
#     before the example opened.
#
# And for the tactical board, that two games opened from the menu do not
# share their dice: it rolls them only at the top of the tree, and the
# review found every game from the menu on the scenario's seed 0.
#
# Each rule first meets planted examples built in memory: one that takes
# Escape in its own `_input` (the menu must still win), one that leaves a node
# behind, one that reports an engine error, one that checks it is at the top
# of the tree when it is ready, and a sound one. `lint-selftests` reaches only
# `scripts/`, so nothing else would notice this walk going blind.
#
#     ./scripts/godot --headless --path godot -s res://test/menu/menu_walk.gd
extends SceneTree

const MENU: String = "res://menu/menu.tscn"
const TACTICAL: String = "res://game/tactical/tactical.tscn"
const SETTINGS: String = "user://menu_walk_settings.cfg"

## Each planted example's script body, and the words its failure must use
## ("" for the ones that must pass).
const PLANTED: Dictionary = {
	"sound": ["", ""],
	"takes Escape in its own _input": ["func _input(event):\n\tget_viewport().set_input_as_handled()", ""],
	"leaves a node": ["var kept := Node.new()\nfunc _ready():\n\tget_tree().root.add_child.call_deferred(kept)",
		"left behind"],
	"reports an engine error": ["func _ready():\n\tpush_error(\"planted\")", "engine error"],
	"is not at the top when ready": ["func _ready():\n\tif get_parent() != get_tree().root:\n\t\tpush_error(\"not at the top\")",
		""],
}


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
	# Its own settings file, never the person's: all checkouts share one
	# user:// (T78). And English, whatever the machine speaks.
	_menu.settings_path = SETTINGS
	root.add_child(_menu)
	TranslationServer.set_locale("en")
	current_scene = _menu
	await process_frame
	var failures: Array[String] = await _planted_examples()
	if _menu.catalogue.cards.is_empty():
		failures.append("the menu lists no example: %s" % _menu.catalogue.problem)
	for index: int in range(_menu.catalogue.cards.size()):
		failures += await _walk(index)
	failures += await _tactical_dice()
	for failure: String in failures:
		print(failure)
	print("menu walk: %d example(s), %d failure(s)" % [_menu.catalogue.cards.size(), failures.size()])
	_menu.free()
	quit(1 if not failures.is_empty() else 0)


# Select card `index`, play it, decide once, reload it, leave, and look.
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
	var failures: Array[String] = _while_playing(label, example, card.get("scene", ""))
	if example.has_method("step_decision"):
		example.call("step_decision")
	reload_current_scene()
	await process_frame
	await process_frame
	if current_scene == _menu or current_scene == null or current_scene.scene_file_path != card.get("scene", ""):
		failures.append("%s: after a reload the current scene is %s" % [label, current_scene])
	return failures + await _leave(label, current_scene, nodes_before)


func _while_playing(label: String, example: Node, scene: String) -> Array[String]:
	var failures: Array[String] = []
	if example.scene_file_path != scene:
		failures.append("%s: opened %s, the card names %s" % [label, example.scene_file_path, scene])
	if _menu.visible:
		failures.append("%s: the menu is still showing over it" % label)
	return failures


# Press Escape, as a person would, and check what is left.
func _leave(label: String, example: Node, nodes_before: int) -> Array[String]:
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await process_frame
	await process_frame
	var failures: Array[String] = []
	if _counter.errors > 0:
		failures.append("%s: %d engine error(s) while it ran" % [label, _counter.errors])
	if current_scene != _menu or not _menu.visible:
		failures.append("%s: Escape did not bring the menu back" % label)
		_menu.back()
		await process_frame
	elif not _menu.is_ancestor_of(_menu.get_viewport().gui_get_focus_owner()):
		failures.append("%s: back on the menu, the keyboard is not on it" % label)
	if is_instance_valid(example):
		failures.append("%s: still alive after Escape" % label)
	var left_behind: int = _node_count() - nodes_before
	if left_behind != 0:
		failures.append("%s: %d node(s) left behind after Escape" % [label, left_behind])
	return failures


func _node_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


# Two games of the tactical board from the menu must not begin on one seed.
func _tactical_dice() -> Array[String]:
	var seeds: Array[int] = []
	for game: int in range(2):
		_menu.open((load(TACTICAL) as PackedScene).instantiate())
		await process_frame
		seeds.append(int(current_scene.get("state").dice_seed))
		_menu.back()
		await process_frame
	if seeds[0] == seeds[1]:
		return ["the tactical board from the menu began two games on the seed %d" % seeds[0]]
	return []


# --- the planted cases ------------------------------------------------------

func _planted_examples() -> Array[String]:
	var failures: Array[String] = []
	for label: String in PLANTED:
		var nodes_before: int = _node_count()
		var example := Node2D.new()
		var script := GDScript.new()
		script.source_code = "extends Node2D\n" + PLANTED[label][0] + "\n"
		script.reload()
		example.set_script(script)
		_counter.errors = 0
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
