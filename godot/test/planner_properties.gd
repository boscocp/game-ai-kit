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
#
# A planner that never returned would hang this script rather than fail it, and
# on CI that reads as a slow job rather than a broken one -- the same trap
# `GridGraph.contains` carries a note about. The budget in `StripsPlanner` is
# what stands between the two. This file prints **nothing** until every trial
# has run, so a hang leaves no line at all to say where it stopped; an earlier
# version of this paragraph claimed the opposite, which is the kind of comment
# that is worse than no comment, because it is read at the moment it matters.
#
# Run it directly; T4's acceptance is this command and its exit code:
#
#     ./scripts/godot --headless --path godot -s res://test/planner_properties.gd
extends SceneTree

const TRIALS: int = 400
const SEED: int = 20261012

# Twelve actions over six predicates, which is not the first shape this file
# generated. It was eight predicates and six actions, and almost every domain
# it produced was a chain: 66 of 400 solvable, no two routes to the same world
# of different lengths, and so nothing for the shortest-plan property to see --
# a stack passed it. Crowding more actions into fewer predicates is what makes
# the frontier's order decide the answer: 218 solvable, 156 plans measured, and
# the stack now fails 19 of them.
const PREDICATES: int = 6
const ACTIONS: int = 12

# Larger than 2^PREDICATES, so no honest search here can reach it. That is what
# makes `gave_up` a finding rather than a possibility in these trials.
const BUDGET: int = 1000

# How deep the exhaustive check below will go. Its cost is ACTIONS to the power
# of the depth, so this is where the property stops being free.
const DEEPEST_EXHAUSTIVE_CHECK: int = 5

# Every search, by name (T11). All of them must return plans that run; the
# shortest-plan claim is checked for the three that make it, and not for
# h_add, which gives it up on purpose (`RelaxedCost`).
const SEARCHES: Array[String] = ["strings", "breadth-first", "h_max", "h_add"]
const SHORTEST: Array[String] = ["strings", "breadth-first", "h_max"]

# Tactical boards for the second half: seeded games of the planner against
# the rules, from both seats, every turn's board planned from.
const TACTICAL_GAMES: int = 4


