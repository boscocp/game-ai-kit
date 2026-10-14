## Checkers, described the way `ai_adversarial` asks a game to be described.
##
## This file is the whole of the join between the rules and the search: four
## questions answered by `CheckersRules`, and a fifth, how good a position is,
## answered by `CheckersEvaluation` -- or by the outcome, when the game is over.
## Swap the evaluation and the search plays differently without changing a
## line of `ai_adversarial`, which is what T32 does.
class_name CheckersGame
extends AdversarialGame

## What a won game is worth. Far above anything the evaluation can return --
## twelve kings come to 18 -- so the search never trades a win for material.
const WIN: float = 1000.0


## Red or white: whoever is to move on the board.
func to_move(state: RefCounted) -> int:
	return (state as CheckersBoard).to_move


## The legal moves, captures only when one exists.
func actions(state: RefCounted) -> Array:
	return CheckersRules.legal_moves(state as CheckersBoard)


## The position after the move.
func result(state: RefCounted, action: Variant) -> RefCounted:
	return CheckersRules.play(state as CheckersBoard, action as CheckersMove)


## Over when the side to move cannot move, or the 40-move rule has drawn it.
func is_terminal(state: RefCounted) -> bool:
	return CheckersRules.is_over(state as CheckersBoard)


## A win is `WIN`, a loss `-WIN`, a draw 0, and an unfinished game is the
## hand-written evaluation.
func evaluate(state: RefCounted, player: int) -> float:
	var board := state as CheckersBoard
	if CheckersRules.is_draw(board):
		return 0.0
	var winner: int = CheckersRules.winner(board)
	if winner != -1:
		return WIN if winner == player else -WIN
	return CheckersEvaluation.score(board, player)
