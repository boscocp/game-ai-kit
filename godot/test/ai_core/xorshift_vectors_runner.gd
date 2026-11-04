# Run the conformance vectors in spec/vectors/core against ai_core's
# `Xorshift`. Python reads the same file in `make test-python`, through
# `gameaikit.core`, so the two generators cannot part by one draw without
# one of them going red.
#
# Thin for the same reason as the others: every rule it applies lives in
# `XorshiftVector`, where `xorshift_test.gd` hands it broken vectors and
# planted generators and watches it object.
#
#     ./scripts/godot --headless --path godot -s res://test/ai_core/xorshift_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/core
#
# Exit codes: 0 every vector passes, 1 a claim failed, 2 the vectors could not
# be read -- which includes finding none at all.
extends SceneTree


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("xorshift_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(directory: String) -> int:
	var path: String = directory.path_join("xorshift.json")
	var vector: Variant = null
	if FileAccess.file_exists(path):
		vector = JSON.parse_string(FileAccess.get_file_as_string(path))
	var why: String = XorshiftVector.why_not_a_vector(vector) if vector is Dictionary else "missing, or not JSON"
	if why != "":
		printerr("xorshift_vectors_runner: %s is not a core vector -- %s" % [path, why])
		return 2
	var failures: Array[String] = XorshiftVector.wrong_claims(vector, XorshiftVector.core_generator())
	for failure: String in failures:
		print("xorshift.json: " + failure)
	print("core vectors: %d seed(s), %d failure(s)" % [(vector["cases"] as Array).size(), failures.size()])
	return 1 if not failures.is_empty() else 0
