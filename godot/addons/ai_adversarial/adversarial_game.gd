## What a two-player game must tell an adversarial search: whose turn it is,
## what can be played, what playing it leads to -- for certain or by chance --
## and how good a position looks.
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
## * `to_move` is the only word on whose turn it is. The searches read it at
##   every position, so a side may act several times in a row -- one unit's
##   move, then another's -- and nothing assumes the players alternate;
## * `is_terminal` is true whenever `actions` would be empty, because a
##   position with no moves and no verdict has no value to give;
## * `evaluate(state, player)` is higher when `state` is better for `player`,
##   and is never infinite: the search uses infinity as "nothing seen yet".
##
## Chance is told through `outcomes`: what an action may lead to, each with
## its probability. A game without dice need not mention it -- the default
## is `result`, for certain. Monte Carlo tree search samples from it; minimax
## and alpha-beta read only `result`, so they see a game with dice as if the
## dice always fell the one way `result` says.
##
## When not to use it: a game with hidden cards. Every search here assumes
## both players see the whole state.
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


## Every state `action` may lead to from `state`, each with its chance:
## `[{"probability": float, "state": RefCounted}, ...]`, the probabilities
## adding up to 1, in a fixed order.
##
## Concrete, not abstract, so that a game without chance -- checkers -- never
## has to write it: one outcome, `result`, certain. A game with dice
## overrides it, and `result` should then be one of the outcomes, the one a
## search that cannot handle chance will assume.
func outcomes(state: RefCounted, action: Variant) -> Array:
	return [{"probability": 1.0, "state": result(state, action)}]
