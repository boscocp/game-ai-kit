## How good a checkers position looks to one player, without searching it.
##
## Three things, the three every beginner is told to count:
##
## * **pieces**: a man is worth 1;
## * **kings**: a king is worth 1.5, because it moves both ways;
## * **advancement**: a man is worth 0.05 more for each row it has advanced,
##   because it is that much nearer to being crowned. A man is crowned on
##   its seventh row, so six rows, 0.30, is the most it earns -- less than a
##   man, so advancing never pays for losing a piece.
##
## The score is the player's total minus the opponent's, so 0 is level, +1 is
## a man up. It is deliberately short and deliberately naive: T32 replaces it
## with weights fitted from games, after Samuel, and the search does not change.
## A finished game is scored by `CheckersGame`, not here.
class_name CheckersEvaluation
extends RefCounted

const MAN: float = 1.0
const KING: float = 1.5
const ADVANCEMENT_PER_ROW: float = 0.05


## The score of `board` for `player`: material and advancement, theirs minus
## the opponent's.
static func score(board: CheckersBoard, player: int) -> float:
	return side_total(board, player) - side_total(board, CheckersBoard.opponent(player))


## What one side's pieces are worth by the three counts above.
static func side_total(board: CheckersBoard, player: int) -> float:
	var total: float = 0.0
	var home_row: int = CheckersBoard.SIZE - 1 - CheckersBoard.crowning_row(player)
	for square: Vector2i in board.squares_of(player):
		if CheckersBoard.is_king(board.piece_at(square)):
			total += KING
		else:
			total += MAN + ADVANCEMENT_PER_ROW * absi(square.y - home_row)
	return total
