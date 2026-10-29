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
# A refusal is provoked too, in the tactical match and in the RTS: the
# board and the RTS rules write their refusals in English and the demos
# translate them where they are shown (`TacticalRefusal`, `RtsRefusal`), and
# no example stepped on its own is ever refused.
#
# A line of a Label that does not wrap must fit the window, too: a
# Portuguese line is longer, and T78's review found one running off the
# screen. A Label that wraps must fit as a whole: its rectangle inside the
# window's width, and its wrapped words ending a margin above the window's
# bottom (T102, after the tactical header ran to x=2432 and its status to
# y=719 of 720). A Label3D's words are read as a Label's are (T80).
#
# No pad can be connected headless, so one is planted (`PadAsKeys.planted`):
# an example with a pad must show the pad's legend lines as written now,
# and none of their bindings in English (T103).
#
# Planted: a Label whose auto-translation is disabled, a formatted English
# line, a line too wide, a wrapped Label too tall (also under a ceiling)
# and one too wide, an empty scene, and a pad's line written in English
# and not rebuilt; each must be refused, or the check sees nothing
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
	"res://game/tactical/tactical.tscn": ["Interface/Header", "Interface/Status", "Interface/Keys",
		"Interface/EndTurn", "Interface/Undo", "Interface/Legend"],
	"res://game/main.tscn": ["Interface/Status", "Interface/Legend"],
	"res://demos/steering/steering_demo.tscn": ["Interface/Status", "Interface/Legend"],
	"res://demos/racing/racing_demo.tscn": ["Interface/Status", "Interface/Speedo", "Interface/Legend"],
	"res://game3d/racing/racing3d.tscn": ["Interface/Status", "Interface/Legend"],
	"res://game3d/botmatch/botmatch.tscn": ["Interface/Panel", "Interface/Legend"],
	"res://game3d/infiltration/infiltration.tscn": ["Interface/Panel", "Interface/Legend"],
	"res://game/rts/rts.tscn": ["Interface/Header", "Interface/Thinking", "Interface/Card/Info", "Interface/Legend"],
	"res://game/fighting/fighting.tscn": ["Interface/Status", "Interface/Decision", "Interface/Legend"],
	"res://game/maze/maze.tscn": ["Interface/Status", "Interface/Decision", "Interface/Legend"],
	"res://menu/menu.tscn": [],
}
## The window's size, from `project.godot`: words past it are cut off.
const SCREEN_WIDTH: float = 1280.0
const SCREEN_HEIGHT: float = 720.0
## What a wrapped Label keeps clear above the window's bottom edge: the
## gutter `BoardLayout` leaves between a panel and the edge. Words that end
## at 719 of 720 fit and still read as cut off (T80's review).
const BOTTOM_MARGIN: float = BoardLayout.GUTTER
## Wrapped Labels known to end too low, a layout fix rather than a
## translation one: named here rather than hidden, "scene:node" to the y
## their words were measured to end at in pt-BR. That y is a ceiling, not an
## exemption: a panel named here that gets any lower still fails, and its
## width is measured as any other's. T102 fitted the tactical header and took
## it out; T107 fitted the three it then found (the behaviour demo's status,
## the skirmish's and the RTS card's info) and took them out too. Empty, and
## kept: a panel found too low and not fitted in the same wave goes here,
## with its y. The planted cases below keep the check honest either way.
const NOT_YET_FITTED: Dictionary[String, float] = {}


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
# NOT_YET_FITTED, and a planted panel's ceiling while it is looked at.
var _ceilings: Dictionary[String, float] = NOT_YET_FITTED.duplicate()


func _initialize() -> void:
	OS.add_logger(_counter)
	_run()


func _run() -> void:
	_english = english_patterns()
	var failures: Array[String] = []
	if _english.is_empty():
		failures.append("no key with a pt_BR translation under %s" % LOCALE_FOLDER)
	TranslationServer.set_locale("pt_BR")
	# No pad can be connected headless, and the pad's line is written only
	# for one: planted, every example with a pad shows it (T103).
	PadAsKeys.planted = true
	failures += await _planted()
	for path: String in EXAMPLES:
		# Counted from before the load: a script that fails to parse fails
		# there, and the scene still opens without it (T79 found one).
		_counter.errors = 0
		failures += await _look_at(path, (load(path) as PackedScene).instantiate(), EXAMPLES[path])
	PadAsKeys.planted = false
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
	if node is Label or node is Button or node is Label3D:
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
	if example is TacticalGame:
		failures += await _provoke_a_refusal(example as TacticalGame)
	if example is RtsGame:
		failures += await _provoke_an_rts_refusal(example as RtsGame)
	for path: String in expected:
		if not example.has_node(path):
			failures.append("%s: has no %s to read" % [label, path])
	for node: Node in _walk(example):
		for english: String in english_on_screen(node):
			failures.append("%s: %s shows the English %s" % [label, example.get_path_to(node), english])
		if node is Label:
			failures += _past_the_edge(label, example.get_path_to(node), node as Label)
	failures += _pad_line(label, example)
	if _lines_read == 0:
		failures.append("%s: shows no words at all to check" % label)
	if _counter.errors > 0:
		failures.append("%s: %d engine error(s) while it ran" % [label, _counter.errors])
	example.free()
	return failures


