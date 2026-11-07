# The flocking demo's world, flown headless: the grid finds what the slow
# search finds, two runs from one seed agree, and each switch does what its
# key says. Whether a flock appears on screen is the manual check's.
extends GdUnitTestSuite


func test_the_grid_finds_exactly_the_neighbours_the_naive_search_finds() -> void:
	var world := FlockWorld.new()
	for _step: int in range(30):
		world.step()
	var points := PackedVector2Array()
	for boid: SteeringVehicle in world.boids:
		points.append(boid.position)
	var grid := NeighbourGrid.new(FlockWorld.SIGHT)
	grid.fill(points)
	var counted: int = 0
	for index: int in range(points.size()):
		var expected: PackedInt32Array = NeighbourGrid.near_naively(points, index, FlockWorld.SIGHT)
		assert_array(Array(grid.near(points, index, FlockWorld.SIGHT))).is_equal(Array(expected))
		counted += expected.size()
	# A comparison of empty lists would pass on any grid.
	assert_int(counted).is_greater(FlockWorld.BOIDS)


func test_a_grid_whose_cells_are_too_small_is_caught_missing_neighbours() -> void:
	# The planted case for the test above: cells a fifth of the sight miss
	# the neighbours two cells away, and the comparison has to see it.
	var points := PackedVector2Array([Vector2(0, 0), Vector2(30, 0)])
	var grid := NeighbourGrid.new(FlockWorld.SIGHT / 5.0)
	grid.fill(points)
	assert_array(Array(grid.near(points, 0, FlockWorld.SIGHT))).is_not_equal(
		Array(NeighbourGrid.near_naively(points, 0, FlockWorld.SIGHT)))


func test_two_runs_from_one_seed_agree_to_the_last_bit() -> void:
	var first := FlockWorld.new()
	var second := FlockWorld.new()
	for _step: int in range(120):
		first.step()
		second.step()
	for index: int in range(FlockWorld.BOIDS):
		assert_vector(first.boids[index].position).is_equal(second.boids[index].position)
	assert_bool(first.boids[0].position != FlockWorld.new().boids[0].position).is_true()


func test_a_rule_switched_off_weighs_nothing_in_the_sum() -> void:
	var world := FlockWorld.new()
	world.toggle(Flock.Rule.COHESION)
	assert_float(world.weights_now()[Flock.Rule.COHESION]).is_equal(0.0)
	world.toggle(Flock.Rule.COHESION)
	assert_float(world.weights_now()[Flock.Rule.COHESION]).is_equal(1.0)


func test_without_separation_the_flock_packs_tighter() -> void:
	var apart := FlockWorld.new()
	var packed := FlockWorld.new()
	packed.toggle(Flock.Rule.SEPARATION)
	for _step: int in range(600):
		apart.step()
		packed.step()
	assert_float(_nearest_on_average(packed)).is_less(_nearest_on_average(apart) / 2.0)


func test_the_watched_boid_reports_what_it_counted_and_its_forces() -> void:
	var world := FlockWorld.new()
	world.step()
	assert_bool(world.counted.is_empty()).is_false()
	for rule: int in range(3):
		assert_float(world.forces[rule].length()).is_less_equal(FlockWorld.MAX_FORCE * (1.0 + 1e-5))
	world.watch_next()
	assert_int(world.watched).is_equal(1)


# How far, on average, each boid is from its nearest other.
func _nearest_on_average(world: FlockWorld) -> float:
	var points := PackedVector2Array()
	for boid: SteeringVehicle in world.boids:
		points.append(boid.position)
	var total: float = 0.0
	for index: int in range(points.size()):
		var others: PackedVector2Array = points.duplicate()
		others.remove_at(index)
		total += Array(others).map(func(other: Vector2) -> float: return other.distance_to(points[index])).min()
	return total / points.size()
