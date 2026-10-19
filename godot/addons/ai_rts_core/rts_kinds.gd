## What each kind of unit and building is, as numbers, in one table.
##
## The core needs something to simulate, so it carries the smallest set an
## RTS has: a worker that gathers and builds, a soldier that fights, a base
## that trains workers and takes their loads, a barracks that trains soldiers,
## and a mine. The numbers are a starting point, not a balance: T20's demo is
## where they are tuned against play, and it may replace the whole table.
##
## Speeds are cells a second; times are ticks, at `RtsWorld.TICKS_PER_SECOND`.
##
## When not to use it: a game whose kinds differ in more than numbers --
## abilities, upgrades, armour types. Those are code, not a row.
class_name RtsKinds
extends RefCounted

const WORKER: String = "worker"
const SOLDIER: String = "soldier"
const BASE: String = "base"
const BARRACKS: String = "barracks"
const MINE: String = "mine"

## mobile: walks; health: at full; sight: radius in cells; cost: to build or
## train; ticks: to build or train; damage, reach and cooldown: a strike;
## trains: what a building may queue. A mine's health is what is left in it.
const TABLE: Dictionary = {
	WORKER: {"mobile": true, "health": 40, "speed": 2.0, "sight": 5.0, "cost": 50, "ticks": 300,
		"damage": 2, "reach": 1.1, "cooldown": 60, "trains": []},
	SOLDIER: {"mobile": true, "health": 80, "speed": 2.5, "sight": 6.0, "cost": 100, "ticks": 420,
		"damage": 8, "reach": 1.5, "cooldown": 45, "trains": []},
	BASE: {"mobile": false, "health": 1000, "speed": 0.0, "sight": 8.0, "cost": 400, "ticks": 1800,
		"damage": 0, "reach": 0.0, "cooldown": 0, "trains": [WORKER]},
	BARRACKS: {"mobile": false, "health": 500, "speed": 0.0, "sight": 5.0, "cost": 150, "ticks": 900,
		"damage": 0, "reach": 0.0, "cooldown": 0, "trains": [SOLDIER]},
	MINE: {"mobile": false, "health": 1500, "speed": 0.0, "sight": 0.0, "cost": 0, "ticks": 0,
		"damage": 0, "reach": 0.0, "cooldown": 0, "trains": []},
}

## Ticks a worker spends filling up at a mine, and what it then carries.
const GATHER_TICKS: int = 120
const LOAD: int = 10
## How close a worker stands to a mine, a base or a building site to use it:
## a little over one cell, which is the cell beside it and no further.
const USE_REACH: float = 1.1
## The longest training queue a building keeps.
const QUEUE_LIMIT: int = 5
## The widest sight in the table: how far a fog question has to look.
const LONGEST_SIGHT: float = 8.0


## One number about a kind, by name: `RtsKinds.of(RtsKinds.SOLDIER, "speed")`.
static func of(kind: String, field: String) -> Variant:
	return TABLE[kind][field]


## True for the kinds that stand still and block their cell.
static func is_building(kind: String) -> bool:
	return not TABLE[kind]["mobile"]
