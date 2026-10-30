## One learning vector: the board it describes, and the numbers it claims.
##
## Separate from the runner that reads the files, for the reason the other two
## families learned the hard way: a runner is a `SceneTree`, a `SceneTree` is
## awkward to test, and rules living where no test can reach them can be
## deleted one at a time with every check in the repository staying green.
## `lint-selftests` cannot help -- it only looks inside `scripts/`.
##
## When not to use it: anything but learning vectors. The shape is specific
## and is documented in `spec/vectors/learning/README.md`.
class_name LearningVector
extends RefCounted

## How far two implementations of the same arithmetic may differ.
##
## Scaled by the size of the expected answer, so a prediction of 9.0 is held
## as tightly as one of 0.6. Doubles agree to about 1e-16 relative, so this is
## seven orders of margin: it catches a different formula, never a different
## libm.
const TOLERANCE: float = 1e-9

## The three things a case can be: a row handed straight to a model, a fight
## read off the board, or a side's run at a node.
const KINDS: Array[String] = ["row", "combat", "capture"]

const BOARD_FIELDS: Array[String] = ["width", "height", "costs", "units"]
const UNIT_FIELDS: Array[String] = ["id", "faction", "x", "y", "health"]


## Why this dictionary is not a usable vector, or "" when it is one.
static func why_not_a_vector(data: Dictionary) -> String:
	var published: TacticalWeights = models_of(data)
	if not published.is_loaded():
		return published.error
	if not (data.get("cases") is Array) or (data["cases"] as Array).is_empty():
		return "V1 the vector claims nothing: `cases` is missing or empty"
	var board: String = _why_board_is_wrong(data)
	if board != "":
		return board
	for index: int in range((data["cases"] as Array).size()):
		var wrong: String = _why_a_case_is_wrong(data, data["cases"][index], index)
		if wrong != "":
			return wrong
	return ""


## The models this vector carries, as the game would load them.
##
## The vector carries its own weights rather than reading the published ones,
## so retraining cannot change what a conformance vector claims. What it pins
## is the arithmetic, which is the thing two languages have to agree on.
static func models_of(data: Dictionary) -> TacticalWeights:
	return TacticalWeights.from_dictionary(data, "the vector")


## The board this vector describes, or null when it describes none.
static func board_of(data: Dictionary) -> BoardState:
	if not (data.get("board") is Dictionary):
		return null
	var described: Dictionary = data["board"]
	var graph := GakGridGraph.new(int(described["width"]), int(described["height"]))
	for y: int in range(int(described["height"])):
		for x: int in range(int(described["width"])):
			graph.set_cost(Vector2i(x, y), int(described["costs"][y][x]))
	var units: Array[Unit] = []
	# A unit may name its type (T44), one of the tactical board's walkers, so
	# the counter table can be read off it; an untyped unit has none.
	var types: Dictionary = TacticalRules.unit_types()
	for entry: Dictionary in described["units"]:
		var kind: UnitType = types[entry["type"]] if entry.has("type") else null
		units.append(Unit.new(
			int(entry["id"]), int(entry["faction"]),
			Vector2i(int(entry["x"]), int(entry["y"])), int(entry["health"]), 3, kind,
		))
	return BoardState.new(graph, units, 0)


## Everything this vector claims, checked against the addon.
static func check(name: String, data: Dictionary) -> Array[String]:
	var published: TacticalWeights = models_of(data)
	var state: BoardState = board_of(data)
	var failures: Array[String] = []
	for case: Dictionary in data["cases"]:
		failures += _check_case(name, case, state, published)
	return failures


# One case: the row the board produces, and what the model says about it.
static func _check_case(name: String, case: Dictionary, state: BoardState,
		published: TacticalWeights) -> Array[String]:
	var label: String = "%s [%s]" % [name, str(case["why"])]
	var failures: Array[String] = []
	var expected: Dictionary = case["features"]
	var row: Dictionary = _row_for(case, state, published)
	if not row.is_empty():
		failures += _compare_rows(label, expected, row)
	var model: LearnedModel = published.model(_model_name(case))
	var predicted: float = model.predict_named(expected)
	if not _close_enough(predicted, float(case["prediction"])):
		failures.append("%s: C2 the model answers %.12f, and the vector says %.12f" % [
			label, predicted, case["prediction"],
		])
	return failures