func _init() -> void:
	var failures: Array[String] = []
	for search: String in SEARCHES:
		failures += _run_trials(search)
	failures += _check_tactical_boards()
	for failure: String in failures:
		print(failure)
	print("planner properties: %d trials, %d failure(s)" % [TRIALS, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _run_trials(search: String) -> Array[String]:
	var random := RandomNumberGenerator.new()
	random.seed = SEED
	var failures: Array[String] = []
	var solved: int = 0
	var checked_for_shorter: int = 0

	for trial: int in range(TRIALS):
		var actions: Array[StripsAction] = _random_domain(random)
		var start: WorldState = WorldState.new(_random_predicates(random, 2))
		var goal: PackedStringArray = _random_predicates(random, 2)
		var result: PlanResult = _plan(search, actions, start, goal)
		solved += 1 if result.solved else 0
		var measurable: bool = _is_measurable(result) and search in SHORTEST
		checked_for_shorter += 1 if measurable else 0
		for failure: String in _check(trial, result, actions, start, goal, measurable):
			failures.append("%s, %s" % [search, failure])

	# A run where every trial fell the same way proves half of what it claims,
	# and this used to be a sentence beside a `print` -- so `TRIALS = 0`
	# reported "0 trials, 0 failures" and passed, and so did a generator whose
	# every goal was unreachable, with the plan-replay half never running once.
	# The two claims are only both exercised when both numbers are non-zero.
	print("planner properties, %s: %d of %d domains had a plan" % [search, solved, TRIALS])
	if solved == 0 or solved == TRIALS:
		failures.append(
			"%d of %d domains had a plan, so only one of the two claims ran"
			% [solved, TRIALS]
		)
	print("planner properties, %s: %d plans measured against an exhaustive search"
		% [search, checked_for_shorter])
	if checked_for_shorter == 0 and search in SHORTEST:
		failures.append("no plan was checked for a shorter one")
	return failures


# What this trial's answer has to satisfy, whichever way it came out.
func _check(trial: int, result: PlanResult, actions: Array[StripsAction],
		start: WorldState, goal: PackedStringArray, measurable: bool) -> Array[String]:
	# There was a `result.visited > BUDGET` guard here. It cannot fire --
	# `plan` returns the moment `visited` reaches the budget -- so it was a
	# check that could only ever go green, which is the thing this repository
	# is arranged against. What the budget is actually worth is pinned in
	# `planning_test.gd`, where a run stopped at 3 states reports exactly 3.
	if not result.solved:
		return _check_no_plan(trial, result, actions, start, goal)
	return _check_the_plan_runs(trial, result, actions, start, goal, measurable)


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


# A plan: every step runs where the plan puts it, the goal holds at the end,
# and no shorter plan exists.
func _check_the_plan_runs(trial: int, result: PlanResult, actions: Array[StripsAction],
		start: WorldState, goal: PackedStringArray, measurable: bool) -> Array[String]:
	var world: WorldState = start
	for index: int in range(result.steps.size()):
		var action: StripsAction = result.steps[index]
		if not action.is_applicable(world):
			return [_could_not_run(trial, index, action)]
		world = action.apply(world)

	if not world.holds_all(goal):
		return ["trial %d: the plan ran to the end and the goal does not hold" % trial]
	if measurable and _a_shorter_plan_exists(actions, start, goal,
			result.steps.size() - 1):
		return ["trial %d: %d steps, and a shorter plan exists"
			% [trial, result.steps.size()]]
	return []


# True when this plan is short enough to measure against an exhaustive search.
#
# The search below has no visited set and no frontier, so its cost is the
# branching factor to the power of the depth. Past a handful of steps that is
# the rest of the afternoon, and a property check nobody runs proves nothing.
func _is_measurable(result: PlanResult) -> bool:
	return result.solved and result.steps.size() > 0 \
		and result.steps.size() - 1 <= DEEPEST_EXHAUSTIVE_CHECK


# Is there any plan of `depth` steps or fewer? Every sequence, tried.
#
# This is the slow truth the planner is measured against, and it is deliberately
# written the other way round: no queue, no visited set, nothing shared with the
# code it is checking. A review turned the planner's queue into a stack and
# every gate in the repository stayed green, because the shortest-plan claim --
# the only claim breadth-first makes -- was asserted by nothing.
func _a_shorter_plan_exists(actions: Array[StripsAction], world: WorldState,
		goal: PackedStringArray, depth: int) -> bool:
	if depth <= 0:
		return false
	for action: StripsAction in actions:
		if not action.is_applicable(world):
			continue
		var next: WorldState = action.apply(world)
		if next.holds_all(goal):
			return true
		if _a_shorter_plan_exists(actions, next, goal, depth - 1):
			return true
	return false


# `search`'s plan for one problem.
func _plan(search: String, actions: Array[StripsAction], start: WorldState,
		goal: PackedStringArray) -> PlanResult:
	if search == "strings":
		return StripsPlanner.new().plan(actions, start, goal, BUDGET)
	var guide: HeuristicPlanner.Guide = {"breadth-first": HeuristicPlanner.Guide.BREADTH_FIRST,
		"h_max": HeuristicPlanner.Guide.H_MAX, "h_add": HeuristicPlanner.Guide.H_ADD}[search]
	return HeuristicPlanner.new().plan(actions, start, goal, guide, BUDGET)


# T11's property, over generated tactical boards rather than one example:
# every board the side to move saw in seeded games of the planner against the
# rules, turned into predicates, planned from with every search -- and each
# plan replayed, every step's preconditions holding where it runs and the
# goal holding at the end. Both answers must turn up, or half of it never ran.
func _check_tactical_boards() -> Array[String]:
	var worlds: Array[WorldState] = []
	for dice: int in range(TACTICAL_GAMES):
		var collect: Callable = func(state: BoardState) -> void: worlds.append(TacticalPlanBridge.world_of(state))
		TacticalMatch.play(PlannedBlue.new(), RuleBasedBlue.new(), dice, collect)
		TacticalMatch.play(RuleBasedBlue.new(), PlannedBlue.new(), dice, collect)
	# Since the fords (T48) no sampled board has every crossing shut, so none
	# is without a plan, and half the property would never run. Each board is
	# also planned from as it would be with every crossing shut and their
	# workshop guarded -- which no plan in this domain gets past.
	for index: int in range(worlds.size()):
		worlds.append(_shut_and_guarded(worlds[index]))
	var failures: Array[String] = []
	var solved: int = 0
	for index: int in range(worlds.size() * SEARCHES.size()):
		var world: WorldState = worlds[index / SEARCHES.size()]
		var search: String = SEARCHES[index % SEARCHES.size()]
		var result: PlanResult = _plan(search, TacticalPlanBridge.actions(), world, TacticalPlanBridge.goal())
		solved += 1 if result.solved else 0
		for failure: String in _check(index / SEARCHES.size(), result, TacticalPlanBridge.actions(), world, TacticalPlanBridge.goal(), false):
			failures.append("tactical board %s, %s" % [search, failure])
	print("planner properties, tactical: %d boards, %d of %d plans found" % [worlds.size(), solved, worlds.size() * SEARCHES.size()])
	if solved == 0 or solved == worlds.size() * SEARCHES.size():
		failures.append("tactical: %d of %d calls had a plan, so only one of the two claims ran" % [solved, worlds.size() * SEARCHES.size()])
	return failures


# `world` with every crossing shut and their workshop guarded.
static func _shut_and_guarded(world: WorldState) -> WorldState:
	var kept := PackedStringArray()
	for predicate: String in world.predicates():
		if not predicate in ["crossing_open", "their_workshop_unguarded"]:
			kept.append(predicate)
	return WorldState.new(kept)


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
		# `_random_predicates` never returns an empty list, so the guard this
		# line used to carry -- `and not needs.is_empty()` -- was always true.
		var deletes := PackedStringArray()
		if random.randf() < 0.5:
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
