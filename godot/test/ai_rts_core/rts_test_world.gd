# The worlds T19's two scripts play on, built the same way every time from a
# seed, so a recording can be replayed on a fresh one.
#
# A 64 x 64 board with a wall down the middle and three gaps in it, and two
# strips of mud, so a route is a choice and a flow field has something to go
# round. On it, either two armies of a hundred shields facing each other --
# the budget's scale -- or two small economies, a base, a barracks, a depot,
# workers and two rocks a side, for the simulation's match.
class_name RtsTestWorld
extends RefCounted

const SIZE: int = 64
const WALL_COLUMN: int = 32
const GAPS: Array[int] = [12, 32, 52]
const MUD_COST: int = 3
const LEFT: int = 0
const RIGHT: int = 1


## The board both scripts play on.
static func board() -> GakGridGraph:
	var graph := GakGridGraph.new(SIZE, SIZE)
	for row: int in range(SIZE):
		if not (row in GAPS or row - 1 in GAPS or row + 1 in GAPS):
			graph.block(Vector2i(WALL_COLUMN, row))
	for row: int in range(20, 44):
		graph.set_cost(Vector2i(16, row), MUD_COST)
		graph.set_cost(Vector2i(48, row), MUD_COST)
	return graph


## Two armies of `per_side` shields in blocks either side of the wall.
static func armies(seed_value: int, per_side: int = 100) -> RtsWorld:
	var world := RtsWorld.new(board(), seed_value)
	for index: int in range(per_side):
		var offset := Vector2i(index % 10, index / 10)
		world.add_unit(RtsKinds.SHIELD, LEFT, Vector2i(4, 27) + offset)
		world.add_unit(RtsKinds.SHIELD, RIGHT, Vector2i(50, 27) + offset)
	return world


## Two small economies: a side's base, barracks, depot, four workers and two
## rocks near it, and enough ore to start.
static func economies(seed_value: int) -> RtsWorld:
	var world := RtsWorld.new(board(), seed_value)
	for side: int in [LEFT, RIGHT]:
		var home := Vector2i(8, 32) if side == LEFT else Vector2i(55, 32)
		var away: int = 1 if side == LEFT else -1
		world.add_unit(RtsKinds.BASE, side, home)
		world.add_unit(RtsKinds.BARRACKS, side, home + Vector2i(3 * away, 4))
		world.add_unit(RtsKinds.DEPOT, side, home + Vector2i(0, -5))
		world.add_unit(RtsKinds.ROCKS, RtsWorld.NEUTRAL, home + Vector2i(-3 * away, -3))
		world.add_unit(RtsKinds.ROCKS, RtsWorld.NEUTRAL, home + Vector2i(-3 * away, 3))
		for index: int in range(4):
			world.add_unit(RtsKinds.WORKER, side, home + Vector2i(away * (index + 1), -2))
		world.set_funds(side, 300)
	return world
