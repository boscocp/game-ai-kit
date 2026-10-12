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


func test_a_good_vector_reports_nothing() -> void:
	assert_int(PlanningVector.check("good", _good(), StripsPlanner.new()).size()).is_equal(0)


# A planner that hands back the right number of steps in the wrong order. Every
# other claim it makes is true; only replaying the plan catches it.
class ClaimsAPlanItCannotRun extends StripsPlanner:
	func plan(actions: Array[StripsAction], _start: WorldState,
			_goal: PackedStringArray, _budget: int = DEFAULT_BUDGET) -> PlanResult:
		var backwards: Array[StripsAction] = [actions[1], actions[0]]
		return PlanResult.new(backwards, true, 2, false)


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
