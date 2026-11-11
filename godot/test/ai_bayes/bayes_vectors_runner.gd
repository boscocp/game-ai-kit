# Run the conformance vectors in spec/vectors/bayes against ai_bayes.
#
# Thin for the same reason as the others: every rule it applies lives in
# `BayesVector`, where `bayes_vector_test.gd` hands it broken vectors and
# planted networks and watches it object. Run through godot_checked.py, so
# a SCRIPT ERROR that empties a typed answer fails it too.
#
#     python3 scripts/godot_checked.py res://test/ai_bayes/bayes_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/bayes
#
# Exit codes: 0 every vector passes, 1 a claim failed, 2 the vectors could not
# be read -- which includes finding none at all.
extends SceneTree


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("bayes_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(directory: String) -> int:
	var vectors: Array[String] = []
	for name: String in DirAccess.get_files_at(directory):
		if name.ends_with(".json"):
			vectors.append(name)
	if vectors.is_empty():
		printerr("bayes_vectors_runner: no .json vectors under %s" % directory)
		return 2
	var failures: Array[String] = []
	var queries: int = 0
	for name: String in vectors:
		var vector: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(name)))
		var wrong: String = BayesVector.why_not_a_vector(vector, name) if vector is Dictionary else "not JSON"
		if wrong != "":
			printerr("bayes_vectors_runner: %s is not a Bayesian network vector -- %s" % [name, wrong])
			return 2
		queries += (vector["queries"] as Array).size()
		for claim: String in BayesVector.wrong_claims(vector, BayesVector.network_of(vector)):
			failures.append("%s: %s" % [name, claim])
	for failure: String in failures:
		print(failure)
	print("bayes vectors: %d vector(s), %d query(ies), %d failure(s)" % [vectors.size(), queries, failures.size()])
	return 1 if not failures.is_empty() else 0
