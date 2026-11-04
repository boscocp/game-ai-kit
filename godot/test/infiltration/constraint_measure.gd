# Generate and test against the constraint solver, seed by seed: levels
# found, what each way spent, and how many of the drawn levels break the
# two conditions only the solver asks for. A table for
# docs/godot/infiltration.md, not a gate.
#
#     ./scripts/godot --headless --path godot -s res://test/infiltration/constraint_measure.gd -- 200
#
# Exit codes: 0 measured, 1 a solved level broke a condition on the real
# arena (which the suite should have caught first).
extends SceneTree


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var seeds: int = int(arguments[0]) if not arguments.is_empty() else 200
	var totals: Dictionary = {"drawn": 0, "draws": 0, "solved": 0, "assignments": 0, "backtracks": 0, "gave_up": 0,
		"restarts": 0, "no_hiding": 0, "no_dark": 0, "in_sight": 0, "solver_broke": 0, "draw_ms": 0, "solve_ms": 0}
	var most: Dictionary = {"backtracks": 0, "assignments": 0, "solve_ms": 0}
	for seed_value: int in range(1, seeds + 1):
		_measure(seed_value, totals, most)
	print("seeds: %d" % seeds)
	print("draw and test: %d found, %d draws, %d ms" % [totals["drawn"], totals["draws"], totals["draw_ms"]])
	print("  of those found: %d with no hiding place near a route, %d with no dark way, %d with a post in sight"
			% [totals["no_hiding"], totals["no_dark"], totals["in_sight"]])
	print("constraints: %d found, %d gave up, %d assignments, %d backtracks, %d fresh starts, %d ms" % [totals["solved"],
			totals["gave_up"], totals["assignments"], totals["backtracks"], totals["restarts"], totals["solve_ms"]])
	print("  the most on one seed: %d assignments, %d backtracks, %d ms" % [most["assignments"], most["backtracks"], most["solve_ms"]])
	print("  solved levels that broke a condition on the real arena: %d" % totals["solver_broke"])
	quit(1 if totals["solver_broke"] > 0 else 0)


func _measure(seed_value: int, totals: Dictionary, most: Dictionary) -> void:
	var began: int = Time.get_ticks_msec()
	var drawn: Dictionary = LevelGenerator.make(seed_value)
	totals["draws"] += LevelGenerator.draws_spent(seed_value)
	totals["draw_ms"] += Time.get_ticks_msec() - began
	if not drawn.is_empty():
		totals["drawn"] += 1
		var broken: Array[String] = LevelAudit.broken(drawn)
		totals["no_hiding"] += int(broken.has(LevelConstraintRules.HIDING_NEAR))
		totals["no_dark"] += int(broken.has(LevelConstraintRules.DARK_WAY))
		totals["in_sight"] += int(broken.has(LevelConstraintRules.OUT_OF_SIGHT))
	began = Time.get_ticks_msec()
	var solved := LevelConstraints.solve(seed_value)
	var spent: int = Time.get_ticks_msec() - began
	totals["solve_ms"] += spent
	totals["assignments"] += solved.spent
	totals["backtracks"] += solved.spent_backtracks
	totals["restarts"] += solved.restarts
	totals["gave_up"] += int(solved.solver.gave_up)
	most["assignments"] = maxi(most["assignments"], solved.spent)
	most["backtracks"] = maxi(most["backtracks"], solved.spent_backtracks)
	most["solve_ms"] = maxi(most["solve_ms"], spent)
	if not solved.data.is_empty():
		totals["solved"] += 1
		var broken: Array[String] = LevelAudit.broken(solved.data)
		if not broken.is_empty():
			print("seed %d: the solved level breaks %s" % [seed_value, broken])
			totals["solver_broke"] += 1
