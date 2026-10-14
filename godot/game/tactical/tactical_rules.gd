## The tactical scenario's table: five unit types, two towers, the building
## that makes them, the upgrade that unlocks the last one, and what each kind
## of ground costs.
##
## Everything here is a number a planner can read, which is the point. The
## five types differ in exactly the things a plan reasons about -- how far
## they go, how far they reach, what they beat, what they cost -- and the
## counter table is a cycle, because rock-paper-scissors is what makes a plan
## beat a reflex: the reflex builds what beats what it sees, and the plan
## builds what beats what is coming.
##
## The names and the roles are this kit's own. Mechanics are not
## copyrightable; names and designs are, so nothing here borrows either.
##
## When not to use it: balance. These numbers make each type *different*; no
## one has played enough games to say they are *fair*, and T12 is where that
## is measured rather than guessed.
class_name TacticalRules
extends RefCounted

## Terrain, as the characters a scenario map is written in.
const PLAIN: String = "."
const TREES: String = "T"
const ROCK: String = "#"
const WATER: String = "~"
## Dry ground over the river: costs what open ground costs, and is drawn as a
## bridge because the only crossing should look like one.
const BRIDGE: String = "="

## Trees cost this much to enter. They will also block sight, once there is
## fog to see through (T20); for now `sight` is a number nothing reads.
const TREES_COST: int = 3

## The cost map the wader walks on, by name. See `UnitType.mover`.
const WATER_MOVER: String = "water"

## What each side earns at the start of its turn, and starts with.
const INCOME: int = 3
const STARTING_FUNDS: int = 4

const RUNNER: String = "runner"
const SHIELD: String = "shield"
const MORTAR: String = "mortar"
const WADER: String = "wader"
const RAM: String = "ram"
const BOLT_TOWER: String = "bolt tower"
const WATCHTOWER: String = "watchtower"
const WORKSHOP: String = "workshop"

## The one upgrade: a forge, which the ram needs.
const FORGE: String = "forge"
const FORGE_COST: int = 5

## The five types a workshop makes, in the order the number keys pick them.
const BUILDABLE: Array[String] = [RUNNER, SHIELD, MORTAR, WADER, RAM]


## Every type in the scenario, by name. Built fresh each call, so a test that
## changes one cannot change the game's.
static func unit_types() -> Dictionary:
	var types: Dictionary = {}
	for kind: UnitType in _mobile_types() + _fixed_types():
		types[kind.type_name] = kind
	return types


## The forge, as something a faction can buy.
static func forge() -> Upgrade:
	return Upgrade.new(FORGE, FORGE_COST)


## The board's own cost map, and the wader's: one terrain map read twice.
## Water is a wall to everything but the wader, which is the whole of what
## makes it a wader -- and `ai_core` never learns what water is.
static func graphs_from(rows: Array[String]) -> Dictionary:
	var ground := GridGraph.new(rows[0].length(), rows.size())
	var water := GridGraph.new(rows[0].length(), rows.size())
	for y: int in range(rows.size()):
		for x: int in range(rows[y].length()):
			var cell := Vector2i(x, y)
			ground.set_cost(cell, _ground_cost(rows[y][x]))
			water.set_cost(cell, GridGraph.DEFAULT_COST if rows[y][x] == WATER else _ground_cost(rows[y][x]))
	return {UnitType.GROUND: ground, WATER_MOVER: water}


## Every cell of a map written in one terrain character.
static func cells_of(rows: Array[String], terrain: String) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for index: int in range(rows.size() * rows[0].length()):
		var cell := Vector2i(index % rows[0].length(), index / rows[0].length())
		if rows[cell.y][cell.x] == terrain:
			found.append(cell)
	return found


# The five a workshop builds, and the cycle between them: the runner is fast
# and cheap and catches what is slow (mortar, ram); the shield holds the line
# against runners and waders; the mortar outranges the shield; the wader goes
# where nobody else can and finds mortars there; the ram, behind the forge,
# is for buildings.
static func _mobile_types() -> Array[UnitType]:
	var runner := UnitType.new(RUNNER, 6, 1, 3, 1)
	runner.strong_against.assign([MORTAR, RAM])
	var shield := UnitType.new(SHIELD, 3, 1, 2, 2)
	shield.strong_against.assign([RUNNER, WADER])
	var mortar := UnitType.new(MORTAR, 2, 3, 2, 3)
	mortar.strong_against.assign([SHIELD])
	var wader := UnitType.new(WADER, 4, 1, 3, 2)
	wader.mover = WATER_MOVER
	wader.strong_against.assign([MORTAR])
	var ram := UnitType.new(RAM, 2, 1, 1, 4)
	ram.requires = FORGE
	ram.strong_against.assign([BOLT_TOWER, WATCHTOWER, WORKSHOP])
	return [runner, shield, mortar, wader, ram]


# The two towers -- one that shoots, one that sees -- and the workshop. None of
# them moves, and that is one field on the type, not a class of its own.
static func _fixed_types() -> Array[UnitType]:
	var bolt := UnitType.new(BOLT_TOWER, 0, 2, 3, 0, false)
	bolt.strong_against.assign([RUNNER, WADER])
	var watch := UnitType.new(WATCHTOWER, 0, 0, 6, 0, false)
	var workshop := UnitType.new(WORKSHOP, 0, 0, 2, 0, false)
	workshop.produces.assign(BUILDABLE)
	return [bolt, watch, workshop]


static func _ground_cost(terrain: String) -> int:
	match terrain:
		TREES:
			return TREES_COST
		ROCK, WATER:
			return GridGraph.BLOCKED
	return GridGraph.DEFAULT_COST
