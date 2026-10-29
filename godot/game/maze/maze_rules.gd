## The maze and its rules, read from `maze.json` and `rules.json` beside this
## file -- byte-for-byte copies of `spec/maze/`, which Python reads too
## (ADR 0007): every number a step depends on is there, and `rules.json`'s
## "about" is the rules in words, after Pittman's Pac-Man Dossier.
##
## A cell is a `Vector2i`, (column, row), row 0 at the top, so up is
## row - 1. A direction is one of the names "up", "left", "down", "right",
## as the files and the vectors write them.
##
## These are the board's facts and the Dossier's measure; what a ghost does
## with them is `MazeGhost`, and a whole step is `MazeGame`.
##
## When not to use it: a maze with tunnels, a ghost house or energizers --
## none is modelled, and `rules.json` says so rather than half-model them.
class_name MazeRules
extends RefCounted

const MAZE_FILE: String = "res://game/maze/maze.json"
const RULES_FILE: String = "res://game/maze/rules.json"
const WALL: String = "#"
const SCATTER: String = "scatter"
const CHASE: String = "chase"

static var _maze: Dictionary = {}
static var _rules: Dictionary = {}


## The maze file: rows, pellets, where everyone starts, the ghosts' corners.
static func maze() -> Dictionary:
	if _maze.is_empty():
		_maze = _read(MAZE_FILE)
	return _maze


## The rules file: directions, tie order, schedule, precision, targets.
static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = _read(RULES_FILE)
	return _rules


## A cell from the files' [column, row].
static func cell_of(pair: Array) -> Vector2i:
	return Vector2i(int(pair[0]), int(pair[1]))


## Whether `cell` is floor. Outside the rows counts as wall.
static func is_open(cell: Vector2i) -> bool:
	var rows: Array = maze()["rows"]
	if cell.y < 0 or cell.y >= rows.size() or cell.x < 0 or cell.x >= String(rows[cell.y]).length():
		return false
	return String(rows[cell.y])[cell.x] != WALL


## Every floor cell, row by row from the top left.
static func floor_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var extent: Vector2i = size()
	for index: int in range(extent.x * extent.y):
		var cell := Vector2i(index % extent.x, index / extent.x)
		if is_open(cell):
			cells.append(cell)
	return cells


## How many cells wide and tall the maze is, walls included.
static func size() -> Vector2i:
	var rows: Array = maze()["rows"]
	return Vector2i(String(rows[0]).length(), rows.size())


## One cell's step towards `direction`.
static func step_of(direction: String) -> Vector2i:
	return cell_of(rules()["directions"][direction])


## The cell one step from `cell` towards `direction`, wall or not.
static func moved(cell: Vector2i, direction: String) -> Vector2i:
	return cell + step_of(direction)


## The direction back the way `direction` came.
static func reverse(direction: String) -> String:
	for name: String in rules()["directions"]:
		if step_of(name) == -step_of(direction):
			return name
	return direction


## The ghosts' mode during step `step`, counted from 0, by the schedule:
## the Dossier's level one, each of its seconds two steps.
static func mode_at(step: int) -> String:
	var start: int = 0
	var schedule: Array = rules()["schedule"]
	for period: Dictionary in schedule:
		if period["steps"] == null or step < start + int(period["steps"]):
			return period["mode"]
		start += int(period["steps"])
	return schedule[-1]["mode"]


## The straight line between two cells, squared: a whole number, so the
## comparison is exact here and in Python.
static func squared_distance(first: Vector2i, second: Vector2i) -> int:
	var apart: Vector2i = first - second
	return apart.x * apart.x + apart.y * apart.y


## The chance an imprecise ghost keeps the Dossier's way at a fork.
static func precision() -> float:
	return float(rules()["precision"])


## Whether the ghosts are imprecise in `mode`: in chase only.
static func imprecise_in(mode: String) -> bool:
	return mode in rules()["imprecise_in"]


# `JSON.new().parse()`, not `parse_string()`, which prints an engine error of
# its own on a bad file (docs/godot/reading-json-in-godot.md). A file that
# cannot be read is named, once, and gives {}.
static func _read(path: String) -> Dictionary:
	var reader := JSON.new()
	if reader.parse(FileAccess.get_file_as_string(path)) != OK or not reader.data is Dictionary:
		push_error("MazeRules: %s could not be read" % path)  # not shown: for the log
		return {}
	return reader.data
