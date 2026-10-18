# Every search T11 builds, over the same seeded problems from the tactical
# domain: worlds visited and milliseconds per plan, for breadth-first over
# strings (`StripsPlanner`), breadth-first over bits, and A* with h_max and
# with h_add over bits.
#
#     ./scripts/godot --headless --path godot -s res://test/planner_benchmark.gd
#
# The problems are real: boards from seeded games -- the rules against the
# rules, and the planner against the rules from both seats, so the boards a
# planner sees after buying the forge and the ram are among them -- every
# turn of them, each turned into predicates for the side to move by
# `TacticalPlanBridge`. Duplicates are dropped, so a common opening is not
# counted forty times. A board with no plan (bridge shut, workshop guarded:
# the domain cannot clear either) is counted apart, because breadth-first
# spends its whole search proving that and the table would charge it to the
# boards that have plans.
#
# What it cannot do: tell h_max from h_add. On this domain h_max is exact --
# A* visits one world per step and one more -- so the two tie and a broken
# h_max that still guesses no more than the truth passes here. The domain
# that separates them is pinned in `heuristic_planner_test.gd`.
#
# It asserts three things and prints the table step 7 publishes:
#
#   1. h_max's plans are exactly as long as breadth-first's, on every problem:
#      an admissible guess must not change the answer;
#   2. in total over the set, each heuristic visits fewer worlds than
#      breadth-first. On the set, not on each problem -- no theorem promises
#      that, since breadth-first tests the goal as it generates a world and A*
#      as it takes one off;
#   3. a call given a small budget returns within it, and says it gave up.
#
# Exit codes: 0 all three held; 1 one did not, each printed.
extends SceneTree

const GAMES: int = 6
const SMALL_BUDGET: int = 3
const BUDGET: int = HeuristicPlanner.DEFAULT_BUDGET
const ROWS: Array[String] = ["breadth-first, strings", "breadth-first, bits", "h_max, bits", "h_add, bits"]


func _init() -> void:
	var problems: Array[WorldState] = _problems()
	var totals: Array[Dictionary] = []
	var without_a_plan: Array[Dictionary] = []
	for row: String in ROWS:
		totals.append({"visited": 0, "usec": 0, "steps": 0, "boards": 0})
		without_a_plan.append({"visited": 0, "usec": 0, "steps": 0, "boards": 0})
	var failures: Array[String] = []
	for world: WorldState in problems:
		failures += _measure_one(world, totals if _plan(3, world).solved else without_a_plan)
	failures += _check_totals(totals)
	failures += _check_the_budget(problems)
	print("boards with a plan:")
	_print_table(totals)
	print("boards with none (worlds spent proving it):")
	_print_table(without_a_plan)
	for failure: String in failures:
		print(failure)
	print("planner benchmark: %d problems, %d failure(s)" % [problems.size(), failures.size()])
	quit(1 if not failures.is_empty() else 0)


# Every distinct world the side to move saw in `GAMES` seeded games of each
# pairing.
func _problems() -> Array[WorldState]:
	var found: Dictionary[String, WorldState] = {}
	var keep: Callable = func(state: BoardState) -> void: found[TacticalPlanBridge.world_of(state).key()] = TacticalPlanBridge.world_of(state)
	for dice: int in range(GAMES):
		TacticalMatch.play(RuleBasedBlue.new(), RuleBasedBlue.new(), dice, keep)
		TacticalMatch.play(PlannedBlue.new(), RuleBasedBlue.new(), dice, keep)
		TacticalMatch.play(RuleBasedBlue.new(), PlannedBlue.new(), dice, keep)
	var keys: Array[String] = found.keys()
	keys.sort()
	var worlds: Array[WorldState] = []
	for key: String in keys:
		worlds.append(found[key])
	return worlds


