## Monte Carlo tree search: judge a move by playing on at random from it,
## many times, and spend more of those playouts on the moves that do well.
##
## Alpha-beta needs an evaluation function that says how good a position is.
## MCTS needs none before the end of the game: it plays the position out with
## random moves and counts who won. One playout says little; hundreds, spread
## by UCB1 between the moves that look best and the moves still poorly known,
## say a lot. And it is **anytime**: stop it after any iteration and it has an
## answer, the move it has tried most. This file follows Russell & Norvig,
## *Artificial Intelligence: A Modern Approach*, 4th edition, section 5.4 and
## figure 5.11: one iteration is SELECT, EXPAND, SIMULATE, BACK-PROPAGATE,
## with UCB1 as the selection policy -- the combination called UCT.
##
## Chance: after an action whose `outcomes` are several, the tree keeps one
## child per outcome, grown as each is drawn, so what the search learns under
## a lucky roll is never mixed with what it learns under an unlucky one.
## Every random choice -- the outcome drawn, the playout's moves, which
## untried move to expand -- comes from one seeded `GakXorshift`, which is what
## lets `gameaikit.adversarial.mcts` repeat the search draw for draw.
##
## Complexity: each iteration costs one descent of the tree plus one playout,
## so the work is iterations times (depth + playout length); the tree holds
## one node per iteration, plus one per outcome first drawn.
##
## When not to use it: a game alpha-beta can search deep enough with a good
## evaluation -- checkers at depth 6 -- where it is exact and MCTS only
## converges towards it; or a game where random play says nothing, because a
## random move almost always loses at once, and the playouts then measure the
## randomness rather than the position.
class_name MonteCarloSearch
extends RefCounted

## UCB1's exploration constant, the square root of two: the value the
## analysis of UCB1 gives for outcomes between 0 and 1. A game whose values
## run from -1 to 1 can take twice it; a larger constant tries poorly known
## moves more often, a smaller one trusts the means sooner.
const EXPLORATION: float = 1.4142135623730951
## How many moves a playout plays before it stops and asks `evaluate`, so a
## game that might never end -- two kings chasing -- cannot hold a step.
const PLAYOUT_LIMIT: int = 200


## A position in the tree: its state, whose turn it is, and one branch per
## action, in the game's order, made when that action is first expanded.
class TreeNode extends RefCounted:
	var state: RefCounted
	var player: int
	var terminal: bool
	var actions: Array
	var branches: Array = []
	var untried: Array[int] = []
	var visits: int = 0

	func _init(game: GakAdversarialGame, held: RefCounted) -> void:
		state = held
		player = game.to_move(held)
		actions = game.actions(held)
		terminal = game.is_terminal(held) or actions.is_empty()
		branches.resize(actions.size())
		for index: int in range(actions.size()):
			untried.append(index)


## One action from a node: its playouts, their total value for the player who
## chose it, and the nodes it leads to -- one per outcome, null until drawn.
class Branch extends RefCounted:
	var action: Variant
	var player: int
	var outcomes: Array
	var children: Array = []
	var visits: int = 0
	var total: float = 0.0

	func _init(chosen: Variant, chooser: int, possible: Array) -> void:
		action = chosen
		player = chooser
		outcomes = possible
		children.resize(possible.size())


## The way one iteration came down the tree, kept apart from the tree so that
## no child holds its parent: the nodes passed, and the branches between them.
class Descent extends RefCounted:
	var nodes: Array[TreeNode] = []
	var branches: Array[Branch] = []


var _game: GakAdversarialGame
var _root: TreeNode
var _random: GakXorshift
var _exploration: float = EXPLORATION
var _playout_limit: int = PLAYOUT_LIMIT
var _iterations: int = 0


## A search for the player to move in `state`, its random choices drawn from
## `from_seed`. Nothing is searched until `step` is called.
func _init(game: GakAdversarialGame, state: RefCounted, from_seed: int = 1,
		exploration: float = EXPLORATION, playout_limit: int = PLAYOUT_LIMIT) -> void:
	_game = game
	_root = TreeNode.new(game, state)
	_random = GakXorshift.new(from_seed)
	_exploration = exploration
	_playout_limit = maxi(playout_limit, 0)


## Run `iterations` more iterations and say where the search stands. This is
## the frame budget: the caller decides how many fit in its frame and calls
## again next frame; the tree carries over. Counted in iterations, never cut
## by the clock, so the same calls give the same answer on any machine.
func step(iterations: int) -> MctsResult:
	if not _root.terminal:
		for _iteration: int in range(maxi(iterations, 0)):
			_iterate()
	return result()


## Where the search stands now, without searching further: every root move's
## visits, mean and bound, and the most visited move.
func result() -> MctsResult:
	var found := MctsResult.new()
	found.iterations = _iterations
	var most_visits: int = -1
	for index: int in range(_root.actions.size()):
		var entry: Dictionary = _entry_for(index)
		found.considered.append(entry)
		if entry["visits"] > most_visits:
			most_visits = entry["visits"]
			found.action = entry["action"]
	return found


## The line of play the search expects, as far as it has looked: from the
## root, the most visited move, then the outcome of it drawn most often,
## then that position's most visited move, and so on -- at most `most`
## moves, and none past a position no iteration went beyond. Both sides'
## moves, in the order they would be played (T87 draws it). A line, not a
## plan: the deeper a move, the fewer playouts it rests on.
func principal_line(most: int = 8) -> Array:
	var line: Array = []
	var node: TreeNode = _root
	while line.size() < most and node != null and not node.terminal:
		var branch: Branch = _most_visited(node.branches)
		if branch == null:
			break
		line.append(branch.action)
		node = _most_visited(branch.children)
	return line


