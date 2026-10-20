## The RTS map, and the state a match on it starts from.
##
## T10's ground, grown to real time. A river runs down the middle; one
## bridge, two cells wide, is the chokepoint, and two fords near the ends
## are the slow way round. Trees are slow to cross and rock is not crossed
## at all. Water is impassable to every unit, since the wader that swam it
## is not among the three kept. The map is the same turned half round, so
## neither side starts nearer anything.
##
## Each side has a home -- a base, three rocks and a vent -- and an
## expansion with two rocks and a vent of its own. The expansions sit by the
## *far* fords, nearer the enemy's crossing than one's own home: taking one
## is worth something because it can be taken from you.
##
## The map is text, one row per line, so a reader sees it in the source and
## a change to it is a diff a person can review -- `TacticalScenario`'s way.
##
## When not to use it: a second map. The day there are two, the rows belong
## in a data file.
class_name RtsScenario
extends RefCounted

const WEST: int = 0
const EAST: int = 1

## `.` open, `T` trees (cost 2), `#` rock, `~` water, `=` the bridge, `f` a
## ford (cost 3), `o` rocks to mine for ore, `v` a vent for magma, `A` and
## `B` the two bases. Generated half-turn symmetric; `test/rts_match.gd`
## checks it still is.
const MAP: Array[String] = [
	".......................~~.......................",
	".......................~~.......................",
	".......................~~..............v....o...",
	".............o.........ff......#................",
	"..........o............ff......#................",
	".......................~~......#..........B..o..",
	"..................#....~~.......................",
	"...........v......#....~~.......................",
	"..................##...~~.........##.........o..",
	".............TT........~~...TT.....#............",
	".............T.........~~....TT....#............",
	".......................~~..........#............",
	"....TT..............T..~~.TTT...................",
	".....T.............TT..~~...TT..................",
	"...................T...~~.........###TT.........",
	".......................==............TTT........",
	"........TTT............==.......................",
	".........TT###.........~~...T...................",
	"..................TT...~~..TT.............T.....",
	"...................TTT.~~..T..............TT....",
	"............#..........~~.......................",
	"............#....TT....~~.........T.............",
	"............#.....TT...~~........TT.............",
	"..o.........##.........~~...##..................",
	".......................~~....#......v...........",
	".......................~~....#..................",
	"..o..A..........#......~~.......................",
	"................#......ff............o..........",
	"................#......ff.........o.............",
	"...o....v..............~~.......................",
	".......................~~.......................",
	".......................~~.......................",
]

const TREE_COST: int = 2
const FORD_COST: int = 3

## What each side starts with: enough for a depot and a little over, the
## barracks a minute of mining away.
const START_ORE: int = 200
const START_MAGMA: int = 0
const START_WORKERS: int = 4

## The places worth going, by name: what the squads score. Each a cell and
## what it is worth to whom -- `home` to its owner, `expansion` to whoever
## takes it, `crossing` to anybody who wants to get over.
const REGIONS: Dictionary = {
	"west home": {"cell": Vector2i(5, 26), "kind": "home", "side": WEST},
	"east home": {"cell": Vector2i(42, 5), "kind": "home", "side": EAST},
	"west expansion": {"cell": Vector2i(11, 5), "kind": "expansion", "side": WEST},
	"east expansion": {"cell": Vector2i(36, 26), "kind": "expansion", "side": EAST},
	"bridge": {"cell": Vector2i(24, 15), "kind": "crossing", "side": -1},
	"north ford": {"cell": Vector2i(23, 3), "kind": "crossing", "side": -1},
	"south ford": {"cell": Vector2i(24, 28), "kind": "crossing", "side": -1},
}

## A match lasts at most this long, then the tiebreak decides (`RtsVictory`).
const TIME_LIMIT_SECONDS: int = 20 * 60


## The board the map draws: costs for trees and fords, rock and water
## blocked, deposits and bases left open for `start` to stand things on.
static func board() -> GridGraph:
	var graph := GridGraph.new(MAP[0].length(), MAP.size())
	for cell: Vector2i in _cells():
		var letter: String = MAP[cell.y][cell.x]
		if letter in ["#", "~"]:
			graph.block(cell)
		elif letter == "T" or letter == "f":
			graph.set_cost(cell, TREE_COST if letter == "T" else FORD_COST)
	return graph


## The match as it starts, its dice seeded with `match_seed`: each base,
## its workers beside it, every deposit, and each side's opening funds.
static func start(match_seed: int) -> RtsWorld:
	var world := RtsWorld.new(board(), match_seed)
	for cell: Vector2i in _cells():
		_stand(world, MAP[cell.y][cell.x], cell)
		if MAP[cell.y][cell.x] == "#":
			world.add_wall(cell)
	for side: int in [WEST, EAST]:
		world.set_funds(side, START_ORE, START_MAGMA)
	return world


## The cell `side`'s first base stands on.
static func home(side: int) -> Vector2i:
	return REGIONS["west home" if side == WEST else "east home"]["cell"]


## The other side.
static func enemy_of(side: int) -> int:
	return EAST if side == WEST else WEST


# Every cell of the map, row by row.
static func _cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for index: int in range(MAP.size() * MAP[0].length()):
		cells.append(Vector2i(index % MAP[0].length(), index / MAP[0].length()))
	return cells


static func _stand(world: RtsWorld, letter: String, cell: Vector2i) -> void:
	match letter:
		"o":
			world.add_unit(RtsKinds.ROCKS, RtsWorld.NEUTRAL, cell)
		"v":
			world.add_unit(RtsKinds.VENT, RtsWorld.NEUTRAL, cell)
		"A", "B":
			_found_a_side(world, WEST if letter == "A" else EAST, cell)


# A base, and its workers on the side of it that faces the map's middle.
static func _found_a_side(world: RtsWorld, side: int, cell: Vector2i) -> void:
	world.add_unit(RtsKinds.BASE, side, cell)
	var inward: int = 1 if side == WEST else -1
	for index: int in range(START_WORKERS):
		world.add_unit(RtsKinds.WORKER, side, cell + Vector2i(inward * (index + 1), -inward))
