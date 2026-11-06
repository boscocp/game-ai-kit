## What an adversarial search chose, and what it looked at to choose it.
##
## The move alone hides the lesson. Two searches that pick the same move can
## have done very different amounts of work, and a move worth 0.4 beside one
## worth 0.39 is a much less certain choice than one worth 0.4 beside -3. So
## the result carries every move considered at the root with its value, the
## number of positions visited, and how many moves were cut.
##
## When not to use it: a search still under way. This is the record of a
## finished one -- for expectiminimax, which runs across frames, of the
## deepest depth it has finished.
class_name AdversarialResult
extends RefCounted

## The move chosen: the first of the best, in the order the game listed them.
## Null when the position had no move at all.
var action: Variant = null

## The value of `action` for the player who was to move.
var value: float = 0.0

## One entry per move at the root, in the game's order:
## `{"action": Variant, "value": float, "exact": bool}`.
##
## `exact` is false when alpha-beta stopped early because it had already
## proved the move no better than one it had seen. `value` is then an upper
## bound -- the move is worth *at most* that -- and not its minimax value.
## Plain minimax always has `exact` true.
##
## Expectiminimax's entries are always exact, and carry one key more:
## `"outcomes": [{"probability": float, "value": float}, ...]`, what each
## outcome of the move was worth, in the game's order -- a shot's hit and
## miss, say. `value` is then their sum, each weighed by its probability.
var considered: Array[Dictionary] = []

## How many positions the search visited, the root included.
var positions: int = 0

## How many moves alpha-beta never looked at, because a move before them had
## already settled that the position would not be played into. Each one is a
## whole subtree left unsearched. Always zero for plain minimax.
var pruned: int = 0

## The depth the search looked to, in plies: one ply is one player's move.
## Expectiminimax's chance nodes add no ply. 0 when no depth has finished.
var depth: int = 0
