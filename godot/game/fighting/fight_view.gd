## Draws a fight as a training mode would: the fighters, every box, and the
## health.
##
## A fighter is its sprite (T35), the cel `FighterSprites` picks from the
## frame data, or -- when its strips are not on disk -- a filled block in its
## side's colour, lower while it crouches. Over either, its hurtbox is
## outlined in blue -- longer than the body once a move's limb is out -- and
## a hitbox, while one is out, is a red bar at the height the
## move hits: at the head for an overhead, the chest for a mid, the shins for
## a low; a throw's is orange, since no guard stops it. The boxes are the point:
## a person learning frame data has to see the box that won, not only the
## damage it did.
##
## The boxes are drawn over the sprite, never hidden by it: the sprite is
## what the move looks like, the boxes are what it does.
##
## When not to use it: a game. Players see sprites and no boxes; boxes are a
## debug view, and this scenario is about the boxes.
class_name FightView
extends Node2D

const FLOOR_Y: float = 360.0
const BODY_HEIGHT: float = 120.0
const SIDES: Array[Color] = [Color(0.85, 0.30, 0.25), Color(0.25, 0.45, 0.85)]
const HURTBOX: Color = Color(0.35, 0.65, 1.0)
const HITBOX: Color = Color(1.0, 0.2, 0.2, 0.85)
const THROW: Color = Color(1.0, 0.6, 0.1, 0.9)
## A crouching body's height, as a share of a standing one.
const CROUCH_SHARE: float = 0.6
## Where a hitbox is drawn, down from the top of a standing body of
## `BODY_HEIGHT`, by height; a taller figure scales it.
const HIT_DEPTH: Dictionary = {"overhead": 4.0, "mid": 40.0, "throw": 40.0, "low": 96.0}
const STUNNED: Color = Color(1.0, 1.0, 1.0, 0.35)
const STAGE: Color = Color(0.22, 0.22, 0.25)
const HEALTH_WIDTH: float = 260.0
## A stunned fighter's sprite, paler, as the block was.
const STUNNED_SPRITE: Color = Color(1.0, 1.0, 1.0, 0.65)

var sprites: FighterSprites = FighterSprites.read()
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
	var drawn: bool = sprites.complete(fighter.character, _data)
	var height: float = figure_height(fighter) * (CROUCH_SHARE if fighter.crouching else 1.0)
	var top: float = FLOOR_Y - height
	if drawn:
		_draw_sprite(fighter)
	else:
		_draw_block(fighter, colour, top, height)
	var hurt: Array[int] = FightBoxes.hurtbox(fighter, _data)
	draw_rect(Rect2(hurt[0], top - 4.0, hurt[1] - hurt[0], height + 4.0), HURTBOX, false, 2.0)
	var hit: Array[int] = FightBoxes.hitbox(fighter, _data)
	if not hit.is_empty():
		var hits: String = _data.move(fighter.character, fighter.move)["height"]
		var depth: float = minf(HIT_DEPTH[hits] * figure_height(fighter) / BODY_HEIGHT, height - 14.0)
		draw_rect(Rect2(hit[0], top + depth, hit[1] - hit[0], 14.0), THROW if hits == "throw" else HITBOX)


## How tall a fighter stands on screen: its sprite's standing height at the
## scale it is drawn, or the block's height when it has no sprite. The boxes
## are drawn to this height, so they sit over the figure.
func figure_height(fighter: FighterState) -> float:
	if _data == null or not sprites.complete(fighter.character, _data):
		return BODY_HEIGHT
	var drawn: Dictionary = sprites.table["characters"][fighter.character]
	return float(drawn["standing_height"]) * float(drawn["scale_percent"]) / 100.0


func _draw_block(fighter: FighterState, colour: Color, top: float, height: float) -> void:
	var body: float = float(_data.character(fighter.character)["body"])
	draw_rect(Rect2(fighter.x - body, top, body * 2.0, height), colour)
	if fighter.stun > 0:
		draw_rect(Rect2(fighter.x - body, top, body * 2.0, height), STUNNED)
	draw_circle(Vector2(fighter.x + fighter.facing * body * 0.5, top + 18.0), 5.0, Color.WHITE)


# The fighter's cel, its anchor -- where the feet are in the cel -- on the
# fighter's place on the floor, mirrored when it faces left.
func _draw_sprite(fighter: FighterState) -> void:
	var lost: bool = _state.winner != FightState.NOBODY and fighter.health <= 0
	var pose: Array = sprites.pose(fighter, _data, _state.frame, lost)
	var drawn: Dictionary = sprites.table["characters"][fighter.character]
	var cell: Vector2 = Vector2(sprites.cell(fighter.character))
	var anchor: Vector2 = Vector2(float(drawn["anchor"][0]), float(drawn["anchor"][1]))
	var scale_by: float = float(drawn["scale_percent"]) / 100.0
	draw_set_transform(Vector2(fighter.x, FLOOR_Y), 0.0, Vector2(fighter.facing * scale_by, scale_by))
	var source: Rect2 = Rect2(Vector2(int(pose[1]) * cell.x, 0.0), cell)
	var tint: Color = STUNNED_SPRITE if fighter.stun > 0 else Color.WHITE
	draw_texture_rect_region(sprites.strip(fighter.character, pose[0]), Rect2(-anchor, cell), source, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_health(index: int, width: float) -> void:
	var fighter: FighterState = _state.fighters[index]
	var full: float = float(_data.character(fighter.character)["health"])
	var left: float = 0.0 if index == 0 else width - HEALTH_WIDTH
	draw_rect(Rect2(left, 20.0, HEALTH_WIDTH, 14.0), STAGE)
	draw_rect(Rect2(left, 20.0, HEALTH_WIDTH * fighter.health / full, 14.0), SIDES[index])
