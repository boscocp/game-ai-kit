# Key 1 cycles the guards' belief -- off, the grid, the particles (T91) --
# and a guard's search reads whichever is on.
extends GdUnitTestSuite


func _world() -> InfiltrationWorld:
	return InfiltrationWorld.make(InfiltrationRuns.levels()[0], InfiltrationRules.read(), 1)


func test_key_one_cycles_grid_particles_off() -> void:
	var rules := InfiltrationRules.read()
	assert_bool(rules.use_belief and not rules.use_particles).is_true()
	InfiltrationKeys.next_belief(rules)
	assert_bool(rules.use_belief and rules.use_particles).is_true()
	InfiltrationKeys.next_belief(rules)
	assert_bool(rules.use_belief or rules.use_particles).is_false()
	InfiltrationKeys.next_belief(rules)
	assert_bool(rules.use_belief and not rules.use_particles).is_true()


func test_the_search_reads_the_belief_that_is_on() -> void:
	var world: InfiltrationWorld = _world()
	var guard: InfiltrationGuard = world.guard(0)
	guard.belief.collapse(3)
	guard.particles.collapse(5)
	assert_float(InfiltrationWorld.searched_from(world, guard)[3]).is_equal(1.0)
	world.rules.use_particles = true
	assert_float(InfiltrationWorld.searched_from(world, guard)[5]).is_equal_approx(1.0, 1e-9)


func test_a_sighting_collapses_both_beliefs() -> void:
	var guard: InfiltrationGuard = _world().guard(0)
	guard.collapse_belief(7)
	assert_float(guard.belief.shares[7]).is_equal(1.0)
	assert_float(guard.particles.shares[7]).is_equal_approx(1.0, 1e-9)


func test_the_panel_names_the_belief() -> void:
	var rules := InfiltrationRules.read()
	TranslationServer.set_locale("en")
	assert_str(InfiltrationText.belief_word(rules)).is_equal("grid")
	rules.use_particles = true
	assert_str(InfiltrationText.belief_word(rules)).is_equal("particles")


# The level's first and last search spots, as walk cells: two places far
# enough apart that a spot near one is not near the other.
func _two_far_spots(world: InfiltrationWorld) -> Array[int]:
	var spots: Array[Dictionary] = world.team.search.spots
	return [int(spots[0]["cell"]), int(spots[spots.size() - 1]["cell"])]


func test_the_spot_is_weighed_from_the_belief_that_is_on() -> void:
	for use_particles: bool in [false, true]:
		var world: InfiltrationWorld = _world()
		world.rules.use_particles = use_particles
		var guard: InfiltrationGuard = world.guard(0)
		var cells: Array[int] = _two_far_spots(world)
		guard.particles.collapse(cells[0])
		guard.belief.collapse(cells[1])
		world.team.search.share(world, [guard] as Array[InfiltrationGuard])
		var wanted: Vector2 = BotArena.centre_of(world.level.cells[cells[0] if use_particles else cells[1]])
		assert_int(guard.spot).is_not_equal(-1)
		var place: Vector2 = world.team.search.spots[guard.spot]["place"]
		assert_float(place.distance_to(wanted)).is_less_equal(float(world.rules.search["spot_radius"]))


# A coordinator that gives no one a spot, so every searcher covers a way out.
static func _no_spots(_spots: Array[Dictionary], costs: Array[PackedFloat64Array], _claims: bool,
		_weights: SearchCoordinator.Weights) -> PackedInt32Array:
	var none := PackedInt32Array()
	none.resize(costs.size())
	none.fill(-1)
	return none


func test_the_way_out_is_found_from_the_belief_that_is_on() -> void:
	for use_particles: bool in [false, true]:
		var world: InfiltrationWorld = _world()
		world.rules.use_particles = use_particles
		world.coordinator = _no_spots
		var guard: InfiltrationGuard = world.guard(0)
		var cells: Array[int] = _two_far_spots(world)
		guard.particles.collapse(cells[0])
		guard.belief.collapse(cells[1])
		world.team.search.share(world, [guard] as Array[InfiltrationGuard])
		var wanted: Vector2 = BotArena.centre_of(world.level.cells[cells[0] if use_particles else cells[1]])
		assert_float(guard.way_out.distance_to(wanted)).is_less_equal(1.5)


func test_a_silent_guard_would_have_heard_a_creep_close_by() -> void:
	var world: InfiltrationWorld = _world()
	var guard: InfiltrationGuard = world.guard(0)
	var level: InfiltrationLevel = world.level
	var steps: PackedInt32Array = level.arena.steps_from([level.cell_of(guard.position)])
	var near: int = -1
	var far: int = -1
	for index: int in range(level.cells.size()):
		var walked: int = steps[level.cells[index].y * int(level.arena.width) + level.cells[index].x]
		if walked == 1:
			near = index
		elif walked > 4:
			far = index
	guard.percept.loudness = 0.0
	var heard_from: PackedInt32Array = InfiltrationSenses.would_hear(guard, world)
	assert_float(InfiltrationSenses.quietest_step(world)).is_equal(2.0)
	assert_bool(heard_from.has(near)).is_true()
	assert_bool(heard_from.has(far)).is_false()
	guard.percept.loudness = 0.5
	assert_int(InfiltrationSenses.would_hear(guard, world).size()).is_equal(0)
