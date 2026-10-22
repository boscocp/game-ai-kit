## Who searches where: the spots worth looking at, divided among the guards
## searching, each spot to one guard, and a spot off the list once anyone
## has seen it.
##
## Blacklist's search hands its guards spots hidden from where the player
## was likely to be, claimed so two never go to one, and marked off by sight
## [Welsh 2015]; The Last of Us's search map is cleared wherever an enemy
## can see [McIntosh 2015]. So a spot is a row of plain facts -- how much
## of the belief looking there would check (its `worth`), and whether a
## sight line already reached it -- and a searcher is the cost of walking to
## each spot. Nothing here knows a level, a belief or a guard: the example
## computes those and passes numbers, as invariant 2 asks.
##
## A searcher's score for a spot is `worth` x WORTH less `cost` x TRAVEL.
## With claims on, the best pair of searcher and spot is taken first, then
## the next best among those left, so no two searchers share a spot. With
## claims off each searcher takes its own best -- and they bunch, which is
## what the switch is for. A spot already searched, or worth nothing, is
## given to no one. And how many go to the last known position is capped,
## the nearest first [Welsh 2015; Miles 2013].
##
## O(searchers^2 x spots) for the greedy pairing.
##
## When not to use it: a search that must cover every spot in an order --
## a sweep of a corridor. That is a route, planned; this is a share-out.
class_name SearchCoordinator
extends RefCounted


## The weights a score is made of; a data row can override each.
class Weights extends RefCounted:
	var worth: float = 10.0
	var travel: float = 0.2


## The spot each searcher is given, in the searchers' order, by its index
## in `spots`; -1, none. `spots`: [{worth, searched}]; `costs`: for each
## searcher, the walk to each spot (INF where it cannot get there).
static func assign(spots: Array[Dictionary], costs: Array[PackedFloat64Array], use_claims: bool,
		weights: Weights) -> PackedInt32Array:
	var given := PackedInt32Array()
	given.resize(costs.size())
	given.fill(-1)
	if not use_claims:
		for searcher: int in range(costs.size()):
			given[searcher] = _best_spot(spots, costs[searcher], {}, weights)
		return given
	var taken: Dictionary[int, bool] = {}
	for round_number: int in range(costs.size()):
		var pair: Vector2i = _best_pair(spots, costs, given, taken, weights)
		if pair.x == -1:
			break
		given[pair.x] = pair.y
		taken[pair.y] = true
	return given


## A searcher's score for a spot; -INF when the spot is not worth going to.
static func score(spot: Dictionary, cost: float, weights: Weights) -> float:
	if bool(spot["searched"]) or float(spot["worth"]) <= 0.0 or not is_finite(cost):
		return -INF
	return float(spot["worth"]) * weights.worth - cost * weights.travel


## Which of the searchers wanting the last known position may go: the `cap`
## nearest, by `costs` (one per searcher), as indices in the searchers'
## order; the nearer of equal costs is the earlier.
static func grant_last_known(costs: PackedFloat64Array, cap: int) -> PackedInt32Array:
	var order: Array[int] = []
	for searcher: int in range(costs.size()):
		order.append(searcher)
	order.sort_custom(func(one: int, other: int) -> bool: return costs[one] < costs[other] or (costs[one] == costs[other] and one < other))
	var granted := PackedInt32Array()
	for searcher: int in order.slice(0, maxi(cap, 0)):
		granted.append(searcher)
	granted.sort()
	return granted


static func _best_spot(spots: Array[Dictionary], costs: PackedFloat64Array, taken: Dictionary, weights: Weights) -> int:
	var best: int = -1
	var best_score: float = -INF
	for spot: int in range(spots.size()):
		var value: float = score(spots[spot], costs[spot], weights)
		if not taken.has(spot) and value > best_score:
			best = spot
			best_score = value
	return best


# The highest-scoring searcher and spot both still free, as (searcher,
# spot); (-1, -1) when none is left. Ties go to the earlier searcher.
static func _best_pair(spots: Array[Dictionary], costs: Array[PackedFloat64Array], given: PackedInt32Array,
		taken: Dictionary, weights: Weights) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score: float = -INF
	for searcher: int in range(costs.size()):
		var spot: int = _best_spot(spots, costs[searcher], taken, weights) if given[searcher] == -1 else -1
		if spot != -1 and score(spots[spot], costs[searcher][spot], weights) > best_score:
			best = Vector2i(searcher, spot)
			best_score = score(spots[spot], costs[searcher][spot], weights)
	return best
