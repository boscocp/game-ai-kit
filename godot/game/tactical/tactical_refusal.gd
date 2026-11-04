## A board's refusal in the language on screen: "ram needs the forge upgrade
## first" becomes "aríete: compre antes a melhoria forja".
##
## `BoardState` says why a move, a build or a purchase is refused in English,
## and the logic reads those words too -- the AI compares them with LEGAL, the
## tests and the RTS read them -- so they are not translated where they are
## written (T79's review). The shapes the board writes are copied here as
## keys, a `{placeholder}` for each value, and a refusal is matched against
## them where it reaches the screen. A test reads `board_state.gd` and holds
## every refusal it can write to one of these shapes, so a reworded refusal
## fails there instead of falling back to English on the screen.
##
## When not to use it: for a refusal written in this module, which is a key
## already; or anywhere the words are compared rather than shown.
class_name TacticalRefusal
extends RefCounted

## The board's refusals, as `BoardState.why_*_refused` words them.
const SHAPES: Array[String] = [  # shown through tr()
	"no unit with id {id} is on the board",
	"unit {id} belongs to faction {owner}, and faction {mover} is to move",
	"unit {id} is a {kind} and cannot move",
	"the move costs {cost} and unit {id} has {left} movement left",
	"the side to move has no building with id {id}",
	"the order names no unit type",
	"unit {id} does not produce {kind}",
	"{kind} needs the {upgrade} upgrade first",
	"{kind} costs {cost} and the side to move has {funds}",
	"the side to move already owns {upgrade}",
	"{step} does not follow {previous}; a step is one cell, no diagonals",
	"{step} is off the board",
	"{step} is blocked",
	"{step} is occupied by unit {id}",
	"{cell} is not next to unit {id}",
	"a {kind} cannot stand on {cell}",
]
## The placeholders that hold a piece's or an upgrade's name, which are
## translated too; the rest are numbers and cells.
const NAMES: Array[String] = ["kind", "upgrade"]

# Each shape as an anchored pattern, built the first time one is needed.
static var _patterns: Array[RegEx] = []


## `refusal` in the language on screen: a board refusal by its shape, with
## the names in it translated; anything else through the translation tables,
## which return a key's translation or the text itself.
static func words(refusal: String) -> String:
	if _patterns.is_empty():
		for shape: String in SHAPES:
			_patterns.append(RegEx.create_from_string("^" + _pattern_of(shape) + "$"))
	for index: int in range(SHAPES.size()):
		var found: RegExMatch = _patterns[index].search(refusal)
		if found != null:
			return TranslationServer.translate(SHAPES[index]).format(_values(found))
	return TranslationServer.translate(refusal)


## `refusal` worded by the first of `shapes` it matches, the names in it
## translated, or "" when it matches none: for a mode whose refusals have
## shapes of their own, such as the XCOM-style shot's (T85). Each shape is a
## key of that mode's table.
static func worded_by(refusal: String, shapes: Array[String]) -> String:
	for shape: String in shapes:
		var found: RegExMatch = RegEx.create_from_string("^" + _pattern_of(shape) + "$").search(refusal)
		if found != null:
			return TranslationServer.translate(shape).format(_values(found))
	return ""


# The values a match captured, the names among them translated.
static func _values(found: RegExMatch) -> Dictionary:
	var values: Dictionary = {}
	for name: String in found.names:
		var value: String = found.get_string(name)
		values[name] = TacticalStatus.piece(value) if name in NAMES else value
	return values


# A shape as a regular expression: its text literal, each `{name}` a group.
static func _pattern_of(shape: String) -> String:
	var pattern: String = ""
	var pieces: PackedStringArray = shape.split("{")
	pattern += _quoted(pieces[0])
	for piece: String in pieces.slice(1):
		var closing: int = piece.find("}")
		pattern += "(?<%s>.+?)" % piece.left(closing) + _quoted(piece.substr(closing + 1))
	return pattern


static func _quoted(text: String) -> String:
	var quoted: String = ""
	for character: String in text:
		quoted += ("\\" + character) if "\\^$.|?*+()[]{}".contains(character) else character
	return quoted
