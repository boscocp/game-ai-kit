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

## Faction colours, by faction number. A scenario with more sides than this
## draws the extras in the last colour rather than crashing -- a missing colour
## is a presentation problem and should not take the game down.
const FACTION_COLOURS: Array[Color] = [
	Color(0.80, 0.30, 0.25),
	Color(0.30, 0.50, 0.80),
]

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
		var centre: Vector2 = _board.centre_of(unit.cell)
		draw_circle(centre, RADIUS, _colour_of(unit.faction))
		_draw_id(centre, unit.id)
		if unit.id == _selected_id:
			draw_arc(centre, RADIUS + OUTLINE, 0.0, TAU, 24, Color.WHITE, OUTLINE)


# The id, because every reason on the screen names units by it.
func _draw_id(centre: Vector2, unit_id: int) -> void:
	var words: String = str(unit_id)
	var width: float = ThemeDB.fallback_font.get_string_size(
			words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, ID_TEXT_SIZE).x
	draw_string(ThemeDB.fallback_font, centre + Vector2(-width / 2.0, ID_TEXT_SIZE * 0.35), words,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, ID_TEXT_SIZE, Color.WHITE)


# The colour of a faction, clamped to the colours there are.
func _colour_of(faction: int) -> Color:
	var index: int = clampi(faction, 0, FACTION_COLOURS.size() - 1)
	return FACTION_COLOURS[index]
