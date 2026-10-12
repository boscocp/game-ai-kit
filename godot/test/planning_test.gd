# What STRIPS promises, and the one place the game's domain earns a planner.
#
# The planner is four small types and almost all of the risk is in two of them:
# a state that is not really immutable, and a frontier that cannot tell two
# worlds apart. Both are tested here against cases that fail loudly rather than
# by inspecting the happy path.
extends GdUnitTestSuite


func test_an_empty_state_holds_nothing_but_satisfies_an_empty_goal() -> void:
	var nothing := WorldState.new()

	assert_bool(nothing.holds("anything")).is_false()
	assert_bool(nothing.holds_all(PackedStringArray())).is_true()


func test_the_state_an_action_ran_on_is_not_changed() -> void:
	# The whole reason a planner can hold thousands of these at once.
	var before := WorldState.new(["standing"])
	var action := StripsAction.new("sit", ["standing"], ["standing"], ["sitting"])

	var after: WorldState = action.apply(before)

	assert_bool(before.holds("standing")).is_true()
	assert_bool(before.holds("sitting")).is_false()
	assert_bool(after.holds("sitting")).is_true()
	assert_bool(after.holds("standing")).is_false()


func test_a_predicate_in_both_lists_survives_the_action() -> void:
	# Deletes run first and adds run second. The other order drops the
	# predicate, and a domain that writes "this is still true afterwards" this
	# way would be quietly wrong.
	var before := WorldState.new(["lit"])
	var action := StripsAction.new("relight", ["lit"], ["lit"], ["lit"])

	assert_bool(action.apply(before).holds("lit")).is_true()


func test_two_states_holding_the_same_things_share_one_key() -> void:
	# Order of construction must not matter, or the frontier sees two worlds
	# where there is one and plans in a circle.
	var one := WorldState.new(["a_thing", "another_thing"])
	var other := WorldState.new(["another_thing", "a_thing"])

	assert_str(one.key()).is_equal(other.key())


func test_an_action_whose_preconditions_are_unmet_is_not_applicable() -> void:
	var action := StripsAction.new("fire", ["loaded"], ["loaded"], ["fired"])

	assert_bool(action.is_applicable(WorldState.new())).is_false()
	assert_bool(action.is_applicable(WorldState.new(["loaded"]))).is_true()


func test_the_planner_returns_the_fewest_actions_not_the_first_route_it_finds() -> void:
	# The only claim breadth-first makes, and it was unpinned: the first
	# version of this test forked at the *start*, where the goal is generated
	# during the very first expansion whatever order the frontier is read in.
	# A review turned the queue into a stack and all 118 tests, 400 property
	# trials and 3 vectors stayed green.
	#
	# This domain forks one level down and declares the long branch last, which
	# is the shape that tells the two apart: a stack walks into the annex and
	# answers with four actions where three exist.
	var result: PlanResult = StripsPlanner.new().plan(
		_a_fork_one_level_down(), WorldState.new(["at_start"]),
		PackedStringArray(["arrived"])
	)

	assert_bool(result.solved).is_true()
	assert_array(result.action_names()).is_equal(PackedStringArray([
		"open_the_door", "the_short_way_one", "the_short_way_two",
	]))


func test_a_world_reached_twice_is_not_planned_through_twice() -> void:
	# Without the visited set the planner walks in a circle on any domain where
	# an action can be undone -- and spends its whole budget doing it, which it
	# would then have to report as "I gave up" on a domain of four states. The
	# claim this suite makes about the frontier was, before this test, made by
	# nothing in it: deleting the dedup left every case here green.
	# A small budget on purpose. Without the visited set this domain burns the
	# default one, and the failing run took 24 seconds -- a red gate nobody
	# wants to wait for is a red gate somebody switches off.
	var result: PlanResult = StripsPlanner.new().plan(
		_a_door_that_opens_and_shuts(), WorldState.new(["shut"]),
		PackedStringArray(["somewhere_else_entirely"]), 50
	)

	assert_bool(result.solved).is_false()
	assert_bool(result.gave_up).is_false()
	assert_int(result.visited).is_less_equal(2)


