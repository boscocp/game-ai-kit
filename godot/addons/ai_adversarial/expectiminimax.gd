## Expectiminimax: minimax for a game with dice. MAX takes the best move,
## MIN the worst for MAX, and where the dice decide, nobody chooses -- the
## position is worth what each outcome is worth, weighed by its chance.
##
## That third kind of position is the chance node. `GakAdversarialGame`
## tells it through `outcomes`: an action leads to several states, each
## with its probability. A move's value is then not one child's value but
## the sum of probability times value over its outcomes -- its *expected*
## value -- and MAX and MIN choose between expected values. Russell &
## Norvig, *Artificial Intelligence: A Modern Approach*, 4th edition,
## section 5.5 (Stochastic Games), write it as one more case of MINIMAX;
## this file is that case, with the depth cutoff of section 5.3. The
## evaluation at the cutoff matters more than in minimax: a chance node
## *adds* values, so only their order no longer suffices -- doubling one
## leaf can change the move (section 5.5.1; `expectiminimax_test.gd`
## holds the book's example).
##
## Anytime, by iterative deepening: depth 1, then 2, then 3, each searched
## from scratch, and the answer is always the deepest *finished* depth's.
## The walk down is kept on an explicit stack rather than in recursion, so
## that `step` can stop after any number of positions -- one frame's worth
## -- and pick up there next frame. The walk is the same as the recursive
## one would be: same order, same values, same count of positions.
##
## Complexity: (b n)^d for b moves and n outcomes a move, at depth d -- the
## dice multiply the branching. No pruning: alpha-beta's cut needs a bound
## on what an unseen outcome may be worth, and *-minimax gets one only from
## the evaluation's range. Memory is the stack, one entry a ply.
##
## When not to use it: a game without chance (alpha-beta is the same answer
## for less work), or one whose evaluation you cannot write -- Monte Carlo
## tree search needs none.
class_name ExpectiminimaxSearch
extends RefCounted

## How deep iterative deepening goes at most, in plies, unless told less.
const DEEPEST: int = 64


## One position on the way down, and how far through it the walk is: the
## move under way, which of its outcomes comes next, and the expected value
## added up so far for that move.
class Visit extends RefCounted:
	var state: RefCounted
	var depth: int
	var maximising: bool
	var actions: Array
	var move: int = 0
	var outcomes: Array = []
	var outcome: int = 0
	var expected: float = 0.0
	var value: float = 0.0
	## Only the root keeps every move's outcomes and values, for the result.
	var keeps_moves: bool = false
	var outcome_values: Array[Dictionary] = []
	var move_values: Array[Dictionary] = []


var _game: GakAdversarialGame
var _root_state: RefCounted
var _player: int = 0
var _deepest: int = DEEPEST
var _depth_limit: int = 1
var _stack: Array[Visit] = []
# Positions visited by the depth under way, and by every depth so far.
var _positions: int = 0
var _positions_in_all: int = 0
# Whether the depth under way stopped anywhere because of the depth limit
# rather than the end of the game: if not, searching deeper finds nothing new.
var _cut_by_depth: bool = false
var _complete: bool = false
var _finished: AdversarialResult


## A search for the player to move in `state`. Nothing is searched until
## `step` or `search_to` is called.
func _init(game: GakAdversarialGame, state: RefCounted, deepest: int = DEEPEST) -> void:
	_game = game
	_root_state = state
	_player = game.to_move(state)
	_deepest = maxi(deepest, 1)
	_finished = _nothing_finished()
	if game.is_terminal(state) or game.actions(state).is_empty():
		_complete = true
		return
	_start_depth()


## Visit `positions` more positions and say where the search stands: the
## deepest finished depth's answer. Counted in positions, never cut by the
## clock, so the same calls give the same answer on any machine -- the
## caller decides how many fit in its frame, as with `MonteCarloSearch.step`.
func step(positions: int) -> AdversarialResult:
	var stop_at: int = _positions_in_all + positions
	while _positions_in_all < stop_at and not _complete:
		_advance()
	return _finished


## Search until depth `depth` is finished -- or the game has nothing
## deeper -- and no further; its answer. For a caller that wants one depth,
## as `MinimaxSearch.search` gives it.
func search_to(depth: int) -> AdversarialResult:
	_deepest = mini(_deepest, maxi(depth, 1))
	while not _complete:
		_advance()
	return _finished


## The deepest finished depth's answer, without searching further. Before
## depth 1 has finished, a result with no action and depth 0.
func result() -> AdversarialResult:
	return _finished


## The depth being searched now; the finished one is `result().depth`.
func depth_under_way() -> int:
	return 0 if _complete else _depth_limit


