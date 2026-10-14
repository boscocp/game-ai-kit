## Draws a checkers position, what the player may do with it, and what the
## computer is thinking about doing.
##
## Everything is drawn with `_draw` -- an 8x8 board is sixty-four rectangles,
## and a tile map would add a tile set to explain. The view holds no rules: the
## scene hands it a position and the marks to put on it.
class_name CheckersView
extends Node2D

const SQUARE: float = 72.0
const LIGHT := Color(0.93, 0.87, 0.75)
const DARK := Color(0.47, 0.32, 0.22)
const RED_PIECE := Color(0.80, 0.16, 0.16)
const WHITE_PIECE := Color(0.96, 0.95, 0.90)
const CROWN := Color(1.0, 0.80, 0.20)
const SELECTED := Color(1.0, 0.95, 0.30)
const MUST_CAPTURE := Color(1.0, 0.55, 0.10)
const TARGET := Color(0.30, 0.90, 0.40, 0.55)
const LAST_MOVE := Color(0.55, 0.75, 1.0, 0.45)
const CONSIDERED := Color(0.45, 0.80, 1.0, 0.85)
const CHOSEN := Color(1.0, 0.80, 0.10)
const TEXT_SIZE: int = 16

var _board: CheckersBoard = CheckersBoard.new()
var _marks: Dictionary = {}


## Show `board` with `marks`: any of `selected` (a square), `targets` and
## `must_capture` (lists of squares), `last` (a move), and `considered` (the
## computer's root moves, each `{"move", "value", "exact", "chosen"}`).
func show_position(board: CheckersBoard, marks: Dictionary) -> void:
	_board = board
	_marks = marks
	queue_redraw()


## The square under a point in this node's own coordinates, or (-1, -1) off
## the board.
func square_at(point: Vector2) -> Vector2i:
	var square := Vector2i(floori(point.x / SQUARE), floori(point.y / SQUARE))
	return square if CheckersBoard.is_inside(square) else Vector2i(-1, -1)


## The centre of a square, in this node's own coordinates.
static func centre_of(square: Vector2i) -> Vector2:
	return (Vector2(square) + Vector2(0.5, 0.5)) * SQUARE


func _draw() -> void:
	_draw_squares()
	_draw_last_move()
	_draw_targets()
	_draw_pieces()
	_draw_considered()


func _draw_squares() -> void:
	var font: Font = ThemeDB.fallback_font
	for row: int in range(CheckersBoard.SIZE):
		for column: int in range(CheckersBoard.SIZE):
			var square := Vector2i(column, row)
			draw_rect(Rect2(Vector2(square) * SQUARE, Vector2.ONE * SQUARE), DARK if CheckersBoard.is_dark(square) else LIGHT)
		var size: float = CheckersBoard.SIZE * SQUARE
		draw_string(font, Vector2(-22.0, (row + 0.5) * SQUARE + 6.0), str(CheckersBoard.SIZE - row), HORIZONTAL_ALIGNMENT_LEFT, -1.0, TEXT_SIZE)
		draw_string(font, Vector2((row + 0.5) * SQUARE - 5.0, size + 20.0), CheckersMove.COLUMNS[row], HORIZONTAL_ALIGNMENT_LEFT, -1.0, TEXT_SIZE)


func _draw_last_move() -> void:
	var last: CheckersMove = _marks.get("last")
	if last == null:
		return
	for square: Vector2i in [last.from(), last.to()]:
		draw_rect(Rect2(Vector2(square) * SQUARE, Vector2.ONE * SQUARE), LAST_MOVE)


func _draw_targets() -> void:
	for square: Vector2i in _marks.get("targets", []):
		draw_rect(Rect2(Vector2(square) * SQUARE, Vector2.ONE * SQUARE), TARGET)


func _draw_pieces() -> void:
	var radius: float = SQUARE * 0.36
	for player: int in [CheckersBoard.RED, CheckersBoard.WHITE]:
		for square: Vector2i in _board.squares_of(player):
			_draw_piece(square, player, radius)
	for square: Vector2i in _marks.get("must_capture", []):
		draw_arc(centre_of(square), radius + 6.0, 0.0, TAU, 32, MUST_CAPTURE, 4.0)
	var selected: Vector2i = _marks.get("selected", Vector2i(-1, -1))
	if CheckersBoard.is_inside(selected):
		draw_arc(centre_of(selected), radius + 6.0, 0.0, TAU, 32, SELECTED, 5.0)


func _draw_piece(square: Vector2i, player: int, radius: float) -> void:
	var centre: Vector2 = centre_of(square)
	draw_circle(centre, radius + 2.0, Color.BLACK)
	draw_circle(centre, radius, RED_PIECE if player == CheckersBoard.RED else WHITE_PIECE)
	if CheckersBoard.is_king(_board.piece_at(square)):
		draw_circle(centre, radius * 0.45, CROWN)


# Each move the computer considered, as a line along its path with its value
# written on it. The chosen one is drawn last, so nothing covers it.
func _draw_considered() -> void:
	var considered: Array = _marks.get("considered", [])
	for entry: Dictionary in considered.filter(func(item: Dictionary) -> bool: return not item["chosen"]):
		_draw_one_considered(entry, CONSIDERED, 3.0)
	for entry: Dictionary in considered.filter(func(item: Dictionary) -> bool: return item["chosen"]):
		_draw_one_considered(entry, CHOSEN, 6.0)


func _draw_one_considered(entry: Dictionary, colour: Color, width: float) -> void:
	var move: CheckersMove = entry["move"]
	var points := PackedVector2Array()
	for square: Vector2i in move.path:
		points.append(centre_of(square))
	draw_polyline(points, colour, width, true)
	draw_circle(points[points.size() - 1], width + 3.0, colour)
	# The value sits part of the way along the last hop, so two moves landing
	# on the same square from different pieces keep their numbers apart.
	var label_at: Vector2 = points[points.size() - 2].lerp(points[points.size() - 1], 0.6)
	var words: String = value_words(entry["value"], entry["exact"])
	var font: Font = ThemeDB.fallback_font
	var offset := Vector2(-font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TEXT_SIZE).x / 2.0, 6.0)
	draw_string_outline(font, label_at + offset, words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TEXT_SIZE, 5, Color.BLACK)
	draw_string(font, label_at + offset, words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TEXT_SIZE, colour)


## A value as the board and the panel write it: signed, two decimals, `≤` in
## front of a bound, and "wins" or "loses" for a game the search saw finish.
static func value_words(value: float, exact: bool) -> String:
	var bound: String = "" if exact else "≤ "
	if value >= CheckersGame.WIN:
		return "wins"
	if value <= -CheckersGame.WIN:
		return bound + "loses"
	return bound + "%+.2f" % value
