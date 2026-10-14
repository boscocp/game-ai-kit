## What a two-player game must tell an adversarial search: whose turn it is,
## what can be played, what playing it leads to, and how good a position looks.
##
## The names are the ones Russell & Norvig give the formal definition of a game
## (*Artificial Intelligence: A Modern Approach*, 4th edition, section 5.1):
## `to_move`, `actions`, `result`, `is_terminal`. Their `UTILITY` only scores a
## finished game, and a search that stops at a fixed depth also has to score an
## unfinished one, so the two are folded into `evaluate`, the book's `EVAL`
## from section 5.3. On a finished game it must return the true outcome.
##
## A state and an action are whatever the game says they are. The search never
## looks inside either: it only hands them back to the game.
##
## An implementation must guarantee:
##
## * `result` returns a new state and does not change the one it was given,
##   because the search keeps the parent while it explores the children;
## * `actions` returns the same actions in the same order every time it is
##   asked about the same state. The tie-break between equally good moves is
##   "the first one", so an order that changed would change the move;
## * the players alternate: after one player's action it is the other's turn.
##   A move made of several hops, like a multi-jump in checkers, is one action;
## * `is_terminal` is true whenever `actions` would be empty, because a
##   position with no moves and no verdict has no value to give;
## * `evaluate(state, player)` is higher when `state` is better for `player`,
##   and is never infinite: the search uses infinity as "nothing seen yet".
##
## When not to use it: a game with dice or hidden cards. Minimax assumes both
## players see everything and nothing is left to chance; those games need
## expectiminimax or a different family altogether.
@abstract
class_name AdversarialGame
extends RefCounted


## The player whose turn it is in `state`.
@abstract func to_move(state: RefCounted) -> int


## Every action the player to move may take in `state`, in a fixed order.
@abstract func actions(state: RefCounted) -> Array


## The state that playing `action` in `state` leads to.
@abstract func result(state: RefCounted, action: Variant) -> RefCounted


## True when the game is over in `state`, so there is nothing left to search.
@abstract func is_terminal(state: RefCounted) -> bool


## How good `state` is for `player`: the outcome if the game is over, an
## estimate if it is not.
@abstract func evaluate(state: RefCounted, player: int) -> float