# The person's workshop asked for a ram before the forge is bought: the board
# refuses it, and the status must say so -- in Portuguese, which the walk
# below then checks. Fails when no refusal could be provoked, so the check
# cannot pass on a screen that never showed one.
func _provoke_a_refusal(game: TacticalGame) -> Array[String]:
	game.new_game()
	if game.state.current_faction != game.person_side:
		game.swap_sides()
	for unit: Unit in game.state.units:
		if unit.faction == game.person_side and unit.type.type_name == TacticalRules.WORKSHOP:
			game.click_cell(unit.cell)
	game.build(TacticalRules.BUILDABLE.find(TacticalRules.RAM))
	await process_frame
	var status: Label = game.get_node("Interface/Status")
	var refused: String = TranslationServer.translate("refused: {why}").split("{")[0]
	if not status.text.contains(refused):
		return ["tactical: no refusal could be provoked to check:\n" + status.text]
	return []


# The RTS: one of your workers ordered to build a lab with no barracks yet.
# The rules refuse it in English, and the header must say so through
# `RtsRefusal` -- in Portuguese, which the walk then checks.
func _provoke_an_rts_refusal(game: RtsGame) -> Array[String]:
	var worker: int = -1
	for unit: RtsUnit in game.world.units():
		if unit.side == RtsScenario.WEST and unit.kind == RtsKinds.WORKER:
			worker = unit.id
	if worker == -1:
		return ["rts: no worker of yours to give the order to"]
	game._give(RtsCommand.build(worker, RtsKinds.LAB, RtsScenario.home(RtsScenario.WEST)))
	game._refresh()
	await process_frame
	if game.last_refusal == "":
		return ["rts: no refusal could be provoked to check"]
	var header: Label = game.get_node("Interface/Header")
	if not header.text.contains(RtsRefusal.words(game.last_refusal)) or game.last_refusal == RtsRefusal.words(game.last_refusal):
		return ["rts: the refusal \"%s\" is not shown translated:\n%s" % [game.last_refusal, header.text]]
	return []


# An example with a pad and a legend must show the pad's lines as the pad
# writes them now, in pt-BR (planted, with no pad connected): otherwise the
# walk read none of its words, and an English line would pass unseen. Each
# of a line's ", " bindings is read too, after the line's "pad: " and
# without its key's name: "stick A/D/W/S" is "stick {keys}", "D-pad up Up"
# is "D-pad up" (T103).
func _pad_line(label: String, example: Node) -> Array[String]:
	var pads: Array[Node] = _walk(example).filter(func(node: Node) -> bool: return node is PadAsKeys)
	var legend := example.find_child("Legend", true, false) as Legend
	if pads.is_empty() or legend == null:
		return []
	var shown: Array = legend.entries.map(func(entry: Array) -> String: return str(entry[1]))
	var failures: Array[String] = []
	for line: String in (pads[0] as PadAsKeys).legend_lines(legend):
		if not line in shown:
			failures.append("%s: the legend does not show the pad's line %s" % [label, line])
		for binding: String in _english_bindings(line):
			failures.append("%s: the pad's line shows the English %s" % [label, binding])
	return failures


# The bindings of a pad's line that are, or are named by, the English of a key.
func _english_bindings(line: String) -> Array[String]:
	var before_the_first: String = TranslationServer.translate("pad: {bindings}").split("{")[0]
	var found: Array[String] = []
	for binding: String in line.trim_prefix(before_the_first).strip_edges().split(", "):
		var name: String = binding.substr(0, binding.rfind(" "))
		if _is_english(binding) or _is_english(name):
			found.append(binding)
	return found


# Each line of a Label that does not wrap or clip, measured in its own font:
# one that reaches past the window's edge is cut off on the screen. A Label
# that wraps is measured whole, by `_wrapped_past_the_edge`. Only a visible
# Label is measured, in the state the stepped scene left it: a Button, a
# Label3D, a HUD drawn with draw_string and a panel shown only when toggled
# are not (the legends are, by test-demo-overlays).
func _past_the_edge(label: String, path: NodePath, shown: Label) -> Array[String]:
	if shown.clip_text or not shown.is_visible_in_tree():
		return []
	if shown.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return _wrapped_past_the_edge(label, path, shown)
	var font: Font = shown.get_theme_font("font")
	var size: int = shown.get_theme_font_size("font_size")
	var failures: Array[String] = []
	for line: String in shown.atr(shown.text).split("\n"):
		var right: float = shown.get_global_rect().position.x + font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if right > SCREEN_WIDTH:
			failures.append("%s: %s runs off the window, to x=%.0f: %s" % [label, path, right, line])
	return failures


