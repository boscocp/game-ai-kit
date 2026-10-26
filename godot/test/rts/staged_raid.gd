# The moment the armed tower is for, staged by hand, for `rts_game_test.gd`
# and `rts_measure.gd` alike: whole matches seldom reach it (T56).
#
# West mid-match: a barracks and a tower up (the tower at home + (3, -3)),
# its workers on the nearest vent so magma flows, and 2000 of each resource.
# East runners raid it at a spot of the test's choosing and are **held**
# there: any that wander more than two cells off are put back every second,
# which flatters a gun that cannot move -- said wherever a number from here
# is quoted.
extends RefCounted

## A raid inside the tower's gun reach, and one at home but out of it.
const IN_REACH := Vector2i(4, 0)
const OUT_OF_REACH := Vector2i(-4, 4)
## Where an army away from home stands: the far east corner.
const AWAY := Vector2i(44, 3)


## West's home as the header says, from `seed_value`.
static func home_with_a_tower(seed_value: int) -> RtsWorld:
	var world: RtsWorld = RtsScenario.start(seed_value)
	var home: Vector2i = RtsScenario.home(RtsScenario.WEST)
	world.add_unit(RtsKinds.BARRACKS, RtsScenario.WEST, home + Vector2i(0, -3))
	world.add_unit(RtsKinds.TOWER, RtsScenario.WEST, home + Vector2i(3, -3))
	world.set_funds(RtsScenario.WEST, 2000, 2000)
	var vent: RtsUnit = world.nearest(Vector2(home), RtsWorld.NEUTRAL, RtsKinds.VENT)
	var workers: Array[int] = []
	for unit: RtsUnit in world.units():
		if unit.side == RtsScenario.WEST and unit.kind == RtsKinds.WORKER:
			workers.append(unit.id)
	world.command(RtsScenario.WEST, RtsCommand.gather(workers, vent.id))
	return world


## `count` of `kind` for `side`, round the cell `at`.
static func add(world: RtsWorld, side: int, kind: String, count: int, at: Vector2i) -> Array[RtsUnit]:
	var added: Array[RtsUnit] = []
	for _index: int in range(count):
		added.append(world.add_unit(kind, side, world.free_cell_near(at)))
	return added


## West's home with the raid on it: `raiders` east runners round home +
## `spot`, and four west shields at home when `defended`, else away.
static func stage(seed_value: int, raiders: int, spot: Vector2i, defended: bool) -> RtsWorld:
	var world: RtsWorld = home_with_a_tower(seed_value)
	var home: Vector2i = RtsScenario.home(RtsScenario.WEST)
	add(world, RtsScenario.WEST, RtsKinds.SHIELD, 4, home + Vector2i(1, -1) if defended else AWAY)
	add(world, RtsScenario.EAST, RtsKinds.RUNNER, raiders, home + spot)
	return world


## A normal commander as west, `may_arm` or not, on a `stage`d world for
## `seconds`, the raid held at home + `spot`. The match, to read what west
## bought.
static func play(world: RtsWorld, seed_value: int, spot: Vector2i, may_arm: bool, seconds: int) -> RtsMatch:
	var raid: Array[RtsUnit] = []
	for unit: RtsUnit in world.units():
		if unit.side == RtsScenario.EAST:
			raid.append(unit)
	var commander := RtsCommander.new(RtsScenario.WEST, RtsLevels.named("normal"), seed_value)
	commander.may_arm = may_arm
	var played := RtsMatch.new(world, seed_value, {RtsScenario.WEST: commander})
	for _second: int in range(seconds):
		played.play(RtsWorld.TICKS_PER_SECOND)
		hold(world, raid, RtsScenario.home(RtsScenario.WEST) + spot)
	return played


## Every raider still standing more than two cells off `at` is put back there.
static func hold(world: RtsWorld, raid: Array[RtsUnit], at: Vector2i) -> void:
	var spot: Vector2 = Vector2(at) + Vector2(0.5, 0.5)
	for raider: RtsUnit in raid:
		if raider.health > 0 and raider.position.distance_to(spot) > 2.0:
			world.place(raider, spot)


## How many arms `side` bought in `played`, refusals not counted.
static func arms_by(played: RtsMatch, side: int) -> int:
	return _arms(played, side).size()


## The tick `side` first bought an arm in `played`, or -1 for never.
static func first_arm_tick(played: RtsMatch, side: int) -> int:
	var bought: Array[Dictionary] = _arms(played, side)
	return -1 if bought.is_empty() else int(bought[0]["tick"])


static func _arms(played: RtsMatch, side: int) -> Array[Dictionary]:
	var bought: Array[Dictionary] = []
	for entry: Dictionary in played.accepted:
		if entry["side"] == side and entry["command"]["what"] == RtsKinds.ARM:
			bought.append(entry)
	return bought
