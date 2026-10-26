# T15: `ai_behaviour`'s four ways to decide, and the guard written in each.
# The engines first, each held to the claim its header makes; then the guard:
# a board where all four must agree, and one where they are documented to
# differ -- if they could never disagree, the comparison would teach nothing.
extends GdUnitTestSuite

## GOAP's worlds / the HTN's, for `_situations` in order: on the round,
## setting out to look, looking, and the chase. What `WaysToDecide` reports.
const MEASURED: Array[String] = ["2/2", "3/3", "2/2", "3/3"]

var _locale_before: String = ""


# The demo's words are read in English unless a test says otherwise, whatever
# the machine's locale (T79).
func before() -> void:
	_locale_before = TranslationServer.get_locale()


func before_test() -> void:
	TranslationServer.set_locale("en")


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func test_the_words_the_demo_translates_are_the_addon_s_words() -> void:
	# `RIGHT_WHEN` and `TREE_ANSWERS` copy English the addon writes, so that
	# the demo's table can translate it; a change in the addon must show here,
	# or the screen would fall back to English without a word.
	# Asked by each brain's own name, as the status asks: a row the addon
	# renamed would leave the screen saying nothing, and a loop over the
	# addon's rows would not miss it.
	for brain: GuardBrain in _brains():
		var when: String = BehaviourDemo._when_right(brain.brain_name())
		assert_str(when).override_failure_message("%s: no row in WaysToDecide" % brain.brain_name()).is_not_empty()
		assert_array(BehaviourDemo.RIGHT_WHEN).contains([when])
	for answer: BehaviourTree.Status in [BehaviourTree.Status.SUCCESS, BehaviourTree.Status.FAILURE,
			BehaviourTree.Status.RUNNING]:
		assert_array(BrainPanel.TREE_ANSWERS).contains([BehaviourTree.said(answer)])


func test_the_panel_translates_each_name_and_keeps_the_notation() -> void:
	TranslationServer.set_locale("pt_BR")

	assert_str(BrainPanel.words("patrol -> suspicious: something is off")).is_equal(
		"ronda -> desconfiado: algo está estranho")
	assert_str(BrainPanel.words("go and look: running")).is_equal("ir olhar: em execução")
	assert_str(BrainPanel.words("guard: seize them")).is_equal("guarda: agarrar o intruso")
	assert_str(BrainPanel.words("walk_round")).is_equal("fazer a ronda")


func test_in_portuguese_the_status_stays_three_lines_for_every_brain() -> void:
	# The window has room under the board for three lines and no more, and a
	# Portuguese line is longer: one that wrapped would push the keys off.
	TranslationServer.set_locale("pt_BR")
	var demo: BehaviourDemo = auto_free(load("res://demos/behaviour/behaviour_demo.tscn").instantiate())
	add_child(demo)
	var status: Label = demo.get_node("Interface/Status")
	for brain: int in range(4):
		demo.swap_brain(brain)
		demo.step_decision()

		assert_str(status.text).contains("turno")
		assert_int(status.get_line_count()).override_failure_message(status.text).is_less_equal(3)


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
	assert_array(tree.trail).is_equal(["one: success", "two: failure", "and: failure", "three: running", "or: running"])


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


func test_an_htn_that_backs_out_of_a_method_takes_back_the_steps_it_had_made() -> void:
	var domain := HtnDomain.new()
	domain.add_primitive("step in", {}, {"in": true})
	domain.add_primitive("open the door", {"has_key": true}, {"through": true})
	domain.add_primitive("climb in", {}, {"through": true})
	domain.add_method("get in", "by the door", {}, ["step in", "open the door"] as Array[String])
	domain.add_method("get in", "by the window", {}, ["climb in"] as Array[String])
	var found: BehaviourPlan = HtnPlanner.new().plan(domain, {}, "get in")

	assert_array(found.steps).is_equal(["climb in"])
	assert_array(found.methods).is_equal(["get in: by the window"])


func test_goap_that_runs_out_of_budget_says_so_and_not_that_there_is_no_plan() -> void:
	var actions: Array[GoapAction] = [
		GoapAction.new("a", 1, {"b": true}, {"done": true}),
		GoapAction.new("b", 1, {"c": true}, {"b": true}),
		GoapAction.new("c", 1, {}, {"c": true}),
	]
	var found: BehaviourPlan = GoapPlanner.new().plan(actions, {}, {"done": true}, 2)

	assert_bool(found.solved).is_false()
	assert_bool(found.gave_up).is_true()


func test_an_htn_that_runs_out_of_budget_says_so() -> void:
	var domain := HtnDomain.new()
	domain.add_method("forever", "again", {}, ["forever"] as Array[String])
	var found: BehaviourPlan = HtnPlanner.new().plan(domain, {}, "forever", 50)

	assert_bool(found.solved).is_false()
	assert_bool(found.gave_up).is_true()


func test_every_brain_is_a_decision_policy_and_only_ever_makes_legal_moves() -> void:
	for brain: GuardBrain in _brains():
		var world := BehaviourWorld.new(brain)
		var policy: DecisionPolicy = brain
		assert_object(policy.choose(world.board(), BehaviourWorld.GUARD_ID)).is_not_null()
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


