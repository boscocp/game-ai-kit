## The planner the game plays with: STRIPS over bits, searched with a guess
## about how far the goal is, inside a budget.
##
## `StripsPlanner` is the version to read first and it stays as it is. This is
## the same problem with the three changes ADR 0010 asks for:
##
## 1. **bits** -- a world is one `int` (`PackedDomain`), not a set of strings;
## 2. **a heuristic** -- A*, with the frontier ordered by `f = g + h`, where
##    `g` is the actions taken and `h` is `RelaxedCost`'s h_max or h_add;
## 3. **a budget that still answers** -- a call that runs out returns the way
##    to the world that looked nearest, marked `partial`, rather than nothing.
##
## And a **horizon** (T12): how many actions ahead it may look. A world that
## many actions from the start is weighed but not expanded, so a goal further
## off is not found -- the search ends with the way to the world that looked
## nearest, `partial`, as a budget does. The budget bounds the work; the
## horizon bounds how far ahead the plan sees, which is the difficulty knob.
##
## Breadth-first over bits is here too, as `Guide.BREADTH_FIRST`: the same
## search as `StripsPlanner` with only the representation changed, so the
## benchmark can tell what the bits are worth apart from what the guess is.
## It is the baseline and is never what the game runs, because it has no `h`
## and so no world it could call nearest when the budget runs out.
##
## Measured by `test/planner_benchmark.gd` on the tactical domain
## (`spec/pddl/tactics-domain.pddl`): the 60 distinct boards with a plan
## from eighteen seeded games, budget 50000, on 2026-10-18 (milliseconds are
## one machine's):
##
## | search                 | worlds | ms a plan | steps |
## |------------------------|-------:|----------:|------:|
## | breadth-first, strings |  11102 |      5.07 |  5.38 |
## | breadth-first, bits    |  11102 |      0.70 |  5.38 |
## | A* with h_max, bits    |    383 |      0.59 |  5.38 |
## | A* with h_add, bits    |    383 |      0.58 |  5.38 |
##
## Bits alone are worth seven times; a guess, twenty-nine times fewer worlds.
## On the 6 boards with no plan, breadth-first spends 436 worlds proving it
## and the guesses none. The two guesses tie: h_max is exact on this domain
## -- A* visits one world per step and one more -- so h_add has nothing to
## improve on. The game uses h_max, which costs the same and keeps the plan
## shortest (`PlannedBlue.GUIDE`). Strings against bits was measured on
## breadth-first only, where the representation is the one thing that
## changes; the guesses were built over bits alone.
##
## Complexity: A* expands at most every reachable world, 2^predicates in the
## worst case; each expansion costs one `RelaxedCost.estimate` per child and
## one walk of the frontier, which is a plain array as in `ai_search`.
##
## When not to use it: a domain whose plans are long and whose budget is
## short, with nobody acting on the first step and asking again. A partial
## plan is a direction; followed to its end without replanning, it can lead
## into the dead end the budget did not see.
class_name HeuristicPlanner
extends RefCounted

## Which search: no guess (breadth-first), the admissible guess, or the
## strong one.
enum Guide { BREADTH_FIRST, H_MAX, H_ADD }

## Worlds taken off the frontier before the call gives up. The same unit as
## `StripsPlanner.DEFAULT_BUDGET`, so the two can be compared.
const DEFAULT_BUDGET: int = 50000

## No horizon: look as many actions ahead as the budget allows.
const NO_HORIZON: int = -1


# Every world the search has reached, as parallel arrays indexed by the order
# it reached them in. A world is stored once with the action and the world it
# came from, so a plan is read back by following parents rather than carried
# whole by every world on the frontier -- which is what `StripsPlanner` does,
# and is a copy of the whole plan per world generated.
class _Reached:
	var states: PackedInt64Array = PackedInt64Array()
	var parents: PackedInt32Array = PackedInt32Array()
	var via: PackedInt32Array = PackedInt32Array()
	var taken: PackedInt32Array = PackedInt32Array()
	var guess: PackedInt64Array = PackedInt64Array()

	## Record a world reached from `parent` by `action`, `steps` actions from
	## the start and guessed `estimate` from the goal; returns its index.
	func add(bits: int, parent: int, action: int, steps: int, estimate: int) -> int:
		states.append(bits)
		parents.append(parent)
		via.append(action)
		taken.append(steps)
		guess.append(estimate)
		return states.size() - 1

	## The plan that reached world `node`, read back along its parents.
	func steps_to(node: int, domain: PackedDomain) -> Array[StripsAction]:
		var backwards: Array[StripsAction] = []
		while parents[node] != -1:
			backwards.append(domain.actions[via[node]])
			node = parents[node]
		backwards.reverse()
		return backwards


