# BayesNetwork's rules, one test each, beside what the vectors hold: the
# book's answer, a table read by its parents, explaining away, the strongest
# evidence, impossible evidence, and each malformed network named by its rule.
extends GdUnitTestSuite


func _burglary() -> BayesNetwork:
	return BayesNetwork.new({"variables": [
		{"name": "burglary", "values": ["yes", "no"], "parents": [], "table": [[0.001, 0.999]]},
		{"name": "earthquake", "values": ["yes", "no"], "parents": [], "table": [[0.002, 0.998]]},
		{"name": "alarm", "values": ["yes", "no"], "parents": ["burglary", "earthquake"],
			"table": [[0.95, 0.05], [0.94, 0.06], [0.29, 0.71], [0.001, 0.999]]},
		{"name": "john_calls", "values": ["yes", "no"], "parents": ["alarm"], "table": [[0.90, 0.10], [0.05, 0.95]]},
		{"name": "mary_calls", "values": ["yes", "no"], "parents": ["alarm"], "table": [[0.70, 0.30], [0.01, 0.99]]},
	]})


func _one(values: Array, table: Array, parents: Array = []) -> BayesNetwork:
	return BayesNetwork.new({"variables": [{"name": "one", "values": values, "parents": parents, "table": table}]})


func test_the_books_answer() -> void:
	var distribution: PackedFloat64Array = _burglary().ask("burglary", {"john_calls": "yes", "mary_calls": "yes"})
	assert_float(distribution[0]).is_equal_approx(0.284, 0.0005)
	assert_float(distribution[0] + distribution[1]).is_equal_approx(1.0, 1e-12)


func test_no_evidence_is_the_prior() -> void:
	assert_float(_burglary().ask("burglary", {})[0]).is_equal_approx(0.001, 1e-12)


func test_a_table_entry_is_read_by_its_parents() -> void:
	assert_float(_burglary().probability("alarm", "yes", {"burglary": "no", "earthquake": "yes"})).is_equal(0.29)


func test_an_earthquake_explains_the_alarm_away() -> void:
	var network: BayesNetwork = _burglary()
	var alone: float = network.ask("burglary", {"alarm": "yes"})[0]
	var explained: float = network.ask("burglary", {"alarm": "yes", "earthquake": "yes"})[0]
	assert_float(explained).is_less(alone)
	assert_float(network.influence("burglary", "yes", {"alarm": "yes", "earthquake": "yes"})["earthquake"]).is_less(0.0)


func test_the_evidence_that_moved_it_most() -> void:
	var moved: Dictionary = _burglary().influence("burglary", "yes", {"john_calls": "yes", "mary_calls": "yes"})
	assert_str(BayesNetwork.most_moved(moved)).is_equal("mary_calls")
	assert_str(BayesNetwork.most_moved({"one": -0.5, "two": 0.25})).is_equal("one")
	assert_str(BayesNetwork.most_moved({"one": 0.25, "two": -0.25})).is_equal("one")
	assert_str(BayesNetwork.most_moved({})).is_equal("")


func test_impossible_evidence_has_no_answer() -> void:
	var network := BayesNetwork.new({"variables": [
		{"name": "cause", "values": ["yes", "no"], "parents": [], "table": [[1.0, 0.0]]},
		{"name": "effect", "values": ["yes", "no"], "parents": ["cause"], "table": [[1.0, 0.0], [0.0, 1.0]]}]})
	assert_int(network.ask("cause", {"effect": "no"}).size()).is_equal(0)
	assert_dict(network.influence("cause", "yes", {"effect": "no"})).is_empty()


func test_each_malformed_network_is_named_by_its_rule() -> void:
	var cases: Array[Array] = [
		["B1", BayesNetwork.new({"variables": []})],
		["B2", _one(["yes"], [[1.0]])],
		["B2", _one(["yes", "yes"], [[0.5, 0.5]])],
		["B3", _one(["yes", "no"], [[0.5, 0.5]], ["two"])],
		["B4", _one(["yes", "no"], [[0.5, 0.5], [0.5, 0.5]])],
		["B4", _one(["yes", "no"], [[1.0]])],
		["B5", _one(["yes", "no"], [[0.7, 0.7]])],
		["B5", _one(["yes", "no"], [[1.5, -0.5]])],
	]
	for case: Array in cases:
		assert_str((case[1] as BayesNetwork).problem()).starts_with(case[0])
	assert_str(_burglary().problem()).is_empty()
