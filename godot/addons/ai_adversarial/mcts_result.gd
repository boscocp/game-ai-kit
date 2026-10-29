## Where a Monte Carlo tree search stands: what it would play now, and what
## it has learned about every move at the root so far.
##
## Unlike `AdversarialResult`, this is not the record of a finished search.
## MCTS can be stopped after any iteration and still has an answer, so a
## caller asks for one after every `step` and may draw it while the search
## goes on: the visits growing on the move it believes in, the bounds of the
## others shrinking towards their means.
##
## When not to use it: to compare with alpha-beta's values. A mean here is
## the average outcome of random playouts, not a minimax value; the two are
## on different scales even when the game's `evaluate` is the same.
class_name MctsResult
extends RefCounted

## The move to play if the search stopped now: the most visited, and of
## equally visited ones the first in the game's order. Null when the
## position had no move. The most visited, not the best mean, because a
## mean from three playouts is a guess and one from three hundred is not.
var action: Variant = null

## One entry per move at the root, in the game's order:
## `{"action": Variant, "visits": int, "mean": float, "bound": float}`.
##
## `mean` is the average value of the playouts through the move, for the
## player to move at the root. `bound` is UCB1's upper confidence bound,
## the number selection compares: the mean plus a bonus that shrinks as the
## move is tried. A move never tried has 0 visits, a mean of 0 and a bound
## of `INF` -- it will be tried before any move is tried twice.
var considered: Array[Dictionary] = []

## How many iterations the search has run since it started: one iteration
## is one selection, one expansion, one playout and one backpropagation.
var iterations: int = 0
