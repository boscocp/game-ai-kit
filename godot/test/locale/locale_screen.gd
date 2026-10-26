# Each translated example, opened in pt-BR and stepped a few frames: does any
# Control show, or any legend draw, the English of a key that has a
# Portuguese translation? (T78)
#
# What a Control shows is read by the rule measured in step 1
# (docs/godot/localisation.md): a Label keeps the English key in `text` and
# the screen shows its translation, so the property alone says nothing. The
# screen shows `atr(text)` -- the lookup that honours the node's
# auto-translate mode, and returns the text unchanged where that is off.
# Each line is checked on its own, since a status is several sentences.
# A legend is drawn, not a Control; its entries are the words it draws.
#
# Planted: a Label whose auto-translation is disabled, holding a key. If this
# does not see it, it sees nothing, and says so. Any engine error while the
# demos run is a failure too: a SCRIPT ERROR aborts only its function and
# the run would otherwise print a clean summary.
#
#     ./scripts/godot --headless --fixed-fps 60 --path godot -s res://test/locale/locale_screen.gd
extends SceneTree

const LOCALE_FOLDER: String = "res://locale"
const SETTINGS: String = "user://locale_screen_settings.cfg"
const FRAMES: int = 5
const EXAMPLES: Dictionary = {
	"checkers": "res://game/checkers/checkers.tscn",
	"search demo": "res://demos/search/search_demo.tscn",
	"menu": "res://menu/menu.tscn",
}


class ErrorCounter extends Logger:
	var errors: int = 0

	func _log_error(_function: String, _file: String, _line: int, _code: String,
			_rationale: String, _editor_notify: bool, _error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		errors += 1

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _counter := ErrorCounter.new()
# The English of every key whose pt_BR differs from it.
var _translated_keys: Dictionary = {}


func _initialize() -> void:
	OS.add_logger(_counter)
	_run()


func _run() -> void:
	_translated_keys = english_keys()
	var failures: Array[String] = []
	if _translated_keys.is_empty():
		failures.append("no key with a pt_BR translation under %s" % LOCALE_FOLDER)
	TranslationServer.set_locale("pt_BR")
	failures += await _planted()
	for label: String in EXAMPLES:
		failures += await _look_at(label, EXAMPLES[label])
	TranslationServer.set_locale("en")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	for failure: String in failures:
		print("FAIL ", failure)
	print("locale screen: %d example(s) in pt_BR, %d failure(s)" % [EXAMPLES.size(), failures.size()])
	quit(1 if not failures.is_empty() else 0)


## Every key in every table under res://locale whose pt_BR is not itself.
static func english_keys() -> Dictionary:
	var keys: Dictionary = {}
	for name: String in DirAccess.get_files_at(LOCALE_FOLDER):
		if not name.ends_with(".csv"):
			continue
		keys.merge(_translated_rows(LOCALE_FOLDER.path_join(name)))
	return keys


# The keys of one table whose pt_BR says something else.
static func _translated_rows(path: String) -> Dictionary:
	var keys: Dictionary = {}
	var table := FileAccess.open(path, FileAccess.READ)
	var portuguese: int = table.get_csv_line().find("pt_BR")
	while not table.eof_reached():
		var row: PackedStringArray = table.get_csv_line()
		if row.size() > portuguese and row[0] != "" and row[portuguese] != row[0]:
			keys[row[0]] = true
	return keys


## What `node` puts on the screen in English that has a translation, line by
## line: a Control's text as it is shown, or a legend's words.
func english_on_screen(node: Node) -> Array[String]:
	var shown: Array[String] = []
	if node is Label or node is Button:
		shown.append(node.atr(node.text))
	elif node is Legend:
		for entry: Array in (node as Legend).entries:
			shown.append(str(entry[1]))
	var found: Array[String] = []
	for text: String in shown:
		found.append_array(_keys_among(text.split("\n")))
	return found


# The lines that are, whole, the English of a translated key.
func _keys_among(lines: PackedStringArray) -> Array[String]:
	var found: Array[String] = []
	for line: String in lines:
		if _translated_keys.has(line.strip_edges()):
			found.append(line.strip_edges())
	return found


func _look_at(label: String, scene_path: String) -> Array[String]:
	_counter.errors = 0
	var example: Node = (load(scene_path) as PackedScene).instantiate()
	if example is ExampleMenu:
		(example as ExampleMenu).settings_path = SETTINGS
	root.add_child(example)
	# The menu applies the saved or the system language when it opens.
	TranslationServer.set_locale("pt_BR")
	for frame: int in range(FRAMES):
		if example.has_method("step_decision"):
			example.step_decision()
		await process_frame
	var failures: Array[String] = []
	for node: Node in _walk(example):
		for english: String in english_on_screen(node):
			failures.append("%s: %s shows the English %s" % [label, example.get_path_to(node), english])
	if _counter.errors > 0:
		failures.append("%s: %d engine error(s) while it ran" % [label, _counter.errors])
	example.free()
	return failures


# The planted case: a key on a Label that may not translate itself.
func _planted() -> Array[String]:
	var planted := Label.new()
	planted.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	planted.text = "Play  (Enter)"
	root.add_child(planted)
	await process_frame
	var seen: bool = not english_on_screen(planted).is_empty()
	planted.free()
	if seen:
		return []
	return ["the planted Label with auto-translation off was not seen: this check sees nothing"]


func _walk(node: Node) -> Array[Node]:
	var found: Array[Node] = [node]
	for child: Node in node.get_children():
		found += _walk(child)
	return found
