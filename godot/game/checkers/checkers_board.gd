## A checkers position: which piece stands on each square, whose turn it is,
## and how long it has been since anything irreversible happened.
##
## Squares are `Vector2i(column, row)` with row 0 at the top of the screen.
## Red sits at the bottom and moves up; white sits at the top and moves down.
## Only the dark squares are played on, and on this board those are the ones
## where column + row is odd, which puts a dark square in each player's
## bottom-left corner as the rules require.
##
## A position is not changed once it has been handed out: `CheckersRules.play`
## builds a new one. That is what lets the search keep a parent while it
## explores its children, and it is why the legal moves can be remembered here.
class_name CheckersBoard
extends RefCounted

const SIZE: int = 8

const EMPTY: int = 0
const RED_MAN: int = 1
const RED_KING: int = 2
const WHITE_MAN: int = 3
const WHITE_KING: int = 4

const RED: int = 0
const WHITE: int = 1

## Plies -- one player's move each -- with no capture and no man moved, at
## which the game is drawn: forty moves by each side.
const QUIET_PLIES_TO_DRAW: int = 80

## What stands on each square, row by row from the top.
var squares: PackedInt32Array = PackedInt32Array()

## `RED` or `WHITE`.
var to_move: int = RED

## Plies since the last capture or the last move of a man. Only kings moving
## without capturing count up; anything else starts it again from zero.
var quiet_plies: int = 0

# The legal moves, worked out the first time they are asked for. A position
# never changes after it is handed out, so the answer cannot go stale, and the
# search asks the same position twice (is it over, and what can be played).
var known_moves: Array = []
var moves_are_known: bool = false


func _init() -> void:
	squares.resize(SIZE * SIZE)
	squares.fill(EMPTY)


## The opening position: twelve men each, on the three rows nearest each
## player, red to move first -- the darker pieces start.
static func starting() -> CheckersBoard:
	var board := CheckersBoard.new()
	for index: int in range(SIZE * SIZE):
		var square := Vector2i(index % SIZE, index / SIZE)
		if is_dark(square) and square.y < 3:
			board.set_piece(square, WHITE_MAN)
		elif is_dark(square) and square.y >= SIZE - 3:
			board.set_piece(square, RED_MAN)
	return board


## A position drawn as eight strings, one per row from the top, so a test can
## show the position it is about rather than list coordinates. `r` and `w` are
## men, `R` and `W` kings, anything else an empty square.
static func from_rows(rows: Array[String], side_to_move: int) -> CheckersBoard:
	var board := CheckersBoard.new()
	var pieces: Dictionary = {"r": RED_MAN, "R": RED_KING, "w": WHITE_MAN, "W": WHITE_KING}
	for row: int in range(mini(rows.size(), SIZE)):
		var letters: String = rows[row].replace(" ", "")
		for column: int in range(mini(letters.length(), SIZE)):
			board.set_piece(Vector2i(column, row), pieces.get(letters[column], EMPTY))
	board.to_move = side_to_move
	return board


## True for the squares the game is played on.
static func is_dark(square: Vector2i) -> bool:
	return (square.x + square.y) % 2 == 1


## True when `square` is on the board at all.
static func is_inside(square: Vector2i) -> bool:
	return square.x >= 0 and square.x < SIZE and square.y >= 0 and square.y < SIZE


## Which player owns `piece`: `RED`, `WHITE`, or -1 for an empty square.
static func owner_of(piece: int) -> int:
	if piece == RED_MAN or piece == RED_KING:
		return RED
	if piece == WHITE_MAN or piece == WHITE_KING:
		return WHITE
	return -1


## True for a crowned piece of either colour.
static func is_king(piece: int) -> bool:
	return piece == RED_KING or piece == WHITE_KING


## The other player.
static func opponent(player: int) -> int:
	return WHITE if player == RED else RED


## The row a man of `player` is crowned on: the far side of the board.
static func crowning_row(player: int) -> int:
	return 0 if player == RED else SIZE - 1


## Which way is forward for `player`'s men: up the screen for red, down for white.
static func forward(player: int) -> int:
	return -1 if player == RED else 1


## What stands on `square`, or `EMPTY` off the board.
func piece_at(square: Vector2i) -> int:
	if not is_inside(square):
		return EMPTY
	return squares[square.y * SIZE + square.x]


## Put `piece` on `square`. Only for building a position, before anyone asks it
## for its moves.
func set_piece(square: Vector2i, piece: int) -> void:
	squares[square.y * SIZE + square.x] = piece


## Every square holding a piece of `player`, top row first, left to right.
## The order is fixed, and the search's tie-break depends on it.
func squares_of(player: int) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for index: int in range(squares.size()):
		if owner_of(squares[index]) == player:
			found.append(Vector2i(index % SIZE, index / SIZE))
	return found


## A new position with the same pieces, the same side to move and the same
## count, and nothing remembered about its moves.
func copy() -> CheckersBoard:
	var twin := CheckersBoard.new()
	twin.squares = squares.duplicate()
	twin.to_move = to_move
	twin.quiet_plies = quiet_plies
	return twin