## A plan that makes every predicate of `goal` hold from `start`, searched as
## `guide` says, or a `PlanResult` saying why there is none.
##
## With `Guide.H_MAX` the plan is the shortest; with `Guide.H_ADD` it may not
## be; with `Guide.BREADTH_FIRST` it is, and the budget is the only thing
## standing between the call and 2^predicates worlds. `horizon` is how many
## actions ahead to look (see the header); breadth-first, which has no world
## it could call nearest, gives up at it as it does at its budget.
func plan(actions: Array[StripsAction], start: WorldState, goal: PackedStringArray,
		guide: Guide = Guide.H_ADD, budget: int = DEFAULT_BUDGET, horizon: int = NO_HORIZON) -> PlanResult:
	var domain := PackedDomain.new(actions, start, goal)
	if domain.why_unpackable() != "":
		# Not `impossible`: nothing was searched, so nothing was proved.
		push_error("HeuristicPlanner: " + domain.why_unpackable())
		return PlanResult.ran_out(0)
	var from: int = domain.state_of(start)
	var wanted: int = domain.mask_of(goal)
	if from & wanted == wanted:
		return PlanResult.new([] as Array[StripsAction], true, 0, false)
	if guide == Guide.BREADTH_FIRST:
		return _breadth_first(domain, from, wanted, budget, horizon)
	var combine: RelaxedCost.Combine = RelaxedCost.Combine.MAX if guide == Guide.H_MAX else RelaxedCost.Combine.ADD
	return _a_star(domain, from, domain.bits_of(goal), combine, budget, horizon)


# `StripsPlanner`'s search, over bits. The worlds are reached in the order
# they are taken off, so the list of reached worlds is the queue itself and
# `next` is its front.
func _breadth_first(domain: PackedDomain, from: int, wanted: int, budget: int, horizon: int) -> PlanResult:
	var reached := _Reached.new()
	reached.add(from, -1, -1, 0, 0)
	var seen: Dictionary[int, bool] = {from: true}
	var next: int = 0
	while next < reached.states.size():
		if next >= budget or (horizon != NO_HORIZON and reached.taken[next] >= horizon):
			return PlanResult.ran_out(next)
		var finished: int = _generate(domain, next, reached, wanted, seen)
		if finished != -1:
			return PlanResult.new(reached.steps_to(finished, domain), true, next + 1, false)
		next += 1
	return PlanResult.impossible(next)


# Breadth-first's expansion: every new world one action from world `node`,
# added to the end of `reached`. Returns the first that holds the goal --
# tested as generated, as `StripsPlanner` does, and still the shortest -- or
# -1 when none does.
func _generate(domain: PackedDomain, node: int, reached: _Reached, wanted: int,
		seen: Dictionary[int, bool]) -> int:
	var bits: int = reached.states[node]
	for action: int in range(domain.actions.size()):
		if not domain.applicable(action, bits):
			continue
		var after: int = domain.after(action, bits)
		if seen.has(after):
			continue
		seen[after] = true
		var child: int = reached.add(after, node, action, reached.taken[node] + 1, 0)
		if after & wanted == wanted:
			return child
	return -1


