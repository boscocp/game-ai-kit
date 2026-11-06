## Wave function collapse: `ConstraintSolver` with three of its choices
## changed, and nothing else (T96).
##
## mxgmn's README says it in one line: WFC "translates a texture synthesis
## problem into a constraint satisfaction problem". A cell is a variable, a
## tile a value, two neighbours a binary constraint (`TileGrid` declares
## them), and the propagation that crosses out the tiles a neighbour can no
## longer stand beside "is just adjacency constraint propagation" -- the
## solver's AC-3, unchanged. What WFC changes:
##
## 1. **The variable: least entropy.** The solver's MRV takes the cell with
##    fewest tiles left. WFC takes the one with the least Shannon entropy,
##    `log(W) - sum(w log w) / W` over the weights w of the tiles it may
##    still be (W their sum): fewest tiles, and of cells with as many, the
##    one where one tile is likeliest. A cell down to one tile is certain,
##    entropy 0, and goes first, with no draw: in CSP terms it is still
##    unassigned. mxgmn observes "the minimal nonzero entropy" and counts
##    such a cell as already observed; the map is the same either way. Ties
##    go to the seeded order, as the solver's do.
## 2. **The value: one tile, drawn by weight.** Not the least constraining
##    value, and not a list to try in turn: one draw, each tile as likely as
##    its weight among the tiles left. That draw is what makes the maps
##    differ; the weights are what make plain ground commoner than a bridge.
## 3. **No going back.** When propagation empties a cell -- a
##    *contradiction*: no tile fits there -- the solver would undo and try
##    the next value. WFC stops, notes where, and `solve` starts again from
##    the next seed, as mxgmn's does. `restarts` counts them and
##    `contradictions` names each cell. The README says it happens
##    "surprisingly rarely"; the squad's tiles met none in sixty seeds.
##
## With `record` on, the solver's trace -- each cell chosen with the tiles it
## had left, each tile assigned, each tile crossed out -- is the whole build,
## step by step, and a "contradiction" event marks where an attempt ended.
## `entropy_of` is static, so a view replaying the trace can say what the
## next cell's entropy was without a solver.
##
## Complexity: per collapse, the entropy of every open cell (cells x tiles)
## and the AC-3 that follows; a map is cells x that, times the restarts.
##
## When not to use it: when a map must have something no neighbour can see
## -- a way through, a fair start, one exit. WFC only keeps neighbours
## agreeing; check the whole map after (the squad's maps do), or declare
## the rule as a global constraint and let `ConstraintSolver` backtrack.
## And for large maps, where restarting the whole map on one contradiction
## costs more than backtracking would.
class_name WaveCollapse
extends ConstraintSolver

## How many seeds `solve` tries before it says there is no map.
const ATTEMPTS: int = 10

## Tile -> weight, in the tile set's order (`TileGrid.weights_of`).
var weights: Dictionary = {}
var attempts: int = ATTEMPTS
## The seed the first attempt starts from; the others count up from it.
var first_seed: int = ConstraintDraws.SEED_FOR_ZERO
## How many seeds ran into a contradiction before one did not.
var restarts: int = 0
## The cell ("x,y") each failed attempt ran out of tiles in, in order.
var contradictions: Array[String] = []
## Where the last attempt ran out of tiles; "" when it did not.
var contradiction: String = ""
var _picks: ConstraintDraws


## A collapse of `of_problem`, its tiles drawn by `tile_weights` (tile ->
## weight), starting from `from_seed`.
func _init(of_problem: ConstraintProblem, tile_weights: Dictionary, from_seed: int = ConstraintDraws.SEED_FOR_ZERO) -> void:
	super(of_problem, from_seed)
	weights = tile_weights
	first_seed = from_seed
	lcv = false


## The map ("x,y" -> tile), from the first of `attempts` seeds that reaches
## no contradiction -- `first_seed`, then the next, and so on -- or {} when
## none does. `restarts` and `contradictions` say how the others ended. A
## contradiction before the first collapse ends it at once: only the tiles
## and the pins were in play, and no seed changes those.
func solve() -> Dictionary:
	restarts = 0
	contradictions.clear()
	for number: int in range(attempts):
		var found: Dictionary = attempt(first_seed + number)
		if not found.is_empty():
			return found
		restarts += 1
		contradictions.append(contradiction)
		if assignments == 0:
			return {}
	return {}


## One collapse from `from_seed`, with no restart: the map, or {} at the
## first contradiction, named in `contradiction`.
func attempt(from_seed: int) -> Dictionary:
	seed_value = from_seed
	contradiction = ""
	_picks = ConstraintDraws.new(from_seed)
	return super.solve()


## The entropy of a cell that may still be any of `left`, each as likely as
## its weight in `tile_weights`, summed in that Dictionary's order; 0 for a
## cell down to one tile.
static func entropy_of(left: Array, tile_weights: Dictionary) -> float:
	var total: float = 0.0
	var weighted_logs: float = 0.0
	var count: int = 0
	for tile: Variant in tile_weights:
		if left.has(tile):
			var weight: float = float(tile_weights[tile])
			total += weight
			weighted_logs += weight * log(weight)
			count += 1
	if count <= 1:
		return 0.0
	return log(total) - weighted_logs / total


## `entropy_of` the tiles cell `name` may still be.
func entropy(name: String) -> float:
	return entropy_of(domains[name], weights)


## The tiles `name` may still be, in the tile set's order.
func tiles_left(name: String) -> Array:
	return weights.keys().filter(func(tile: Variant) -> bool: return (domains[name] as Array).has(tile))


# The open cell of least entropy; of equal ones, the first in the seeded order.
func _select() -> String:
	var best: String = ""
	var lowest: float = INF
	for name: String in _order:
		if not assignment.has(name) and entropy(name) < lowest:
			best = name
			lowest = entropy(name)
	return best


# One tile, drawn by weight: the weights of the tiles left, in the tile
# set's order, laid end to end, and a draw landing in one. A cell down to one
# tile spends no draw. One value, so there is nothing to go back to. The
# draws come from a second generator with the attempt's seed (`attempt`), so
# they repeat the numbers the shuffle used: harmless here -- the shuffle's
# are taken modulo the places left, these modulo a sum of weights, and a
# seed is only ever one map -- but a stream meant to be independent should
# start from a seed of its own.
func _values(name: String) -> Array:
	var left: Array = tiles_left(name)
	if left.size() == 1:
		return left
	var total: int = 0
	for tile: Variant in left:
		total += int(weights[tile])
	var draw: int = _picks.index(total)
	for tile: Variant in left:
		if draw < int(weights[tile]):
			return [tile]
		draw -= int(weights[tile])
	return left.slice(-1)


# The solver's revise; a cell left with no tile is a contradiction, and the
# search stops there rather than going back (`gave_up`, which ends it).
func _revise(index: int, target: String) -> bool:
	var removed: bool = super._revise(index, target)
	if (domains[target] as Array).is_empty() and contradiction == "":
		contradiction = target
		gave_up = true
		_note({"event": "contradiction", "variable": target})
	return removed


## The tiles assigned, in the order the trace kept them: [cell, tile] each.
func chosen() -> Array[Array]:
	var picked: Array[Array] = []
	for event: Dictionary in trace:
		if event["event"] == "assign":
			picked.append([event["variable"], event["value"]])
	return picked