# One iteration, the loop body of the book's figure 5.11.
func _iterate() -> void:
	var descent := Descent.new()
	var leaf: TreeNode = _select(descent)
	var child: TreeNode = _expand(leaf, descent)
	var final_state: RefCounted = _simulate(child.state)
	_back_propagate(final_state, descent)
	_iterations += 1


# SELECT: from the root, follow the branch with the highest UCB1 bound while
# every action of the node has been tried and the game is not over. A node
# with an untried action is the leaf to expand.
func _select(descent: Descent) -> TreeNode:
	var node: TreeNode = _root
	descent.nodes.append(node)
	while not node.terminal and node.untried.is_empty():
		var branch: Branch = _best_by_ucb1(node)
		descent.branches.append(branch)
		node = _child_by_chance(branch)
		descent.nodes.append(node)
	return node


# EXPAND: try one untried action of the leaf, drawn among them -- they are
# equally unknown -- and add the node it leads to. A finished game has
# nothing to expand, and is its own child.
func _expand(leaf: TreeNode, descent: Descent) -> TreeNode:
	if leaf.terminal:
		return leaf
	var index: int = leaf.untried.pop_at(_random.index(leaf.untried.size()))
	var action: Variant = leaf.actions[index]
	var branch := Branch.new(action, leaf.player, _game.outcomes(leaf.state, action))
	leaf.branches[index] = branch
	descent.branches.append(branch)
	var child: TreeNode = _child_by_chance(branch)
	descent.nodes.append(child)
	return child


# SIMULATE: random legal moves, and random outcomes by their chances, to the
# end of the game or to the playout limit. The state it stops on is what the
# playout is worth; nothing of it is kept in the tree.
func _simulate(state: RefCounted) -> RefCounted:
	var played: int = 0
	while played < _playout_limit and not _game.is_terminal(state):
		var actions: Array = _game.actions(state)
		if actions.is_empty():
			break
		var action: Variant = actions[_random.index(actions.size())]
		var outcomes: Array = _game.outcomes(state, action)
		state = outcomes[_draw_outcome(outcomes)]["state"]
		played += 1
	return state


# BACK-PROPAGATE: every node passed gains a visit, and every branch taken
# gains a visit and the playout's value for the player who chose it -- so a
# side that moved twice running is credited twice, from its own side.
func _back_propagate(final_state: RefCounted, descent: Descent) -> void:
	var value_for: Dictionary = {}
	for node: TreeNode in descent.nodes:
		node.visits += 1
	for branch: Branch in descent.branches:
		if not value_for.has(branch.player):
			value_for[branch.player] = _game.evaluate(final_state, branch.player)
		branch.visits += 1
		branch.total += value_for[branch.player]


# The branch selection follows: the highest UCB1 bound, and of equal bounds
# the first in the game's order.
func _best_by_ucb1(node: TreeNode) -> Branch:
	var best: Branch = null
	var best_bound: float = -INF
	for branch: Branch in node.branches:
		var bound: float = _ucb1(branch, node.visits)
		if bound > best_bound:
			best = branch
			best_bound = bound
	return best


# UCB1: the branch's mean, which favours what has done well, plus a bonus that
# grows slowly with the parent's visits and shrinks with the branch's own,
# which favours what has been tried little. A branch never tried is infinite.
func _ucb1(branch: Branch, parent_visits: int) -> float:
	if branch.visits == 0:
		return INF
	var mean: float = branch.total / branch.visits
	return mean + _exploration * sqrt(log(float(parent_visits)) / branch.visits)


# The node a branch leads to this time: its only one, or one drawn by the
# outcomes' chances, made the first time that outcome is drawn.
func _child_by_chance(branch: Branch) -> TreeNode:
	var drawn: int = _draw_outcome(branch.outcomes)
	if branch.children[drawn] == null:
		branch.children[drawn] = TreeNode.new(_game, branch.outcomes[drawn]["state"])
	return branch.children[drawn]


# Which outcome happens. One outcome spends no draw, as `GakXorshift.index`
# spends none on one choice; several walk their chances until the drawn
# number falls inside one.
func _draw_outcome(outcomes: Array) -> int:
	if outcomes.size() <= 1:
		return 0
	var drawn: float = _random.uniform()
	var reached: float = 0.0
	for index: int in range(outcomes.size()):
		reached += float(outcomes[index]["probability"])
		if drawn < reached:
			return index
	return outcomes.size() - 1


# Of `entries` -- a node's branches or a branch's children, null where
# nothing was made -- the one visited most, the first of equals; null when
# none was visited.
func _most_visited(entries: Array) -> Variant:
	var best: Variant = null
	for entry: Variant in entries:
		if entry != null and entry.visits > 0 and (best == null or entry.visits > best.visits):
			best = entry
	return best


# What `MctsResult.considered` says about the root's action at `index`.
func _entry_for(index: int) -> Dictionary:
	var branch: Branch = _root.branches[index]
	if branch == null:
		return {"action": _root.actions[index], "visits": 0, "mean": 0.0, "bound": INF}
	return {"action": branch.action, "visits": branch.visits,
			"mean": branch.total / branch.visits if branch.visits > 0 else 0.0,
			"bound": _ucb1(branch, _root.visits)}
