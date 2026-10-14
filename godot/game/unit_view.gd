## Draws the units on top of the board.
##
## Separate from the board view because the two change for different reasons:
## terrain is repainted when the map changes, units every time anybody moves.
## Keeping them apart also keeps each `_draw` short enough to read in one go.
##
## Each unit is its side's picture of its kind, from `Art`: five kinds that walk
## are five silhouettes, and the three that stand are buildings. Its id sits in
## the cell's corner, because every reason on the screen names units by id.
##
## When not to use it: anything with animation. A unit that slides between
## cells needs a node per unit and a tween, and this is one picture per cell.
class_name UnitView
extends Node2D

## How much of a tile a picture covers. Less than all of it, so the ground
## under a unit -- trees, a bridge -- still shows round its edges.
const SPRITE_SCALE: float = 0.85
## Half the picture's width: what a route drawn to a unit stops short of.
const RADIUS: float = BoardView.TILE_PIXELS * SPRITE_SCALE / 2.0
const OUTLINE: float = 3.0
## The id in a cell's corner.
const CORNER_TEXT_SIZE: int = 12
## What a spent unit's picture is multiplied by: the Advance Wars grey.
const SPENT_TINT: Color = Color(0.45, 0.45, 0.45)

## Units that have acted this turn, drawn greyed out -- the Advance Wars
## convention, so a person never has to click a unit to learn it is done.
## Empty unless a scene has turns of that kind.
var spent: Array[int] = []

var _state: BoardState
var _board: BoardView
var _selected_id: int = -1


func _ready() -> void:
	# The pack is pixel art drawn at 16 pixels; smoothed up to a tile, it blurs
	# into a different picture.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Hand the view everything it draws. Called whenever the state changes.
func show_state(state: BoardState, board: BoardView, selected_id: int) -> void:
	_state = state
	_board = board
	_selected_id = selected_id
	queue_redraw()


## Every picture this view draws, as data: unit id to texture, for the units
## alive. `_draw` draws exactly this, so a test can hold which picture each
## unit gets without a screen -- headless, no screen exists.
func pictures() -> Dictionary:
	var drawn: Dictionary = {}
	if _state == null:
		return drawn
	for unit: Unit in _state.units:
		if unit.is_alive():
			drawn[unit.id] = picture_for(unit)
	return drawn


func _draw() -> void:
	if _state == null or _board == null:
		return
	var drawn: Dictionary = pictures()
	for unit: Unit in _state.units:
		if drawn.has(unit.id):
			_draw_unit(unit, drawn[unit.id], _board.centre_of(unit.cell))


func _draw_unit(unit: Unit, picture: Texture2D, centre: Vector2) -> void:
	var square := Rect2(centre - Vector2(RADIUS, RADIUS), Vector2(RADIUS, RADIUS) * 2.0)
	draw_texture_rect(picture, square, false, colour_for(unit))
	_draw_corner_id(centre, unit.id)
	if unit.id == _selected_id:
		draw_rect(square.grow(OUTLINE), Color.WHITE, false, OUTLINE)


## The picture a unit is drawn with: its side's, of its kind.
static func picture_for(unit: Unit) -> Texture2D:
	var type_name: String = unit.type.type_name if unit.type != null else Art.NO_TYPE
	return Art.texture(Art.unit_path(unit.faction, type_name))


## The tint a unit's picture is drawn with: none, or grey once it is spent.
func colour_for(unit: Unit) -> Color:
	return SPENT_TINT if unit.id in spent else Color.WHITE


# The id, small, in the bottom-right corner of the cell, outlined so it reads
# on any ground.
func _draw_corner_id(centre: Vector2, unit_id: int) -> void:
	var half: float = BoardView.TILE_PIXELS / 2.0
	var corner: Vector2 = centre + Vector2(half - 14.0, half - 3.0)
	var font: Font = ThemeDB.fallback_font
	draw_string_outline(font, corner, str(unit_id), HORIZONTAL_ALIGNMENT_LEFT, -1.0, CORNER_TEXT_SIZE, 4, Color.BLACK)
	draw_string(font, corner, str(unit_id), HORIZONTAL_ALIGNMENT_LEFT, -1.0, CORNER_TEXT_SIZE, Color.WHITE)
