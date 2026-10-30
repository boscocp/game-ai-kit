## Minimax: choose the move that is best on the assumption that the opponent
## will then choose the move that is worst for you.
##
## Every search elsewhere in this kit has one side choosing alone. A game has
## two, and the second one is trying to stop you. Minimax handles that by
## asking, at every position, whose turn it is: on yours take the highest
## value, on theirs the lowest, all the way down. The player the search is
## for is MAX; the opponent is MIN. In checkers the two alternate; in a game
## where a side may act twice running, the same question gets it right.
##
## Nobody can search a game of checkers to its end, so the search stops after
## a fixed number of plies and asks the game to *evaluate* the position it
## reached. That is H-MINIMAX in Russell & Norvig, *Artificial Intelligence:
## A Modern Approach*, 4th edition, section 5.3, and this file follows the
## pseudocode of their figure 5.3 with the cutoff test of 5.3 added.
##
## Complexity: every position down to the depth is visited, so time grows as
## b^d -- b moves per position, d plies. Checkers has b around 8, so each ply
## costs roughly eight times the one before. Memory is only the current line.
##
## When not to use it: as it is here, almost never. `AlphaBetaSearch` returns
## the same move and the same value after visiting fewer positions. This file
## exists because alpha-beta is minimax with a shortcut, and the shortcut is
## easier to see beside the thing it shortens.
class_name MinimaxSearch
extends RefCounted

# The search's state while it runs: the game, the player it searches for, how
# deep it may look, and the count of positions it has visited.
var _game: GakAdversarialGame
var _player: int = 0
var _depth_limit: int = 0
var _positions: int = 0


## The best move for the player to move in `state`, looking `depth` plies
## ahead, with every root move's value and the work it took.
##
## The root is MAX-VALUE written out by hand, so that the value of every move
## is kept rather than only the best one -- that list is what the checkers
## example draws.
func search(game: GakAdversarialGame, state: RefCounted, depth: int) -> AdversarialResult:
	_game = game
	_player = game.to_move(state)
	_depth_limit = maxi(depth, 1)
	_positions = 1
	var found := AdversarialResult.new()
	found.depth = _depth_limit
	found.value = -INF
	for action: Variant in game.actions(state):
		var value: float = _value(game.result(state, action), 1)
		found.considered.append({"action": action, "value": value, "exact": true})
		# Strictly greater: an equal value later in the list does not replace
		# the first. That is the tie-break, and alpha-beta keeps the same one.
		if value > found.value:
			found.value = value
			found.action = action
	if found.action == null:
		found.value = game.evaluate(state, _player)
	found.positions = _positions
	return found


# The value of a position: MAX-VALUE when it is MAX's turn there, MIN-VALUE
# when it is anyone else's. The book's figure has the two call each other,
# which is the same thing when the players alternate and wrong when they do
# not.
func _value(state: RefCounted, depth: int) -> float:
	if _game.to_move(state) == _player:
		return _max_value(state, depth)
	return _min_value(state, depth)


# The value of a position where MAX is to move: the best of its children.
func _max_value(state: RefCounted, depth: int) -> float:
	_positions += 1
	if _is_cutoff(state, depth):
		return _game.evaluate(state, _player)
	var value: float = -INF
	for action: Variant in _game.actions(state):
		value = maxf(value, _value(_game.result(state, action), depth + 1))
	return value


# The value of a position where MIN is to move: the worst of its children,
# worst for MAX, which is the best for MIN.
func _min_value(state: RefCounted, depth: int) -> float:
	_positions += 1
	if _is_cutoff(state, depth):
		return _game.evaluate(state, _player)
	var value: float = INF
	for action: Variant in _game.actions(state):
		value = minf(value, _value(_game.result(state, action), depth + 1))
	return value


# Stop here: the game is over, or the search has looked as far as it may.
func _is_cutoff(state: RefCounted, depth: int) -> bool:
	return _game.is_terminal(state) or depth >= _depth_limit
