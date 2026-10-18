# T11's planner: bits, two heuristics and a budget (ADR 0010). Each case is a
# claim one of `PackedDomain`, `RelaxedCost` or `HeuristicPlanner` makes in its
# header, held against a case that fails when the claim does.
extends GdUnitTestSuite

const BFS: HeuristicPlanner.Guide = HeuristicPlanner.Guide.BREADTH_FIRST
const H_MAX: HeuristicPlanner.Guide = HeuristicPlanner.Guide.H_MAX
const H_ADD: HeuristicPlanner.Guide = HeuristicPlanner.Guide.H_ADD


func test_a_world_packed_and_unpacked_holds_what_it_held() -> void:
	var domain := PackedDomain.new(GameDomain.actions(), GameDomain.opening_world(), GameDomain.goal())
	var world := WorldState.new(["node_held", "barracks_built"])

	assert_str(domain.world_of(domain.state_of(world)).key()).is_equal(world.key())


func test_packed_deletes_run_before_adds_as_strips_says() -> void:
	var relight := StripsAction.new("relight", ["lit"], ["lit"], ["lit"])
	var domain := PackedDomain.new([relight] as Array[StripsAction])
	var lit: int = domain.mask_of(["lit"])

	assert_int(domain.after(0, lit)).is_equal(lit)


func test_a_domain_too_big_for_an_int_says_so_and_does_not_claim_impossible() -> void:
	var names := PackedStringArray()
	for index: int in range(PackedDomain.MOST_PREDICATES + 1):
		names.append("p%d" % index)
	var everything := StripsAction.new("everything", [], [], names)
	# Held in an array: a closure cannot assign to a variable outside it.
	var results: Array[PlanResult] = []

	await assert_error(func() -> void:
		results.append(HeuristicPlanner.new().plan([everything] as Array[StripsAction], WorldState.new(), ["p0"]))
	).is_push_error(any_string())

	var result: PlanResult = results[0]
	assert_bool(result.solved).is_false()
	assert_bool(result.gave_up).is_true()


func test_every_search_plans_the_game_domain_as_long_as_strips_planner_does() -> void:
	var shortest: int = StripsPlanner.new().plan(GameDomain.actions(), GameDomain.opening_world(), GameDomain.goal()).steps.size()

	for guide: HeuristicPlanner.Guide in [BFS, H_MAX]:
		assert_int(_plan_game(guide).steps.size()).is_equal(shortest)


func test_the_guesses_visit_fewer_worlds_than_breadth_first_on_the_game_domain() -> void:
	# 14, 12 and 9 when this was written.
	assert_int(_plan_game(H_MAX).visited).is_less(_plan_game(BFS).visited)
	assert_int(_plan_game(H_ADD).visited).is_less(_plan_game(H_MAX).visited)


func test_h_max_keeps_the_plan_shortest_where_h_add_does_not() -> void:
	# Found by a throwaway search over 20000 random domains (not committed):
	# 28 had a longer h_add plan, and this is the first. The generator `planner_properties.gd` uses never makes
	# one, so without this case h_max could be h_add and every gate stayed
	# green -- which a planted mutation showed.
	var actions: Array[StripsAction] = _where_h_add_wanders()
	var start := WorldState.new(["p7"])

	assert_int(HeuristicPlanner.new().plan(actions, start, ["p2", "p5"], BFS).steps.size()).is_equal(5)
	assert_int(HeuristicPlanner.new().plan(actions, start, ["p2", "p5"], H_MAX).steps.size()).is_equal(5)
	assert_int(HeuristicPlanner.new().plan(actions, start, ["p2", "p5"], H_ADD).steps.size()).is_equal(6)


func test_h_max_never_guesses_more_than_the_shortest_plan_from_any_world_it_plans() -> void:
	# Admissible, measured directly: from each world on the way of the shortest
	# plan, the guess is at most the steps still to take.
	var actions: Array[StripsAction] = _where_h_add_wanders()
	var start := WorldState.new(["p7"])
	var domain := PackedDomain.new(actions, start, ["p2", "p5"])
	var plan: PlanResult = HeuristicPlanner.new().plan(actions, start, ["p2", "p5"], BFS)
	var world: WorldState = start

	for index: int in range(plan.steps.size()):
		var guess: int = RelaxedCost.estimate(domain, domain.state_of(world), domain.bits_of(["p2", "p5"]), RelaxedCost.Combine.MAX)
		assert_int(guess).is_less_equal(plan.steps.size() - index)
		world = plan.steps[index].apply(world)


func test_a_goal_the_relaxation_cannot_reach_is_impossible_without_a_search() -> void:
	var result: PlanResult = HeuristicPlanner.new().plan(GameDomain.actions(), GameDomain.opening_world(), ["nobody_adds_this"], H_MAX)

	assert_bool(result.solved).is_false()
	assert_bool(result.gave_up).is_false()
	assert_int(result.visited).is_equal(0)


func test_a_budget_reached_returns_a_partial_plan_that_runs() -> void:
	var result: PlanResult = HeuristicPlanner.new().plan(GameDomain.actions(), GameDomain.opening_world(), GameDomain.goal(), H_ADD, 3)
	var world: WorldState = GameDomain.opening_world()

	assert_bool(result.solved).is_false()
	assert_bool(result.gave_up).is_true()
	assert_bool(result.partial).is_true()
	assert_int(result.visited).is_less_equal(3)
	for step: StripsAction in result.steps:
		assert_bool(step.is_applicable(world)).is_true()
		world = step.apply(world)


func test_breadth_first_has_no_partial_plan_to_give() -> void:
	var result: PlanResult = HeuristicPlanner.new().plan(GameDomain.actions(), GameDomain.opening_world(), GameDomain.goal(), BFS, 3)

	assert_bool(result.gave_up).is_true()
	assert_bool(result.partial).is_false()
	assert_array(result.steps).is_empty()


func _plan_game(guide: HeuristicPlanner.Guide) -> PlanResult:
	return HeuristicPlanner.new().plan(GameDomain.actions(), GameDomain.opening_world(), GameDomain.goal(), guide)


func _where_h_add_wanders() -> Array[StripsAction]:
	return [
		StripsAction.new("a0", ["p2"], [], ["p0"]),
		StripsAction.new("a1", ["p3", "p2"], [], ["p5", "p6"]),
		StripsAction.new("a2", ["p2"], ["p2"], ["p4", "p6"]),
		StripsAction.new("a3", ["p1", "p2"], ["p1"], ["p1"]),
		StripsAction.new("a4", ["p7"], [], ["p5"]),
		StripsAction.new("a5", ["p3", "p7"], ["p3"], ["p0", "p1"]),
		StripsAction.new("a6", ["p0"], [], ["p6"]),
		StripsAction.new("a7", ["p1", "p0"], [], ["p6", "p0"]),
		StripsAction.new("a8", ["p6", "p0"], [], ["p5", "p2"]),
		StripsAction.new("a9", ["p5"], ["p5"], ["p3"]),
	]
