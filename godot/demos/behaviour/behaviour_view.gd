## What the behaviour demo draws over the board: the guard, where it looks,
## where it thinks the intruder is, and the intruder.
##
## The words -- which brain, and what it is thinking -- are the status line's;
## this draws only what has a place on the board.
class_name BehaviourView
extends Node2D

const TILE: float = float(BoardView.TILE_PIXELS)
const GUARD: Color = Color(0.95, 0.55, 0.15)
const SIGHT: Color = Color(1.0, 0.9, 0.2, 0.45)
const LAST_KNOWN: Color = Color(1.0, 0.3, 0.3, 0.9)
const INTRUDER: Color = Color(0.95, 0.95, 0.95)
const STEP: Color = Color(1.0, 0.4, 0.8, 0.9)

var _world: BehaviourWorld
var _board: BoardView


## Draw `world` over `board`.
func show_world(world: BehaviourWorld, board: BoardView) -> void:
	_world = world
	_board = board
	queue_redraw()


func _draw() -> void:
	if _world == null:
		return
	for cell: Vector2i in _seen_cells():
		draw_rect(_rect(cell, 0.0), SIGHT)
	if _world.senses.last_known != GuardSenses.NOWHERE:
		draw_arc(_board.centre_of(_world.senses.last_known), TILE * 0.4, 0.0, TAU, 24, LAST_KNOWN, 3.0)
	if _world.last_move != null:
		for cell: Vector2i in _world.last_move.path:
			draw_circle(_board.centre_of(cell), 4.0, STEP)
	draw_circle(_board.centre_of(_world.intruder.cell), TILE * 0.3, INTRUDER)
	var centre: Vector2 = _board.centre_of(_world.guard.cell)
	draw_rect(_rect(_world.guard.cell, 6.0), GUARD)
	draw_line(centre, centre + Vector2(_world.facing) * TILE * 0.5, Color.BLACK, 3.0)


# Every cell the guard's cone sees from where it stands.
func _seen_cells() -> Array[Vector2i]:
	var seen: Array[Vector2i] = []
	var graph: GakGridGraph = _world.room.graph
	for index: int in range(graph.width * graph.height):
		var cell := Vector2i(index % graph.width, index / graph.width)
		if _world.cone.sees(graph, _world.guard.cell, _world.facing, cell):
			seen.append(cell)
	return seen


func _rect(cell: Vector2i, inset: float) -> Rect2:
	var middle: Vector2 = _board.centre_of(cell)
	return Rect2(middle - Vector2.ONE * (TILE / 2.0 - inset), Vector2.ONE * (TILE - 2.0 * inset))