# Plan from `world` with every search, add what each cost to `totals`, and
# check h_max against breadth-first.
func _measure_one(world: WorldState, totals: Array[Dictionary]) -> Array[String]:
	var results: Array[PlanResult] = []
	for row: int in range(ROWS.size()):
		var started: int = Time.get_ticks_usec()
		var result: PlanResult = _plan(row, world)
		totals[row]["usec"] += Time.get_ticks_usec() - started
		totals[row]["visited"] += result.visited
		totals[row]["steps"] += result.steps.size()
		totals[row]["boards"] += 1
		results.append(result)
	var problems: Array[String] = []
	for row: int in range(ROWS.size()):
		problems += _replay(world, results[row], ROWS[row])
	if results[0].solved != results[2].solved or results[0].steps.size() != results[2].steps.size():
		problems.append("from {%s}: breadth-first %d steps, h_max %d -- an admissible guess changed the answer"
			% [", ".join(world.predicates()), results[0].steps.size(), results[2].steps.size()])
	return problems


func _plan(row: int, world: WorldState) -> PlanResult:
	var actions: Array[StripsAction] = TacticalPlanBridge.actions()
	var goal: PackedStringArray = TacticalPlanBridge.goal()
	if row == 0:
		return StripsPlanner.new().plan(actions, world, goal, BUDGET)
	var guides: Array[HeuristicPlanner.Guide] = [HeuristicPlanner.Guide.BREADTH_FIRST,
		HeuristicPlanner.Guide.H_MAX, HeuristicPlanner.Guide.H_ADD]
	return HeuristicPlanner.new().plan(actions, world, goal, guides[row - 1], BUDGET)


# A returned plan is replayed, not trusted: every step runs where it stands,
# and a solved plan ends at the goal.
func _replay(world: WorldState, result: PlanResult, row: String) -> Array[String]:
	for step: StripsAction in result.steps:
		if not step.is_applicable(world):
			return ["%s: step %s could not run where the plan puts it" % [row, step.name]]
		world = step.apply(world)
	if result.solved and not world.holds_all(TacticalPlanBridge.goal()):
		return ["%s: a plan said solved and does not reach the goal" % row]
	return []


func _check_totals(totals: Array[Dictionary]) -> Array[String]:
	var problems: Array[String] = []
	var breadth_first: int = totals[1]["visited"]
	for row: int in [2, 3]:
		var said: String = "%s visited %d worlds over the set, breadth-first %d: the guess bought nothing" % [ROWS[row], totals[row]["visited"], breadth_first]
		if totals[row]["visited"] >= breadth_first:
			problems.append(said)
	return problems


# Every heuristic call given `SMALL_BUDGET` worlds stops at or under it, and
# one that stops unsolved on a problem that has a plan says it gave up rather
# than calling the problem impossible. A problem with no plan may be proved
# so inside any budget -- the relaxation sees it from the start -- and that
# answer is not a budget's.
func _check_the_budget(problems: Array[WorldState]) -> Array[String]:
	var failures: Array[String] = []
	var stopped: int = 0
	var guides: Array[HeuristicPlanner.Guide] = [HeuristicPlanner.Guide.H_MAX, HeuristicPlanner.Guide.H_ADD]
	for world: WorldState in problems:
		for guide: HeuristicPlanner.Guide in guides if _plan(3, world).solved else []:
			var result: PlanResult = HeuristicPlanner.new().plan(TacticalPlanBridge.actions(), world, TacticalPlanBridge.goal(), guide, SMALL_BUDGET)
			failures += _budget_problems(result)
			stopped += 0 if result.solved else 1
	if stopped == 0:
		failures.append("no call ran out of a budget of %d, so the budget was never tested" % SMALL_BUDGET)
	return failures


# What is wrong with one call made on `SMALL_BUDGET`: more worlds than it
# was allowed, or "impossible" said of a problem that has a plan.
func _budget_problems(result: PlanResult) -> Array[String]:
	var problems: Array[String] = []
	if result.visited > SMALL_BUDGET:
		problems.append("a call with a budget of %d visited %d" % [SMALL_BUDGET, result.visited])
	if not result.solved and not result.gave_up:
		problems.append("a call ran out of budget on a problem with a plan, and called it impossible")
	return problems


func _print_table(totals: Array[Dictionary]) -> void:
	var count: int = maxi(totals[0]["boards"], 1)
	print("| search | boards | worlds visited | ms per plan | steps on average |")
	print("|---|---:|---:|---:|---:|")
	for row: int in range(ROWS.size()):
		print("| %s | %d | %d | %.3f | %.2f |" % [ROWS[row], totals[row]["boards"], totals[row]["visited"],
			totals[row]["usec"] / 1000.0 / count, float(totals[row]["steps"]) / count])
