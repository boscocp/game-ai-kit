## Where each squad goes: every region scored by how much it is worth and
## how the fight there would go, and the best taken.
##
## Utility over influence maps, as Dill describes Kohan II's AI ("Spatial
## Reasoning for Strategic Decision Making", Game AI Pro 2, ch. 31): no
## plan, no search -- each option gets a number, and the numbers are what
## the designer tunes. A region's score for a squad is
##
##     worth x advantage / (1 + distance / DISTANCE_SCALE)
##
## where **worth** is what holding it would mean to this side -- its home
## under threat most of all, the enemy's bases next, a crossing a little --
## and **advantage** is the squad's strength over its strength plus the
## enemy influence there, so an even fight scores half and a hopeless one
## nearly nothing. The enemy half is `RtsInfluence`'s belief, fog and all.
##
## Two of T12's knobs act here. `search_depth` 2 also weighs the enemy's
## answer: the enemy strength in the squares *around* the region, which
## could arrive while the squad fights there; at 1 a squad sees only the
## region itself. `evaluation_noise` blurs each score by up to that
## fraction either way before the best is taken. Neither changes what the
## squad may see or do.
##
## When not to use it: a fight that depends on order more than place -- who
## to focus first. That is the squad's state machine, not a map.
class_name SquadTactics
extends RefCounted

## How much better a new region must score before a squad turns to it.
const STICK: float = 1.3
## Distance, in cells, at which a region's score halves.
const DISTANCE_SCALE: float = 20.0
## What a region is worth, by kind and whose it is.
const HOME_WORTH: float = 0.1
const THREAT_WORTH: float = 4.0
const ENEMY_HOME_WORTH: float = 2.0
const ENEMY_BASE_WORTH: float = 2.5
## An enemy expansion not yet looked at: the enemy may have taken it.
const UNKNOWN_EXPANSION_WORTH: float = 1.0
const OPEN_EXPANSION_WORTH: float = 0.3
## A region looked at and found empty: nothing there to take.
const CLEARED_WORTH: float = 0.05
const CROSSING_WORTH: float = 0.4

var _side: int
var _depth: int
var _noise: float
var _dice := RandomNumberGenerator.new()


## Tactics for `side` at a level's `depth` and `noise`, its blur drawn from
## `seed_value`.
func _init(side: int, depth: int, noise: float, seed_value: int) -> void:
	_side = side
	_depth = depth
	_noise = noise
	_dice.seed = seed_value


## Every region's score for `squad`, by name: what the screen lists, and
## what `best` takes the top of.
func scores(squad: Squad, belief: RtsInfluence) -> Dictionary:
	var scored: Dictionary = {}
	for region: String in RtsScenario.REGIONS:
		var cell: Vector2i = RtsScenario.REGIONS[region]["cell"]
		var worth: float = worth_of(region, belief)
		var against: float = _enemy_at(cell, belief)
		var advantage: float = squad.strength / (squad.strength + against) if squad.strength + against > 0.0 else 0.0
		var distance: float = squad.centre.distance_to(Vector2(cell))
		var score: float = worth * advantage / (1.0 + distance / DISTANCE_SCALE)
		scored[region] = score * (1.0 + _dice.randf_range(-_noise, _noise))
	return scored


## The region `squad` should go to: the highest score, ties to the first
## in `REGIONS` -- unless it already has a target scoring within `STICK` of
## the best. Without that a squad between two near-equal regions turns round
## every decision and arrives at neither.
func choose(squad: Squad, belief: RtsInfluence) -> String:
	var scored: Dictionary = scores(squad, belief)
	squad.scores = scored
	var chosen: String = ""
	for region: String in scored:
		if chosen == "" or scored[region] > scored[chosen]:
			chosen = region
	if squad.target != "" and scored.get(squad.target, 0.0) * STICK >= scored[chosen]:
		return squad.target
	return chosen


## What holding `region` is worth to this side, given what it believes.
func worth_of(region: String, belief: RtsInfluence) -> float:
	var entry: Dictionary = RtsScenario.REGIONS[region]
	# How much enemy the side believes is there, as a share of a squad's worth.
	var threat: float = minf(belief.at(entry["cell"])[1] / 300.0, 1.0)
	var ours: bool = entry["side"] == _side
	var unknown: bool = not belief.cleared.has(region)
	if entry["kind"] == "home" and ours:
		return HOME_WORTH + THREAT_WORTH * threat
	if entry["kind"] == "home":
		return ENEMY_HOME_WORTH if unknown or belief.base_believed_near(entry["cell"]) else CLEARED_WORTH
	if entry["kind"] == "expansion":
		return _expansion_worth(entry, ours, unknown, threat, belief)
	return CROSSING_WORTH


# A base believed there makes it a target, whoever's region it is; else one's
# own is worth defending, and the enemy's worth a look until looked at.
func _expansion_worth(entry: Dictionary, ours: bool, unknown: bool, threat: float, belief: RtsInfluence) -> float:
	if belief.base_believed_near(entry["cell"]):
		return ENEMY_BASE_WORTH
	if ours:
		return OPEN_EXPANSION_WORTH + THREAT_WORTH * 0.5 * threat
	return UNKNOWN_EXPANSION_WORTH if unknown else CLEARED_WORTH


# The enemy a squad would meet at `cell`: the square itself at depth 1, and
# the squares round it too at depth 2 -- who could come to its defence.
func _enemy_at(cell: Vector2i, belief: RtsInfluence) -> float:
	var against: float = belief.at(cell)[1]
	if _depth < 2:
		return against
	for direction: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		against += belief.at(cell + direction * RtsInfluence.CELL)[1] * 0.5
	return against

