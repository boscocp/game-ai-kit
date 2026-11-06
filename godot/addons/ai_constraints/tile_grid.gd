## A map of tiles declared as a `ConstraintProblem`: a cell a variable, a
## tile a value, and two neighbouring cells a binary constraint saying which
## tiles may stand together -- the problem `WaveCollapse` solves (T96).
##
## The adjacency is a **table written by hand**, a *tile set*: a Dictionary
## whose `tiles` lists, for each tile, its one-character name (`tile`), its
## `weight` -- how often it is drawn -- and the tiles that may stand beside
## it left or right (`left_right`) and above or below it (`up_down`), each
## a String of tile characters. Nothing is counted from an example map:
## mxgmn's *overlapping* model learns its adjacency from a picture, and this
## is his *simple tiled* model, which is told it.
##
## Adjacency here is **symmetric** within an axis: `left_right` lists the
## tiles allowed on *either* side, so a table cannot say "high ground only to
## the cliff's left". mxgmn's simple tiled model has directed pairs; a tile
## set with a direction needs `left` and `right` (and `up` and `down`) lists,
## which this does not have.
##
## A pair is said from both sides or not at all. A table in which water may
## have a bridge below it and the bridge may not have water above it is
## refused by `why_not`, not quietly made to agree: the one who wrote it
## meant one of the two, and only they know which.
##
## The cells are declared row by row, "x,y" each, and the constraints cell
## by cell, the one with the cell to the right before the one with the cell
## below. That order is what AC-3's queue follows, so it is part of what
## `spec/vectors/constraints/collapse/` holds both languages to.
##
## Complexity: linear in the cells; two constraints a cell.
##
## When not to use it: for a map whose rules are not about neighbours --
## "a path from here to there", "one exit" -- which are global constraints
## on the whole map, and belong in `ConstraintProblem.add_global` or in a
## check after it is built.
class_name TileGrid
extends RefCounted

## The keys a tile of a tile set has, no more and no fewer.
const TILE_KEYS: Array[String] = ["left_right", "tile", "up_down", "weight"]
## What a map's row shows for a cell no tile was chosen for yet.
const UNDECIDED: String = "?"


## The variable a cell is: "x,y".
static func cell_name(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


## The cell a variable is, from its "x,y".
static func cell_of(name: String) -> Vector2i:
	var parts: PackedStringArray = name.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))


## Tile -> weight, in the order the tile set lists them. Every choice of
## `WaveCollapse` that walks the tiles walks them in this order, so the same
## tiles give the same sums, to the bit, in both languages.
static func weights_of(tile_set: Dictionary) -> Dictionary:
	var weights: Dictionary = {}
	for entry: Dictionary in tile_set["tiles"]:
		weights[entry["tile"]] = int(entry["weight"])
	return weights


## What is wrong with `tile_set`, or "" when nothing is: a tile without its
## four keys or with a weight below 1, a tile listed twice, a neighbour that
## is no tile, or a pair said from one side only.
static func why_not(tile_set: Dictionary) -> String:
	var tiles: Variant = tile_set.get("tiles")
	if not tiles is Array or (tiles as Array).is_empty():
		return "a tile set lists at least one tile"
	var by_name: Dictionary = {}
	for entry: Dictionary in tiles:
		var keys: Array = entry.keys()
		keys.sort()
		if keys != TILE_KEYS or (entry["tile"] as String).length() != 1:
			return "a tile has the keys %s and one character: %s" % [TILE_KEYS, entry]
		if float(entry["weight"]) != floorf(float(entry["weight"])) or float(entry["weight"]) < 1.0:
			return "the tile '%s' needs a whole weight of 1 or more" % entry["tile"]
		if by_name.has(entry["tile"]):
			return "a tile is listed twice"
		by_name[entry["tile"]] = entry
	for axis: String in ["left_right", "up_down"]:
		var wrong: String = _one_sided(by_name, axis)
		if wrong != "":
			return wrong
	return ""


# The first pair along `axis` that names no tile or is said from one side.
static func _one_sided(by_name: Dictionary, axis: String) -> String:
	for tile: String in by_name:
		var wrong: String = _one_sided_from(by_name, axis, tile)
		if wrong != "":
			return wrong
	return ""


# The first tile `tile` names along `axis` that is no tile, or does not name
# `tile` back.
static func _one_sided_from(by_name: Dictionary, axis: String, tile: String) -> String:
	for other: String in (by_name[tile][axis] as String):
		if not by_name.has(other):
			return "'%s' names '%s' beside it, which is no tile" % [tile, other]
		if not (by_name[other][axis] as String).contains(tile):
			return "'%s' may stand %s of '%s', but not '%s' of '%s'" % [tile, axis, other, other, tile]
	return ""


## A variable per cell, row by row, each with every tile -- or, for a cell
## in `pinned` ("x,y" -> the tiles it may be), only those -- and, cell by
## cell, a constraint with the cell to its right, then with the one below.
static func problem(tile_set: Dictionary, size: Vector2i, pinned: Dictionary = {}) -> ConstraintProblem:
	var beside: Dictionary = {}
	for entry: Dictionary in tile_set["tiles"]:
		beside[entry["tile"]] = entry
	var every_tile: Array = weights_of(tile_set).keys()
	var made := ConstraintProblem.new()
	for y: int in range(size.y):
		for x: int in range(size.x):
			var name: String = cell_name(Vector2i(x, y))
			made.add_variable(name, pinned.get(name, every_tile))
	var sideways: Callable = func(left: String, right: String) -> bool: return (beside[left]["left_right"] as String).contains(right)
	var upwards: Callable = func(above: String, below: String) -> bool: return (beside[above]["up_down"] as String).contains(below)
	for y: int in range(size.y):
		for x: int in range(size.x):
			_tie_to_the_right_and_below(made, Vector2i(x, y), size, [sideways, upwards])
	return made


# The constraint between `cell` and the cell to its right, then the one
# below, when they are on the map: `tests` holds the two adjacency tests.
static func _tie_to_the_right_and_below(made: ConstraintProblem, cell: Vector2i, size: Vector2i, tests: Array[Callable]) -> void:
	if cell.x + 1 < size.x:
		made.add_binary(cell_name(cell), cell_name(cell + Vector2i.RIGHT), tests[0], "left_right")
	if cell.y + 1 < size.y:
		made.add_binary(cell_name(cell), cell_name(cell + Vector2i.DOWN), tests[1], "up_down")


## The map as rows of characters, from "x,y" -> tile; a cell with no tile
## yet shows `UNDECIDED`.
static func rows_of(tiles: Dictionary, size: Vector2i) -> Array[String]:
	var rows: Array[String] = []
	for y: int in range(size.y):
		var row: String = ""
		for x: int in range(size.x):
			row += tiles.get(cell_name(Vector2i(x, y)), UNDECIDED)
		rows.append(row)
	return rows
