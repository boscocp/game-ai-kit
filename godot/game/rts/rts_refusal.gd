## An RTS refusal in the language on screen: "a mortar needs a lab first"
## becomes "morteiro: antes, um laboratório".
##
## `RtsRules.why_refused` says why an order is refused in English, and the
## rules and the AIs read those words -- an empty refusal is a yes -- so they
## are not translated where they are written; the addon `ai_rts_core` has no
## table at all. The shapes it writes are copied here as keys, a
## `{placeholder}` for each value, and a refusal is matched against them
## where it reaches the screen, as `TacticalRefusal` does for the board (T79).
## A test reads `rts_rules.gd` and holds every refusal it can write to one
## of these shapes, so a reworded refusal fails there instead of falling
## back to English on the screen.
##
## When not to use it: for a sentence written in this module, which is a
## key already; or anywhere the words are compared rather than shown.
class_name RtsRefusal
extends RefCounted

## The rules' refusals, as `RtsRules` words them.
const SHAPES: Array[String] = [  # shown through tr()
	"there is no order called {order}",
	"an order needs at least one unit",
	"unit {id} is not one of yours",
	"unit {id} is a {kind}, which trains nothing",
	"unit {id} is a {kind} and cannot {order}",
	"only a worker can {order}, and unit {id} is a {kind}",
	"{cell} is off the board",
	"nobody can stand on {cell}",
	"unit {id} is not in sight",
	"unit {id} is nothing to gather",
	"unit {id} is not an enemy",
	"unit {id} is not a building of yours",
	"unit {id} is not damaged",
	"one worker builds a building",
	"{kind} is not something a worker builds",
	"{cell} is not in sight",
	"{cell} is not free to build on",
	"one building trains at a time",
	"unit {id} is still being built",
	"a {kind} does not train a {what}",
	"unit {id} already has {count} in its queue",
	"a {kind} needs {supply} supply and you have {free} free of {cap}",
	"unit {id} is already armed",
	"unit {id} is already arming",
	"a {kind} needs a {needed} first",
	"a {kind} costs {price} {resource} and you have {held}",
]
## The placeholders that hold a name, translated too; the rest are numbers
## and cells. An order's name ("gather", "build") is `RtsCommand`'s own.
const NAMES: Array[String] = ["kind", "what", "needed", "resource", "order"]
# Each shape as an anchored pattern, built the first time one is needed.
static var _patterns: Array[RegEx] = []


## `refusal` in the language on screen: a rules refusal by its shape, with
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


# The values a match captured, the names among them translated.
static func _values(found: RegExMatch) -> Dictionary:
	var values: Dictionary = {}
	for name: String in found.names:
		var value: String = found.get_string(name)
		values[name] = RtsWords.word(value) if name in NAMES else value
	return values


# A shape as a regular expression: its text literal, each `{name}` a group.
static func _pattern_of(shape: String) -> String:
	var pieces: PackedStringArray = shape.split("{")
	var pattern: String = _quoted(pieces[0])
	for piece: String in pieces.slice(1):
		var closing: int = piece.find("}")
		pattern += "(?<%s>.+?)" % piece.left(closing) + _quoted(piece.substr(closing + 1))
	return pattern


static func _quoted(text: String) -> String:
	var quoted: String = ""
	for character: String in text:
		quoted += ("\\" + character) if "\\^$.|?*+()[]{}".contains(character) else character
	return quoted
