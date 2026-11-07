# T151's flock, a piece at a time: what it changes, what it leaves alone,
# and that it is still one match from one seed. The wall-gap jam, the
# planted case, is `rts_flock_gap.gd`'s; this holds the small claims.
extends GdUnitTestSuite

## Twelve shields, the manual check's group, in a block at the open board's
## west end, and the cell they are sent to at its east end.
const GROUP: int = 12
const GOAL := Vector2i(36, 10)
## Mid-way: long after the field has bent everybody onto it, long before
## the last straight stretch, where the core walks them all at one point.
const MIDWAY: int = 6 * RtsWorld.TICKS_PER_SECOND


func test_the_base_crowd_walks_exactly_as_the_core_always_has() -> void:
	# A flock switched off and the port's own base are both the core's
	# walk: the same match to the digest as a world nobody gave a crowd.
	var untouched: RtsWorld = _sent(null)
	var based: RtsWorld = _sent(GakRtsCrowd.new())
	var off: RtsWorld = _sent(RtsFlock.new())
	for world: RtsWorld in [untouched, based, off]:
		_play(world, MIDWAY)
	assert_str(based.digest()).is_equal(untouched.digest())
	assert_str(off.digest()).is_equal(untouched.digest())


func test_on_the_group_walks_abreast_where_the_column_files_into_a_line() -> void:
	# Measured mid-way: the column is one file, no wider than a point and
	# 4.6 cells long; the flock about a cell wide and 2.9 long, each unit
	# twice as far from its nearest groupmate (0.53 cells against 0.28).
	var column: RtsWorld = _sent(null)
	var flocked: RtsWorld = _sent(_flock_on())
	_play(column, MIDWAY)
	_play(flocked, MIDWAY)
	print("  column: %s cells, nearest %.2f; flock: %s cells, nearest %.2f" % [
		_extent(column), _nearest_apart(column), _extent(flocked), _nearest_apart(flocked)])
	assert_float(_extent(column).y).is_less(0.1)
	assert_float(_extent(flocked).y).is_greater(0.5)
	assert_float(_extent(flocked).x).is_less(_extent(column).x)
	assert_float(_nearest_apart(flocked)).is_greater(1.5 * _nearest_apart(column))


func test_on_the_group_still_goes_where_it_was_sent() -> void:
	var flocked: RtsWorld = _sent(_flock_on())
	_play(flocked, 30 * RtsWorld.TICKS_PER_SECOND)
	for unit: RtsUnit in flocked.units():
		assert_str(unit.order).is_equal(RtsUnit.IDLE)
		assert_float(unit.position.distance_to(Vector2(GOAL))).is_less(2.5)


func test_a_unit_sent_alone_does_not_flock() -> void:
	var alone: RtsWorld = _board_world()
	var flocked: RtsWorld = _board_world()
	flocked.crowd = _flock_on()
	for world: RtsWorld in [alone, flocked]:
		var walker: RtsUnit = world.add_unit(RtsKinds.SHIELD, 0, Vector2i(3, 3))
		world.command(0, RtsCommand.move([walker.id] as Array[int], GOAL))
		_play(world, MIDWAY)
	assert_str(flocked.digest()).is_equal(alone.digest())


func test_a_group_on_another_order_does_not_flock() -> void:
	# A group gathering is not a move order: the flock leaves it to the core.
	var plain: RtsWorld = _gatherers(null)
	var flocked: RtsWorld = _gatherers(_flock_on())
	_play(plain, MIDWAY)
	_play(flocked, MIDWAY)
	assert_str(flocked.digest()).is_equal(plain.digest())


func test_on_one_seed_is_still_one_match() -> void:
	var first: RtsWorld = _sent(_flock_on())
	var second: RtsWorld = _sent(_flock_on())
	_play(first, MIDWAY)
	_play(second, MIDWAY)
	assert_str(second.digest()).is_equal(first.digest())
	assert_str(first.digest()).is_not_equal(_played(_sent(null)).digest())


func test_the_watched_unit_shows_its_three_forces_and_who_it_counted() -> void:
	var flock: RtsFlock = _flock_on()
	var world: RtsWorld = _sent(flock)
	flock.watched = world.units()[GROUP / 2].id
	_play(world, MIDWAY)
	assert_int(flock.watched_forces.size()).is_equal(3)
	assert_bool(flock.watched_counted.is_empty()).is_false()
	assert_bool(flock.watched_counted.has(flock.watched)).is_false()
	var pushed: bool = false
	for force: Vector2 in flock.watched_forces:
		pushed = pushed or force != Vector2.ZERO
	assert_bool(pushed).is_true()


