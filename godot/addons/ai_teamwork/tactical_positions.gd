## Where a bot should stand: candidate points, dropped by conditions,
## weighed, and the best one nobody on its team has claimed.
##
## CryEngine's tactical position system writes it as a query -- generate,
## filter, weigh, take the best [Jack 2013] -- and Killzone's weights are the
## worked example here: line of fire to the main threat 40 from partial cover
## and 20 otherwise, cover from the other threats 20, nearness 20, preferred
## range 10 [Beij & Straatman 2005]. The claim is Far Cry's: never pick a spot
## another agent already took, which is what keeps a squad from bunching.
## Linear in the candidates. The same query hides a bot as well as places
## it to fight: asked with `cover_from_all`, a spot any known threat sees is
## dropped, and with the threat weights at zero nearness alone ranks the
## rest -- the nearest cover from everyone (T68).
##
## It reads facts, not geometry: whoever builds a `Candidate` has
## already cast the rays. So a test can state a query in a few numbers, and
## the Python twin can answer it without a physics engine.
##
## When not to use it: when the right place is one place -- a single sniper's
## nest, a door to hold. A score over candidates is for a choice among many.
class_name TacticalPositions
extends RefCounted

## Why a candidate was dropped, or that it was kept. The order is the order
## the conditions are asked in, so a candidate reports the first it failed.
const KEPT: String = "kept"
const TOO_FAR: String = "too_far"
const OUTSIDE_AREA: String = "outside_area"
const CLAIMED: String = "claimed"
const EXPOSED: String = "exposed"
## Asked to hide (`Weights.cover_from_all`), a spot some known enemy sees.
const SEEN: String = "seen"


## One candidate point, as the facts the score needs.
class Candidate extends RefCounted:
	var id: String = ""
	## How far the bot must walk to get there, in metres.
	var travel: float = 0.0
	## How far it is from the main threat, in metres.
	var threat_distance: float = 0.0
	## Crouched there, the main threat cannot see the bot.
	var covered_from_main: bool = false
	## Standing there, the bot can shoot the main threat.
	var fires_on_main: bool = false
	## The share of the other known threats it is covered from, 0 to 1.
	var covered_from_others: float = 0.0
	## Crouched there, no known threat at all can see the bot: the main one
	## and every other. What a bot hiding to heal asks for (T68).
	var hidden_from_all: bool = false
	## Inside the area the bot's squad was sent to.
	var in_area: bool = true
	## The bot that claimed it, or -1.
	var claimed_by: int = -1


## The weights and limits. The defaults are Killzone's worked example.
class Weights extends RefCounted:
	var partial_cover: float = 40.0
	var line_of_fire: float = 20.0
	var other_cover: float = 20.0
	var nearness: float = 20.0
	var preferred_range: float = 10.0
	## The range the bot likes to fight at, and how far off it still scores.
	var preferred_metres: float = 15.0
	var range_band: float = 10.0
	## Farther than this is not a candidate at all.
	var max_travel: float = 20.0
	## A query to hide, not to fight: a spot any known threat sees is
	## dropped, as SEEN.
	var cover_from_all: bool = false


## What the query found: every candidate's status and score, and the one
## chosen -- its index, or -1 when every candidate was dropped.
class Choice extends RefCounted:
	var statuses: Array[String] = []
	var scores: PackedFloat64Array = PackedFloat64Array()
	var chosen: int = -1


## Choose for bot `bot_id` among `candidates`. `has_threat` false means the
## bot knows of no enemy: the threat terms and the exposed condition then say
## nothing, and nearness decides. `use_claims` false is the toggle that lets
## a squad bunch.
static func choose(bot_id: int, candidates: Array[Candidate], weights: Weights,
		has_threat: bool, use_claims: bool) -> Choice:
	var choice := Choice.new()
	var best: float = -INF
	for index: int in range(candidates.size()):
		var candidate: Candidate = candidates[index]
		var status: String = status_of(bot_id, candidate, weights, has_threat, use_claims)
		var score: float = score_of(candidate, weights, has_threat) if status == KEPT else 0.0
		choice.statuses.append(status)
		choice.scores.append(score)
		if status == KEPT and score > best:
			best = score
			choice.chosen = index
	return choice


## The first condition `candidate` fails, or KEPT.
static func status_of(bot_id: int, candidate: Candidate, weights: Weights,
		has_threat: bool, use_claims: bool) -> String:
	if candidate.travel > weights.max_travel:
		return TOO_FAR
	if not candidate.in_area:
		return OUTSIDE_AREA
	if use_claims and candidate.claimed_by != -1 and candidate.claimed_by != bot_id:
		return CLAIMED
	if has_threat and weights.cover_from_all and not candidate.hidden_from_all:
		return SEEN
	if has_threat and not candidate.covered_from_main and not candidate.fires_on_main:
		return EXPOSED
	return KEPT


## The weighted sum for a candidate that passed every condition.
static func score_of(candidate: Candidate, weights: Weights, has_threat: bool) -> float:
	var score: float = weights.nearness * (1.0 - candidate.travel / weights.max_travel)
	if not has_threat:
		return score
	if candidate.fires_on_main:
		score += weights.partial_cover if candidate.covered_from_main else weights.line_of_fire
	score += weights.other_cover * candidate.covered_from_others
	var off_range: float = absf(candidate.threat_distance - weights.preferred_metres)
	score += weights.preferred_range * maxf(0.0, 1.0 - off_range / weights.range_band)
	return score
