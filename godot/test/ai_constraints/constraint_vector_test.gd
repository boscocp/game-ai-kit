# The constraint vector's rules, each refusing a planted case, and two
# planted solvers -- one that gives a tie between variables to the last, one
# with least constraining value backwards -- each failing the vector it must.
extends GdUnitTestSuite

const NAMES: Array[String] = ["australia-in-three-colours.json", "australia-another-seed.json",
		"australia-in-order-alone.json", "six-queens-plain-backtracking.json",
		"six-queens-maintaining-arc-consistency.json", "four-by-four-sudoku.json",
		"a-triangle-in-two-colours-has-none.json", "a-global-checked-late.json", "least-constraining-first.json"]


## Of equally constrained variables, the last in the seeded order.
class LastOfEqual extends ConstraintSolver:
	func _fewer(name: String, best: String) -> bool:
		var left: int = (domains[name] as Array).size()
		var best_left: int = (domains[best] as Array).size()
		return left < best_left or (left == best_left and _degree(name) >= _degree(best))


## The value that crosses out most, first.
class MostConstraining extends ConstraintSolver:
	func _values(name: String) -> Array:
		var values: Array = super(name)
		values.reverse()
		return values


func _vector(name: String) -> Dictionary:
	var path: String = ProjectSettings.globalize_path("res://").path_join("../spec/vectors/constraints").path_join(name)
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func test_the_vectors_are_vectors_and_hold() -> void:
	for name: String in NAMES:
		var vector: Dictionary = _vector(name)
		assert_str(ConstraintVector.why_not_a_vector(vector)).override_failure_message(name).is_empty()
		var claims: Array[String] = ConstraintVector.wrong_claims(vector, ConstraintVector.solver_of(vector))
		assert_array(claims).override_failure_message("%s: %s" % [name, claims]).is_empty()


func test_a_broken_vector_is_refused_by_its_rule() -> void:
	var sound: Dictionary = _vector("australia-in-three-colours.json")
	var changes: Array[Array] = [["V1", "solutoin", null], ["V2", "binary", [{"between": ["WA", "NT"], "relation": "unequal"}]],
			["V3", "global", [{"over": ["WA"], "relation": "sum"}]], ["V4", "variables", [{"name": "WA", "values": []}]],
			["V5", "assignments", 99], ["V6", "solution", {"WA": "red"}]]
	for change: Array in changes:
		var broken: Dictionary = sound.duplicate(true)
		broken[change[1]] = change[2]
		assert_str(ConstraintVector.why_not_a_vector(broken)).starts_with(change[0])


func test_a_solver_that_breaks_ties_to_the_last_fails() -> void:
	var vector: Dictionary = _vector("australia-in-three-colours.json")
	var planted := LastOfEqual.new(ConstraintVector.problem_of(vector))
	assert_array(ConstraintVector.wrong_claims(vector, ConstraintVector.solver_of(vector, planted))).is_not_empty()


func test_a_solver_with_lcv_backwards_fails() -> void:
	var vector: Dictionary = _vector("least-constraining-first.json")
	var planted := MostConstraining.new(ConstraintVector.problem_of(vector))
	assert_array(ConstraintVector.wrong_claims(vector, ConstraintVector.solver_of(vector, planted))).is_not_empty()
