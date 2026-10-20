## What each kind of unit and building is, as numbers, in one table.
##
## T20's minimum game, built backwards from the AIs that play it: two
## resources, so spending is a trade (Churchill and Buro's StarCraft build
## orders); a worker that gathers and builds; three fighters in a
## rock-paper-scissors table taken from T10's five -- the runner beats the
## mortar, the shield the runner, the mortar the shield; a base, a barracks
## and one technology building, the lab, which the mortar needs; a depot,
## because a population cap that forces a building lengthens the build
## order without a new rule; and T10's tower that sees, which buys vision
## without spending a unit. T19 started with a smaller table and said T20
## would replace it; this is that table.
##
## Speeds are cells a second; times are ticks, at `RtsWorld.TICKS_PER_SECOND`.
## Costs are by resource. The numbers are tuned by the matches in
## `test/rts_match.gd`, not derived; change one and run it.
##
## When not to use it: a game whose kinds differ in more than numbers --
## abilities, upgrades, armour types. Those are code, not a row.
class_name RtsKinds
extends RefCounted

const WORKER: String = "worker"
const RUNNER: String = "runner"
const SHIELD: String = "shield"
const MORTAR: String = "mortar"
const BASE: String = "base"
const BARRACKS: String = "barracks"
const LAB: String = "lab"
const DEPOT: String = "depot"
const TOWER: String = "tower"
const ROCKS: String = "rocks"
const VENT: String = "vent"

## The two resources, in the order every list of them keeps.
const ORE: String = "ore"
const MAGMA: String = "magma"
const RESOURCES: Array[String] = [ORE, MAGMA]

## The three that fight, weakest-first by nothing: each beats one other.
const FIGHTERS: Array[String] = [RUNNER, SHIELD, MORTAR]

## mobile: walks; health: at full; sight: radius in cells; cost: by
## resource, to build or train; ticks: to build or train; damage, reach and
## cooldown: a strike; siege: strikes buildings at full weight, where every
## other kind strikes them at a third; trains: what a building may queue; supply: room a
## unit takes; provides: room a building gives; needs: a building that must
## stand, complete, before this may be built or trained; beats: the kinds it
## strikes twice as hard; yields: the resource a deposit holds, its health
## being what is left in it.
const TABLE: Dictionary = {
	WORKER: {"mobile": true, "health": 40, "speed": 2.0, "sight": 5.0, "cost": {ORE: 50}, "ticks": 300,
		"damage": 2, "reach": 1.1, "cooldown": 60, "supply": 1},
	RUNNER: {"mobile": true, "health": 60, "speed": 3.2, "sight": 6.0, "cost": {ORE: 75}, "ticks": 360,
		"damage": 5, "reach": 1.3, "cooldown": 30, "supply": 1, "beats": [MORTAR]},
	SHIELD: {"mobile": true, "health": 140, "speed": 1.8, "sight": 5.0, "cost": {ORE: 100, MAGMA: 25}, "ticks": 480,
		"damage": 7, "reach": 1.3, "cooldown": 45, "supply": 2, "beats": [RUNNER]},
	MORTAR: {"mobile": true, "health": 50, "speed": 1.8, "sight": 7.0, "cost": {ORE: 100, MAGMA: 75}, "ticks": 540,
		"damage": 12, "reach": 5.0, "cooldown": 90, "supply": 2, "beats": [SHIELD], "needs": LAB, "siege": true},
	BASE: {"mobile": false, "health": 1200, "sight": 8.0, "cost": {ORE: 400}, "ticks": 1800,
		"trains": [WORKER], "provides": 10},
	BARRACKS: {"mobile": false, "health": 600, "sight": 5.0, "cost": {ORE: 150}, "ticks": 900,
		"trains": [RUNNER, SHIELD, MORTAR]},
	LAB: {"mobile": false, "health": 500, "sight": 5.0, "cost": {ORE: 150, MAGMA: 100}, "ticks": 1200,
		"needs": BARRACKS},
	DEPOT: {"mobile": false, "health": 300, "sight": 4.0, "cost": {ORE: 100}, "ticks": 600, "provides": 8},
	TOWER: {"mobile": false, "health": 300, "sight": 11.0, "cost": {ORE: 75, MAGMA: 25}, "ticks": 600},
	ROCKS: {"mobile": false, "health": 2500, "sight": 0.0, "yields": ORE},
	VENT: {"mobile": false, "health": 2000, "sight": 0.0, "yields": MAGMA},
}

