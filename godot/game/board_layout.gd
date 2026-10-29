## Where a board scene puts its three parts: the board in the middle of the
## window, the legend to its right level with the board's top edge, and the
## status running the whole column to its left, from a top the scene gives
## down to the gutter above the window's bottom. Begun level with the board,
## the status ran off the window in both scenes that use this, once a played
## game filled it: the tactical match's (T102) and the skirmish's (T107).
##
## Shared because two scenes need it and a copy is two layouts that drift. T8
## measured why it exists: a board pinned to a corner of the window, and the
## status line that described it 600 px below.
##
## The window is the one the project asks for, not `get_viewport_rect()`:
## headless, the root viewport is 100x100 (measured on the pinned engine), and
## a layout that depends on where it is run cannot be tested where tests run.
##
## When not to use it: a window the player resizes. This lays out once, for
## the size in `project.godot`.
class_name BoardLayout
extends RefCounted

## Space between the board and the panels beside it, and between a panel and
## the edge of the window.
const GUTTER: float = 24.0


## The window the project asks for, in pixels.
static func window_size() -> Vector2:
	return Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))


## Centre `root` (the node the board, units and overlays hang from) and place
## the two panels beside it, the status's column starting at `status_top`.
static func lay_out(root: Node2D, graph: GridGraph, status: Control, legend: Control, status_top: float) -> void:
	var window: Vector2 = window_size()
	root.position = BoardView.offset_to_centre(graph, window)
	var board := Rect2(root.position, BoardView.pixel_size(graph))
	status.position = Vector2(GUTTER, status_top)
	status.size = Vector2(board.position.x - 2.0 * GUTTER, window.y - status_top - GUTTER)
	legend.position = Vector2(board.end.x + GUTTER, board.position.y)
