## Alpha-beta: minimax that stops looking at a move once it is proved no
## better than one already found.
##
## Say MAX has already found a move worth 3. It starts on a second move and
## the first reply MIN finds there is worth 2. Whatever else MIN could reply,
## that second move is worth *at most* 2 to MAX, which is less than 3, so MAX
## will never play it -- and the rest of MIN's replies need not be looked at.
## That is a cut, and two numbers carry what makes it possible:
##
## * `alpha`, the best value MAX is already sure of on the way down;
## * `beta`, the best value MIN is already sure of on the way down.
##
## A position whose value falls outside the window between them cannot change
## the decision at the root, so the search stops there. The value and the move
## at the root are exactly minimax's -- the gdUnit suite holds that over many
## positions -- only the work changes. This file follows the pseudocode of
## Russell & Norvig, *Artificial Intelligence: A Modern Approach*, 4th edition,
## figure 5.7, with the depth cutoff of section 5.3.
##
## Complexity: still b^d in the worst case, when the best moves come last.
## With the best moves first it is about b^(d/2), which means looking twice as
## deep for the same cost. So move order matters to the speed, never to the
## answer.
##
## When not to use it: a game with chance or hidden information (see
## `GakAdversarialGame`), or one so wide that even b^(d/2) is too many -- go, for
## instance -- where Monte Carlo tree search is the usual answer.
class_name AlphaBetaSearch
extends RefCounted

# The search's state while it runs, as in `MinimaxSearch`, and one count
# more: the moves a cut left unlooked-at.
var _game: GakAdversarialGame
var _player: int = 0
var _depth_limit: int = 0
var _positions: int = 0
var _pruned: int = 0


## The best move for the player to move in `state`, looking `depth` plies
## ahead: the same move and value minimax returns, usually for less work.
##
## The root is MAX-VALUE written out, as in `MinimaxSearch`. Each root move is
## searched with the `alpha` the earlier ones earned, so a move that cannot
## beat them may come back as a bound rather than an exact value, and is
## marked so.
func search(game: GakAdversarialGame, state: RefCounted, depth: int) -> AdversarialResult:
	_game = game
	_player = game.to_move(state)
	_depth_limit = maxi(depth, 1)
	_positions = 1
	_pruned = 0
	var found := AdversarialResult.new()
	found.depth = _depth_limit
	found.value = -INF
	var alpha: float = -INF
	for action: Variant in game.actions(state):
		var pruned_before: int = _pruned
		var value: float = _value(game.result(state, action), alpha, INF, 1)
		# Above `alpha` the value is exact: the window is (alpha, +inf), and
		# a value inside it is the minimax value. At or below `alpha` it is a
		# bound when the search below cut something: it proved the move no
		# better than one already seen, and stopped. With nothing cut it
		# looked at everything, and is exact all the same.
		var exact: bool = value > alpha or _pruned == pruned_before
		found.considered.append({"action": action, "value": value, "exact": exact})
		if value > found.value:
			found.value = value
			found.action = action
		alpha = maxf(alpha, found.value)
	if found.action == null:
		found.value = game.evaluate(state, _player)
	found.positions = _positions
	found.pruned = _pruned
	return found


# MAX-VALUE or MIN-VALUE by whose turn it is at `state`, as in
# `MinimaxSearch`: a side that acts twice running stays MAX or MIN, and the
# window passes down unchanged either way.
func _value(state: RefCounted, alpha: float, beta: float, depth: int) -> float:
	if _game.to_move(state) == _player:
		return _max_value(state, alpha, beta, depth)
	return _min_value(state, alpha, beta, depth)


# MAX to move. `alpha` rises as MAX finds better moves; once the value here
# reaches `beta`, MIN -- who chooses the move above this position -- already
# has something better for itself and will never let play come here. The moves
# not yet looked at are the ones cut, and they are counted.
func _max_value(state: RefCounted, alpha: float, beta: float, depth: int) -> float:
	_positions += 1
	if _is_cutoff(state, depth):
		return _game.evaluate(state, _player)
	var value: float = -INF
	var actions: Array = _game.actions(state)
	for index: int in range(actions.size()):
		value = maxf(value, _value(_game.result(state, actions[index]), alpha, beta, depth + 1))
		if value >= beta:
			_pruned += actions.size() - index - 1
			return value
		alpha = maxf(alpha, value)
	return value


# MIN to move, the mirror image: `beta` falls as MIN finds better replies, and
# once the value here drops to `alpha`, MAX already has something better above.
func _min_value(state: RefCounted, alpha: float, beta: float, depth: int) -> float:
	_positions += 1
	if _is_cutoff(state, depth):
		return _game.evaluate(state, _player)
	var value: float = INF
	var actions: Array = _game.actions(state)
	for index: int in range(actions.size()):
		value = minf(value, _value(_game.result(state, actions[index]), alpha, beta, depth + 1))
		if value <= alpha:
			_pruned += actions.size() - index - 1
			return value
		beta = minf(beta, value)
	return value


# Stop here: the game is over, or the search has looked as far as it may.
func _is_cutoff(state: RefCounted, depth: int) -> bool:
	return _game.is_terminal(state) or depth >= _depth_limit