# A Label that wraps breaks its lines at its own width, so no line is wider
# than the Label: what can run off is the Label itself, to the right, or its
# words, downwards. Its minimum height is the height of its wrapped words
# (measured on the pinned engine: the tactical status, given 552 px, held
# words 569 px tall and grew to them), so that is where its words end.
func _wrapped_past_the_edge(label: String, path: NodePath, shown: Label) -> Array[String]:
	var box: Rect2 = shown.get_global_rect()
	var failures: Array[String] = []
	if box.end.x > SCREEN_WIDTH:
		failures.append("%s: %s runs off the window, to x=%.0f" % [label, path, box.end.x])
	var bottom: float = box.position.y + shown.get_combined_minimum_size().y
	var lowest: float = _ceilings.get("%s:%s" % [label, path], SCREEN_HEIGHT - BOTTOM_MARGIN)
	if bottom > lowest:
		failures.append("%s: %s runs off the window, its words ending at y=%.0f, below %.0f (the window is %.0f)" % [
			label, path, bottom, lowest, SCREEN_HEIGHT])
	return failures


# The planted cases: a key on a Label that may not translate itself, a line
# formatted from a key, a line too long for the window, a wrapped Label too
# tall for it -- 4 px past the gutter, and the same under a ceiling 2 px
# above its words -- and one too wide, and a scene with nothing in it.
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
	var wide := Label.new()
	wide.text = "x".repeat(400)
	var wide_holder := Node2D.new()
	wide_holder.add_child(wide)
	var found: Array[String] = await _look_at("planted", wide_holder, [])
	if not found.any(func(failure: String) -> bool: return failure.contains("runs off the window")):
		failures.append("the planted line of 400 x was not seen running off the window")
	var too_low := Rect2(24, SCREEN_HEIGHT - BOTTOM_MARGIN - 40 + 4, 1232, 40)
	failures += await _planted_wrapped("too tall", too_low, "a panel ending 4 px too low")
	failures += await _planted_wrapped("below its ceiling", too_low, "a panel named in NOT_YET_FITTED", too_low.end.y - 2)
	failures += await _planted_wrapped("too wide", Rect2(1000, 8, 600, 40), "a header laid past the edge")
	_counter.errors = 0
	if (await _look_at("planted", Node2D.new(), [])).is_empty():
		failures.append("an empty scene passed: this check would pass a blank screen")
	failures += await _planted_english_pad()
	return failures


# A legend whose pad line was written in English and never rebuilt: the
# demo that forgot to call `add_to` again when the language changed.
func _planted_english_pad() -> Array[String]:
	_counter.errors = 0
	var holder := Node2D.new()
	var legend := Legend.new()
	legend.name = "Legend"
	var pad := PadAsKeys.new()
	pad.use({JOY_BUTTON_DPAD_UP: KEY_UP}, [KEY_A, KEY_D, KEY_W, KEY_S], true)
	holder.add_child(legend)
	holder.add_child(pad)
	TranslationServer.set_locale("en")
	pad.add_to(legend)
	var found: Array[String] = await _look_at("planted", holder, [])
	if not found.any(func(failure: String) -> bool: return failure.contains("shows the English pad: ")):
		return ["the planted pad line in English was not seen: %s" % [found]]
	return []


# A wrapped Label laid at `box`, as the tactical header is, saying `words`,
# under `ceiling` as if NOT_YET_FITTED named it (none when negative): the
# check must find it running off the window. Its minimum height is the
# box's, so it ends where the box does, a few words in it or not.
func _planted_wrapped(what: String, box: Rect2, words: String, ceiling: float = -1.0) -> Array[String]:
	_counter.errors = 0
	var wrapped := Label.new()
	wrapped.name = "Planted"
	wrapped.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wrapped.position = box.position
	wrapped.custom_minimum_size = box.size
	wrapped.text = words
	var holder := CanvasLayer.new()
	holder.add_child(wrapped)
	if ceiling >= 0.0:
		_ceilings["planted:Planted"] = ceiling
	var found: Array[String] = await _look_at("planted", holder, [])
	_ceilings.erase("planted:Planted")
	if not found.any(func(failure: String) -> bool: return failure.contains("runs off the window")):
		return ["the planted wrapped Label %s was not seen running off the window" % what]
	return []


func _walk(node: Node) -> Array[Node]:
	var found: Array[Node] = [node]
	for child: Node in node.get_children():
		found += _walk(child)
	return found
