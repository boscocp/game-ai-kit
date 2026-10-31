## The XCOM-style mode's numbers, read from `rules.json` beside this file --
## a byte-for-byte copy of `spec/squad/rules.json`, which the Python twin
## reads too (ADR 0007; `python/tests/test_squad_vectors.py` holds the copies).
##
## A piece's aim, defence and damage live here, not on `UnitType`: they are
## this mode's, and the Advance Wars game has no use for them. What the board
## does read -- how far a piece walks, reaches and sees -- is put on the
## mode's own `UnitType`s, built here under the tactical names so the
## tactical pictures and words find them.
##
## When not to use it: the Advance Wars pieces. Their table is
## `TacticalRules`; a piece here shares only its name and its ground.
class_name SquadTable
extends RefCounted

const RULES_PATH: String = "res://game/squad/rules.json"

static var _rules: Dictionary = {}


## The whole table, read once.
static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	return _rules


## One number of one piece, such as `number("mortar", "aim")`, as an int:
## JSON reads every number as a float.
static func number(piece_name: String, field: String) -> int:
	return int(rules()["pieces"][piece_name][field])


## How far one action walks a piece of this kind: half its type's movement.
static func action(piece_name: String) -> int:
	return number(piece_name, "action")


## The cover a cell of `full` or `half` cover is worth.
static func cover_worth(kind: String) -> int:
	return int(rules()["cover"][kind])


## The squad's pieces, in the order each side's are placed.
static func squad() -> Array[String]:
	var names: Array[String] = []
	names.assign(rules()["squad"])
	return names


## The mode's unit types, by name, fresh each call. Movement is two actions,
## the reach is the shot's range and the sight is the rules'; each walks on
## the ground its tactical namesake walks on, so the wader still wades.
static func unit_types() -> Dictionary:
	var tactical: Dictionary = TacticalRules.unit_types()
	var types: Dictionary = {}
	for piece_name: String in squad():
		var kind := UnitType.new(piece_name, 2 * action(piece_name), number(piece_name, "range"),
			number(piece_name, "sight"), 0)
		kind.mover = (tactical[piece_name] as UnitType).mover
		types[piece_name] = kind
	return types
