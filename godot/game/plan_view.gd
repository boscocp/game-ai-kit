## Draws what blue is about to do, before it does it.
##
## Blue's turn is played one decision at a time: a unit decides, this view
## draws the route it chose, the cell it will end on and the number that
## decided it, and only the next press plays the move. A decision drawn after
## it was played is only an outcome, which invariant 13 says is not enough.
class_name PlanView
extends Node2D

const ROUTE: Color = Color(0.55, 0.75, 1.0, 0.9)
const ROUTE_WIDTH: float = 3.0
const TEXT_SIZE: int = 14

var _plan: LearnedDecision
var _state: BoardState
var _board: BoardView


## Hand the view the decision about to be played, or null when there is none.
func show_plan(plan: LearnedDecision, state: BoardState, board: BoardView) -> void:
	_plan = plan
	_state = state
	_board = board
	queue_redraw()


func _draw() -> void:
	if _plan == null or _board == null:
		return
	var unit: Unit = _state.unit_by_id(_plan.unit_id)
	if unit == null:
		return
	var points := PackedVector2Array([_board.centre_of(unit.cell)])
	for cell: Vector2i in _plan.move.path:
		points.append(_board.centre_of(cell))
	if points.size() > 1:
		draw_polyline(points, ROUTE, ROUTE_WIDTH)
	var end: Vector2 = points[points.size() - 1]
	var half: float = BoardView.TILE_PIXELS / 2.0 - 2.0
	draw_rect(Rect2(end - Vector2(half, half), Vector2(half, half) * 2.0), ROUTE, false, 2.0)
	draw_string(ThemeDB.fallback_font, points[0] + Vector2(14.0, -14.0), number_of(_plan),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, TEXT_SIZE, ROUTE)


## The number a decision was made on, as a person reads it: the chance of
## winning for a fight weighed, the turns to hold for a node chosen.
static func number_of(decision: LearnedDecision) -> String:
	if is_finite(decision.win_probability):
		return "p(win) %.2f" % decision.win_probability
	if is_finite(decision.predicted_turns):
		return "%.1f turns" % decision.predicted_turns
	return decision.action
