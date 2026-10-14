## A walking figure: one picture holding every frame, and the table that says
## which frame is where.
##
## A sheet is a grid of square frames, one row per way the figure can face and
## one column per moment of its walk. The table names the rows by facing, the
## columns of the walk in the order they play, the column it stands in once
## it has acted, and the square inside each frame the figure fills -- packs
## draw a 14-pixel soldier on a 32-pixel frame, and scaled whole it would be
## half the size of the pieces round it.
##
## Two tables exist, because two kinds of sheet do: the pack's (`puny`) and
## the generator's (`generated`). A sheet is only ever read through the table
## of where it came from, and `Art` is what knows that.
##
## When not to use it: an animation with timing per frame, events, or blending.
## That is Godot's `SpriteFrames` and `AnimationPlayer`, edited in the editor.
## Here a walk is a list of columns and a rate, and a reader sees all of it.
class_name UnitSheet
extends RefCounted

## The file, as `Art` names it. `Art.texture` turns it into a picture.
var path: String
## The side of one square frame, in the sheet's pixels.
var frame_pixels: int
## The square inside a frame that is drawn, in the frame's own pixels.
var figure: Rect2i
## Facing, as the step last taken, to the row drawn for it.
var rows: Dictionary
## The columns of the walk, in the order they are drawn, round and round.
var walk: Array[int]
## The column of a figure standing still: a unit that has acted this turn.
var stand: int


func _init(file: String, frame_side: int, inside: Rect2i, facing_rows: Dictionary,
		walk_columns: Array[int], stand_column: int) -> void:
	path = file
	frame_pixels = frame_side
	figure = inside
	rows = facing_rows
	walk = walk_columns
	stand = stand_column


## Puny Characters' layout, which both its soldiers share: 32-pixel frames, 24
## across, and a row for each of eight facings, clockwise from facing the
## reader. The walk is stand, left foot, stand, right foot -- columns 0, 2, 0,
## 3, read off the sheet, since the pack ships no table. Measured on all four
## sheets, the figure never leaves the 22-pixel square at (5, 3).
static func puny(file: String) -> UnitSheet:
	var facing: Dictionary = {Vector2i.DOWN: 0, Vector2i.RIGHT: 2, Vector2i.UP: 4, Vector2i.LEFT: 6}
	return UnitSheet.new(file, 32, Rect2i(5, 3, 22, 22), facing, [0, 2, 0, 3] as Array[int], 0)


## The generator's layout, which is the walk LoRA's (T31, T33): a 4 by 4 grid
## of 32-pixel frames, a row each facing down, left, right and up, three
## walking frames and one pose. The middle walking frame is the one standing.
static func generated(file: String) -> UnitSheet:
	var facing: Dictionary = {Vector2i.DOWN: 0, Vector2i.LEFT: 1, Vector2i.RIGHT: 2, Vector2i.UP: 3}
	return UnitSheet.new(file, 32, Rect2i(0, 0, 32, 32), facing, [0, 1, 2, 1] as Array[int], 1)


## The part of the sheet that is step `step` of the walk, facing `facing`.
## Any step number works: the walk goes round.
func walking(facing: Vector2i, step: int) -> Rect2:
	return _frame(facing, walk[posmod(step, walk.size())])


## The part of the sheet that is the figure standing still, facing `facing`.
func standing(facing: Vector2i) -> Rect2:
	return _frame(facing, stand)


## True when a picture `size` pixels across holds every frame this table
## names, whole. A sheet that fails this draws a slice of two frames, or of
## nothing, and only a person looking would see it.
func fits(size: Vector2i) -> bool:
	if size.x % frame_pixels != 0 or size.y % frame_pixels != 0:
		return false
	var columns: Array[int] = walk.duplicate()
	columns.append(stand)
	var inside_frame: bool = Rect2i(0, 0, frame_pixels, frame_pixels).encloses(figure)
	return (inside_frame and columns.max() < size.x / frame_pixels
		and rows.values().max() < size.y / frame_pixels)


# The figure's square in the frame at `column` of the row for `facing`. A
# facing the table has no row for -- a diagonal, or none yet -- faces down,
# towards the reader.
func _frame(facing: Vector2i, column: int) -> Rect2:
	var row: int = rows.get(facing, rows[Vector2i.DOWN])
	var corner := Vector2i(column, row) * frame_pixels + figure.position
	return Rect2(corner, figure.size)
