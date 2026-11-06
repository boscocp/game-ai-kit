# Wave function collapse on the solver (T96): the entropy, the tile set it
# refuses, a build that never goes back, and a contradiction marked where it
# happened, in the trace a view replays.
extends GdUnitTestSuite

const CHECKERS: Dictionary = {"tiles": [{"tile": "a", "weight": 1, "left_right": "b", "up_down": "b"},
		{"tile": "b", "weight": 1, "left_right": "a", "up_down": "a"}]}
const THREE: Dictionary = {"tiles": [{"tile": "r", "weight": 1, "left_right": "gb", "up_down": "gb"},
		{"tile": "g", "weight": 1, "left_right": "rb", "up_down": "rb"},
		{"tile": "b", "weight": 1, "left_right": "rg", "up_down": "rg"}]}


# Land, river and crossings: the squad's tile set, as its vectors carry it.
func _squad_tiles() -> Dictionary:
	var path: String = ProjectSettings.globalize_path("res://").path_join("../spec/vectors/constraints/collapse/squad-map-seed-1.json")
	return {"tiles": JSON.parse_string(FileAccess.get_file_as_string(path))["tiles"]}


func test_two_equal_tiles_are_log_two_and_one_tile_is_certain() -> void:
	assert_float(WaveCollapse.entropy_of(["a", "b"], {"a": 1, "b": 1})).is_equal_approx(log(2.0), 1e-12)
	assert_float(WaveCollapse.entropy_of(["a"], {"a": 5, "b": 1})).is_equal(0.0)
	assert_float(WaveCollapse.entropy_of(["a", "b"], {"a": 9, "b": 1})).is_less(log(2.0))


func test_the_squads_tile_set_is_one_and_a_one_sided_pair_is_refused() -> void:
	assert_str(TileGrid.why_not(_squad_tiles())).is_empty()
	var one_sided: Dictionary = {"tiles": [{"tile": "~", "weight": 1, "left_right": "~", "up_down": "~="},
			{"tile": "=", "weight": 1, "left_right": "=", "up_down": ""}]}
	assert_str(TileGrid.why_not(one_sided)).contains("but not")
	var no_such: Dictionary = {"tiles": [{"tile": ".", "weight": 1, "left_right": ".x", "up_down": "."}]}
	assert_str(TileGrid.why_not(no_such)).contains("which is no tile")
	var weightless: Dictionary = {"tiles": [{"tile": ".", "weight": 0, "left_right": ".", "up_down": "."}]}
	assert_str(TileGrid.why_not(weightless)).contains("whole weight")


func test_a_map_is_built_without_ever_going_back() -> void:
	var collapse := WaveCollapse.new(TileGrid.problem(_squad_tiles(), Vector2i(6, 4)), TileGrid.weights_of(_squad_tiles()), 3)
	collapse.record = true
	var found: Dictionary = collapse.solve()
	assert_int(found.size()).is_equal(24)
	assert_int(collapse.backtracks).is_equal(0)
	assert_int(collapse.chosen().size()).is_equal(24)
	assert_bool(collapse.trace.any(func(event: Dictionary) -> bool: return event["event"] == "undo")).is_false()


func test_each_cell_chosen_had_the_least_entropy_of_those_open() -> void:
	var collapse := WaveCollapse.new(TileGrid.problem(_squad_tiles(), Vector2i(5, 3)), TileGrid.weights_of(_squad_tiles()), 4)
	collapse.record = true
	collapse.solve()
	var domains: Dictionary = TileGrid.problem(_squad_tiles(), Vector2i(5, 3)).domains.duplicate(true)
	var assigned: Dictionary = {}
	for event: Dictionary in collapse.trace:
		if event["event"] == "choose":
			var chosen: float = WaveCollapse.entropy_of(domains[event["variable"]], collapse.weights)
			assert_float(chosen).is_equal(_least_open(domains, assigned, collapse.weights))
		elif event["event"] == "assign":
			domains[event["variable"]] = [event["value"]]
			assigned[event["variable"]] = true
		elif event["event"] == "prune":
			(domains[event["variable"]] as Array).erase(event["value"])


# The least entropy of the cells in `domains` not in `assigned`.
func _least_open(domains: Dictionary, assigned: Dictionary, weights: Dictionary) -> float:
	var least: float = INF
	for name: String in domains:
		if not assigned.has(name):
			least = minf(least, WaveCollapse.entropy_of(domains[name], weights))
	return least


func test_a_contradiction_is_marked_where_it_happened_and_the_next_seed_tried() -> void:
	var collapse := WaveCollapse.new(TileGrid.problem(THREE, Vector2i(8, 8)), TileGrid.weights_of(THREE), 30)
	collapse.record = true
	assert_dict(collapse.attempt(30)).is_empty()
	assert_str(collapse.contradiction).is_equal("6,4")
	# It stopped there: nothing gone back over, one undo -- the attempt's last.
	assert_int(collapse.backtracks).is_equal(0)
	assert_int(collapse.trace.filter(func(event: Dictionary) -> bool: return event["event"] == "undo").size()).is_equal(1)
	var last: Dictionary = collapse.trace.filter(func(event: Dictionary) -> bool: return event["event"] == "contradiction")[0]
	assert_str(last["variable"]).is_equal("6,4")
	assert_int(collapse.solve().size()).is_equal(64)
	assert_int(collapse.restarts).is_equal(1)
	assert_array(collapse.contradictions).contains_exactly(["6,4"])


func test_pins_that_cannot_stand_together_leave_no_map_and_say_so() -> void:
	var collapse := WaveCollapse.new(TileGrid.problem(CHECKERS, Vector2i(3, 2), {"0,0": ["a"], "1,0": ["a"]}),
			TileGrid.weights_of(CHECKERS), 1)
	collapse.attempts = 3
	assert_dict(collapse.solve()).is_empty()
	assert_int(collapse.restarts).is_equal(3)
	assert_array(collapse.contradictions).contains_exactly(["0,0", "0,0", "0,0"])


func test_rows_show_an_undecided_cell() -> void:
	assert_array(TileGrid.rows_of({"0,0": "a", "1,1": "b"}, Vector2i(2, 2))).contains_exactly(["a?", "?b"])
	assert_object(TileGrid.cell_of("12,3")).is_equal(Vector2i(12, 3))
