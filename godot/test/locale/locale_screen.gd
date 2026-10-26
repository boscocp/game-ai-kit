# Each translated example, opened in pt-BR and stepped a few frames: does any
# Control show, or any legend draw, the English of a key that has a
# Portuguese translation? (T78)
#
# What a Control shows is read by the rule measured in step 1
# (docs/godot/localisation.md): a Label keeps the English key in `text` and
# the screen shows its translation, so the property alone says nothing. The
# screen shows `atr(text)` -- the lookup that honours the node's
# auto-translate mode, and returns the text unchanged where that is off.
# A legend is drawn, not a Control; its entries are the words it draws.
#
# Each line is read whole and in its "  ·  " segments, and a key with
# `{placeholders}` is matched as a pattern, so "cost 7" is the English of
# "cost {cost}". An example must show something: the nodes named in
# EXAMPLES must be there, and at least one line read, or a blank scene
# would pass.
#
# Planted: a Label whose auto-translation is disabled, a formatted English
# line, and an empty scene; each must be refused, or the check sees nothing
# and says so. Any engine error while the demos run is a failure too: a
# SCRIPT ERROR aborts only its function and the run would otherwise print a
# clean summary.
#
#     ./scripts/godot --headless --fixed-fps 60 --path godot -s res://test/locale/locale_screen.gd
extends SceneTree

