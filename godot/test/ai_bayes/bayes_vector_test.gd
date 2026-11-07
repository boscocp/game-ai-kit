# The Bayesian network vector's rules, each refusing a planted case, and
# three planted networks -- one that reads a table's rows with the wrong
# parent slowest, one that sums a hidden variable over its first value only,
# one that takes any table -- each failing the vectors it must.
extends GdUnitTestSuite

const NAMES: Array[String] = ["burglary-john-and-mary-call.json", "burglary-explained-away.json",
		"three-values-and-two-parents.json", "impossible-evidence.json", "the-guards-intruder.json",
		"refused-a-parent-after-its-child.json", "refused-a-row-short.json", "refused-a-row-not-summing-to-one.json"]


## The last parent varies slowest along the rows, not the first.
class LastParentSlowest extends BayesNetwork:
	func probability(variable: String, value: String, assignment: Dictionary) -> float:
		var row: int = 0
		var above: PackedStringArray = parents[variable].duplicate()
		above.reverse()
		for parent: String in above:
			row = row * values[parent].size() + values[parent].find(str(assignment[parent]))
		return float(tables[variable][row][values[variable].find(value)])


## A hidden variable is fixed at its first value instead of summed over.
class FirstValueOnly extends BayesNetwork:
	func _enumerate_all(index: int, assignment: Dictionary) -> float:
		if index < names.size() and not assignment.has(names[index]):
			var fixed: Dictionary = assignment.duplicate()
			fixed[names[index]] = values[names[index]][0]
			return super(index, fixed)
		return super(index, assignment)


## Any table is taken, however many rows and whatever they sum to.
class NoRowCheck extends BayesNetwork:
	func _table_problem(_name: String, _own: PackedStringArray, _above: PackedStringArray, _table: Variant) -> String:
		return ""


func _vector(name: String) -> Dictionary:
	var path: String = ProjectSettings.globalize_path("res://").path_join("../spec/vectors/bayes").path_join(name)
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func test_the_vectors_are_vectors_and_hold() -> void:
	for name: String in NAMES:
		var vector: Dictionary = _vector(name)
		assert_str(BayesVector.why_not_a_vector(vector)).override_failure_message(name).is_empty()
		assert_array(BayesVector.wrong_claims(vector, BayesVector.network_of(vector))).override_failure_message(name).is_empty()


func test_a_broken_vector_is_refused_by_its_rule() -> void:
	var sound: Dictionary = _vector("burglary-john-and-mary-call.json")
	var asked: Dictionary = sound["queries"][0]
	var misspelt: Dictionary = asked.duplicate(true)
	misspelt["valu"] = misspelt["value"]
	misspelt.erase("value")
	var unsummed: Dictionary = asked.duplicate(true)
	unsummed["distribution"] = [0.5, 0.6]
	var half_moved: Dictionary = asked.duplicate(true)
	half_moved["influence"] = {"mary_calls": 0.1}
	var changes: Array[Array] = [["V1", "queris", []], ["V2", "problem", "B3"], ["V3", "queries", [misspelt]],
			["V4", "queries", [unsummed]], ["V5", "queries", [half_moved]]]
	for change: Array in changes:
		var broken: Dictionary = sound.duplicate(true)
		broken[change[1]] = change[2]
		assert_str(BayesVector.why_not_a_vector(broken)).starts_with(change[0])


func test_a_network_that_reads_rows_the_wrong_way_fails() -> void:
	var vector: Dictionary = _vector("three-values-and-two-parents.json")
	assert_array(BayesVector.wrong_claims(vector, LastParentSlowest.new(vector["network"]))).is_not_empty()


func test_a_network_that_skips_the_hidden_sum_fails() -> void:
	var vector: Dictionary = _vector("burglary-john-and-mary-call.json")
	assert_array(BayesVector.wrong_claims(vector, FirstValueOnly.new(vector["network"]))).is_not_empty()


func test_a_network_that_takes_any_table_fails_the_refusals() -> void:
	for name: String in ["refused-a-row-short.json", "refused-a-row-not-summing-to-one.json"]:
		var vector: Dictionary = _vector(name)
		assert_array(BayesVector.wrong_claims(vector, NoRowCheck.new(vector["network"]))).override_failure_message(name).is_not_empty()
