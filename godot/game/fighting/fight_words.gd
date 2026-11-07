## The fighting game's names and events in the language chosen (T80).
##
## An action, a situation, a dummy mode, a level, a stance, a button, a
## height: each is an identifier the rules, the opponents and the recordings
## compare, so it stays English where it is written and is translated only
## here, where it is drawn (the owner's rule, docs/godot/localisation.md).
## A move's name (`jab`, `side_kick`), a character's (`lancer`) and the
## frame data's terms (frame, startup, active, recovery, hitstun) stay as
## they are, as fighting-game players say them; the pt-BR glossary has them.
##
## The rules write each frame's events in English, and those words are in
## every frame's digest, which the replay gate compares -- so they are not
## translated where they are written. `event` matches the shapes the rules
## and `FightBoxes` write, copied here as keys, and a test replays the
## recorded fights and holds every event they produce to a shape.
##
## When not to use it: anywhere the words are compared rather than shown.
class_name FightWords
extends RefCounted

## Every identifier the screen shows, so the table holds each one. A test
## holds this list to `FightAction.ACTIONS`, the opponents' situations and
## the scene's modes: a name added there and missing here would show
## English without a sound.
const SHOWN: Array[String] = [  # shown through tr()
	"step in", "step out", "crouch", "jump", "high", "mid", "low", "overhead", "throw",
	"guard standing", "guard crouching", "evade",
	"after being hit", "after blocking", "it blocked", "it evaded", "it whiffed", "it crouches", "neutral",
	"stand", "jab", "low kick", "anti-air (sees you now)", "opponent: easy", "opponent: medium", "opponent: hard",
	"learner: easy", "learner: medium", "learner: hard", "bandit: easy", "bandit: medium", "bandit: hard",
	"ghost: exact", "ghost: nearest", "clone", "tree: easy", "tree: medium", "tree: hard",
	"easy", "medium", "hard",
	"standing", "crouching", "air",
	"light_punch", "heavy_punch", "light_kick", "heavy_kick",
	"(anything)", "nothing yet",
]
## Whole events, as `FightRules` and `FightBoxes` write them.
const EVENTS: Array[String] = [  # shown through tr()
	"p{first} cancels {from} into {to}",
	"p{first}'s {move} passes through p{second} (evading)",
	"p{first}'s throw is beaten by p{second}'s {move} (strike beats throw)",
	"the throws clash and both break",
	"trade",
	"p{first}'s {move} passes over p{second}",
	"p{first}'s {move} passes under p{second}",
	"p{first} is blocked by p{second} with {move}",
	"p{first} counter-hits p{second} with {move}",
	"p{first} hits p{second} with {move}",
	"p{first} throws p{second} with {move}",
]
## Why, in brackets after an event, as `FightRules._judge` and
## `FightBoxes.misses_vertically` write it.
const WHY: Array[String] = [  # shown through tr()
	"(a throw cannot be blocked)",
	"(caught evading, which cannot guard)",
	"(caught in the air, starting up)",
	"(in the air, which cannot guard)",
	"(holding away, {guard})",
	"(a low through a {guard} guard)",
	"(an overhead through a {guard} guard)",
	"(a high through a {guard} guard)",
	"(caught starting up)",
	"(a high misses a crouch)",
	"(a low misses a fighter in the air)",
	"(it is in the air)",
]
## The placeholders that hold a name, translated too; a move's stays.
const NAMES: Array[String] = ["guard"]

static var _events: Array[RegEx] = []
static var _whys: Array[RegEx] = []
static var _bracket := RegEx.create_from_string("^(.*?) (\\([^()]*\\))$")


## `identifier` as the screen shows it in the language chosen.
static func word(identifier: String) -> String:
	return TranslationServer.translate(identifier)


## One event of a frame in the language chosen: a whole shape, or a shape
## and the reason in brackets after it. One the shapes do not know is shown
## as the rules wrote it.
static func event(said: String) -> String:
	if _events.is_empty():
		_events = _patterns(EVENTS)
		_whys = _patterns(WHY)
	var whole: String = _matched(said, EVENTS, _events)
	if whole != "":
		return whole
	var split: RegExMatch = _bracket.search(said)
	if split == null:
		return said
	var main: String = _matched(split.get_string(1), EVENTS, _events)
	var why: String = _matched(split.get_string(2), WHY, _whys)
	return said if main == "" or why == "" else main + " " + why


## A learner's context, as `NGramPredictor.context` writes it -- "high >
## low" -- with each action's name translated.
static func context(said: String) -> String:
	var actions: PackedStringArray = []
	for action: String in said.split(" > "):
		actions.append(word(action))
	return " > ".join(actions)


## A row of a learner's table, as `NGramPredictor.rows` writes it --
## "high > low -> mid 3.0, low 1.0" -- with each action's name translated.
static func row(said: String) -> String:
	var halves: PackedStringArray = said.split(" -> ")
	if halves.size() != 2:
		return said
	var cells: PackedStringArray = []
	for cell: String in halves[1].split(", "):
		var weight: int = cell.rfind(" ")
		cells.append(cell if weight < 0 else word(cell.left(weight)) + cell.substr(weight))
	return context(halves[0]) + " -> " + ", ".join(cells)


## A frame's events, joined as the panel shows them.
static func events(said: Array[String]) -> String:
	var shown: PackedStringArray = []
	for one: String in said:
		shown.append(event(one))
	return ", ".join(shown)


static func _matched(said: String, shapes: Array[String], patterns: Array[RegEx]) -> String:
	for index: int in range(shapes.size()):
		var found: RegExMatch = patterns[index].search(said)
		if found != null:
			return TranslationServer.translate(shapes[index]).format(_values(found))
	return ""


# The values a match captured, the names among them translated.
static func _values(found: RegExMatch) -> Dictionary:
	var values: Dictionary = {}
	for name: String in found.names:
		values[name] = word(found.get_string(name)) if name in NAMES else found.get_string(name)
	return values


static func _patterns(shapes: Array[String]) -> Array[RegEx]:
	var made: Array[RegEx] = []
	for shape: String in shapes:
		var pieces: PackedStringArray = shape.split("{")
		var pattern: String = "^" + _quoted(pieces[0])
		for piece: String in pieces.slice(1):
			var closing: int = piece.find("}")
			# A value is one word -- a player's number, a move's name, a
			# guard -- with no bracket: the reason in brackets is matched on
			# its own, and a reworded event must not hide inside a value.
			pattern += "(?<%s>[^() ]+)" % piece.left(closing) + _quoted(piece.substr(closing + 1))
		made.append(RegEx.create_from_string(pattern + "$"))
	return made


static func _quoted(text: String) -> String:
	var quoted: String = ""
	for character: String in text:
		quoted += ("\\" + character) if "\\^$.|?*+()[]{}".contains(character) else character
	return quoted
