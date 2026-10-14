## Noughts and crosses, and the eight ways of turning the board.
##
## A board is a String of nine characters, row by row from the top left: `X`,
## `O`, or `.` for an empty square -- the same text the published bead file
## uses for its keys, so a box can be looked up by the board itself.
##
## This is the GDScript twin of `python/gameaikit/menace/board.py`, and the two
## must agree exactly: which turn of the board is found first decides which
## real square a bead stands for. `spec/vectors/menace/` holds them to it.
class_name TicTacToeBoard
extends RefCounted

const EMPTY: String = "."
const CROSS: String = "X"
const NOUGHT: String = "O"
const DRAW: String = "draw"
const START: String = "........."

## The eight lines that win.
const LINES: Array[Array] = [
	[0, 1, 2], [3, 4, 5], [6, 7, 8],
	[0, 3, 6], [1, 4, 7], [2, 5, 8],
	[0, 4, 8], [2, 4, 6],
]

## The eight symmetries of the square, in Python's order: the turned board has,
## on square `i`, what the original had on square `SYMMETRIES[k][i]`.
const SYMMETRIES: Array[Array] = [
	[0, 1, 2, 3, 4, 5, 6, 7, 8],
	[6, 3, 0, 7, 4, 1, 8, 5, 2],
	[8, 7, 6, 5, 4, 3, 2, 1, 0],
	[2, 5, 8, 1, 4, 7, 0, 3, 6],
	[2, 1, 0, 5, 4, 3, 8, 7, 6],
	[6, 7, 8, 3, 4, 5, 0, 1, 2],
	[0, 3, 6, 1, 4, 7, 2, 5, 8],
	[8, 5, 2, 7, 4, 1, 6, 3, 0],
]


## Whose turn it is. Crosses move first, as MENACE did.
static func to_move(board: String) -> String:
	return CROSS if board.count(CROSS) == board.count(NOUGHT) else NOUGHT


## `X` or `O` for a won game, `draw` for a full board, "" while it goes on.
static func winner(board: String) -> String:
	for line: Array in LINES:
		var first: String = board[line[0]]
		if first != EMPTY and first == board[line[1]] and first == board[line[2]]:
			return first
	return DRAW if not board.contains(EMPTY) else ""


## The empty squares, in order, while the game is not over.
static func moves(board: String) -> Array[int]:
	var found: Array[int] = []
	if winner(board) != "":
		return found
	for square: int in range(9):
		if board[square] == EMPTY:
			found.append(square)
	return found


## The board after the player to move takes `square`.
static func play(board: String, square: int) -> String:
	return board.substr(0, square) + to_move(board) + board.substr(square + 1)


## The board turned by one of the eight symmetries.
static func turned(board: String, symmetry: int) -> String:
	var letters: String = ""
	for source: int in SYMMETRIES[symmetry]:
		letters += board[source]
	return letters


## The position's matchbox -- the smallest of the eight turned boards, compared
## as text -- and the first symmetry that turns the board into it.
static func canonical(board: String) -> Array:
	var best: String = turned(board, 0)
	var found: int = 0
	for symmetry: int in range(1, 8):
		var candidate: String = turned(board, symmetry)
		if candidate < best:
			best = candidate
			found = symmetry
	return [best, found]


## The real square a square of the board's box stands for.
static func real_square(board: String, box_square: int) -> int:
	return SYMMETRIES[canonical(board)[1]][box_square]


## The box square that stands for the same move as `square`: the lowest square
## any symmetry keeping the box unchanged sends it to. On the empty board the
## four corners are one move, and corner 0 holds their beads.
static func representative(box: String, square: int) -> int:
	var lowest: int = square
	for symmetry: int in range(8):
		if turned(box, symmetry) == box:
			lowest = mini(lowest, SYMMETRIES[symmetry][square])
	return lowest
