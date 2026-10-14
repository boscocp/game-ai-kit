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
const CROWN := Color(0.85, 0.65, 0.10)
const SELECTED := Color(1.0, 0.95, 0.30)
const MUST_CAPTURE := Color(1.0, 0.55, 0.10)
const TARGET := Color(0.30, 0.90, 0.40, 0.55)
const LAST_MOVE := Color(0.55, 0.62, 0.80, 0.55)
const CONSIDERED := Color(0.45, 0.80, 1.0, 0.85)
const CHOSEN := Color(1.0, 0.30, 0.80)
const LABEL_BACKGROUND := Color(0.0, 0.0, 0.0, 0.72)
const TEXT_SIZE: int = 15
const NOWHERE := Vector2i(-1, -1)

var _board: CheckersBoard = CheckersBoard.new()
var _marks: Dictionary = {}
# The value labels already drawn this frame, so the next one can avoid them.
var _placed_labels: Array[Rect2] = []


## Show `board` with `marks`: any of `selected` (a square), `targets`,
## `route` and `must_capture` (lists of squares), `paths` (the moves still
## possible for the piece in hand), `last` (a move), and `considered` (the
## computer's root moves, each `{"move", "value", "exact", "chosen"}`).
func show_position(board: CheckersBoard, marks: Dictionary) -> void:
	_board = board
	_marks = marks
	queue_redraw()


## The square under a point in this node's own coordinates, or (-1, -1) off
## the board.
func square_at(point: Vector2) -> Vector2i:
	var square := Vector2i(floori(point.x / SQUARE), floori(point.y / SQUARE))
	return square if CheckersBoard.is_inside(square) else NOWHERE


## The centre of a square, in this node's own coordinates.
static func centre_of(square: Vector2i) -> Vector2:
	return (Vector2(square) + Vector2(0.5, 0.5)) * SQUARE


## A value as the board and the panel write it: signed, two decimals, `≤` in
## front of a bound, and "wins" or "loses" for a game the search saw finish.
static func value_words(value: float, exact: bool) -> String:
	var bound: String = "" if exact else "≤ "
	if value >= CheckersGame.WIN:
		# A bound at a win says nothing about the move: it was cut short once
		# a winning move had been found, and could be worth anything.
		return "wins" if exact else "≤ wins: not looked at"
	if value <= -CheckersGame.WIN:
		return bound + "loses"
	# Rounded first, so a value a hair below zero is not printed as "-0.00".
	var shown: float = snappedf(value, 0.01)
	return bound + "%+.2f" % (0.0 if is_zero_approx(shown) else shown)


func _draw() -> void:
	_placed_labels.clear()
	_draw_squares()
	_draw_squares_marked()
	_draw_hand()
	_draw_pieces()
	_draw_considered()


func _draw_squares() -> void:
	var font: Font = ThemeDB.fallback_font
	for index: int in range(CheckersBoard.SIZE * CheckersBoard.SIZE):
		var square := Vector2i(index % CheckersBoard.SIZE, index / CheckersBoard.SIZE)
		_fill(square, DARK if CheckersBoard.is_dark(square) else LIGHT)
	var size: float = CheckersBoard.SIZE * SQUARE
	for line: int in range(CheckersBoard.SIZE):
		draw_string(font, Vector2(-22.0, (line + 0.5) * SQUARE + 6.0), str(CheckersBoard.SIZE - line), HORIZONTAL_ALIGNMENT_LEFT, -1.0, TEXT_SIZE)
		draw_string(font, Vector2((line + 0.5) * SQUARE - 5.0, size + 20.0), CheckersMove.COLUMNS[line], HORIZONTAL_ALIGNMENT_LEFT, -1.0, TEXT_SIZE)


func _draw_squares_marked() -> void:
	var last: CheckersMove = _marks.get("last")
	if last != null:
		_fill(last.from(), LAST_MOVE)
		_fill(last.to(), LAST_MOVE)
	for square: Vector2i in _marks.get("targets", []):
		_fill(square, TARGET)


# The piece in hand: every route still open to it as a thin green line, the
# hops already clicked as a thick one.
func _draw_hand() -> void:
	for move: CheckersMove in _marks.get("paths", []):
		draw_polyline(_points_of(move.path), TARGET, 3.0, true)
	var route: Array = _marks.get("route", [])
	if route.size() > 1:
		draw_polyline(_points_of(route), SELECTED, 5.0, true)