# A*: take the world with the smallest `f`, stop when it holds the goal.
#
# The goal is tested when a world is *taken off* the frontier, not when it is
# generated. With a guess in play that is not a detail: a world generated
# early may have been reached the long way round, and only the one taken off
# with the smallest `f` is known to be the end of a shortest plan -- under
# h_max. Under h_add nothing is known, which is the bargain it makes.
func _a_star(domain: PackedDomain, from: int, goal: PackedInt32Array,
		combine: RelaxedCost.Combine, budget: int, horizon: int) -> PlanResult:
	var reached := _Reached.new()
	var first_guess: int = RelaxedCost.estimate(domain, from, goal, combine)
	if first_guess >= RelaxedCost.UNREACHABLE:
		return PlanResult.impossible(0)
	var frontier: Array[int] = [reached.add(from, -1, -1, 0, first_guess)]
	var cheapest_way: Dictionary[int, int] = {from: 0}
	var nearest: int = 0
	var visited: int = 0
	var beyond_the_horizon: bool = false
	while not frontier.is_empty():
		if visited >= budget:
			return PlanResult.partial_plan(reached.steps_to(nearest, domain), visited)
		var node: int = frontier.pop_at(_smallest_f(frontier, reached))
		# A world reached again more cheaply was queued again; the dearer copy
		# is stale, and expanding it would count a world twice.
		if reached.taken[node] > cheapest_way[reached.states[node]]:
			continue
		visited += 1
		if _looks_nearer(reached, node, nearest):
			nearest = node
		if _holds(reached.states[node], goal):
			return PlanResult.new(reached.steps_to(node, domain), true, visited, false)
		if horizon != NO_HORIZON and reached.taken[node] >= horizon:
			beyond_the_horizon = true
			continue
		_expand(domain, node, reached, goal, combine, cheapest_way, frontier)
	# Nothing left to try proves there is no plan only if nothing was cut off.
	if beyond_the_horizon:
		return PlanResult.partial_plan(reached.steps_to(nearest, domain), visited)
	return PlanResult.impossible(visited)


# Queue every world one action from `node`'s that is new, or newly cheaper.
# A world whose goal the relaxation says is unreachable is not queued at all:
# that guess is a proof (see `RelaxedCost.estimate`).
func _expand(domain: PackedDomain, node: int, reached: _Reached, goal: PackedInt32Array,
		combine: RelaxedCost.Combine, cheapest_way: Dictionary[int, int],
		frontier: Array[int]) -> void:
	var bits: int = reached.states[node]
	var steps: int = reached.taken[node] + 1
	for action: int in range(domain.actions.size()):
		if not domain.applicable(action, bits):
			continue
		var after: int = domain.after(action, bits)
		if cheapest_way.has(after) and cheapest_way[after] <= steps:
			continue
		var guess: int = RelaxedCost.estimate(domain, after, goal, combine)
		if guess >= RelaxedCost.UNREACHABLE:
			continue
		cheapest_way[after] = steps
		frontier.append(reached.add(after, node, action, steps, guess))


# True when world `node` looks nearer the goal than world `nearest`: a smaller
# guess, or the same guess further from the start. The second half is not a
# detail. h_max is often flat for several steps -- banking money brings no
# goal predicate nearer -- and with strict "smaller" alone a budget that ran
# out on that plateau handed back the start, an empty partial plan, which the
# game read as "no plan". A wave 48 test caught it.
static func _looks_nearer(reached: _Reached, node: int, nearest: int) -> bool:
	if reached.guess[node] != reached.guess[nearest]:
		return reached.guess[node] < reached.guess[nearest]
	return reached.taken[node] > reached.taken[nearest]


# The index in `frontier` of the world with the smallest `f`. Ties go to the
# smaller guess -- the world that looks nearer the goal -- and then to the
# one reached first, so the same problem always gives the same plan.
static func _smallest_f(frontier: Array[int], reached: _Reached) -> int:
	var best: int = 0
	for index: int in range(1, frontier.size()):
		var node: int = frontier[index]
		var holder: int = frontier[best]
		var f: int = reached.taken[node] + reached.guess[node]
		var best_f: int = reached.taken[holder] + reached.guess[holder]
		if f < best_f or (f == best_f and reached.guess[node] < reached.guess[holder]):
			best = index
	return best


# True when every predicate of `goal` is set in `bits`.
static func _holds(bits: int, goal: PackedInt32Array) -> bool:
	for index: int in goal:
		if not bits & (1 << index):
			return false
	return true