## Every field a row may leave out, and what it then means. A row says only
## what makes its kind different, so the table reads as the game's design.
const DEFAULTS: Dictionary = {"speed": 0.0, "cost": {}, "ticks": 0, "damage": 0, "reach": 0.0,
	"cooldown": 0, "siege": false, "trains": [], "supply": 0, "provides": 0, "needs": "", "beats": [],
	"yields": ""}

## Ticks a worker spends filling up at a deposit, and what it then carries.
const GATHER_TICKS: int = 120
const LOAD: int = 10
## How close a worker stands to a deposit, a base or a building site to use
## it: a little over one cell, which is the cell beside it and no further.
const USE_REACH: float = 1.1
## The longest training queue a building keeps.
const QUEUE_LIMIT: int = 5
## The most room a side may have, however many depots it raises.
const SUPPLY_LIMIT: int = 60
## How much harder a fighter strikes the kind it beats.
const COUNTER_FACTOR: int = 2
## How much a building divides a blow from anything but a siege unit: T10's
## ram, which alone broke a workshop, is the mortar here. Without it a
## handful of runners razed a base in two minutes and no match reached the
## lab -- measured on the first matches of `test/rts_match.gd`.
const FORTIFIED: int = 3
## What a building still going up sees: its own cell and the worker raising
## it, never the tower's eleven cells the moment it is paid for.
const SITE_SIGHT: float = 1.5
## The widest sight in the table: how far a fog question has to look.
const LONGEST_SIGHT: float = 11.0


## One number about a kind, by name: `RtsKinds.of(RtsKinds.SHIELD, "speed")`.
static func of(kind: String, field: String) -> Variant:
	var row: Dictionary = TABLE[kind]
	return row[field] if row.has(field) else DEFAULTS[field]


## What `kind` costs, by resource, every resource named -- 0 for the ones it
## does not need, so a caller can loop over `RESOURCES` without asking.
static func cost(kind: String) -> Dictionary:
	var priced: Dictionary = of(kind, "cost")
	var whole: Dictionary = {}
	for resource: String in RESOURCES:
		whole[resource] = priced.get(resource, 0)
	return whole


## How far a `kind` sees: its row's sight once `complete`, `SITE_SIGHT`
## while it goes up. Every fog question asks this, never the row.
static func sight(kind: String, complete: bool) -> float:
	var full: float = of(kind, "sight")
	return full if complete else minf(full, SITE_SIGHT)


## True for the kinds that stand still and block their cell.
static func is_building(kind: String) -> bool:
	return not TABLE[kind]["mobile"]


## True for a deposit: something that belongs to nobody and is gathered.
static func is_deposit(kind: String) -> bool:
	return of(kind, "yields") != ""


## True for a unit that fights of its own accord when idle: mobile, armed,
## and not a worker, which has a job.
static func fights(kind: String) -> bool:
	return kind in FIGHTERS


## The damage a blow by `attacker` deals `target`, before the dice: twice
## against the kind it beats, a third against a building unless it besieges.
static func blow(attacker: String, target: String) -> int:
	var damage: int = of(attacker, "damage")
	if target in of(attacker, "beats"):
		return damage * COUNTER_FACTOR
	if is_building(target) and not of(attacker, "siege"):
		return maxi(damage / FORTIFIED, 1)
	return damage
