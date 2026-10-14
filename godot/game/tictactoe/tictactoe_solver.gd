## Noughts and crosses, solved: what every square is worth with both players
## perfect from here.
##
## It is minimax, as in `ai_adversarial` and T27's checkers, with no depth
## limit -- the whole game has 5,478 positions, so it is searched to the end
## and every answer remembered. That is what makes it the yardstick MENACE is
## measured against: the move it would play is never worse than the best one.
## Twin of `perfect_move` and `value` in `python/gameaikit/menace/opponents.py`.
class_name TicTacToeSolver
extends RefCounted

const WIN: int = 1
const DRAW: int = 0
const LOSS: int = -1

# board + player -> value, filled as positions are solved.
static var _known: Dictionary = {}


## What the game is worth to `player` (`X` or `O`) with both sides perfect.
static func value(board: String, player: String) -> int:
	var key: String = board + player
	if _known.has(key):
		return _known[key]
	var outcome: String = TicTacToeBoard.winner(board)
	var worth: int = DRAW
	if outcome == player:
		worth = WIN
	elif outcome != "" and outcome != TicTacToeBoard.DRAW:
		worth = LOSS
	elif outcome == "":
		worth = _best_of_children(board, player)
	_known[key] = worth
	return worth


## What each empty square is worth to the player to move, if they take it.
static func square_values(board: String) -> Dictionary:
	var player: String = TicTacToeBoard.to_move(board)
	var found: Dictionary = {}
	for square: int in TicTacToeBoard.moves(board):
		found[square] = value(TicTacToeBoard.play(board, square), player)
	return found


## The square minimax plays: the best value, the lowest square on a tie.
static func best_square(board: String) -> int:
	var values: Dictionary = square_values(board)
	var best: int = -1
	for square: int in values:
		if best == -1 or values[square] > values[best]:
			best = square
	return best


## Every square as good as the best one. All of them, not the first: on the
## empty board every square draws, and naming one of them made a machine that
## chose the centre look as if it had got the opening wrong.
static func best_squares(board: String) -> Array[int]:
	var values: Dictionary = square_values(board)
	var found: Array[int] = []
	for square: int in values:
		if values[square] == values[best_square(board)]:
			found.append(square)
	return found


## How a value reads on the board.
static func words(worth: int) -> String:
	return {WIN: "wins", DRAW: "draws", LOSS: "loses"}[worth]


# Max over the children when `player` moves, min when the other one does.
static func _best_of_children(board: String, player: String) -> int:
	var mine: bool = TicTacToeBoard.to_move(board) == player
	var best: int = LOSS - 1 if mine else WIN + 1
	for square: int in TicTacToeBoard.moves(board):
		var child: int = value(TicTacToeBoard.play(board, square), player)
		best = maxi(best, child) if mine else mini(best, child)
	return best
