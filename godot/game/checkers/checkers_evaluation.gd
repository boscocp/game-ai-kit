## How good a checkers position looks to one player, without searching it.
##
## Three counts, the three every beginner is told to watch, each taken as the
## player's minus the opponent's:
##
## * **men**: men on the board;
## * **kings**: kings on the board;
## * **advancement**: rows advanced by the men, from their own back row.
##
## A score is each count times its weight, added up. T27 chose the weights by
## hand: a man 1, a king 1.5 because it moves both ways -- the ratio Samuel's
## 1959 paper gives, "three to two" -- and a man 0.05 more for each row it has
## advanced, at most 0.30, so advancing never pays for losing a piece.
##
## T32 fits a second set of weights to game results, in Python, and the game
## reads them from `checkers_weights.json` (`CheckersWeights`). Nothing here
## changes a weight: it only multiplies (invariant 6). Which set the search
## uses is `CheckersGame.weights`, and the search does not change.
##
## A finished game is scored by `CheckersGame`, not here.
class_name CheckersEvaluation
extends RefCounted

## The counts, in the order every weight list follows. Python's
## `gameaikit.checkers.evaluation.FEATURES` is the same list, and the
## evaluation vector holds the two to it.
const FEATURES: Array[String] = ["men", "kings", "advancement"]  # shown through tr()

const MAN: float = 1.0
const KING: float = 1.5
const ADVANCEMENT_PER_ROW: float = 0.05

## T27's weights, in the order of `FEATURES`.
const HAND_WEIGHTS: Array[float] = [MAN, KING, ADVANCEMENT_PER_ROW]


## The score of `board` for `player` by the hand-written weights.
static func score(board: CheckersBoard, player: int) -> float:
	return weighted(board, player, HAND_WEIGHTS)


## The score of `board` for `player` by `weights`: each count times its weight.
static func weighted(board: CheckersBoard, player: int, weights: Array[float]) -> float:
	var total: float = 0.0
	for part: float in contributions(board, player, weights):
		total += part
	return total


## Each count times its weight, in the order of `FEATURES`: what the panel
## shows, so a person can see which count a score is made of.
static func contributions(board: CheckersBoard, player: int, weights: Array[float]) -> Array[float]:
	var counts: Array[float] = features(board, player)
	var parts: Array[float] = []
	for index: int in range(counts.size()):
		parts.append(counts[index] * weights[index])
	return parts


## The three counts for `player`, each theirs minus the opponent's.
static func features(board: CheckersBoard, player: int) -> Array[float]:
	var mine: Array[int] = _counts(board, player)
	var theirs: Array[int] = _counts(board, CheckersBoard.opponent(player))
	var differences: Array[float] = []
	for index: int in range(mine.size()):
		differences.append(float(mine[index] - theirs[index]))
	return differences


# One side's men, kings, and rows advanced by its men.
static func _counts(board: CheckersBoard, player: int) -> Array[int]:
	var home_row: int = CheckersBoard.SIZE - 1 - CheckersBoard.crowning_row(player)
	var counted: Array[int] = [0, 0, 0]
	for square: Vector2i in board.squares_of(player):
		if CheckersBoard.is_king(board.piece_at(square)):
			counted[1] += 1
		else:
			counted[0] += 1
			counted[2] += absi(square.y - home_row)
	return counted
