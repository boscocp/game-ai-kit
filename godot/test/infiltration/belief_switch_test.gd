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
	assert_float(InfiltrationWorld.searched_from(world, guard)[5]).is_equal(1.0)


func test_a_sighting_collapses_both_beliefs() -> void:
	var guard: InfiltrationGuard = _world().guard(0)
	guard.collapse_belief(7)
	assert_float(guard.belief.shares[7]).is_equal(1.0)
	assert_float(guard.particles.shares[7]).is_equal(1.0)


func test_the_panel_names_the_belief() -> void:
	var rules := InfiltrationRules.read()
	TranslationServer.set_locale("en")
	assert_str(InfiltrationText.belief_word(rules)).is_equal("grid")
	rules.use_particles = true
	assert_str(InfiltrationText.belief_word(rules)).is_equal("particles")
