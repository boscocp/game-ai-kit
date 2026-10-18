## How far the goal is, guessed by pretending nothing is ever spent.
##
## The relaxation is Bonet and Geffner's (2001): drop every action's delete
## list, and ask how many actions each predicate is from being true. Without
## deletes nothing is ever lost -- a bank once full stays full -- so the
## question has a cheap answer, worked out by sweeping the actions until no
## predicate gets any nearer:
##
##     cost(p) = 0                          if p holds now
##     cost(p) = min over actions adding p  of  1 + cost(its preconditions)
##
## "The cost of its preconditions" is where the two heuristics part:
##
## * **h_max** takes the dearest one. A plan has to pay for that one at least,
##   so the guess never overestimates -- it is *admissible*, and A* with it
##   still returns the shortest plan;
## * **h_add** adds them all up. That counts work two preconditions share
##   twice, so it can overestimate and the plan may be longer than the
##   shortest -- but it tells the search much more about which way to go.
##
## Which of the two the game uses is not decided here. It is measured, in
## `test/planner_benchmark.gd`, and the table is in this addon's
## `heuristic_planner.gd`.
##
## Complexity: O(sweeps x actions x predicates per action), and a sweep can
## only bring a predicate nearer, so there are at most as many sweeps as
## predicates.
##
## When not to use it: a domain where the delete lists *are* the puzzle -- a
## single bank both purchases spend, as `GameDomain` has. The relaxation
## cannot see the spending, so it guesses one mining where two are needed;
## still a guess under the truth, which is all h_max promises.
class_name RelaxedCost
extends RefCounted

## What a predicate costs when no action can ever make it true. Far larger
## than any plan, and far from overflowing when h_add sums a few of them.
const UNREACHABLE: int = 1 << 40

## How the costs of an action's preconditions, or of the goal's predicates,
## are put together.
enum Combine { MAX, ADD }


## The guess for `bits`: the goal predicates' costs, combined as `combine`
## says, or `UNREACHABLE` when some goal predicate can never be made true.
##
## `UNREACHABLE` is a proof and not only a guess. With nothing ever deleted,
## the relaxed problem can reach everything the real one can and more, so a
## goal it cannot reach is a goal no plan reaches -- and the search may drop
## that world without looking further.
static func estimate(domain: PackedDomain, bits: int, goal: PackedInt32Array,
		combine: Combine) -> int:
	var costs: PackedInt64Array = _costs_from(domain, bits, combine)
	return _combined(costs, goal, combine)


# Every predicate's relaxed cost from `bits`: 0 for what holds, and then
# sweep after sweep of the actions until nothing comes any nearer.
static func _costs_from(domain: PackedDomain, bits: int, combine: Combine) -> PackedInt64Array:
	var costs := PackedInt64Array()
	costs.resize(domain.predicates.size())
	for index: int in range(costs.size()):
		costs[index] = 0 if bits & (1 << index) else UNREACHABLE
	while _sweep(costs, domain, combine):
		pass
	return costs


# One pass over every action. True when anything came nearer, which is what
# says another pass is worth making.
static func _sweep(costs: PackedInt64Array, domain: PackedDomain, combine: Combine) -> bool:
	var nearer: bool = false
	for action: int in range(domain.actions.size()):
		nearer = _bring_nearer(costs, domain, action, combine) or nearer
	return nearer


# Lower the cost of everything action `action` adds, if running it is cheaper
# than what was known. True when anything came nearer.
static func _bring_nearer(costs: PackedInt64Array, domain: PackedDomain, action: int,
		combine: Combine) -> bool:
	var before: int = _combined(costs, domain.needed_bits[action], combine)
	if before >= UNREACHABLE:
		return false
	var nearer: bool = false
	for added: int in domain.given_bits[action]:
		if before + 1 < costs[added]:
			costs[added] = before + 1
			nearer = true
	return nearer


# The costs of `wanted`, combined: the dearest, or the sum. An empty list
# costs nothing either way, which is right for an action that needs nothing
# and for a goal of nothing. `UNREACHABLE` as soon as one of them is.
static func _combined(costs: PackedInt64Array, wanted: PackedInt32Array, combine: Combine) -> int:
	var total: int = 0
	for index: int in wanted:
		if costs[index] >= UNREACHABLE:
			return UNREACHABLE
		total = maxi(total, costs[index]) if combine == Combine.MAX else total + costs[index]
	return total