# The row this case's board produces, or {} for a case that supplies its own.
static func _row_for(case: Dictionary, state: BoardState,
		published: TacticalWeights) -> Dictionary:
	if case["kind"] == "combat":
		return BoardFeatures.combat_row(
			state, state.unit_by_id(int(case["attacker"])),
			state.unit_by_id(int(case["defender"])), published)
	if case["kind"] == "capture":
		var node := Vector2i(int(case["node"][0]), int(case["node"][1]))
		return BoardFeatures.capture_row(state, int(case["faction"]), node, published)
	return {}


# Feature by feature, both ways round: a row with a feature the vector does
# not mention is as wrong as one missing a feature it does.
static func _compare_rows(label: String, expected: Dictionary,
		produced: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	for feature: String in expected:
		if not produced.has(feature):
			failures.append("%s: C1 the board produced no `%s`" % [label, feature])
		elif not _close_enough(float(produced[feature]), float(expected[feature])):
			failures.append(_disagreed(label, feature, produced, expected))
	for feature: String in produced:
		if not expected.has(feature):
			failures.append("%s: C1 the board produced `%s`, which the vector does not mention" % [label, feature])
	return failures


# The sentence for one feature that came out differently, out of line so the
# loop above stays within the nesting the readability gate allows.
static func _disagreed(label: String, feature: String, produced: Dictionary,
		expected: Dictionary) -> String:
	return "%s: C1 `%s` came out %s, and the vector says %s" % [
		label, feature, produced[feature], expected[feature],
	]


# Two numbers the same, allowing for the last places of a double.
static func _close_enough(one: float, other: float) -> bool:
	return absf(one - other) <= TOLERANCE * maxf(1.0, absf(other))


# Which model a case is about: the one it names, or the one its kind implies.
static func _model_name(case: Dictionary) -> String:
	if case.has("model"):
		return str(case["model"])
	return "combat" if case["kind"] == "combat" else "capture"


# Why no board can be built from this vector, or "" -- including "it has none
# and needs none".
static func _why_board_is_wrong(data: Dictionary) -> String:
	if not data.has("board"):
		return ""
	if not (data["board"] is Dictionary):
		return "V7 `board` is not an object"
	var described: Dictionary = data["board"]
	for field: String in BOARD_FIELDS:
		if not described.has(field):
			return "V7 the board has no `%s`" % field
	var shape: String = _why_costs_are_wrong(described)
	if shape != "":
		return shape
	return _why_units_are_wrong(described)


# The terrain: one row per line of the board, one cost per column.
static func _why_costs_are_wrong(described: Dictionary) -> String:
	var height: int = int(described["height"])
	var width: int = int(described["width"])
	if width <= 0 or height <= 0:
		return "V7 the board is %dx%d, which holds nothing" % [width, height]
	if not (described["costs"] is Array) or (described["costs"] as Array).size() != height:
		return "V7 the board is %d tall and its costs have %s rows" % [
			height, _size_of(described["costs"]),
		]
	for row: Variant in described["costs"]:
		if not (row is Array) or (row as Array).size() != width:
			return "V7 the board is %d wide and a row of costs has %s entries" % [width, _size_of(row)]
	return ""


# The units: every field, distinct ids, on the board, one to a cell.
static func _why_units_are_wrong(described: Dictionary) -> String:
	if not (described["units"] is Array) or (described["units"] as Array).is_empty():
		return "V7 the board has no units on it"
	var seen_ids: Dictionary = {}
	var seen_cells: Dictionary = {}
	for entry: Variant in described["units"]:
		var wrong: String = _why_a_unit_is_wrong(entry, described)
		if wrong != "":
			return wrong
		if seen_ids.has(entry["id"]):
			return "V7 two units share the id %d" % int(entry["id"])
		var cell := Vector2i(int(entry["x"]), int(entry["y"]))
		if seen_cells.has(cell):
			return "V7 two units stand on %s" % cell
		seen_ids[entry["id"]] = true
		seen_cells[cell] = true
	return ""


# One unit: every field present, and standing somewhere that exists.
static func _why_a_unit_is_wrong(entry: Variant, described: Dictionary) -> String:
	if not (entry is Dictionary):
		return "V7 a unit is not an object"
	for field: String in UNIT_FIELDS:
		if not (entry as Dictionary).has(field):
			return "V7 a unit has no `%s`" % field
	var cell := Vector2i(int(entry["x"]), int(entry["y"]))
	var inside: bool = (
		cell.x >= 0 and cell.y >= 0
		and cell.x < int(described["width"]) and cell.y < int(described["height"])
	)
	if not inside:
		return "V7 unit %d stands on %s, which is off the board" % [int(entry["id"]), cell]
	if int(entry["health"]) <= 0:
		return "V7 unit %d has no health, so no board would carry it" % int(entry["id"])
	return ""


# One case: a kind, a row, a claim, and whatever that kind needs beside it.
static func _why_a_case_is_wrong(data: Dictionary, case: Variant,
		index: int) -> String:
	if not (case is Dictionary):
		return "V2 case %d is not an object" % index
	var entry: Dictionary = case
	if not KINDS.has(str(entry.get("kind"))):
		return "V2 case %d is of kind `%s`, which is none of %s" % [
			index, entry.get("kind"), ", ".join(KINDS),
		]
	if not (entry.get("features") is Dictionary) or (entry["features"] as Dictionary).is_empty():
		return "V3 case %d gives the model no features" % index
	if not _is_a_number(entry.get("prediction")):
		return "V4 case %d claims no prediction" % index
	# Required, and it used to be required by the Python half only -- which
	# read `case["why"]` and died with a KeyError naming a dictionary key
	# rather than the vector, while this side quietly defaulted. A case with
	# no `why` is a case whose failure nobody can read.
	if not (entry.get("why") is String) or str(entry["why"]).strip_edges() == "":
		return "V10 case %d does not say what it is for" % index
	return _why_the_case_cannot_be_run(data, entry, index)


# What this kind of case needs that the vector may not have given it.
static func _why_the_case_cannot_be_run(data: Dictionary, entry: Dictionary,
		index: int) -> String:
	if not data["models"].has(_model_name(entry)):
		return "V5 case %d is about the model `%s`, which the vector does not publish" % [
			index, _model_name(entry),
		]
	if entry["kind"] == "row":
		return ""
	if not data.has("board"):
		return "V6 case %d reads a board, and the vector describes none" % index
	if entry["kind"] == "combat":
		return _why_the_fight_cannot_be_run(data, entry, index)
	return _why_the_run_at_the_node_cannot_be_run(data, entry, index)


# A fight needs two different units, both of them on the board.
static func _why_the_fight_cannot_be_run(data: Dictionary, entry: Dictionary,
		index: int) -> String:
	var state: BoardState = board_of(data)
	for side: String in ["attacker", "defender"]:
		if not entry.has(side) or state.unit_by_id(int(entry[side])) == null:
			return "V8 case %d names no `%s` that is on the board" % [index, side]
	if int(entry["attacker"]) == int(entry["defender"]):
		return "V8 case %d has unit %d fighting itself" % [index, int(entry["attacker"])]
	return ""


# A run at a node needs a node, and a side with something to send.
static func _why_the_run_at_the_node_cannot_be_run(data: Dictionary,
		entry: Dictionary, index: int) -> String:
	if not (entry.get("node") is Array) or (entry["node"] as Array).size() != 2:
		return "V9 case %d names no node as a pair of coordinates" % index
	var state: BoardState = board_of(data)
	if not entry.has("faction") or state.units_of(int(entry["faction"])).is_empty():
		return "V9 case %d is about a side with no units on the board" % index
	return ""


# A finite int or float, whatever JSON made of it.
static func _is_a_number(value: Variant) -> bool:
	if not (value is float or value is int):
		return false
	return is_finite(float(value))


# How many entries, for a message, whatever was actually there.
static func _size_of(value: Variant) -> String:
	return str((value as Array).size()) if value is Array else "no"
