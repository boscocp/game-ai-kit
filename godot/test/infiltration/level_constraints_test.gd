# The infiltration level declared and solved (T95): every solved level keeps
# every condition when measured on the arena the game builds, the solver's
# sketch walks as the arena walks, a seed is one level, the drawn levels are
# untouched -- and the audit that holds the solver refuses the planted cases.
extends GdUnitTestSuite

const SEEDS: Array[int] = [1, 2, 3, 4, 5, 6]


func test_every_solved_level_keeps_every_condition_on_the_real_arena() -> void:
	for seed_value: int in SEEDS:
		var solved := LevelConstraints.solve(seed_value)
		assert_bool(solved.data.is_empty()).override_failure_message("seed %d found none" % seed_value).is_false()
		assert_array(LevelAudit.broken(solved.data)).override_failure_message("seed %d" % seed_value).is_empty()
		assert_bool(LevelGenerator._playable(solved.data)).is_true()


func test_the_sketch_walks_where_the_arena_walks() -> void:
	for seed_value: int in SEEDS:
		var solved := LevelConstraints.solve(seed_value)
		var arena := BotArena.new(InfiltrationLevel.BODY_RADIUS, solved.data)
		var boxes: Array[Dictionary] = []
		boxes.assign(solved.data["boxes"])
		var mask: PackedByteArray = solved.sketch.blocked("all", boxes)
		for cell: Vector2i in InfiltrationLevel.every_cell(arena):
			var sketched: bool = mask[cell.y * solved.sketch.width + cell.x] != 0
			assert_bool(sketched).override_failure_message("seed %d %s" % [seed_value, cell]).is_equal(arena.walk.is_blocked(cell))


func test_a_seed_is_one_level() -> void:
	assert_dict(LevelConstraints.solve(3).data).is_equal(LevelConstraints.solve(3).data)
	assert_dict(LevelConstraints.solve(3).data).is_not_equal(LevelConstraints.solve(4).data)


func test_the_drawn_levels_are_the_draw_and_test_ones() -> void:
	for seed_value: int in [1, 7, 11]:
		assert_dict(LevelGenerator.make_by(LevelGenerator.DRAW, seed_value)).is_equal(LevelGenerator.make(seed_value))


func test_the_solved_level_carries_the_reserve() -> void:
	var data: Dictionary = LevelGenerator.make_by(LevelGenerator.CONSTRAINTS, 2)
	assert_int((data["reserve"] as Array).size()).is_equal(LevelGenerator.RESERVE)


func test_the_trace_shows_the_choices_and_the_crossing_out() -> void:
	var solved := LevelConstraints.solve(1, true)
	var kinds: Dictionary = {}
	for event: Dictionary in solved.solver.trace:
		kinds[event["event"]] = true
	assert_bool(kinds.has("choose") and kinds.has("assign") and kinds.has("prune")).is_true()


# The generation view keeps the solver's books as it replays them: at the
# end every variable stands where the solver put it, and every undo took
# back its assignment's saved counts (seed 54 goes back several times).
func test_the_view_replays_to_the_level_solved() -> void:
	var solved := LevelConstraints.solve(54, true)
	assert_int(solved.solver.backtracks).is_greater(0)
	var view: GenerationView = auto_free(GenerationView.new())
	view.show_solving(solved)
	view._process(1.0e6)
	assert_int(view.progress().x).is_equal(solved.solver.trace.size())
	assert_dict(view._placed).is_equal(solved.assignment)
	assert_int(view._saved.size()).is_equal(solved.assignment.size())


# The rules file says which constraints a level is declared with: every
# rule by default, and a rule left out of its list is not asked for.
func test_the_rules_file_names_the_constraints_declared() -> void:
	assert_array(LevelConstraints.solve(1).declared).is_equal(LevelConstraintRules.LABELS)
	var without: Array = LevelConstraintRules.LABELS.filter(func(label: String) -> bool:
		return label != LevelConstraintRules.DARK_WAY)
	var solved := LevelConstraints.solve(1, false, {"constraints": without})
	assert_array(solved.declared).not_contains([LevelConstraintRules.DARK_WAY])
	assert_int(solved.declared.size()).is_equal(LevelConstraintRules.LABELS.size() - 1)


func test_the_view_says_when_the_solver_gave_up() -> void:
	var view: GenerationView = auto_free(GenerationView.new())
	view.show_gave_up(12)
	assert_int(view._gave_up_on).is_equal(12)
	view.show_solving(LevelConstraints.solve(1, true))
	assert_int(view._gave_up_on).is_equal(-1)


func test_a_limit_too_small_gives_up_rather_than_lie() -> void:
	var solved := LevelConstraints.solve(1, false, {"limit": 3})
	assert_dict(solved.data).is_empty()
	assert_bool(solved.solver.gave_up).is_true()


func test_the_impossible_is_never_returned() -> void:
	var solved := LevelConstraints.solve(1, false, {"hiding_near_route": {"count": 9, "steps": 6}, "limit": 400, "restarts": 0})
	assert_dict(solved.data).is_empty()


func test_the_audit_refuses_a_lamp_over_every_way() -> void:
	var data: Dictionary = LevelConstraints.solve(1).data.duplicate(true)
	data["lights"].append({"x": data["width"] / 2.0, "z": data["depth"] / 2.0, "radius": 80.0, "value": 1.0})
	assert_array(LevelAudit.broken(data)).contains([LevelConstraintRules.DARK_WAY])


func test_the_audit_refuses_a_post_in_the_open_before_the_start() -> void:
	var data: Dictionary = LevelConstraints.solve(1).data.duplicate(true)
	data["boxes"] = []
	data["guards"][2]["post"] = [14.5, data["spawns"]["player"][0][1]]
	assert_array(LevelAudit.broken(data)).contains([LevelConstraintRules.OUT_OF_SIGHT])


func test_the_audit_refuses_a_route_far_from_every_hiding_place() -> void:
	var data: Dictionary = LevelConstraints.solve(1).data.duplicate(true)
	data["hiding"] = [{"x": 2, "z": 2, "width": 2, "depth": 2, "hides": 0.7}]
	assert_array(LevelAudit.broken(data)).contains([LevelConstraintRules.HIDING_NEAR])


func test_the_audit_refuses_a_walled_exit() -> void:
	var data: Dictionary = LevelConstraints.solve(1).data.duplicate(true)
	data["boxes"].append({"x": data["width"] - 4, "z": data["depth"] / 2.0, "width": 1, "depth": data["depth"] + 2, "height": 2.5})
	assert_array(LevelAudit.broken(data)).contains([LevelConstraintRules.EXIT_REACHED])