func test_switched_off_mid_walk_the_column_takes_over() -> void:
	var flock: RtsFlock = _flock_on()
	var world: RtsWorld = _sent(flock)
	_play(world, MIDWAY / 2)
	flock.on = false
	_play(world, MIDWAY)
	assert_float(_extent(world).y).is_less(0.1)


func test_g_switches_the_games_flock_and_the_overlay_shows_the_watched_unit() -> void:
	var game: RtsGame = auto_free((load("res://game/rts/rts.tscn") as PackedScene).instantiate())
	add_child(game)
	assert_object(game.world.crowd).is_same(game.flock)
	assert_bool(game.flock.on).is_false()
	game._on_key(KEY_G)
	assert_bool(game.flock.on).is_true()
	var ids: Array[int] = []
	for unit: Dictionary in RtsSnapshot.of(game.world, RtsScenario.WEST).mine(RtsKinds.WORKER):
		ids.append(unit["id"])
		game._view.selected[unit["id"]] = true
	game._order_at(RtsScenario.home(RtsScenario.WEST) + Vector2i(12, -6), Vector2(-999, -999))
	game._refresh()
	game.played.play(RtsWorld.TICKS_PER_SECOND)
	game._refresh()
	game.played.play(RtsFlock.DECIDE_EVERY)
	ids.sort()
	assert_int(game.flock.watched).is_equal(ids[0])
	var shown: Dictionary = game.decision_overlay()
	assert_bool(shown.has("flock")).is_true()
	for rule: String in RtsFlock.RULES:
		assert_bool(shown["flock"].has(rule)).is_true()
	game._on_key(KEY_G)
	game.played.play(1)
	assert_bool(game.decision_overlay().has("flock")).is_false()


func _flock_on() -> RtsFlock:
	var flock := RtsFlock.new()
	flock.on = true
	return flock


# An open board, forty by twenty, nobody on it.
func _board_world() -> RtsWorld:
	return RtsWorld.new(GakGridGraph.new(40, 20), 151)


# The group in its block, sent to `GOAL` as one order, on a world given
# `crowd` -- or none, the core's own.
func _sent(crowd: GakRtsCrowd) -> RtsWorld:
	var world: RtsWorld = _board_world()
	if crowd != null:
		world.crowd = crowd
	var ids: Array[int] = []
	for index: int in range(GROUP):
		ids.append(world.add_unit(RtsKinds.SHIELD, 0, Vector2i(2 + index % 4, 8 + index / 4)).id)
	world.command(0, RtsCommand.move(ids, GOAL))
	return world


# Four workers sent together to one rock.
func _gatherers(crowd: GakRtsCrowd) -> RtsWorld:
	var world: RtsWorld = _board_world()
	if crowd != null:
		world.crowd = crowd
	world.add_unit(RtsKinds.BASE, 0, Vector2i(3, 10))
	var rock: RtsUnit = world.add_unit(RtsKinds.ROCKS, RtsWorld.NEUTRAL, Vector2i(30, 10))
	var ids: Array[int] = []
	for index: int in range(4):
		ids.append(world.add_unit(RtsKinds.WORKER, 0, Vector2i(5, 8 + index)).id)
	world.command(0, RtsCommand.gather(ids, rock.id))
	return world


func _play(world: RtsWorld, ticks: int) -> void:
	for _tick: int in range(ticks):
		world.step()


func _played(world: RtsWorld) -> RtsWorld:
	_play(world, MIDWAY)
	return world


# The mean, over the units, of the distance to the nearest other.
static func _nearest_apart(world: RtsWorld) -> float:
	var total: float = 0.0
	var units: Array[RtsUnit] = world.units()
	for unit: RtsUnit in units:
		var nearest: float = INF
		for other: RtsUnit in units:
			nearest = minf(nearest, INF if other == unit else unit.position.distance_to(other.position))
		total += nearest
	return total / units.size()



# How far the units reach, from the westmost to the eastmost and from the
# northmost to the southmost: along their way and across it, here.
static func _extent(world: RtsWorld) -> Vector2:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for unit: RtsUnit in world.units():
		low = low.min(unit.position)
		high = high.max(unit.position)
	return high - low
