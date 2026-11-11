# Run the conformance vectors in spec/vectors/constraints against ai_constraints:
# the solver's, and in `collapse/` beside them wave function collapse's (T96).
#
# Thin for the same reason as the others: every rule it applies lives in
# `ConstraintVector` and `CollapseVector`, where `constraint_vector_test.gd`
# and `collapse_vector_test.gd` hand them broken vectors and planted solvers
# and watch them object.
#
#     ./scripts/godot --headless --path godot -s res://test/ai_constraints/constraint_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/constraints
#
# Exit codes: 0 every vector passes, 1 a claim failed, 2 the vectors could not
# be read -- which includes finding none at all.
extends SceneTree


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("constraint_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	var solved: int = _run(arguments[0])
	var collapsed: int = _run_collapse(arguments[0].path_join("collapse"))
	quit(maxi(solved, collapsed))


# The `.json` files in `directory`, by name; none is reported, by the caller.
func _vectors_in(directory: String) -> Array[String]:
	var vectors: Array[String] = []
	for name: String in DirAccess.get_files_at(directory):
		if name.ends_with(".json"):
			vectors.append(name)
	if vectors.is_empty():
		printerr("constraint_vectors_runner: no .json vectors under %s" % directory)
	return vectors


func _run(directory: String) -> int:
	var vectors: Array[String] = _vectors_in(directory)
	if vectors.is_empty():
		return 2
	var failures: Array[String] = []
	for name: String in vectors:
		var vector: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(name)))
		var wrong: String = ConstraintVector.why_not_a_vector(vector, name) if vector is Dictionary else "not JSON"
		if wrong != "":
			printerr("constraint_vectors_runner: %s is not a constraint vector -- %s" % [name, wrong])
			return 2
		for claim: String in ConstraintVector.wrong_claims(vector, ConstraintVector.solver_of(vector)):
			failures.append("%s: %s" % [name, claim])
	for failure: String in failures:
		print(failure)
	print("constraint vectors: %d vector(s), %d failure(s)" % [vectors.size(), failures.size()])
	return 1 if not failures.is_empty() else 0


func _run_collapse(directory: String) -> int:
	var vectors: Array[String] = _vectors_in(directory)
	if vectors.is_empty():
		return 2
	var failures: Array[String] = []
	for name: String in vectors:
		var vector: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(name)))
		var wrong: String = CollapseVector.why_not_a_vector(vector, name) if vector is Dictionary else "not JSON"
		if wrong != "":
			printerr("constraint_vectors_runner: %s is not a collapse vector -- %s" % [name, wrong])
			return 2
		for claim: String in CollapseVector.wrong_claims(vector, CollapseVector.collapse_of(vector)):
			failures.append("collapse/%s: %s" % [name, claim])
	for failure: String in failures:
		print(failure)
	print("collapse vectors: %d vector(s), %d failure(s)" % [vectors.size(), failures.size()])
	return 1 if not failures.is_empty() else 0
