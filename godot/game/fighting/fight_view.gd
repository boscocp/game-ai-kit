## Draws a fight as a training mode would: the bodies, every box, and the
## health.
##
## A body is a filled block in its side's colour. Its hurtbox is outlined in
## blue -- longer than the body once a move's limb is out -- and a hitbox,
## while one is out, is a red bar at arm's height. The boxes are the point:
## a person learning frame data has to see the box that won, not only the
## damage it did.
##
## When not to use it: a game. Players see sprites; boxes are a debug view,
## and this scenario is about the boxes until T17 gives it an opponent.
class_name FightView
extends Node2D

const FLOOR_Y: float = 360.0
const BODY_HEIGHT: float = 120.0
const SIDES: Array[Color] = [Color(0.85, 0.30, 0.25), Color(0.25, 0.45, 0.85)]
const HURTBOX: Color = Color(0.35, 0.65, 1.0)
const HITBOX: Color = Color(1.0, 0.2, 0.2, 0.85)
const STUNNED: Color = Color(1.0, 1.0, 1.0, 0.35)
const STAGE: Color = Color(0.22, 0.22, 0.25)
const HEALTH_WIDTH: float = 260.0

var _state: FightState
var _data: FightData


## Hand the view the frame to draw.
func show_fight(state: FightState, data: FightData) -> void:
	_state = state
	_data = data
	queue_redraw()


func _draw() -> void:
	if _state == null:
		return
	var width: float = float(_data.table["stage"]["width"])
	draw_rect(Rect2(0.0, FLOOR_Y, width, 8.0), STAGE)
	for index: int in range(2):
		_draw_fighter(_state.fighters[index], SIDES[index])
		_draw_health(index, width)


func _draw_fighter(fighter: FighterState, colour: Color) -> void:
	var body: float = float(_data.character(fighter.character)["body"])
	var top: float = FLOOR_Y - BODY_HEIGHT
	draw_rect(Rect2(fighter.x - body, top, body * 2.0, BODY_HEIGHT), colour)
	if fighter.stun > 0:
		draw_rect(Rect2(fighter.x - body, top, body * 2.0, BODY_HEIGHT), STUNNED)
	var hurt: Array[int] = FightBoxes.hurtbox(fighter, _data)
	draw_rect(Rect2(hurt[0], top - 4.0, hurt[1] - hurt[0], BODY_HEIGHT + 4.0), HURTBOX, false, 2.0)
	var hit: Array[int] = FightBoxes.hitbox(fighter, _data)
	if not hit.is_empty():
		draw_rect(Rect2(hit[0], top + 30.0, hit[1] - hit[0], 14.0), HITBOX)
	var eye: Vector2 = Vector2(fighter.x + fighter.facing * body * 0.5, top + 18.0)
	draw_circle(eye, 5.0, Color.WHITE)


func _draw_health(index: int, width: float) -> void:
	var fighter: FighterState = _state.fighters[index]
	var full: float = float(_data.character(fighter.character)["health"])
	var left: float = 0.0 if index == 0 else width - HEALTH_WIDTH
	draw_rect(Rect2(left, 20.0, HEALTH_WIDTH, 14.0), STAGE)
	draw_rect(Rect2(left, 20.0, HEALTH_WIDTH * fighter.health / full, 14.0), SIDES[index])
