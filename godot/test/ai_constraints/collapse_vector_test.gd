# The collapse vector's rules, each refusing a planted case, and three planted
# collapses -- one that takes the cell of most entropy, one that skips
# propagation, one blind to a contradiction -- each failing the vector it must.
extends GdUnitTestSuite

const NAMES: Array[String] = ["checkers-decided-by-one-cell.json", "heavy-and-light.json",
		"pinned-so-there-is-none.json", "squad-map-seed-1.json", "squad-map-seed-2.json",
		"three-colours-restart.json", "three-colours-two-restarts.json"]


## The cell of most entropy, not least; of equal ones, the first.
class MostEntropy extends WaveCollapse:
	func _select() -> String:
		var best: String = ""
		var highest: float = -1.0
		for name: String in _order:
			if not assignment.has(name) and entropy(name) > highest:
				best = name
				highest = entropy(name)
		return best


## A tile chosen, and nothing crossed out round it.
class NoPropagation extends WaveCollapse:
	func _ac3(_arcs: Array[Vector2i]) -> bool:
		return true


## A cell emptied, and the search carries on as the solver's would: back.
class BlindToContradictions extends WaveCollapse:
	func _revise(index: int, target: String) -> bool:
		var other_values: Array = domains[problem.other_end(index, target)]
		var kept: Array = (domains[target] as Array).filter(func(value: Variant) -> bool:
			return other_values.any(func(other: Variant) -> bool: return problem.allows(index, target, value, other)))
		var removed: bool = kept.size() < (domains[target] as Array).size()
		domains[target] = kept
		return removed


func _vector(name: String) -> Dictionary:
	var path: String = ProjectSettings.globalize_path("res://").path_join("../spec/vectors/constraints/collapse").path_join(name)
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _planted(vector: Dictionary, planted: WaveCollapse) -> Array[String]:
	return CollapseVector.wrong_claims(vector, CollapseVector.collapse_of(vector, planted))


func test_the_vectors_are_vectors_and_hold() -> void:
	for name: String in NAMES:
		var vector: Dictionary = _vector(name)
		assert_str(CollapseVector.why_not_a_vector(vector)).override_failure_message(name).is_empty()
		var claims: Array[String] = CollapseVector.wrong_claims(vector, CollapseVector.collapse_of(vector))
		assert_array(claims).override_failure_message("%s: %s" % [name, claims]).is_empty()


func test_a_broken_vector_is_refused_by_its_rule() -> void:
	var sound: Dictionary = _vector("three-colours-restart.json")
	var changes: Array[Array] = [["C1", "mapp", null],
			["C2", "tiles", [{"tile": "r", "weight": 0, "left_right": "", "up_down": ""}]],
			["C3", "pinned", {"99,0": ["r"]}], ["C4", "restarts", 2], ["C5", "attempts", 1], ["C6", "collapsed", []]]
	for change: Array in changes:
		var broken: Dictionary = sound.duplicate(true)
		broken[change[1]] = change[2]
		assert_str(CollapseVector.why_not_a_vector(broken)).starts_with(change[0])


func test_no_map_with_attempts_to_spare_is_refused_unless_it_stopped_at_the_first() -> void:
	var broken: Dictionary = _vector("pinned-so-there-is-none.json").duplicate(true)
	broken["restarts"] = 2
	broken["contradictions"] = ["0,0", "0,0"]
	assert_str(CollapseVector.why_not_a_vector(broken)).starts_with("C5")


func test_the_cell_of_most_entropy_first_fails() -> void:
	var vector: Dictionary = _vector("squad-map-seed-1.json")
	var planted := MostEntropy.new(CollapseVector.problem_of(vector), CollapseVector.weights_of(vector))
	assert_array(_planted(vector, planted)).is_not_empty()


func test_a_collapse_that_does_not_propagate_fails() -> void:
	var vector: Dictionary = _vector("checkers-decided-by-one-cell.json")
	var planted := NoPropagation.new(CollapseVector.problem_of(vector), CollapseVector.weights_of(vector))
	assert_array(_planted(vector, planted)).is_not_empty()


func test_a_collapse_blind_to_contradictions_fails() -> void:
	var vector: Dictionary = _vector("three-colours-restart.json")
	var planted := BlindToContradictions.new(CollapseVector.problem_of(vector), CollapseVector.weights_of(vector))
	assert_array(_planted(vector, planted)).is_not_empty()


# T121: a list given as text in a copy of a real file is refused before
# anything reads it, never a SCRIPT ERROR the runner shrugs off.
func test_a_vector_of_the_wrong_types_is_refused_before_it_is_read() -> void:
	var vector: Dictionary = _vector("three-colours-restart.json")
	var paths: Array = [["tiles"], ["collapsed"], ["contradictions"], ["pinned"], ["map"]]
	for path: Array in paths:
		var why: String = CollapseVector.why_not_a_vector(VectorShape.planted(vector, path, "x"))
		assert_str(why).override_failure_message(str(path)).starts_with("C7")