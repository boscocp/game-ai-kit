## Draws the noughts-and-crosses board and what is on its squares: the pieces,
## MENACE's beads for each move, the move it drew, and what perfect play makes
## of each square.
##
## Static functions that draw onto the scene's own canvas, because the scene
## is a 3x3 grid and a second node would only pass the board along. Every
## word goes through `TranslationServer.translate` before it is drawn: text
## handed to `draw_string` is drawn as it is given (T79).
class_name TicTacToeView
extends RefCounted

const CELL: float = TicTacToeExample.CELL
const BIG: int = 34
const SMALL: int = 15
## How much of a square an X or an O covers.
const MARK_SIZE: float = 0.66
## The squares as a person names them, in board order.
const SQUARE_NAMES: Array[String] = ["top left", "top edge", "top right",  # shown through tr()
		"left edge", "centre", "right edge", "bottom left", "bottom edge", "bottom right"]
## What taking a square leads to with perfect play, by `TicTacToeSolver.words`
## and by who would take it.
const IF_CROSS_TAKES: Dictionary = {  # shown through tr()
	"wins": "if X takes it: wins", "draws": "if X takes it: draws", "loses": "if X takes it: loses"}
const IF_YOU_TAKE: Dictionary = {  # shown through tr()
	"wins": "if you take it: wins", "draws": "if you take it: draws", "loses": "if you take it: loses"}


## The grid and the pieces on it. The marks are white pictures from `Art`,
## tinted with each side's colour; the X and the O differ in shape first.
static func draw_board(canvas: CanvasItem, board: String) -> void:
	for line: int in range(1, 3):
		canvas.draw_line(Vector2(line * CELL, 0.0), Vector2(line * CELL, 3.0 * CELL), TicTacToeExample.GRID_COLOUR, 4.0)
		canvas.draw_line(Vector2(0.0, line * CELL), Vector2(3.0 * CELL, line * CELL), TicTacToeExample.GRID_COLOUR, 4.0)
	var mark: Vector2 = Vector2.ONE * CELL * MARK_SIZE
	for square: int in range(9):
		var picture: String = picture_of(board[square])
		if not picture.is_empty():
			var colour: Color = TicTacToeExample.CROSS_COLOUR if board[square] == TicTacToeBoard.CROSS else TicTacToeExample.NOUGHT_COLOUR
			canvas.draw_texture_rect(Art.texture(picture), Rect2(centre_of(square) - mark / 2.0, mark), false, colour)


## The picture a square's mark is drawn with, or nothing for an empty square.
static func picture_of(mark: String) -> String:
	if mark == TicTacToeBoard.CROSS:
		return Art.CROSS
	if mark == TicTacToeBoard.NOUGHT:
		return Art.NOUGHT
	return ""


## On each empty square: its beads as a number and as a bar, and the chance
## of drawing one. A square that is another one turned says which, because its
## beads are that square's; the last square left says the move is forced.
static func draw_beads(canvas: CanvasItem, squares: Array) -> void:
	var font: Font = ThemeDB.fallback_font
	var grey := Color(0.7, 0.7, 0.7)
	for entry: Dictionary in squares:
		var corner: Vector2 = Vector2(entry["square"] % 3, entry["square"] / 3) * CELL
		if entry.get("forced", false):
			_write(canvas, font, corner + Vector2(14.0, CELL * 0.5), TranslationServer.translate("forced"), SMALL + 7, TicTacToeExample.BEAD_COLOUR)
			_write(canvas, font, corner + Vector2(14.0, CELL * 0.5 + 22.0), TranslationServer.translate("the last square"), SMALL, TicTacToeExample.BEAD_COLOUR)
			continue
		if entry.has("same_move_as"):
			_write(canvas, font, corner + Vector2(12.0, CELL * 0.55), TranslationServer.translate("same move as"), SMALL, grey)
			_write(canvas, font, corner + Vector2(12.0, CELL * 0.55 + 18.0), TranslationServer.translate("the {square}").format({square = square_name(entry["same_move_as"])}), SMALL, grey)
			continue
		_draw_bead_count(canvas, font, corner, entry["beads"], entry["probability"])


static func _draw_bead_count(canvas: CanvasItem, font: Font, corner: Vector2, beads: int, probability: float) -> void:
	var count_line: String = TranslationServer.translate("beads · {percent}")
	if beads == 1:
		count_line = TranslationServer.translate("bead · {percent}")
	_write(canvas, font, corner + Vector2(14.0, CELL * 0.5 + 4.0), str(beads), BIG, TicTacToeExample.BEAD_COLOUR)
	_write(canvas, font, corner + Vector2(14.0, CELL * 0.5 + 26.0), count_line.format({percent = TicTacToePanel.percent(probability)}), SMALL, TicTacToeExample.BEAD_COLOUR)
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
	var outcomes: Dictionary = IF_CROSS_TAKES if perfect["for"] == TicTacToeExample.MENACE_SIDE else IF_YOU_TAKE
	var values: Dictionary = perfect["values"]
	for square: int in values:
		var corner: Vector2 = Vector2(square % 3, square / 3) * CELL
		_write(canvas, font, corner + Vector2(10.0, 22.0), TranslationServer.translate(outcomes[TicTacToeSolver.words(values[square])]), SMALL - 2, TicTacToeExample.MINIMAX_COLOUR)
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
	return TranslationServer.translate(SQUARE_NAMES[square])


static func _write(canvas: CanvasItem, font: Font, at: Vector2, words: String, size: int, colour: Color) -> void:
	canvas.draw_string_outline(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, 4, Color.BLACK)
	canvas.draw_string(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, colour)