const LOCALE_FOLDER: String = "res://locale"
const SETTINGS: String = "user://locale_screen_settings.cfg"
const FRAMES: int = 5
const SEGMENT: String = "  ·  "
## Each translated example, and the nodes its words must be found in.
const EXAMPLES: Dictionary = {
	"res://game/checkers/checkers.tscn": ["Interface/Status", "Interface/Decision", "Interface/Legend"],
	"res://demos/search/search_demo.tscn": ["Interface/Status", "Interface/Help", "Interface/Legend"],
	"res://game/tictactoe/tictactoe.tscn": ["Interface/Status", "Interface/Decision", "Interface/Legend"],
	"res://game/stealth/stealth.tscn": ["Interface/Status", "Interface/Legend"],
	"res://demos/behaviour/behaviour_demo.tscn": ["Interface/Status", "Interface/Legend"],
	"res://game/tactical/tactical.tscn": ["Interface/Header", "Interface/Status", "Interface/EndTurn",
		"Interface/Undo", "Interface/Legend"],
	"res://game/main.tscn": ["Interface/Status", "Interface/Legend"],
	"res://menu/menu.tscn": [],
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
# One pattern per key whose pt_BR differs from it, matched against a whole
# line or segment.
var _english: Array[RegEx] = []
# Lines read in the example being looked at.
var _lines_read: int = 0


func _initialize() -> void:
	OS.add_logger(_counter)
	_run()


func _run() -> void:
	_english = english_patterns()
	var failures: Array[String] = []
	if _english.is_empty():
		failures.append("no key with a pt_BR translation under %s" % LOCALE_FOLDER)
	TranslationServer.set_locale("pt_BR")
	failures += await _planted()
	for path: String in EXAMPLES:
		# Counted from before the load: a script that fails to parse fails
		# there, and the scene still opens without it (T79 found one).
		_counter.errors = 0
		failures += await _look_at(path, (load(path) as PackedScene).instantiate(), EXAMPLES[path])
	TranslationServer.set_locale("en")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	for failure: String in failures:
		print("FAIL ", failure)
	print("locale screen: %d example(s) in pt_BR, %d failure(s)" % [EXAMPLES.size(), failures.size()])
	quit(1 if not failures.is_empty() else 0)


## A pattern for every key in the tables under res://locale whose pt_BR is
## not itself: the key escaped, each `{placeholder}` standing for any text.
static func english_patterns() -> Array[RegEx]:
	var patterns: Array[RegEx] = []
	var keys: Array[String] = []
	for name: String in DirAccess.get_files_at(LOCALE_FOLDER):
		if name.ends_with(".csv"):
			keys.append_array(_translated_rows(LOCALE_FOLDER.path_join(name)))
	for key: String in keys:
		patterns.append(RegEx.create_from_string("^" + _escaped(key) + "$"))
	return patterns


# The keys of one table whose pt_BR says something else.
static func _translated_rows(path: String) -> Array[String]:
	var keys: Array[String] = []
	var table := FileAccess.open(path, FileAccess.READ)
	var portuguese: int = table.get_csv_line().find("pt_BR")
	while not table.eof_reached():
		var row: PackedStringArray = table.get_csv_line()
		if row.size() > portuguese and row[0] != "" and row[portuguese] != row[0]:
			keys.append(row[0])
	return keys


# A key as a regular expression: its text literal, its placeholders wild.
static func _escaped(key: String) -> String:
	var pattern: String = ""
	for piece: String in key.split("{"):
		var closing: int = piece.find("}")
		var literal: String = piece if closing < 0 else piece.substr(closing + 1)
		pattern += ("" if closing < 0 else ".+") + _quoted(literal)
	return pattern


static func _quoted(text: String) -> String:
	var quoted: String = ""
	for character: String in text:
		quoted += ("\\" + character) if "\\^$.|?*+()[]{}".contains(character) else character
	return quoted


## What `node` puts on the screen in English that has a translation: each
## line of a Control's text as it is shown, or of a legend's words, and each
## of a line's "  ·  " segments.
func english_on_screen(node: Node) -> Array[String]:
	var shown: Array[String] = []
	if node is Label or node is Button:
		shown.append(node.atr(node.text))
	elif node is Legend:
		for entry: Array in (node as Legend).entries:
			shown.append(str(entry[1]))
	var found: Array[String] = []
	for text: String in shown:
		for line: String in text.split("\n"):
			found.append_array(_english_in(line.strip_edges()))
	return found


# The line, or those of its segments, that are the English of a key.
func _english_in(line: String) -> Array[String]:
	if line == "":
		return []
	_lines_read += 1
	var found: Array[String] = []
	var pieces: PackedStringArray = line.split(SEGMENT)
	pieces.append(line)
	for piece: String in pieces:
		if _is_english(piece.strip_edges()):
			found.append(piece.strip_edges())
	return found


func _is_english(text: String) -> bool:
	return _english.any(func(pattern: RegEx) -> bool: return pattern.search(text) != null)


# The errors counted since `_counter.errors` was last set to 0 are this
# example's: the caller zeroes it before it loads the scene.
func _look_at(label: String, example: Node, expected: Array) -> Array[String]:
	_lines_read = 0
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
	for path: String in expected:
		if not example.has_node(path):
			failures.append("%s: has no %s to read" % [label, path])
	for node: Node in _walk(example):
		for english: String in english_on_screen(node):
			failures.append("%s: %s shows the English %s" % [label, example.get_path_to(node), english])
	if _lines_read == 0:
		failures.append("%s: shows no words at all to check" % label)
	if _counter.errors > 0:
		failures.append("%s: %d engine error(s) while it ran" % [label, _counter.errors])
	example.free()
	return failures


# The planted cases: a key on a Label that may not translate itself, a line
# formatted from a key, and a scene with nothing in it.
func _planted() -> Array[String]:
	var failures: Array[String] = []
	for text: String in ["Play  (Enter)", "expandiu 3  ·  cost 7"]:
		_counter.errors = 0
		var planted := Label.new()
		planted.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		planted.text = text
		var holder := Node2D.new()
		holder.add_child(planted)
		if (await _look_at("planted", holder, [])).is_empty():
			failures.append("the planted Label %s was not seen: this check sees nothing" % text)
	_counter.errors = 0
	if (await _look_at("planted", Node2D.new(), [])).is_empty():
		failures.append("an empty scene passed: this check would pass a blank screen")
	return failures


func _walk(node: Node) -> Array[Node]:
	var found: Array[Node] = [node]
	for child: Node in node.get_children():
		found += _walk(child)
	return found