func test_an_alerted_guard_that_sees_the_intruder_chases_it_whatever_its_brain() -> void:
	for brain: GuardBrain in _brains():
		var world := _alerted(brain, Vector2i(5, 7), Vector2i(2, 7))
		brain.choose(world.board(), BehaviourWorld.GUARD_ID)
		assert_str(brain.deed).is_equal(GuardBrain.CHASE)


func test_an_alerted_guard_beside_the_intruder_it_sees_catches_it_whatever_its_brain() -> void:
	for brain: GuardBrain in _brains():
		var world := _alerted(brain, Vector2i(3, 7), Vector2i(2, 7))
		brain.choose(world.board(), BehaviourWorld.GUARD_ID)
		assert_str(brain.deed).is_equal(GuardBrain.CATCH)


func test_no_brain_chases_an_intruder_it_does_not_see() -> void:
	for brain: GuardBrain in _brains():
		var world := _alerted(brain, Vector2i(5, 7), Vector2i(2, 7))
		world.senses.sees_player = false
		world.senses.player_cell = GuardSenses.NOWHERE
		brain.choose(world.board(), BehaviourWorld.GUARD_ID)
		assert_str(brain.deed).is_equal(GuardBrain.GO_TO_LAST_KNOWN)


func test_the_tree_goes_and_looks_through_one_subtree_from_both_of_its_branches() -> void:
	var lost_sight := GuardTree.new()
	var world := _alerted(lost_sight, Vector2i(5, 7), Vector2i(2, 7))
	world.senses.sees_player = false
	world.senses.player_cell = GuardSenses.NOWHERE
	lost_sight.choose(world.board(), BehaviourWorld.GUARD_ID)
	var investigating := GuardTree.new()
	var calmer := BehaviourWorld.new(investigating)
	calmer.senses.last_known = Vector2i(5, 7)
	calmer.senses.suspicion.level = 50.0
	investigating.choose(calmer.board(), BehaviourWorld.GUARD_ID)

	assert_array(lost_sight.tree.trail).contains(["go and look: running", "chase: running"])
	assert_array(investigating.tree.trail).contains(["go and look: running", "investigate: running"])


func test_on_this_loop_the_brains_that_commit_chase_and_catch_and_the_ones_that_reconsider_never_get_there() -> void:
	# A property of this room, this loop and T14's suspicion, not of trees or
	# GOAP: the chase board above shows the tree chasing once alerted. What
	# carries is the mechanism -- the state machine's gap and the HTN's kept
	# plan hold a search the others drop.
	var deeds: Dictionary = {}
	for brain: GuardBrain in _brains():
		var world := BehaviourWorld.new(brain)
		var done: Array[String] = []
		for _turn: int in range(300):
			world.step()
			done.append(brain.deed)
		deeds[brain.brain_name()] = done
	for committing: String in ["state machine", "HTN"]:
		for deed: String in [GuardBrain.LOOK_AROUND, GuardBrain.CHASE, GuardBrain.CATCH]:
			assert_array(deeds[committing]).contains([deed])
	for reconsidering: String in ["behaviour tree", "GOAP"]:
		assert_array(deeds[reconsidering]).not_contains([GuardBrain.CHASE])
	# One way to each goal, so GOAP's search finds what the tree was told.
	assert_array(deeds["GOAP"]).is_equal(deeds["behaviour tree"])
	assert_array(deeds["HTN"]).is_not_equal(deeds["state machine"])
	assert_array(deeds["HTN"]).is_not_equal(deeds["behaviour tree"])


func test_as_suspicion_fades_mid_search_the_machine_and_the_htn_carry_on_and_the_others_turn_back() -> void:
	var deeds: Dictionary = {}
	for brain: GuardBrain in _brains():
		var world := BehaviourWorld.new(brain)
		world.senses.last_known = Vector2i(5, 7)
		# Suspicious enough to go and look -- each brain sets out; the state
		# machine first turns towards it, and then they all walk there...
		world.senses.suspicion.level = 50.0
		brain.choose(world.board(), BehaviourWorld.GUARD_ID)
		assert_str(brain.deed).is_equal(GuardBrain.TURN_TOWARDS if brain is GuardFsm else GuardBrain.GO_TO_LAST_KNOWN)
		brain.choose(world.board(), BehaviourWorld.GUARD_ID)
		assert_str(brain.deed).is_equal(GuardBrain.GO_TO_LAST_KNOWN)
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
	for moment: Array in load("res://test/demo_behaviour/behaviour_benchmark.gd").moments():
		found.append(moment[1])
	return found


# A world whose guard, on `guard_cell`, is alerted and sees the intruder on
# `intruder_cell`; a state machine is brought to its alerted state first.
static func _alerted(brain: GuardBrain, intruder_cell: Vector2i, guard_cell: Vector2i) -> BehaviourWorld:
	var world := BehaviourWorld.new(brain)
	world.guard.cell = guard_cell
	world.intruder.cell = intruder_cell
	world.senses.suspicion.level = 90.0
	world.senses.sees_player = true
	world.senses.player_cell = intruder_cell
	world.senses.last_known = intruder_cell
	if brain is GuardFsm:
		(brain as GuardFsm).machine.current = GuardFsm.ALERTED
	return world


static func _brains() -> Array[GuardBrain]:
	return [GuardFsm.new(), GuardTree.new(), GuardGoap.new(), GuardHtn.new()]
