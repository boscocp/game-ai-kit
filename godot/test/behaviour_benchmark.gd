# T15's measurement: GOAP and the HTN planning the same guard, in worlds
# looked at and in microseconds a plan, in four moments of its evening -- on
# the round, setting out to look, looking, and the chase.
#
#     ./scripts/godot --headless --path godot -s res://test/behaviour_benchmark.gd
#
# Worlds are deterministic, and `behaviour_test.gd` holds them. Microseconds
# are one machine's and move with it; they are printed, never asserted. What
# `WaysToDecide` reports was read from this.
#
# Exit codes: 0 measured; 1 the two planners disagree on a plan, which would
# make the comparison meaningless.
extends SceneTree

## Plans made of each, per moment, for the time.
const REPEATS: int = 2000


func _init() -> void:
	var goap := GoapPlanner.new()
	var htn := HtnPlanner.new()
	var actions: Array[GoapAction] = GuardActions.goap()
	var domain: HtnDomain = GuardActions.htn()
	var disagreements: int = 0
	for moment: Array in moments():
		var facts: Dictionary = moment[1]
		var backwards: BehaviourPlan = goap.plan(actions, facts, GuardActions.goal(facts))
		var forwards: BehaviourPlan = htn.plan(domain, facts, "guard")
		disagreements += 0 if backwards.steps == forwards.steps else 1
		print("%-16s GOAP %d worlds, %.1f us a plan  ·  HTN %d worlds, %.1f us a plan  ·  %s" % [moment[0],
			backwards.visited, _time(func() -> void: goap.plan(actions, facts, GuardActions.goal(facts))),
			forwards.visited, _time(func() -> void: htn.plan(domain, facts, "guard")), forwards.steps])
	quit(1 if disagreements > 0 else 0)


## The four moments, as [name, facts].
static func moments() -> Array[Array]:
	var senses := GuardSenses.new([Vector2i(2, 2)] as Array[Vector2i])
	var found: Array[Array] = [["on the round", senses.facts(Vector2i(2, 2))]]
	senses.last_known = Vector2i(5, 7)
	senses.suspicion.level = 50.0
	found.append(["setting out", senses.facts(Vector2i(2, 2))])
	found.append(["looking", senses.facts(Vector2i(5, 7))])
	senses.suspicion.level = 90.0
	senses.sees_player = true
	senses.player_cell = Vector2i(5, 8)
	found.append(["the chase", senses.facts(Vector2i(2, 2))])
	return found


# Microseconds a call of `plan_once` takes, over `REPEATS` calls.
static func _time(plan_once: Callable) -> float:
	var started: int = Time.get_ticks_usec()
	for _repeat: int in range(REPEATS):
		plan_once.call()
	return float(Time.get_ticks_usec() - started) / REPEATS
