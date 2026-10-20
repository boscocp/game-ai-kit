## How an RTS match ends, and who won it.
##
## Two ways, because T25's league needs every match to finish. A side whose
## last base has fallen has lost. And at `RtsScenario.TIME_LIMIT_SECONDS`
## the side holding more wins: everything it has standing, priced at what
## it cost -- ore and magma counted alike -- plus what it has banked. Equal
## worth is a draw. Worth, not kills: a side that traded well and built
## nothing has nothing to show for it, which is the economy's lesson.
##
## When not to use it: a game with a score of its own. This one has only
## the board.
class_name RtsVictory
extends RefCounted

## No side has won yet.
const UNDECIDED: int = -2
## The time ran out with both sides worth the same.
const DRAW: int = -3


## The winner of `world` now: a side, `UNDECIDED` while it goes on, or `DRAW`.
static func winner(world: RtsWorld) -> int:
	var standing: Array[int] = []
	for side: int in [RtsScenario.WEST, RtsScenario.EAST]:
		if _has_a_base(world, side):
			standing.append(side)
	if standing.size() == 1:
		return standing[0]
	if standing.is_empty():
		return DRAW
	if world.tick < RtsScenario.TIME_LIMIT_SECONDS * RtsWorld.TICKS_PER_SECOND:
		return UNDECIDED
	return _on_worth(world)


## Why the match ended as it did, in a sentence for the screen and the log.
static func why(world: RtsWorld) -> String:
	var won: int = winner(world)
	if won == UNDECIDED:
		return "still going"
	var west: int = worth(world, RtsScenario.WEST)
	var east: int = worth(world, RtsScenario.EAST)
	if world.tick < RtsScenario.TIME_LIMIT_SECONDS * RtsWorld.TICKS_PER_SECOND:
		return "%s's last base fell" % _name(RtsScenario.enemy_of(won))
	if won == DRAW:
		return "time: both sides worth %d" % west
	return "time: west worth %d, east %d" % [west, east]


## What `side` holds, priced: every unit and building at its cost, and its
## funds, both resources counted alike.
static func worth(world: RtsWorld, side: int) -> int:
	var total: int = 0
	for unit: RtsUnit in world.units():
		if unit.side != side:
			continue
		for resource: String in RtsKinds.RESOURCES:
			total += RtsKinds.cost(unit.kind)[resource]
	for resource: String in RtsKinds.RESOURCES:
		total += world.funds(side)[resource]
	return total


static func _on_worth(world: RtsWorld) -> int:
	var west: int = worth(world, RtsScenario.WEST)
	var east: int = worth(world, RtsScenario.EAST)
	if west == east:
		return DRAW
	return RtsScenario.WEST if west > east else RtsScenario.EAST


# Any base, a complete one or one still going up: a base the side has paid
# for keeps it in the match, and taking it down is the other side's job.
static func _has_a_base(world: RtsWorld, side: int) -> bool:
	for unit: RtsUnit in world.units():
		if unit.side == side and unit.kind == RtsKinds.BASE:
			return true
	return false


static func _name(side: int) -> String:
	return "west" if side == RtsScenario.WEST else "east"
