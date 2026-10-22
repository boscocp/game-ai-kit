## Two errands a bot may leave its post for -- back to its base for rounds,
## or out to fetch a power weapon lying on the map -- each weighed as a gain
## less its costs, the plainest utility, and the larger taken when it is
## above zero (the owner's asks for the bot match, 2026-10-21).
##
## Going back is worth the share of its rounds spent, the share of its
## health missing -- the base heals it whole (T68) -- and the power weapon
## too when its kills have earned one there; it costs each second of the
## walk, and what leaving its post costs -- more attacking a point than
## holding one, nothing when it has no round left to fight with. Fetching
## is worth what the weapon is worth, less each second of the walk, less
## each enemy its team knows of near the weapon. A team sends one bot to
## fetch it, the one it is worth most to, so two do not race for one gun.
##
## Each weighing is a list -- [gain, walk seconds, cost, score] -- so a view
## can show why. Constant time a bot. When not to use it: errands that
## chain (go here, then there), or a gain that is not a sum of parts; then
## the score is a plan's, or a curve's (`ActionChoice`).
class_name ErrandChoice
extends RefCounted

const NONE: String = ""
const RESUPPLY: String = "resupply"
const FETCH: String = "fetch power"


## What each part of a weighing is worth, in score points.
class Weights extends RefCounted:
	## A second of walking back, and leaving a post held or attacked.
	var resupply_walk: float = 0.05
	var leave_holding: float = 0.3
	var leave_attacking: float = 0.5
	## What all of a bot's health is worth, as all of its rounds are 1.
	var health_worth: float = 1.0
	## The power weapon's worth, a second of walking to it, and each enemy
	## known near it.
	var power_worth: float = 1.0
	var power_walk: float = 0.08
	var power_danger: float = 0.3


## What going back is weighed on, as the game measured it.
class Resupply extends RefCounted:
	## The share of its rounds it has spent, 0 full to 1 none left.
	var spent: float = 0.0
	## The share of its health missing, 0 whole to 1 none left.
	var hurt: float = 0.0
	## Whether its kills have earned it the power weapon at its base.
	var earned_power: bool = false
	var walk_seconds: float = 0.0
	## Whether it is attacking a point, not holding one; and whether it has
	## no round left at all, and so no post to leave.
	var attacking: bool = false
	var empty: bool = false


## What fetching is weighed on.
class Fetch extends RefCounted:
	## Whether the weapon lies there for this bot to take: it is there, the
	## bot does not hold it, and the bot can walk to it.
	var available: bool = false
	var walk_seconds: float = 0.0
	## Enemies its team knows of near the weapon.
	var enemies_near: int = 0


## Going back, weighed: [gain, walk seconds, cost of leaving, score].
static func weigh_resupply(facts: Resupply, weights: Weights) -> PackedFloat64Array:
	var gain: float = facts.spent + facts.hurt * weights.health_worth
	gain += weights.power_worth if facts.earned_power else 0.0
	var leaving: float = weights.leave_attacking if facts.attacking else weights.leave_holding
	if facts.empty:
		leaving = 0.0
	var score: float = gain - facts.walk_seconds * weights.resupply_walk - leaving
	return PackedFloat64Array([gain, facts.walk_seconds, leaving, score])


## Fetching, weighed: [worth, walk seconds, danger, score]; all nothing when
## the weapon is not there for it.
static func weigh_fetch(facts: Fetch, weights: Weights) -> PackedFloat64Array:
	if not facts.available:
		return PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	var danger: float = facts.enemies_near * weights.power_danger
	var score: float = weights.power_worth - facts.walk_seconds * weights.power_walk - danger
	return PackedFloat64Array([weights.power_worth, facts.walk_seconds, danger, score])


## Which of a team's bots is sent to fetch, by their fetching scores: the
## one it is worth most to, above zero, the first of equal worth; -1 nobody.
static func fetcher(scores: PackedFloat64Array) -> int:
	var best: int = -1
	var best_score: float = 0.0
	for index: int in range(scores.size()):
		if scores[index] > best_score:
			best_score = scores[index]
			best = index
	return best


## One bot's errand, from its two scores -- `fetch_score` 0 unless its team
## sent it: back, when that is above zero and no less than fetching; fetch,
## when that is above zero; otherwise none.
static func choose(resupply_score: float, fetch_score: float) -> String:
	if resupply_score > 0.0 and resupply_score >= fetch_score:
		return RESUPPLY
	if fetch_score > 0.0:
		return FETCH
	return NONE
