# The planning conformance runner is a gate, and a gate is only as good as the
# cases it rejects. Every rule in `PlanningVector` has one here, so deleting the
# rule turns this suite red rather than leaving the repository green -- which is
# what happened on the search side, where three of the runner's rules were
# deleted one at a time and nothing noticed.
extends GdUnitTestSuite


func test_a_good_vector_is_accepted() -> void:
	assert_str(PlanningVector.why_not_a_vector(_good())).is_equal("")


func test_a_dictionary_that_is_not_a_vector_is_named_rather_than_crashing() -> void:
	assert_str(PlanningVector.why_not_a_vector({"hello": 1})).contains("no `actions`")


func test_an_action_missing_one_of_its_three_lists_is_refused() -> void:
	# The list a reader forgets is `deletes`, and a domain without it plans a
	# world where nothing is ever spent.
	var careless: Dictionary = _good()
	careless["actions"] = [{"name": "step_one", "preconditions": ["a"], "adds": ["b"]}]

	assert_str(PlanningVector.why_not_a_vector(careless)).contains("has no `deletes`")


func test_an_action_that_is_not_a_dictionary_is_refused() -> void:
	var wrong: Dictionary = _good()
	wrong["actions"] = ["step_one"]

	assert_str(PlanningVector.why_not_a_vector(wrong)).contains("action 0 is not a dictionary")


func test_a_predicate_list_holding_something_else_is_refused() -> void:
	var wrong: Dictionary = _good()
	wrong["init"] = [7]

	assert_str(PlanningVector.why_not_a_vector(wrong)).contains("not a predicate name")


func test_an_empty_goal_is_refused_because_every_state_satisfies_it() -> void:
	var pointless: Dictionary = _good()
	pointless["goal"] = []

	assert_str(PlanningVector.why_not_a_vector(pointless)).contains("every state satisfies")


func test_a_claimed_plan_with_no_step_count_is_refused() -> void:
	# It would pass against a planner returning any plan at all, however long.
	var vague: Dictionary = _good()
	vague["expect"] = {"solved": true}

	assert_str(PlanningVector.why_not_a_vector(vague)).contains("no `steps` to pin it to")


func test_a_step_count_on_a_vector_with_no_plan_is_refused() -> void:
	var confused: Dictionary = _good()
	confused["expect"] = {"solved": false, "steps": 2}

	assert_str(PlanningVector.why_not_a_vector(confused)).contains("no plan to have `steps`")


func test_a_vector_naming_a_pddl_file_that_is_not_there_is_refused() -> void:
	# The Python half of the run reads those two files. A vector naming one
	# that does not exist halves the conformance check in silence.
	assert_str(PlanningVector.why_files_are_missing("res://test", _good())).contains(
		"which is not beside the vector"
	)


func test_a_vector_whose_pddl_files_are_there_is_accepted() -> void:
	var directory: String = "user://planning_vector_test"
	DirAccess.make_dir_recursive_absolute(directory)
	for name: String in ["beside-domain.pddl", "beside-problem.pddl"]:
		FileAccess.open(directory + "/" + name, FileAccess.WRITE).store_string("; here\n")
	var beside: Dictionary = _good()
	beside["domain"] = "beside-domain.pddl"
	beside["problem"] = "beside-problem.pddl"

	assert_str(PlanningVector.why_files_are_missing(directory, beside)).is_equal("")


func test_a_vector_whose_step_count_is_wrong_is_reported() -> void:
	var lying: Dictionary = _good()
	lying["expect"] = {"solved": true, "steps": 99}

	var problems: Array[String] = PlanningVector.check("lying", lying, StripsPlanner.new())

	assert_int(problems.size()).is_equal(1)
	assert_str(problems[0]).contains("the fewest is 99")


func test_a_vector_claiming_the_wrong_solvability_is_reported() -> void:
	var lying: Dictionary = _good()
	lying["expect"] = {"solved": false}

	var problems: Array[String] = PlanningVector.check("lying", lying, StripsPlanner.new())

	assert_int(problems.size()).is_equal(1)
	assert_str(problems[0]).contains("solved=true, expected false")


func test_a_plan_whose_first_step_cannot_run_is_reported() -> void:
	# The planner says it solved it, the step count agrees, and the plan cannot
	# be executed. Reading `solved` and stopping would pass this.
	var problems: Array[String] = PlanningVector.check(
		"liar", _good(), ClaimsAPlanItCannotRun.new()
	)

	assert_int(problems.size()).is_equal(1)
	assert_str(problems[0]).contains("cannot run where the plan puts it")


func test_a_domain_field_that_is_not_a_pddl_file_is_refused() -> void:
	var wrong: Dictionary = _good()
	wrong["domain"] = "two-steps.json"

	assert_str(PlanningVector.why_not_a_vector(wrong)).contains("does not name a .pddl file")


func test_a_vector_with_no_actions_is_refused() -> void:
	# `{}` compares equal to `{}`, so a vector with an empty domain is the
	# shape of a check that passes while measuring nothing.
	var empty: Dictionary = _good()
	empty["actions"] = []

	assert_str(PlanningVector.why_not_a_vector(empty)).contains("non-empty array")


