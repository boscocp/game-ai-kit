## Draws the units on top of the board.
##
## Separate from the board view because the two change for different reasons:
## terrain is repainted when the map changes, units every time anybody moves.
## Keeping them apart also keeps each `_draw` short enough to read in one go.
##
## When not to use it: anything with animation. A unit that slides between
## cells needs a node per unit and a tween, and this is a circle.
class_name UnitView
extends Node2D

## A third of a tile, so a unit grows with the board instead of shrinking
## into it when the tiles get bigger.
const RADIUS: float = BoardView.TILE_PIXELS / 3.0
const OUTLINE: float = 3.0
const ID_TEXT_SIZE: int = 18
## The id in a cell's corner, when the piece's own label is a type: messages
## still name units by id, and a reader has to find "unit 4" on the board.
const CORNER_TEXT_SIZE: int = 12
## How far a spent unit's colour is pulled towards grey.
const SPENT_GREY: Color = Color(0.45, 0.45, 0.45)
const SPENT_AMOUNT: float = 0.65

## Faction colours, by faction number. A scenario with more sides than this
## draws the extras in the last colour rather than crashing -- a missing colour
## is a presentation problem and should not take the game down.
const FACTION_COLOURS: Array[Color] = [
	Color(0.80, 0.30, 0.25),
	Color(0.30, 0.50, 0.80),
]

## A short label per `UnitType.type_name`, drawn instead of the id when the
## scene gives one. Until T9 brings silhouettes, two letters are how five
## types are told apart without relying on colour.
var labels: Dictionary = {}

## Units that have acted this turn, drawn greyed out -- the Advance Wars
## convention, so a person never has to click a unit to learn it is done.
## Empty unless a scene has turns of that kind.
var spent: Array[int] = []

var _state: BoardState
var _board: BoardView
var _selected_id: int = -1


## Hand the view everything it draws. Called whenever the state changes.
func show_state(state: BoardState, board: BoardView, selected_id: int) -> void:
	_state = state
	_board = board
	_selected_id = selected_id
	queue_redraw()


func _draw() -> void:
	if _state == null or _board == null:
		return
	for unit: Unit in _state.units:
		if not unit.is_alive():
			continue
		_draw_unit(unit, _board.centre_of(unit.cell))


# A circle for what walks, a square for what stands: a tower or a building
# reads as fixed before anyone reads its label.
func _draw_unit(unit: Unit, centre: Vector2) -> void:
	var fixed: bool = unit.type != null and not unit.type.mobile
	var square := Rect2(centre - Vector2(RADIUS, RADIUS), Vector2(RADIUS, RADIUS) * 2.0)
	var colour: Color = _colour_of(unit.faction)
	if unit.id in spent:
		colour = colour.lerp(SPENT_GREY, SPENT_AMOUNT)
	if fixed:
		draw_rect(square, colour)
	else:
		draw_circle(centre, RADIUS, colour)
	_draw_label(centre, _label_of(unit))
	if _label_of(unit) != str(unit.id):
		_draw_corner_id(centre, unit.id)
	if unit.id != _selected_id:
		return
	if fixed:
		draw_rect(square.grow(OUTLINE), Color.WHITE, false, OUTLINE)
	else:
		draw_arc(centre, RADIUS + OUTLINE, 0.0, TAU, 24, Color.WHITE, OUTLINE)


# The type's label when the scene gave one, the id otherwise -- the id because
# every reason on the screen names units by it.
func _label_of(unit: Unit) -> String:
	if unit.type != null and labels.has(unit.type.type_name):
		return labels[unit.type.type_name]
	return str(unit.id)


# The id, small, in the bottom-right corner of the cell, outlined so it reads
# on any ground.
func _draw_corner_id(centre: Vector2, unit_id: int) -> void:
	var half: float = BoardView.TILE_PIXELS / 2.0
	var corner: Vector2 = centre + Vector2(half - 14.0, half - 3.0)
	var font: Font = ThemeDB.fallback_font
	draw_string_outline(font, corner, str(unit_id), HORIZONTAL_ALIGNMENT_LEFT, -1.0, CORNER_TEXT_SIZE, 4, Color.BLACK)
	draw_string(font, corner, str(unit_id), HORIZONTAL_ALIGNMENT_LEFT, -1.0, CORNER_TEXT_SIZE, Color.WHITE)


func _draw_label(centre: Vector2, words: String) -> void:
	var width: float = ThemeDB.fallback_font.get_string_size(
			words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, ID_TEXT_SIZE).x
	draw_string(ThemeDB.fallback_font, centre + Vector2(-width / 2.0, ID_TEXT_SIZE * 0.35), words,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, ID_TEXT_SIZE, Color.WHITE)


# The colour of a faction, clamped to the colours there are.
func _colour_of(faction: int) -> Color:
	var index: int = clampi(faction, 0, FACTION_COLOURS.size() - 1)
	return FACTION_COLOURS[index]
