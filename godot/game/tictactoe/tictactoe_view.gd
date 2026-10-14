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
## How much of a square an X or an O covers.
const MARK_SIZE: float = 0.66


## The grid and the pieces on it. The marks are white pictures from `Art`,
## tinted with each side's colour; the X and the O differ in shape first.
static func draw_board(canvas: CanvasItem, board: String) -> void:
	for line: int in range(1, 3):
		canvas.draw_line(Vector2(line * CELL, 0.0), Vector2(line * CELL, 3.0 * CELL), TicTacToeExample.GRID_COLOUR, 4.0)
		canvas.draw_line(Vector2(0.0, line * CELL), Vector2(3.0 * CELL, line * CELL), TicTacToeExample.GRID_COLOUR, 4.0)
	for square: int in range(9):
		var mark: Vector2 = Vector2.ONE * CELL * MARK_SIZE
		var box := Rect2(centre_of(square) - mark / 2.0, mark)
		if board[square] == TicTacToeBoard.CROSS:
			canvas.draw_texture_rect(Art.texture(Art.CROSS), box, false, TicTacToeExample.CROSS_COLOUR)
		elif board[square] == TicTacToeBoard.NOUGHT:
			canvas.draw_texture_rect(Art.texture(Art.NOUGHT), box, false, TicTacToeExample.NOUGHT_COLOUR)


## On each empty square: its beads as a number and as a bar, and the chance
## of drawing one. A square that is another one turned says which, because its
## beads are that square's; the last square left says the move is forced.
static func draw_beads(canvas: CanvasItem, squares: Array) -> void:
	var font: Font = ThemeDB.fallback_font
	var grey := Color(0.7, 0.7, 0.7)
	for entry: Dictionary in squares:
		var corner: Vector2 = Vector2(entry["square"] % 3, entry["square"] / 3) * CELL
		if entry.get("forced", false):
			_write(canvas, font, corner + Vector2(14.0, CELL * 0.5), "forced", SMALL + 7, TicTacToeExample.BEAD_COLOUR)
			_write(canvas, font, corner + Vector2(14.0, CELL * 0.5 + 22.0), "the last square", SMALL, TicTacToeExample.BEAD_COLOUR)
			continue
		if entry.has("same_move_as"):
			_write(canvas, font, corner + Vector2(12.0, CELL * 0.55), "same move as", SMALL, grey)
			_write(canvas, font, corner + Vector2(12.0, CELL * 0.55 + 18.0), "the " + square_name(entry["same_move_as"]), SMALL, grey)
			continue
		_draw_bead_count(canvas, font, corner, entry["beads"], entry["probability"])


static func _draw_bead_count(canvas: CanvasItem, font: Font, corner: Vector2, beads: int, probability: float) -> void:
	var noun: String = "bead" if beads == 1 else "beads"
	_write(canvas, font, corner + Vector2(14.0, CELL * 0.5 + 4.0), str(beads), BIG, TicTacToeExample.BEAD_COLOUR)
	_write(canvas, font, corner + Vector2(14.0, CELL * 0.5 + 26.0), "%s · %s" % [noun, TicTacToePanel.percent(probability)], SMALL, TicTacToeExample.BEAD_COLOUR)
	var full := Rect2(corner + Vector2(10.0, CELL - 26.0), Vector2(CELL - 20.0, 14.0))
	canvas.draw_rect(full, Color(1, 1, 1, 0.12))
	canvas.draw_rect(Rect2(full.position, Vector2(full.size.x * probability, full.size.y)), TicTacToeExample.BEAD_COLOUR)


## A frame round the square MENACE last played.
static func draw_chosen(canvas: CanvasItem, square: int) -> void:
	var corner: Vector2 = Vector2(square % 3, square / 3) * CELL
	canvas.draw_rect(Rect2(corner + Vector2(5.0, 5.0), Vector2(CELL - 10.0, CELL - 10.0)), TicTacToeExample.CHOSEN_COLOUR, false, 4.0)


## Along the top of each empty square, what taking it leads to with perfect
## play, for whoever moves now. The best squares are framed -- unless every
## square is as good, when framing one would pick a favourite that is not there.
static func draw_perfect(canvas: CanvasItem, perfect: Dictionary) -> void:
	var font: Font = ThemeDB.fallback_font
	var who: String = "if X takes it" if perfect["for"] == TicTacToeExample.MENACE_SIDE else "if you take it"
	var values: Dictionary = perfect["values"]
	for square: int in values:
		var corner: Vector2 = Vector2(square % 3, square / 3) * CELL
		_write(canvas, font, corner + Vector2(10.0, 22.0), "%s: %s" % [who, TicTacToeSolver.words(values[square])], SMALL - 2, TicTacToeExample.MINIMAX_COLOUR)
	if (perfect["best"] as Array).size() == values.size():
		return
	for square: int in perfect["best"]:
		var corner: Vector2 = Vector2(square % 3, square / 3) * CELL
		canvas.draw_rect(Rect2(corner + Vector2(8.0, 30.0), Vector2(CELL - 16.0, CELL - 38.0)), TicTacToeExample.MINIMAX_COLOUR, false, 2.0)


## A line through three in a row, when somebody has them.
static func draw_winning_line(canvas: CanvasItem, board: String) -> void:
	for line: Array in TicTacToeBoard.LINES:
		var first: String = board[line[0]]
		if first != TicTacToeBoard.EMPTY and first == board[line[1]] and first == board[line[2]]:
			canvas.draw_line(centre_of(line[0]), centre_of(line[2]), Color(1, 1, 1, 0.9), 10.0)


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
