## Draws what blue is about to do, before it does it.
##
## A walk is a pink line along the route with a ring where it ends; an attack
## (T26) is a dashed line from the attacker to its target, with a cross on the
## target; a build is a pink square where the new unit will stand; a hold is a
## ring round the piece that is staying put. Pink because the checkers board already taught
## that pink is "the move the computer will play".
##
## When not to use it: red's turn. A person's own intentions need no drawing.
class_name IntentView
extends Node2D

const INTENT: Color = Color(1.0, 0.40, 0.85, 0.95)
const WIDTH: float = 4.0
const RING: float = 20.0

var _decision: TacticalDecision
var _state: BoardState
var _board: BoardView


## Draw `decision`, or nothing when it is null.
func show_decision(decision: TacticalDecision, state: BoardState, board: BoardView) -> void:
	_decision = decision
	_state = state
	_board = board
	queue_redraw()


func _draw() -> void:
	if _decision == null or _board == null:
		return
	match _decision.kind():
		"move":
			_draw_walk()
		"attack":
			_draw_attack()
		"build":
			var side: float = BoardView.TILE_PIXELS - 8.0
			var corner: Vector2 = _board.centre_of(_decision.target) - Vector2(side, side) / 2.0
			draw_rect(Rect2(corner, Vector2(side, side)), INTENT, false, WIDTH)
		_:
			draw_arc(_board.centre_of(_decision.target), RING, 0.0, TAU, 32, INTENT, WIDTH)


# Who strikes whom: dashed, so it is never read as a walk, from the attacker
# to a cross on the target -- a ring alone looked exactly like a hold.
func _draw_attack() -> void:
	var unit: Unit = _state.unit_by_id(_decision.unit_id)
	var target: Vector2 = _board.centre_of(_decision.target)
	if unit != null:
		draw_dashed_line(_board.centre_of(unit.cell), target, INTENT, WIDTH, 8.0)
	var arm: Vector2 = Vector2(RING, RING) * 0.6
	draw_line(target - arm, target + arm, INTENT, WIDTH)
	draw_line(target + Vector2(arm.x, -arm.y), target + Vector2(-arm.x, arm.y), INTENT, WIDTH)


func _draw_walk() -> void:
	var unit: Unit = _state.unit_by_id(_decision.unit_id)
	if unit == null:
		return
	var points := PackedVector2Array([_board.centre_of(unit.cell)])
	for cell: Vector2i in _decision.move.path:
		points.append(_board.centre_of(cell))
	draw_polyline(points, INTENT, WIDTH)
	draw_arc(points[points.size() - 1], RING, 0.0, TAU, 32, INTENT, WIDTH)
