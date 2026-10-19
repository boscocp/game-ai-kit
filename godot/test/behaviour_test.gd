# T15: `ai_behaviour`'s four ways to decide, and the guard written in each.
# The engines first, each held to the claim its header makes; then the guard:
# a board where all four must agree, and one where they are documented to
# differ -- if they could never disagree, the comparison would teach nothing.
extends GdUnitTestSuite

## GOAP's worlds / the HTN's, for `_situations` in order: on the round,
## setting out to look, looking, and the chase. What `WaysToDecide` reports.
const MEASURED: Array[String] = ["2/2", "3/3", "2/2", "3/3"]


func test_a_state_machine_takes_the_first_arrow_that_holds_and_only_one() -> void:
	var machine := StateMachine.new("a")
	machine.add_arrow("a", "b", func(facts: Dictionary) -> bool: return facts["go"], "first")
	machine.add_arrow("a", "c", func(facts: Dictionary) -> bool: return facts["go"], "second")
	machine.add_arrow("b", "c", func(facts: Dictionary) -> bool: return facts["go"], "onwards")

	assert_str(machine.update({"go": false})).is_equal("a")
	assert_str(machine.update({"go": true})).is_equal("b")
	assert_str(machine.last_change).is_equal("a -> b: first")
	assert_array(machine.states()).is_equal(["a", "b", "c"])


func test_a_sequence_stops_at_the_first_failure_and_a_selector_at_the_first_success() -> void:
	var asked: Array[String] = []
	var answer: Callable = func(name: String, status: BehaviourTree.Status) -> BehaviourTree.Action:
		return BehaviourTree.Action.new(name, func(_facts: Dictionary) -> BehaviourTree.Status:
			asked.append(name)
			return status)
	var tree := BehaviourTree.new(BehaviourTree.Selector.new("or", [
		BehaviourTree.Sequence.new("and", [answer.call("one", BehaviourTree.Status.SUCCESS),
			answer.call("two", BehaviourTree.Status.FAILURE), answer.call("never", BehaviourTree.Status.SUCCESS)] as Array[BehaviourTree.TreeNode]),
		answer.call("three", BehaviourTree.Status.RUNNING),
		answer.call("not either", BehaviourTree.Status.SUCCESS),
	] as Array[BehaviourTree.TreeNode]))

	assert_int(tree.tick({})).is_equal(BehaviourTree.Status.RUNNING)
	assert_array(asked).is_equal(["one", "two", "three"])
	assert_array(tree.trail).is_equal(["one: success", "two: failure", "three: running"])


func test_goap_finds_the_cheapest_plan_and_not_the_shortest() -> void:
	var actions: Array[GoapAction] = [
		GoapAction.new("dear shortcut", 5, {}, {"done": true}),
		GoapAction.new("prepare", 1, {}, {"ready": true}),
		GoapAction.new("cheap way", 1, {"ready": true}, {"done": true}),
	]
	var found: BehaviourPlan = GoapPlanner.new().plan(actions, {}, {"done": true})

	assert_bool(found.solved).is_true()
	assert_array(found.steps).is_equal(["prepare", "cheap way"])


func test_goap_says_there_is_no_plan_and_does_not_call_it_running_out() -> void:
	var actions: Array[GoapAction] = [GoapAction.new("needs magic", 1, {"magic": true}, {"done": true})]
	var found: BehaviourPlan = GoapPlanner.new().plan(actions, {}, {"done": true})

	assert_bool(found.solved).is_false()
	assert_bool(found.gave_up).is_false()


func test_goap_never_undoes_what_the_goal_wants() -> void:
	var actions: Array[GoapAction] = [
		GoapAction.new("spoil", 1, {}, {"done": true, "clean": false}),
		GoapAction.new("tidy finish", 3, {}, {"done": true}),
	]
	var found: BehaviourPlan = GoapPlanner.new().plan(actions, {"clean": true}, {"done": true, "clean": true})

	assert_array(found.steps).is_equal(["tidy finish"])


