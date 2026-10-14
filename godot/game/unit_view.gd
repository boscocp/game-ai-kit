## Draws the units on top of the board, and moves them.
##
## Separate from the board view because the two change for different reasons:
## terrain is repainted when the map changes, units every time anybody moves.
## Keeping them apart also keeps each `_draw` short enough to read in one go.
##
## Each unit is its side's picture of its kind, from `Art`: five kinds that walk
## are five silhouettes, and the three that stand are buildings. Its id sits in
## the cell's corner, because every reason on the screen names units by id.
##
## T33 makes them move. A kind with a sheet -- the figures on legs -- marches
## on the spot, as Advance Wars' units do, and stands still once it has acted.
## A unit told to `walk` goes along its route over a fraction of a second,
## facing the way it goes, instead of appearing at the end; a machine, which
## has no legs, bobs as it rolls. All of it hangs off one clock that `advance`
## moves, so a test can stop it anywhere.
##
## When not to use it: dozens of animated pieces, or animation with timing per
## frame. That wants a node per unit and Godot's `AnimatedSprite2D`; this is
## one `_draw` and a list of columns.
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
## Frames a second of a figure marching on the spot, and of one walking. Slow
## at rest, so a board of them is not a flicker; faster on the move.
const MARCH_RATE: float = 4.0
const WALK_RATE: float = 10.0
## How far a machine rises on alternate frames as it rolls, in screen
## pixels, and how many times a second it does.
const BOB_PIXELS: float = 3.0
const BOB_RATE: float = 12.0

## Units that have acted this turn, drawn greyed out -- the Advance Wars
## convention, so a person never has to click a unit to learn it is done.
## Empty unless a scene has turns of that kind.
var spent: Array[int] = []
## Seconds of animation so far. Moved only by `advance`.
var clock: float = 0.0

var _state: BoardState
var _board: BoardView
var _selected_id: int = -1
# Units on the move, by id, and the way each last faced, by id.
var _walks: Dictionary = {}
var _facing: Dictionary = {}


func _ready() -> void:
	# The pack is pixel art drawn at 16 pixels; smoothed up to a tile, it blurs
	# into a different picture.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	advance(delta)


## Hand the view everything it draws. Called whenever the state changes.
##
## A walk whose unit is no longer bound for its last cell is dropped: the move
## was taken back, or the game started again, and the unit is drawn where the
## state says it is.
func show_state(state: BoardState, board: BoardView, selected_id: int) -> void:
	_state = state
	_board = board
	_selected_id = selected_id
	for unit_id: int in _walks.keys():
		var unit: Unit = state.unit_by_id(unit_id)
		if unit == null or unit.cell != (_walks[unit_id] as UnitWalk).destination():
			_walks.erase(unit_id)
	queue_redraw()


## Draw `unit_id` walking from `start` along `path` -- the cells of the `Move`
## the rules just played -- rather than standing at the end of it already.
func walk(unit_id: int, start: Vector2i, path: Array[Vector2i]) -> void:
	_walks[unit_id] = UnitWalk.new(start, path)


## Move the animation on by `seconds`: the march, every walk, and the way each
## walker faces. A walk that is over is let go, its facing kept.
func advance(seconds: float) -> void:
	clock += seconds
	for unit_id: int in _walks.keys():
		var walking: UnitWalk = _walks[unit_id]
		walking.elapsed += seconds
		if walking.facing() != Vector2i.ZERO:
			_facing[unit_id] = walking.facing()
		if walking.finished():
			_walks.erase(unit_id)
	queue_redraw()


## True while `unit_id` is on its way somewhere.
func is_walking(unit_id: int) -> bool:
	return _walks.has(unit_id)


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


## Where on the board `unit` is drawn: partway along its route while it
## walks, raised on alternate frames if it is a machine doing so, and on its
## own cell's centre otherwise.
func position_of(unit: Unit) -> Vector2:
	if not _walks.has(unit.id):
		return _board.centre_of(unit.cell)
	var point: Vector2 = (_walks[unit.id] as UnitWalk).point(_board.centre_of)
	if _sheet_of(unit) == null and posmod(int(clock * BOB_RATE), 2) == 1:
		point.y -= BOB_PIXELS
	return point


## The part of `unit`'s picture drawn now: one frame of its sheet, or the
## whole picture -- an empty rectangle -- for a unit that has no sheet.
func frame_of(unit: Unit) -> Rect2:
	var sheet: UnitSheet = _sheet_of(unit)
	if sheet == null:
		return Rect2()
	var facing: Vector2i = _facing.get(unit.id, _default_facing(unit))
	if _walks.has(unit.id):
		return sheet.walking(facing, int(clock * WALK_RATE))
	if unit.id in spent:
		return sheet.standing(facing)
	return sheet.walking(facing, int(clock * MARCH_RATE))


func _draw() -> void:
	if _state == null or _board == null:
		return
	var drawn: Dictionary = pictures()
	for unit: Unit in _state.units:
		if drawn.has(unit.id):
			_draw_unit(unit, drawn[unit.id], position_of(unit))


func _draw_unit(unit: Unit, picture: Texture2D, centre: Vector2) -> void:
	var square := Rect2(centre - Vector2(RADIUS, RADIUS), Vector2(RADIUS, RADIUS) * 2.0)
	var frame: Rect2 = frame_of(unit)
	if frame.has_area():
		draw_texture_rect_region(picture, square, frame, colour_for(unit))
	else:
		draw_texture_rect(picture, square, false, colour_for(unit))
	_draw_corner_id(centre, unit.id)
	if unit.id == _selected_id:
		draw_rect(square.grow(OUTLINE), Color.WHITE, false, OUTLINE)


## The picture a unit is drawn from: its side's sheet of its kind, when the
## kind walks on legs, or its side's still picture of its kind.
static func picture_for(unit: Unit) -> Texture2D:
	var sheet: UnitSheet = _sheet_of(unit)
	if sheet != null:
		return Art.texture(sheet.path)
	return Art.texture(Art.unit_path(unit.faction, _type_name_of(unit)))


## The tint a unit's picture is drawn with: none, or grey once it is spent.
func colour_for(unit: Unit) -> Color:
	return SPENT_TINT if unit.id in spent else Color.WHITE


static func _sheet_of(unit: Unit) -> UnitSheet:
	return Art.sheet_for(unit.faction, _type_name_of(unit))


static func _type_name_of(unit: Unit) -> String:
	return unit.type.type_name if unit.type != null else Art.NO_TYPE


# Before a unit has walked anywhere it faces the other side: red across the
# board to the right, everyone else to the left.
static func _default_facing(unit: Unit) -> Vector2i:
	return Vector2i.RIGHT if unit.faction == 0 else Vector2i.LEFT


# The id, small, in the bottom-right corner of the cell, outlined so it reads
# on any ground.
func _draw_corner_id(centre: Vector2, unit_id: int) -> void:
	var half: float = BoardView.TILE_PIXELS / 2.0
	var corner: Vector2 = centre + Vector2(half - 14.0, half - 3.0)
	var font: Font = ThemeDB.fallback_font
	draw_string_outline(font, corner, str(unit_id), HORIZONTAL_ALIGNMENT_LEFT, -1.0, CORNER_TEXT_SIZE, 4, Color.BLACK)
	draw_string(font, corner, str(unit_id), HORIZONTAL_ALIGNMENT_LEFT, -1.0, CORNER_TEXT_SIZE, Color.WHITE)
