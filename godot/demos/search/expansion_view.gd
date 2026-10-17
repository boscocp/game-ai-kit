## Draws what a search looked at, in the order it looked at it.
##
## The path is the boring half. Four algorithms return the same route on an
## open board and arrive at it completely differently, and the only place that
## difference exists is the expansion -- so this view draws the expansion first
## and the path on top of it.
##
## Colour carries order: the earliest cells are dark, the latest are bright.
## That is what makes depth-first legible as a mistake rather than as noise --
## you can see it commit to one direction and keep going.
##
## When not to use it: a board large enough that one rectangle per expanded
## cell matters. At that size you want the whole thing in a shader, and the
## lesson is no longer about the algorithm.
class_name ExpansionView
extends Node2D

# Translucent, and inset, so the board stays visible underneath. At full tile
# size and 0.85 alpha the expansion buried the mud band completely -- so the
# one thing the demo exists to show, *why* Dijkstra goes round, disappeared
# exactly when the picture was finished.
const EARLY: Color = Color(0.16, 0.20, 0.34, 0.50)
const LATE: Color = Color(0.45, 0.78, 0.95, 0.50)
# Pink, not yellow: T8 made mud tan, and a yellow outline on tan vanished on
# exactly the band the demo is about.
const FRONTIER: Color = Color(1.0, 0.40, 0.85, 0.95)
const PATH: Color = Color(1.0, 0.95, 0.85, 1.0)
# Yellow and a strong red, each ringed in near-black. The start was a light
# green and vanished on grass (T41) -- the pink frontier's lesson again: a
# marker's colour is chosen against the tiles it sits on. The ring is what
# keeps either one visible on mud and on the expansion squares too, and
# `marker_contrast_test.gd` measures both against every tile they can stand on.
const START: Color = Color(1.0, 0.85, 0.1)
const GOAL: Color = Color(0.9, 0.1, 0.1)
const MARKER_RING: Color = Color(0.05, 0.05, 0.05)
const NEXT: Color = Color(1.0, 1.0, 1.0, 0.95)

const PATH_WIDTH: float = 3.0
const MARKER_RADIUS: float = 9.0
const MARKER_RING_WIDTH: float = 3.0
const FRONTIER_INSET: float = 6.0
const EXPANSION_INSET: float = 8.0

var _result: SearchResult
var _board: BoardView
var _revealed: int = 0
var _from: Vector2i
var _to: Vector2i
var _frontier: Array[Vector2i] = []


## Show `revealed` cells of this search's expansion, and the path once it is
## all revealed. Stepping is replaying: nothing is searched again.
func show_search(result: SearchResult, board: BoardView, revealed: int,
		from: Vector2i, to: Vector2i, frontier: Array[Vector2i]) -> void:
	_frontier = frontier
	_result = result
	_board = board
	_revealed = revealed
	_from = from
	_to = to
	queue_redraw()


func _draw() -> void:
	if _result == null or _board == null:
		return
	_draw_expansion()
	_draw_frontier()
	if _revealed >= _result.expanded.size():
		_draw_path()
	else:
		# The cell the search takes next, before it takes it: what it is about
		# to do, which is the question invariant 13 asks of every example.
		draw_rect(_cell_rect(_result.expanded[_revealed], FRONTIER_INSET), NEXT, false, 3.0)
	_draw_marker(_from, START)
	_draw_marker(_to, GOAL)


# Every cell taken off the frontier so far, dark to bright in that order.
func _draw_expansion() -> void:
	var total: int = maxi(_result.expanded.size() - 1, 1)
	for index: int in range(mini(_revealed, _result.expanded.size())):
		var shade: Color = EARLY.lerp(LATE, float(index) / float(total))
		draw_rect(_cell_rect(_result.expanded[index], EXPANSION_INSET), shade)


# What the search is choosing among, step by step -- and, when it stops, what
# it never got to. On A* that is most of the board, and that is the entire
# argument for the heuristic.
func _draw_frontier() -> void:
	for cell: Vector2i in _frontier:
		draw_rect(_cell_rect(cell, FRONTIER_INSET), FRONTIER, false, 2.0)


func _draw_path() -> void:
	if _result.path.is_empty():
		return
	var points := PackedVector2Array([_board.centre_of(_from)])
	for cell: Vector2i in _result.path:
		points.append(_board.centre_of(cell))
	draw_polyline(points, PATH, PATH_WIDTH)


func _draw_marker(cell: Vector2i, colour: Color) -> void:
	draw_circle(_board.centre_of(cell), MARKER_RADIUS + MARKER_RING_WIDTH, MARKER_RING)
	draw_circle(_board.centre_of(cell), MARKER_RADIUS, colour)


func _cell_rect(cell: Vector2i, inset: float) -> Rect2:
	var side: float = float(BoardView.TILE_PIXELS)
	var corner: Vector2 = _board.centre_of(cell) - Vector2(side, side) * 0.5
	return Rect2(corner + Vector2(inset, inset) * 0.5, Vector2(side, side) - Vector2(inset, inset))
