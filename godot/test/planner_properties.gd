# The two things a planner must get right, asserted over many domains rather
# than inspected on the one in the repository.
#
# T4 names both, and they are the two failure modes that actually cost you a
# game:
#
#   1. a domain with no plan comes back with an empty plan and says why --
#      `impossible` when the space was exhausted, `gave_up` when the budget
#      was. With a budget larger than the whole state space, as here, "not
#      found" must mean "there is none";
#   2. a plan that is returned can be *run*: every step's preconditions hold at
#      the moment that step runs, and the goal holds at the end. A plan whose
#      third action cannot run is worse than no plan, because the unit has
#      already done the first two.
#
# The domains are generated from a fixed seed, so a failure is reproducible.
# A planner that never returned would hang this script rather than fail it --
# on CI that reads as a slow job rather than a broken one, which is the same
# trap `GridGraph.contains` carries a note about. The budget is what stands
# between the two, and trial 0 of a hung run is the last line printed.
#
# Run it directly; T4's acceptance is this command and its exit code:
#
#     ./scripts/godot --headless --path godot -s res://test/planner_properties.gd
extends SceneTree

const TRIALS: int = 400
const SEED: int = 20261012
const PREDICATES: int = 8
const ACTIONS: int = 6

# Larger than 2^PREDICATES, so no honest search here can reach it. That is what
# makes `gave_up` a finding rather than a possibility in these trials.
const BUDGET: int = 1000


func _init() -> void:
	var failures: Array[String] = _run_trials()
	for failure: String in failures:
		print(failure)
	print("planner properties: %d trials, %d failure(s)" % [TRIALS, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _run_trials() -> Array[String]:
	var random := RandomNumberGenerator.new()
	random.seed = SEED
	var planner := StripsPlanner.new()
	var failures: Array[String] = []
	var solved: int = 0

	for trial: int in range(TRIALS):
		var actions: Array[StripsAction] = _random_domain(random)
		var start: WorldState = WorldState.new(_random_predicates(random, 2))
		var goal: PackedStringArray = _random_predicates(random, 2)
		var result: PlanResult = planner.plan(actions, start, goal, BUDGET)
		solved += 1 if result.solved else 0
		failures += _check(trial, result, actions, start, goal)

	# Printed because a property run where every trial fell the same way is a
	# run that proved half of what it claims. Both numbers have to be non-zero
	# for the two claims above to have been exercised at all.
	print("planner properties: %d of %d domains had a plan" % [solved, TRIALS])
	return failures


# What this trial's answer has to satisfy, whichever way it came out.
func _check(trial: int, result: PlanResult, actions: Array[StripsAction],
		start: WorldState, goal: PackedStringArray) -> Array[String]:
	if result.visited > BUDGET:
		return ["trial %d: visited %d states, and the budget was %d"
			% [trial, result.visited, BUDGET]]
	if not result.solved:
		return _check_no_plan(trial, result, actions, start, goal)
	return _check_the_plan_runs(trial, result, start, goal)


# No plan: an empty one, and an honest reason for it.
func _check_no_plan(trial: int, result: PlanResult, actions: Array[StripsAction],
		start: WorldState, goal: PackedStringArray) -> Array[String]:
	var problems: Array[String] = []
	if not result.steps.is_empty():
		problems.append("trial %d: no plan, but %d steps came back"
			% [trial, result.steps.size()])
	if result.gave_up:
		problems.append("trial %d: gave up at %d states, and %d actions over %d predicates"
			% [trial, result.visited, actions.size(), PREDICATES]
			+ " cannot reach a budget of %d" % BUDGET)
	if start.holds_all(goal):
		problems.append("trial %d: the goal already held and it reported no plan" % trial)
	return problems


# A plan: every step runs where the plan puts it, and the goal holds at the end.
func _check_the_plan_runs(trial: int, result: PlanResult, start: WorldState,
		goal: PackedStringArray) -> Array[String]:
	var world: WorldState = start
	for index: int in range(result.steps.size()):
		var action: StripsAction = result.steps[index]
		if not action.is_applicable(world):
			return [_could_not_run(trial, index, action)]
		world = action.apply(world)

	if not world.holds_all(goal):
		return ["trial %d: the plan ran to the end and the goal does not hold" % trial]
	return []


# The sentence for a step that cannot run, kept out of the loop above so the
# loop stays three levels deep and readable.
func _could_not_run(trial: int, index: int, action: StripsAction) -> String:
	return "trial %d: step %d (%s) could not run where the plan puts it" % [
		trial, index, action.name,
	]


# A domain of actions over `PREDICATES` facts named p0..p7. Each one needs one
# or two of them, may delete one it needed, and adds one. Most such domains are
# unsolvable, which is the half that is hard to get right.
func _random_domain(random: RandomNumberGenerator) -> Array[StripsAction]:
	var actions: Array[StripsAction] = []
	for index: int in range(ACTIONS):
		var needs: PackedStringArray = _random_predicates(random, 2)
		var deletes := PackedStringArray()
		if random.randf() < 0.5 and not needs.is_empty():
			deletes.append(needs[random.randi_range(0, needs.size() - 1)])
		actions.append(StripsAction.new(
			"action_%d" % index, needs, deletes, _random_predicates(random, 1)
		))
	return actions


# One or `most` distinct predicate names.
func _random_predicates(random: RandomNumberGenerator, most: int) -> PackedStringArray:
	var chosen := PackedStringArray()
	for _attempt: int in range(random.randi_range(1, most)):
		var name: String = "p%d" % random.randi_range(0, PREDICATES - 1)
		if not chosen.has(name):
			chosen.append(name)
	return chosen