func test_an_expect_that_is_not_a_dictionary_is_refused() -> void:
	var wrong: Dictionary = _good()
	wrong["expect"] = "solved"

	assert_str(PlanningVector.why_not_a_vector(wrong)).contains("`expect` is not a dictionary")


func test_an_action_with_no_name_is_refused() -> void:
	var nameless: Dictionary = _good()
	nameless["actions"] = [{"name": "", "preconditions": [], "deletes": [], "adds": ["b"]}]

	assert_str(PlanningVector.why_not_a_vector(nameless)).contains("has no name")


func test_a_solved_field_that_is_not_a_bool_is_refused() -> void:
	# `"solved": "true"` is a string, and every string is truthy.
	var stringly: Dictionary = _good()
	stringly["expect"] = {"solved": "true", "steps": 2}

	assert_str(PlanningVector.why_not_a_vector(stringly)).contains("no `solved`")


func test_a_negative_step_count_is_refused() -> void:
	var impossible: Dictionary = _good()
	impossible["expect"] = {"solved": true, "steps": -1}

	assert_str(PlanningVector.why_not_a_vector(impossible)).contains("negative")


func test_a_planner_reporting_no_plan_but_returning_steps_is_caught() -> void:
	var problems: Array[String] = PlanningVector.check(
		"muddled", _unsolvable(), SaysThereIsNoPlanAndReturnsOne.new()
	)

	assert_int(problems.size()).is_equal(1)
	assert_str(problems[0]).contains("no plan, but 1 steps came back")


func test_a_planner_giving_up_on_a_vector_this_size_is_caught() -> void:
	# "I did not find one" is not the answer a vector of two actions asks for,
	# and accepting it would let a planner pass by being too slow to look.
	var problems: Array[String] = PlanningVector.check(
		"timid", _unsolvable(), GivesUpImmediately.new()
	)

	assert_int(problems.size()).is_equal(1)
	assert_str(problems[0]).contains("gave up after")


func test_a_plan_that_runs_but_never_reaches_the_goal_is_caught() -> void:
	# Every step is applicable and the step count is what the vector asks for.
	# Only replaying the plan to its end catches this one.
	var stops_short: Dictionary = _good()
	stops_short["expect"] = {"solved": true, "steps": 1}

	var problems: Array[String] = PlanningVector.check(
		"halfway", stops_short, StopsOneStepShort.new()
	)

	assert_int(problems.size()).is_equal(1)
	assert_str(problems[0]).contains("the goal does not hold")


func test_a_good_vector_reports_nothing() -> void:
	assert_int(PlanningVector.check("good", _good(), StripsPlanner.new()).size()).is_equal(0)


# A planner that hands back the right number of steps in the wrong order. Every
# other claim it makes is true; only replaying the plan catches it.
class ClaimsAPlanItCannotRun extends StripsPlanner:
	func plan(actions: Array[StripsAction], _start: WorldState,
			_goal: PackedStringArray, _budget: int = DEFAULT_BUDGET) -> PlanResult:
		var backwards: Array[StripsAction] = [actions[1], actions[0]]
		return PlanResult.new(backwards, true, 2, false)


# A planner that says there is no plan and hands one over anyway.
class SaysThereIsNoPlanAndReturnsOne extends StripsPlanner:
	func plan(actions: Array[StripsAction], _start: WorldState,
			_goal: PackedStringArray, _budget: int = DEFAULT_BUDGET) -> PlanResult:
		return PlanResult.new([actions[0]], false, 1, false)


# A planner that stops at its budget on a domain of two actions.
class GivesUpImmediately extends StripsPlanner:
	func plan(_actions: Array[StripsAction], _start: WorldState,
			_goal: PackedStringArray, _budget: int = DEFAULT_BUDGET) -> PlanResult:
		return PlanResult.ran_out(1)


# A planner whose plan runs perfectly and arrives somewhere else.
class StopsOneStepShort extends StripsPlanner:
	func plan(actions: Array[StripsAction], _start: WorldState,
			_goal: PackedStringArray, _budget: int = DEFAULT_BUDGET) -> PlanResult:
		return PlanResult.new([actions[0]], true, 1, false)


# The same vector, claiming there is no plan -- which is what the rules about a
# planner's empty answer need in order to be reached at all.
func _unsolvable() -> Dictionary:
	var vector: Dictionary = _good()
	vector["expect"] = {"solved": false}
	return vector


# Two steps, in order: `a` is true, `step_one` makes `b` true, `step_two` makes
# `c` true, and `c` is the goal.
func _good() -> Dictionary:
	return {
		"name": "two steps",
		"domain": "two-steps-domain.pddl",
		"problem": "two-steps-problem.pddl",
		"actions": [
			{"name": "step_one", "preconditions": ["a"], "deletes": [], "adds": ["b"]},
			{"name": "step_two", "preconditions": ["b"], "deletes": [], "adds": ["c"]},
		],
		"init": ["a"],
		"goal": ["c"],
		"expect": {"solved": true, "steps": 2},
	}
