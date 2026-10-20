## The whole board, small, in the bottom left corner: where the camera
## is, what you have seen, and every unit you can see now.
##
## StarCraft's and Age of Empires' minimap, for the same reason: the board
## is bigger than the window, and a person needs to know where to look.
## Click or drag on it to move the camera there. It draws from the same
## snapshot as the board, so it shows no more than the board does.
##
## When not to use it: a board that fits the window.
class_name RtsMinimap
extends Control

## Pixels a cell, here.
const SCALE: float = 4.0

## The board view whose snapshot, fog and camera this mirrors.
var board: RtsView


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	var motion := event as InputEventMouseMotion
	var pressed: bool = button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT
	var dragged: bool = motion != null and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if pressed or dragged:
		var at: Vector2 = (event as InputEventMouse).position / SCALE
		RtsView.frame_at(at - RtsView.shown_cells().size / 2.0)
		accept_event()


func _draw() -> void:
	if board == null or board.view == null:
		return
	var width: int = RtsScenario.MAP[0].length()
	for index: int in range(width * RtsScenario.MAP.size()):
		var cell := Vector2(index % width, index / width)
		var letter: String = RtsScenario.MAP[int(cell.y)][int(cell.x)]
		var colour: Color = RtsView.GROUND[letter]
		if not board.everything and board.explored[index] == 0:
			colour = colour.darkened(0.6)
		draw_rect(Rect2(cell * SCALE, Vector2(SCALE, SCALE)), colour)
	for unit: Dictionary in board.shown_units():
		var colour: Color = RtsView.DEPOSIT_COLOURS.get(unit["kind"], Color.WHITE)
		if unit["side"] >= 0:
			colour = RtsView.SIDE_COLOURS[unit["side"]]
		draw_rect(Rect2((unit["position"] as Vector2) * SCALE - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), colour)
	var shown: Rect2 = RtsView.shown_cells()
	draw_rect(Rect2(shown.position * SCALE, shown.size * SCALE), Color.WHITE, false, 1.0)