func _draw_pieces() -> void:
	var radius: float = SQUARE * 0.36
	for player: int in [CheckersBoard.RED, CheckersBoard.WHITE]:
		for square: Vector2i in _board.squares_of(player):
			_draw_piece(square, player, radius)
	for square: Vector2i in _marks.get("must_capture", []):
		draw_arc(centre_of(square), radius + 6.0, 0.0, TAU, 32, MUST_CAPTURE, 4.0)
	for move: CheckersMove in _marks.get("paths", []):
		for taken: Vector2i in move.captured:
			_draw_cross(centre_of(taken), radius * 0.6, MUST_CAPTURE)
	var selected: Vector2i = _marks.get("selected", NOWHERE)
	if CheckersBoard.is_inside(selected):
		draw_arc(centre_of(selected), radius + 6.0, 0.0, TAU, 32, SELECTED, 5.0)


func _draw_piece(square: Vector2i, player: int, radius: float) -> void:
	var centre: Vector2 = centre_of(square)
	draw_circle(centre, radius + 2.0, Color.BLACK)
	draw_circle(centre, radius, RED_PIECE if player == CheckersBoard.RED else WHITE_PIECE)
	if CheckersBoard.is_king(_board.piece_at(square)):
		draw_circle(centre, radius * 0.45, CROWN)


# Each move the computer considered, as an arrow along its path with its value
# beside it. Arrows first and labels over them, so no line crosses a number;
# the chosen move's arrow is drawn after the others, and its label placed
# first, so neither is ever the one that has to give way.
func _draw_considered() -> void:
	var considered: Array = _marks.get("considered", [])
	var chosen: Array = considered.filter(func(item: Dictionary) -> bool: return item["chosen"])
	var others: Array = considered.filter(func(item: Dictionary) -> bool: return not item["chosen"])
	var boxes: Array[Rect2] = []
	for entry: Dictionary in chosen + others:
		boxes.append(_place_label(entry))
	for entry: Dictionary in others:
		_draw_arrow((entry["move"] as CheckersMove).path, CONSIDERED, 3.0)
	for entry: Dictionary in chosen:
		_draw_arrow((entry["move"] as CheckersMove).path, CHOSEN, 6.0)
	for index: int in range(boxes.size()):
		var entry: Dictionary = (chosen + others)[index]
		_write_label(entry, boxes[index], CHOSEN if entry["chosen"] else CONSIDERED)


func _draw_arrow(path: Array[Vector2i], colour: Color, width: float) -> void:
	var points: PackedVector2Array = _points_of(path)
	var tip: Vector2 = points[points.size() - 1]
	var back: Vector2 = (points[points.size() - 2] - tip).normalized()
	points[points.size() - 1] = tip + back * width * 2.0
	draw_polyline(points, colour, width, true)
	var side: Vector2 = back.orthogonal() * (width * 2.0 + 4.0)
	var base: Vector2 = tip + back * (width * 3.0 + 10.0)
	draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), colour)


# Where a move's value goes: part of the way along its last hop, moved down a
# line at a time until it overlaps no label already placed. Two moves landing
# near each other used to print one number over the other.
func _place_label(entry: Dictionary) -> Rect2:
	var path: Array[Vector2i] = (entry["move"] as CheckersMove).path
	var near: Vector2 = centre_of(path[path.size() - 2]).lerp(centre_of(path[path.size() - 1]), 0.55)
	var size: Vector2 = _label_size(_words_of(entry))
	var box := Rect2(near - size / 2.0, size)
	while _placed_labels.any(func(placed: Rect2) -> bool: return placed.intersects(box)):
		box.position.y += size.y + 2.0
	_placed_labels.append(box)
	return box


func _write_label(entry: Dictionary, box: Rect2, colour: Color) -> void:
	draw_rect(box, LABEL_BACKGROUND)
	draw_string(ThemeDB.fallback_font, box.position + Vector2(4.0, box.size.y - 6.0), _words_of(entry),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, TEXT_SIZE, colour)


func _words_of(entry: Dictionary) -> String:
	return value_words(entry["value"], entry["exact"])


func _label_size(words: String) -> Vector2:
	return ThemeDB.fallback_font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TEXT_SIZE) + Vector2(8.0, 4.0)


func _draw_cross(centre: Vector2, half: float, colour: Color) -> void:
	draw_line(centre + Vector2(-half, -half), centre + Vector2(half, half), colour, 5.0)
	draw_line(centre + Vector2(-half, half), centre + Vector2(half, -half), colour, 5.0)


func _fill(square: Vector2i, colour: Color) -> void:
	draw_rect(Rect2(Vector2(square) * SQUARE, Vector2.ONE * SQUARE), colour)


func _points_of(path: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for square: Vector2i in path:
		points.append(centre_of(square))
	return points