func test_a_goal_that_already_holds_is_an_empty_plan_that_is_still_solved() -> void:
	# The empty plan with two meanings. Without `solved` this is indistinguishable
	# from "there is no plan".
	var result: PlanResult = StripsPlanner.new().plan(
		GameDomain.actions(), WorldState.new([GameDomain.ENEMY_BEATEN]), GameDomain.goal()
	)

	assert_bool(result.solved).is_true()
	assert_int(result.steps.size()).is_equal(0)
	assert_bool(result.gave_up).is_false()


func test_an_unreachable_goal_is_impossible_rather_than_a_budget_running_out() -> void:
	var result: PlanResult = StripsPlanner.new().plan(
		GameDomain.actions(), WorldState.new(), GameDomain.goal()
	)

	assert_bool(result.solved).is_false()
	assert_bool(result.gave_up).is_false()
	assert_int(result.steps.size()).is_equal(0)


func test_a_budget_reached_says_so_rather_than_claiming_there_is_no_plan() -> void:
	# There is a plan; this planner was not allowed to look far enough. Saying
	# "impossible" here would be a claim the run never made.
	var result: PlanResult = StripsPlanner.new().plan(
		GameDomain.actions(), GameDomain.opening_world(), GameDomain.goal(), 3
	)

	assert_bool(result.solved).is_false()
	assert_bool(result.gave_up).is_true()
	assert_int(result.visited).is_equal(3)


func test_the_game_plan_runs_from_the_opening_world_step_by_step() -> void:
	var result: PlanResult = StripsPlanner.new().plan(
		GameDomain.actions(), GameDomain.opening_world(), GameDomain.goal()
	)
	var world: WorldState = GameDomain.opening_world()

	for action: StripsAction in result.steps:
		assert_bool(action.is_applicable(world)).override_failure_message(
			"%s could not run where the plan puts it" % action.name
		).is_true()
		world = action.apply(world)

	assert_bool(world.holds_all(GameDomain.goal())).is_true()


func test_the_game_domain_has_to_mine_twice_to_pay_for_both_things() -> void:
	# The lesson the domain exists for: the barracks and the unit are paid for
	# out of one bank, so the chain is longer than any reactive rule would
	# produce, and it is the delete lists that say so.
	var result: PlanResult = StripsPlanner.new().plan(
		GameDomain.actions(), GameDomain.opening_world(), GameDomain.goal()
	)
	var names: PackedStringArray = result.action_names()
	var minings: int = 0
	for name: String in names:
		if name == "mine_the_node":
			minings += 1

	assert_int(minings).is_equal(2)
	assert_str(names[names.size() - 1]).is_equal("attack")


func test_the_planner_does_not_change_the_world_it_was_handed() -> void:
	var start: WorldState = GameDomain.opening_world()

	StripsPlanner.new().plan(GameDomain.actions(), start, GameDomain.goal())

	assert_array(start.predicates()).is_equal(
		PackedStringArray([GameDomain.ARMY_IN_RESERVE])
	)


# One door, then a fork: two steps by the stairs, three through the annex.
#
# The fork is deliberately *not* at the start. The goal is tested on each world
# as it is generated, so a domain that forks at the start reaches the goal
# during the first expansion whichever end of the frontier is read -- which is
# why the test this replaces could not fail.
#
# The long branch is declared last, so a stack reaches it first and comes back
# with four actions where three exist.
func _a_fork_one_level_down() -> Array[StripsAction]:
	return [
		StripsAction.new("open_the_door", ["at_start"], ["at_start"], ["in_the_hall"]),
		StripsAction.new("the_short_way_one", ["in_the_hall"], [], ["by_the_stairs"]),
		StripsAction.new("the_short_way_two", ["by_the_stairs"], [], ["arrived"]),
		StripsAction.new("the_long_way_one", ["in_the_hall"], [], ["in_the_annex"]),
		StripsAction.new("the_long_way_two", ["in_the_annex"], [], ["on_the_roof"]),
		StripsAction.new("the_long_way_three", ["on_the_roof"], [], ["arrived"]),
	]


# A door that can be opened and shut again, and a goal neither state reaches.
# There are two worlds here and a planner without a visited set will visit them
# until its budget runs out.
func _a_door_that_opens_and_shuts() -> Array[StripsAction]:
	return [
		StripsAction.new("open_it", ["shut"], ["shut"], ["open"]),
		StripsAction.new("shut_it", ["open"], ["open"], ["shut"]),
	]
