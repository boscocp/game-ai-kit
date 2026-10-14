## One move in checkers: the squares a piece passes through and what it takes.
##
## A multi-jump is one move, not several. The rules say a capture sequence,
## once begun, must be finished, so the half-finished sequence is never a
## position anybody gets to move from -- and the search must not see one either.
class_name CheckersMove
extends RefCounted

const COLUMNS: String = "abcdefgh"

## The square the piece starts on, then every square it lands on, in order.
var path: Array[Vector2i] = []

## The squares of the pieces it jumps, in the order it jumps them.
var captured: Array[Vector2i] = []

## True when the move ends with a man reaching the far row and being crowned.
var crowns: bool = false


func _init(squares: Array[Vector2i] = [], taken: Array[Vector2i] = [], crowned: bool = false) -> void:
	path = squares
	captured = taken
	crowns = crowned


## Where the piece starts.
func from() -> Vector2i:
	return path[0]


## Where the piece ends.
func to() -> Vector2i:
	return path[path.size() - 1]


## True for a jump, single or multiple.
func is_capture() -> bool:
	return not captured.is_empty()


## The move as a person reads it: `c3-d4` for a step, `c3xe5xg3` for a jump.
##
## Columns are a to h from the left, rows 1 to 8 from red's side, which is
## what the board draws along its edges.
func notation() -> String:
	var names: PackedStringArray = PackedStringArray()
	for square: Vector2i in path:
		names.append(square_name(square))
	return ("x" if is_capture() else "-").join(names)


## A square's name, as drawn along the board's edges.
static func square_name(square: Vector2i) -> String:
	return "%s%d" % [COLUMNS[square.x], CheckersBoard.SIZE - square.y]