## Every position visited since the search began, all depths together: the
## work done, where `result().positions` is the finished depth's alone.
func positions_visited() -> int:
	return _positions_in_all


## True once there is nothing more to search: the deepest depth allowed is
## finished, or a depth ran into nothing but finished games.
func is_complete() -> bool:
	return _complete


# One step of the walk, from the position on top of the stack. With an
# outcome of the move under way still to look at, look at it: score it if
# the search stops there, or go down into it. With none, the move is
# finished; with no move left, the position is, and its value goes up to
# the one above. A step counts one position at most.
func _advance() -> void:
	var top: Visit = _stack.back()
	if top.outcome < top.outcomes.size():
		var next: RefCounted = top.outcomes[top.outcome]["state"]
		if _is_cutoff(next, top.depth + 1):
			_add_outcome(top, _game.evaluate(next, _player))
		else:
			_stack.push_back(_visit_of(next, top.depth + 1))
		_count_position()
		return
	_finish_move(top)
	if top.move < top.actions.size():
		return
	_stack.pop_back()
	if _stack.is_empty():
		_finish_depth(top)
	else:
		_add_outcome(_stack.back(), top.value)


# The outcome under way at `visit` is worth `value`: its chance times that
# goes into the move's expected value -- the chance node's sum.
func _add_outcome(visit: Visit, value: float) -> void:
	var probability: float = float(visit.outcomes[visit.outcome]["probability"])
	visit.expected += probability * value
	if visit.keeps_moves:
		visit.outcome_values.append({"probability": probability, "value": value})
	visit.outcome += 1


# Every outcome of the move under way at `visit` is in: MAX keeps the
# higher of it and the best so far, MIN the lower. Then on to the next
# move, its outcomes asked of the game.
func _finish_move(visit: Visit) -> void:
	if visit.maximising:
		visit.value = maxf(visit.value, visit.expected)
	else:
		visit.value = minf(visit.value, visit.expected)
	if visit.keeps_moves:
		visit.move_values.append({"action": visit.actions[visit.move], "value": visit.expected,
			"exact": true, "outcomes": visit.outcome_values})
		visit.outcome_values = []
	visit.move += 1
	_open_move(visit)


# Ready `visit` to look at its move under way: its outcomes, none yet added.
func _open_move(visit: Visit) -> void:
	visit.outcome = 0
	visit.expected = 0.0
	visit.outcomes = _game.outcomes(visit.state, visit.actions[visit.move]) if visit.move < visit.actions.size() else []


# A position to walk down from: MAX's when the player searched for is to
# move there, MIN's otherwise -- read at every position, so a side that
# moves twice running stays MAX.
func _visit_of(state: RefCounted, depth: int) -> Visit:
	var visit := Visit.new()
	visit.state = state
	visit.depth = depth
	visit.maximising = _game.to_move(state) == _player
	visit.value = -INF if visit.maximising else INF
	visit.actions = _game.actions(state)
	_open_move(visit)
	return visit


# Stop here: the game is over, or has no move -- a game that breaks
# `GakAdversarialGame`'s promise is scored, not searched, in both
# languages -- or the search has looked as far as this depth may. Only the
# last makes a deeper search worth starting.
func _is_cutoff(state: RefCounted, depth: int) -> bool:
	if _game.is_terminal(state) or _game.actions(state).is_empty():
		return true
	if depth >= _depth_limit:
		_cut_by_depth = true
		return true
	return false


# A new depth from the root: the root visited, nothing cut yet.
func _start_depth() -> void:
	_positions = 0
	_cut_by_depth = false
	var root: Visit = _visit_of(_root_state, 0)
	root.keeps_moves = true
	_stack.push_back(root)
	_count_position()


func _count_position() -> void:
	_positions += 1
	_positions_in_all += 1


# The root is finished at this depth: its answer is now the one to give,
# the first of the best moves, and the next depth begins -- unless this one
# met nothing but finished games, or was the deepest allowed.
func _finish_depth(root: Visit) -> void:
	var found := AdversarialResult.new()
	found.depth = _depth_limit
	found.positions = _positions
	found.value = -INF
	for entry: Dictionary in root.move_values:
		found.considered.append(entry)
		# Strictly greater: of equal values the first, as minimax breaks ties.
		if entry["value"] > found.value:
			found.value = entry["value"]
			found.action = entry["action"]
	_finished = found
	if not _cut_by_depth or _depth_limit >= _deepest:
		_complete = true
		return
	_depth_limit += 1
	_start_depth()


# The answer before any depth has finished: no move, the position's own
# evaluation.
func _nothing_finished() -> AdversarialResult:
	var nothing := AdversarialResult.new()
	nothing.value = _game.evaluate(_root_state, _player)
	return nothing
