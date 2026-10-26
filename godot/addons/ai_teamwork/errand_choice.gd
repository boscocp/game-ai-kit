## Three errands a bot may leave its post for -- back to its base for
## rounds and health, out to fetch a power weapon lying on the map, or into
## hiding to let its health come back -- each weighed as a gain less its
## costs, the plainest utility, and the largest taken when it is above zero
## (the owner's asks for the bot match, 2026-10-21). Staying at its post is
## no errand: what leaving costs is the fight's price.
##
## Going back is worth the share of its rounds spent, the share of its
## health missing -- the base heals it whole (T68) -- and the power weapon
## too when its kills have earned one there; it costs each second of the
## walk, and what leaving its post costs -- more attacking a point than
## holding one, nothing when it has no round left to fight with. Fetching
## is worth what the weapon is worth, less each second of the walk, less
## each enemy its team knows of near the weapon. A team sends one bot to
## fetch it, the one it is worth most to, so two do not race for one gun.
## Hiding is worth the share of health that would come back, less each
## second away -- the walk to cover and the wait for the health -- less
## what leaving its post costs (T68). Health comes back while it stays too,
## unless it is hit, so the health either errand gains is priced by its
## exposure where it stands, 0 to 1: what staying would cost it, the
## fight it is in. Unseen and unhit, staying heals it as well as leaving,
## and the health is worth nothing to an errand. Not a threshold: a deep
## wound under fire near cover is worth hiding for; a scratch, a long wait,
## or a wound nobody can see is not.
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
const HIDE: String = "hide to heal"


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
	## A second away from its post to hide and wait for its health.
	var hide_second: float = 0.02


## What going back is weighed on, as the game measured it.
class Resupply extends RefCounted:
	## The share of its rounds it has spent, 0 full to 1 none left.
	var spent: float = 0.0
	## The share of its health missing, 0 whole to 1 none left, and how
	## exposed it is where it stands, 0 to 1 -- what the health is worth.
	var hurt: float = 0.0
	var exposure: float = 0.0
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


## What hiding to heal is weighed on.
class Hide extends RefCounted:
	## Whether there is cover from every enemy it knows of to hide behind,
	## and health to come back.
	var available: bool = false
	## The share of its health that would come back, 0 to 1, and how
	## exposed it is where it stands, 0 to 1.
	var hurt: float = 0.0
	var exposure: float = 0.0
	## Seconds to walk there, and to wait there for the health.
	var walk_seconds: float = 0.0
	var wait_seconds: float = 0.0
	var attacking: bool = false


## Going back, weighed: [gain, walk seconds, cost of leaving, score].
static func weigh_resupply(facts: Resupply, weights: Weights) -> PackedFloat64Array:
	var gain: float = facts.spent + facts.hurt * facts.exposure * weights.health_worth
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


## Hiding, weighed: [gain, seconds away, cost of leaving, score]; all
## nothing when there is nowhere to hide or nothing to come back.
static func weigh_hide(facts: Hide, weights: Weights) -> PackedFloat64Array:
	if not facts.available:
		return PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	var gain: float = facts.hurt * facts.exposure * weights.health_worth
	var away: float = facts.walk_seconds + facts.wait_seconds
	var leaving: float = weights.leave_attacking if facts.attacking else weights.leave_holding
	return PackedFloat64Array([gain, away, leaving, gain - away * weights.hide_second - leaving])


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


## One bot's errand, from its scores -- `fetch_score` 0 unless its team
## sent it: the highest above zero, and of equals back first, then fetch,
## then hide; none, when none is above zero.
static func choose(resupply_score: float, fetch_score: float, hide_score: float = 0.0) -> String:
	var best: float = maxf(resupply_score, maxf(fetch_score, hide_score))
	if best <= 0.0:
		return NONE
	if resupply_score >= best:
		return RESUPPLY
	return FETCH if fetch_score >= best else HIDE
