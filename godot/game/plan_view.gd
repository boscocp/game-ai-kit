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
const TEXT_SIZE: int = 18
## The number is written white on a dark outline, above the deciding unit's
## cell: light blue at 14 px on green, beside the unit, could not be read.
const TEXT_OUTLINE: Color = Color(0.05, 0.07, 0.12)
const TEXT_OUTLINE_SIZE: int = 6

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
	var start: Vector2 = points[0]
	if points.size() > 1:
		# From the unit's rim, not its centre, so the line never crosses its id.
		var line: PackedVector2Array = points.duplicate()
		line[0] = start + (points[1] - start).normalized() * UnitView.RADIUS
		draw_polyline(line, ROUTE, ROUTE_WIDTH)
	var end: Vector2 = points[points.size() - 1]
	var half: float = BoardView.TILE_PIXELS / 2.0 - 2.0
	draw_rect(Rect2(end - Vector2(half, half), Vector2(half, half) * 2.0), ROUTE, false, 3.0)
	_draw_number(start + Vector2(0.0, -BoardView.TILE_PIXELS / 2.0 - 4.0))


# The number, centred over a point, outlined so it reads on any ground.
func _draw_number(middle: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	var words: String = number_of(_plan)
	var width: float = font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TEXT_SIZE).x
	var baseline: Vector2 = middle - Vector2(width / 2.0, 0.0)
	draw_string_outline(font, baseline, words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TEXT_SIZE,
			TEXT_OUTLINE_SIZE, TEXT_OUTLINE)
	draw_string(font, baseline, words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TEXT_SIZE, Color.WHITE)


## The number a decision was made on, as a person reads it: the chance of
## winning for a fight weighed, the turns to hold for a node chosen.
static func number_of(decision: LearnedDecision) -> String:
	if is_finite(decision.win_probability):
		return TranslationServer.translate("p(win) {chance}").format({chance = "%.2f" % decision.win_probability})
	if is_finite(decision.predicted_turns):
		return TranslationServer.translate("{turns} turns").format({turns = "%.1f" % decision.predicted_turns})
	return TranslationServer.translate(decision.action)
