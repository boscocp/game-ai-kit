## Draws a fight as a training mode would: the fighters, every box, and the
## health.
##
## A fighter is its sprite (T35), the cel `FighterSprites` picks from the
## frame data, or -- when its strips are not on disk -- a filled block in its
## side's colour, lower while it crouches, drawn where its feet are: off the
## floor in a jump. Over either, its hurtbox is outlined in blue -- longer
## than the body once a move's limb is out, lower in a crouch, and grey on
## the frames of a backdash that nothing can find (T40) -- and a
## hitbox, while one is out, is a red box exactly where the frame data says
## it reaches, along the stage and up from the floor (T38); a throw's is
## orange, since no guard stops it. A high is drawn above a crouch because
## it is above it, not because the view knows the rule. The boxes are the
## point: a person learning frame data has to see the box that won, not only
## the damage it did. One stage unit is one pixel, up as well as along.
##
## The boxes are drawn over the sprite, never hidden by it: the sprite is
## what the move looks like, the boxes are what it does.
##
## When not to use it: a game. Players see sprites and no boxes; boxes are a
## debug view, and this scenario is about the boxes.
class_name FightView
extends Node2D

const FLOOR_Y: float = 360.0
const SIDES: Array[Color] = [Color(0.85, 0.30, 0.25), Color(0.25, 0.45, 0.85)]
const HURTBOX: Color = Color(0.35, 0.65, 1.0)
## The hurtbox on a backdash's invulnerable frames: there, and found by nothing.
const INVULNERABLE: Color = Color(0.6, 0.6, 0.6, 0.6)
const HITBOX: Color = Color(1.0, 0.2, 0.2, 0.5)
const THROW: Color = Color(1.0, 0.6, 0.1, 0.55)
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


# The fighter, its hurtbox, and its hitbox while one is out, each where the
# frame data puts it.
func _draw_fighter(fighter: FighterState, colour: Color) -> void:
	if sprites.complete(fighter.character, _data):
		_draw_sprite(fighter)
	else:
		_draw_block(fighter, colour)
	var hurt: Rect2 = on_screen(FightBoxes.hurtbox(fighter, _data), FightBoxes.hurt_rise(fighter, _data))
	var outline: Color = INVULNERABLE if FightBackdash.invulnerable(fighter, _data) else HURTBOX
	draw_rect(hurt.grow(2.0), outline, false, 2.0)
	var hit: Array[int] = FightBoxes.hitbox(fighter, _data)
	if not hit.is_empty():
		var throwing: bool = _data.is_throw(fighter.character, fighter.move)
		draw_rect(on_screen(hit, FightBoxes.hit_rise(fighter, _data)), THROW if throwing else HITBOX)


## A box on screen: `along` the stage and `up` from the floor, in stage
## units, as a rectangle in pixels. Up is up: the floor is `FLOOR_Y`.
static func on_screen(along: Array[int], up: Array[int]) -> Rect2:
	return Rect2(along[0], FLOOR_Y - up[1], along[1] - along[0], up[1] - up[0])


func _draw_block(fighter: FighterState, colour: Color) -> void:
	var body: int = int(_data.character(fighter.character)["body"])
	var block: Rect2 = on_screen([fighter.x - body, fighter.x + body] as Array[int], FightBoxes.hurt_rise(fighter, _data))
	draw_rect(block, colour)
	if fighter.stun > 0:
		draw_rect(block, STUNNED)
	draw_circle(Vector2(fighter.x + fighter.facing * body * 0.5, block.position.y + 18.0), 5.0, Color.WHITE)


# The fighter's cel, its anchor -- where the feet are in the cel -- on where
# the fighter's feet are, mirrored when it faces left.
func _draw_sprite(fighter: FighterState) -> void:
	var lost: bool = _state.winner != FightState.NOBODY and fighter.health <= 0
	var pose: Array = sprites.pose(fighter, _data, _state.frame, lost)
	var drawn: Dictionary = sprites.table["characters"][fighter.character]
	var cell: Vector2 = Vector2(sprites.cell(fighter.character))
	var anchor: Vector2 = Vector2(float(drawn["anchor"][0]), float(drawn["anchor"][1]))
	var scale_by: float = float(drawn["scale_percent"]) / 100.0
	draw_set_transform(Vector2(fighter.x, FLOOR_Y - fighter.y), 0.0, Vector2(fighter.facing * scale_by, scale_by))
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
