## Draws the noughts-and-crosses board and what is on its squares: the pieces,
## MENACE's beads for each move, the move it drew, and what perfect play makes
## of each square.
##
## Static functions that draw onto the scene's own canvas, because the scene
## is a 3x3 grid and a second node would only pass the board along.
class_name TicTacToeView
extends RefCounted

const CELL: float = TicTacToeExample.CELL
const BIG: int = 34
const SMALL: int = 15


## The grid and the pieces on it.
static func draw_board(canvas: CanvasItem, board: String) -> void:
	for line: int in range(1, 3):
		canvas.draw_line(Vector2(line * CELL, 0.0), Vector2(line * CELL, 3.0 * CELL), TicTacToeExample.GRID_COLOUR, 4.0)
		canvas.draw_line(Vector2(0.0, line * CELL), Vector2(3.0 * CELL, line * CELL), TicTacToeExample.GRID_COLOUR, 4.0)
	for square: int in range(9):
		var centre: Vector2 = centre_of(square)
		if board[square] == TicTacToeBoard.CROSS:
			var arm: float = CELL * 0.3
			canvas.draw_line(centre - Vector2(arm, arm), centre + Vector2(arm, arm), TicTacToeExample.CROSS_COLOUR, 12.0)
			canvas.draw_line(centre + Vector2(-arm, arm), centre + Vector2(arm, -arm), TicTacToeExample.CROSS_COLOUR, 12.0)
		elif board[square] == TicTacToeBoard.NOUGHT:
			canvas.draw_arc(centre, CELL * 0.3, 0.0, TAU, 48, TicTacToeExample.NOUGHT_COLOUR, 12.0)


## On each empty square: its beads as a number and as a bar, and the chance
## of drawing one. A square that is another one turned says which, because its
## beads are that square's.
static func draw_beads(canvas: CanvasItem, squares: Array[Dictionary]) -> void:
	var font: Font = ThemeDB.fallback_font
	for entry: Dictionary in squares:
		var corner: Vector2 = Vector2(entry["square"] % 3, entry["square"] / 3) * CELL
		if entry.has("same_move_as"):
			_write(canvas, font, corner + Vector2(12.0, CELL * 0.55), "same move as", SMALL, Color(0.7, 0.7, 0.7))
			_write(canvas, font, corner + Vector2(12.0, CELL * 0.55 + 18.0), "the " + square_name(entry["same_move_as"]), SMALL, Color(0.7, 0.7, 0.7))
			continue
		var probability: float = entry["probability"]
		_write(canvas, font, corner + Vector2(14.0, CELL * 0.5), str(entry["beads"]), BIG, TicTacToeExample.BEAD_COLOUR)
		_write(canvas, font, corner + Vector2(14.0, CELL * 0.5 + 24.0), "beads · %d%%" % roundi(probability * 100.0), SMALL, TicTacToeExample.BEAD_COLOUR)
		var bar := Rect2(corner + Vector2(10.0, CELL - 26.0), Vector2((CELL - 20.0) * probability, 14.0))
		canvas.draw_rect(Rect2(bar.position, Vector2(CELL - 20.0, 14.0)), Color(1, 1, 1, 0.12))
		canvas.draw_rect(bar, TicTacToeExample.BEAD_COLOUR)


## A frame round the square MENACE last played.
static func draw_chosen(canvas: CanvasItem, square: int) -> void:
	var corner: Vector2 = Vector2(square % 3, square / 3) * CELL
	canvas.draw_rect(Rect2(corner + Vector2(5.0, 5.0), Vector2(CELL - 10.0, CELL - 10.0)), TicTacToeExample.CHOSEN_COLOUR, false, 4.0)


## Along the top of each empty square, what it is worth to the player to move
## with both sides perfect; the square minimax would play is framed.
static func draw_minimax(canvas: CanvasItem, board: String) -> void:
	var font: Font = ThemeDB.fallback_font
	var values: Dictionary = TicTacToeSolver.square_values(board)
	for square: int in values:
		var corner: Vector2 = Vector2(square % 3, square / 3) * CELL
		_write(canvas, font, corner + Vector2(12.0, 26.0), "perfect: " + TicTacToeSolver.words(values[square]), SMALL, TicTacToeExample.MINIMAX_COLOUR)
	var best: int = TicTacToeSolver.best_square(board)
	if best != -1:
		var corner: Vector2 = Vector2(best % 3, best / 3) * CELL
		canvas.draw_rect(Rect2(corner + Vector2(12.0, 12.0), Vector2(CELL - 24.0, CELL - 24.0)), TicTacToeExample.MINIMAX_COLOUR, false, 2.0)


## The middle of a square, in the board's own coordinates.
static func centre_of(square: int) -> Vector2:
	return (Vector2(square % 3, square / 3) + Vector2(0.5, 0.5)) * CELL


## A square as a person names it: "top left", "centre", "bottom edge".
static func square_name(square: int) -> String:
	return ["top left", "top edge", "top right", "left edge", "centre", "right edge",
			"bottom left", "bottom edge", "bottom right"][square]


static func _write(canvas: CanvasItem, font: Font, at: Vector2, words: String, size: int, colour: Color) -> void:
	canvas.draw_string_outline(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, 4, Color.BLACK)
	canvas.draw_string(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, colour)
