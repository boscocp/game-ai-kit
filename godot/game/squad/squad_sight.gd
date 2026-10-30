## Who can see whom on the tactical map: trees and rock block a line, as
## `TacticalRules` promised they would once there was fog.
##
## A line is drawn cell by cell with Bresenham's algorithm, and blocked by a
## tree or a rock on it -- except on a cell beside either end. A piece leans
## out past its own cover to shoot, and shoots at a target behind its cover,
## paying the cover's penalty instead (`SquadCover`); a line that the cover
## itself blocked would leave cover nothing to do. Pieces never block a line.
##
## The line is drawn from the end that sorts first, so it is the same line
## both ways: if one piece sees another, it is seen back. Bresenham from the
## other end can pass through different cells, and a sight that was not
## mutual would be a rule nobody could read off the board.
##
## Complexity: O(distance) per line.
##
## When not to use it: real fog on a large map. A line per pair is fine for
## eight pieces; a big map wants a field of view per piece (shadowcasting).
class_name SquadSight
extends RefCounted

const ROCK: String = "#"
const TREES: String = "T"


## True when nothing on `rows` blocks the line between the two cells.
static func line_clear(rows: Array[String], one: Vector2i, other: Vector2i) -> bool:
	var from: Vector2i = one if _sorts_first(one, other) else other
	var to: Vector2i = other if from == one else one
	for cell: Vector2i in line(from, to):
		if _blocks(rows, cell) and not _beside(cell, from) and not _beside(cell, to):
			return false
	return true


## True when `viewer` sees `cell`: within its type's sight, in steps, and
## with the line clear.
static func sees(rows: Array[String], viewer: Unit, cell: Vector2i) -> bool:
	return steps(viewer.cell, cell) <= viewer.type.sight and line_clear(rows, viewer.cell, cell)


## Steps between two cells, no diagonals: how far a shot or a look reaches.
static func steps(one: Vector2i, other: Vector2i) -> int:
	return absi(one.x - other.x) + absi(one.y - other.y)


## The cells strictly between `from` and `to` on Bresenham's line.
static func line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var delta := Vector2i(absi(to.x - from.x), -absi(to.y - from.y))
	var step := Vector2i(signi(to.x - from.x), signi(to.y - from.y))
	var error: int = delta.x + delta.y
	var here: Vector2i = from
	while here != to:
		var doubled: int = 2 * error
		if doubled >= delta.y:
			error += delta.y
			here.x += step.x
		if doubled <= delta.x:
			error += delta.x
			here.y += step.y
		if here != to:
			cells.append(here)
	return cells


static func _blocks(rows: Array[String], cell: Vector2i) -> bool:
	var letter: String = rows[cell.y][cell.x]
	return letter == ROCK or letter == TREES


static func _beside(cell: Vector2i, end: Vector2i) -> bool:
	return steps(cell, end) == 1


static func _sorts_first(one: Vector2i, other: Vector2i) -> bool:
	return one.x < other.x or (one.x == other.x and one.y <= other.y)