func test_an_htn_tries_the_next_method_when_a_branch_cannot_be_done() -> void:
	var domain := HtnDomain.new()
	domain.add_primitive("open the door", {"has_key": true}, {"inside": true})
	domain.add_primitive("climb in", {}, {"inside": true})
	domain.add_method("get in", "by the door", {}, ["open the door"] as Array[String])
	domain.add_method("get in", "by the window", {}, ["climb in"] as Array[String])
	var found: BehaviourPlan = HtnPlanner.new().plan(domain, {}, "get in")

	assert_bool(found.solved).is_true()
	assert_array(found.steps).is_equal(["climb in"])
	assert_array(found.methods).is_equal(["get in: by the window"])


func test_an_htn_that_runs_out_of_budget_says_so() -> void:
	var domain := HtnDomain.new()
	domain.add_method("forever", "again", {}, ["forever"] as Array[String])
	var found: BehaviourPlan = HtnPlanner.new().plan(domain, {}, "forever", 50)

	assert_bool(found.solved).is_false()
	assert_bool(found.gave_up).is_true()


func test_every_brain_is_a_decision_policy_and_only_ever_makes_legal_moves() -> void:
	for brain: GuardBrain in _brains():
		var world := BehaviourWorld.new(brain)
		assert_bool(brain is DecisionPolicy).is_true()
		var turns: int = 0
		while turns < 80 and not world.caught:
			world.step()
			turns += 1
			assert_str(world.last_board.why_refused(world.last_move)).is_equal(BoardState.LEGAL)


func test_a_calm_guard_on_its_round_walks_the_same_step_whatever_its_brain() -> void:
	var moves: Array[String] = []
	for brain: GuardBrain in _brains():
		var world := BehaviourWorld.new(brain)
		var move: Move = brain.choose(world.board(), BehaviourWorld.GUARD_ID)
		moves.append("%s %s" % [brain.deed, move.path])

	assert_array(moves).contains_same_exactly([moves[0], moves[0], moves[0], moves[0]])
	assert_str(moves[0]).starts_with(GuardBrain.WALK_ROUND)


func test_as_suspicion_fades_mid_search_the_machine_and_the_htn_carry_on_and_the_others_turn_back() -> void:
	var deeds: Dictionary = {}
	for brain: GuardBrain in _brains():
		var world := BehaviourWorld.new(brain)
		world.senses.last_known = Vector2i(5, 7)
		# Suspicious enough to go and look -- each brain sets out...
		world.senses.suspicion.level = 50.0
		brain.choose(world.board(), BehaviourWorld.GUARD_ID)
		brain.choose(world.board(), BehaviourWorld.GUARD_ID)
		# ...then it fades below going-to-look, and above giving up.
		world.senses.suspicion.level = 30.0
		brain.choose(world.board(), BehaviourWorld.GUARD_ID)
		deeds[brain.brain_name()] = brain.deed

	assert_dict(deeds).is_equal({
		"state machine": GuardBrain.GO_TO_LAST_KNOWN, "HTN": GuardBrain.GO_TO_LAST_KNOWN,
		"behaviour tree": GuardBrain.WALK_ROUND, "GOAP": GuardBrain.WALK_ROUND,
	})


func test_goap_and_htn_plan_the_guard_in_the_worlds_the_addon_header_reports() -> void:
	var counts: Array[String] = []
	for facts: Dictionary in _situations():
		var backwards: BehaviourPlan = GoapPlanner.new().plan(GuardActions.goap(), facts, GuardActions.goal(facts))
		var forwards: BehaviourPlan = HtnPlanner.new().plan(GuardActions.htn(), facts, "guard")
		assert_array(forwards.steps).is_equal(backwards.steps)
		counts.append("%d/%d" % [backwards.visited, forwards.visited])

	assert_array(counts).is_equal(MEASURED)



# The facts of the benchmark's four moments in the guard's evening.
static func _situations() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for moment: Array in load("res://test/behaviour_benchmark.gd").moments():
		found.append(moment[1])
	return found


static func _brains() -> Array[GuardBrain]:
	return [GuardFsm.new(), GuardTree.new(), GuardGoap.new(), GuardHtn.new()]
