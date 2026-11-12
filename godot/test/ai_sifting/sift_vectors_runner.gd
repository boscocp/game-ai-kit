# Run the conformance vectors in spec/vectors/sifting against ai_sifting.
#
# Thin for the same reason as the others: every rule it applies lives in
# `SiftVector`, where `sift_vector_test.gd` hands it broken vectors and
# planted sifters and watches it object.
#
#     ./scripts/godot --headless --path godot -s res://test/ai_sifting/sift_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/sifting
#
# Exit codes: 0 every vector passes, 1 a claim failed, 2 the vectors could not
# be read -- which includes finding none at all.
extends SceneTree


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("sift_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(directory: String) -> int:
	var vectors: Array[String] = []
	for name: String in DirAccess.get_files_at(directory):
		if name.ends_with(".json"):
			vectors.append(name)
	if vectors.is_empty():
		printerr("sift_vectors_runner: no .json vectors under %s" % directory)
		return 2
	var failures: Array[String] = []
	for name: String in vectors:
		var vector: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(name)))
		var wrong: String = SiftVector.why_not_a_vector(vector, name) if vector is Dictionary else "not JSON"
		if wrong != "":
			printerr("sift_vectors_runner: %s is not a sifting vector -- %s" % [name, wrong])
			return 2
		for claim: String in SiftVector.wrong_claims(vector, StorySifter.new()):
			failures.append("%s: %s" % [name, claim])
	for failure: String in failures:
		print(failure)
	print("sifting vectors: %d vector(s), %d failure(s)" % [vectors.size(), failures.size()])
	return 1 if not failures.is_empty() else 0
