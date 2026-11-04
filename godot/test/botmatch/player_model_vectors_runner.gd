# Run the conformance vectors in spec/vectors/player_model against Godot's
# `PlayerModel` (T100).
#
# Each vector is the person's events and every interval's reading over
# them -- the counts, the share, the hit rate, the row and its aim error;
# `PlayerModel.replay` must reproduce them through the bot match's own
# table (`ModelConformance`). The files are read by `ModelVectorFiles`,
# which holds no model, so this script reads none itself (N14). The Python
# half is `python/tests/test_player_model_vectors.py`; the answers came
# from neither, from `spec/vectors/player_model/derive.py`.
#
#     ./scripts/godot --headless --path godot -s res://test/botmatch/player_model_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/player_model
#
# Exit codes: 0 every reading matches, 1 one did not, 2 the vectors could
# not be read -- which includes finding none, because a conformance run
# that inspects nothing and reports success is the failure this repository
# is arranged against.
extends SceneTree

const FIELDS: Array[String] = ["description", "last_step", "events", "readings"]


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("player_model_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(directory: String) -> int:
	var vectors: Dictionary = ModelVectorFiles.read_all(directory)
	if vectors.is_empty():
		printerr("player_model_vectors_runner: no .json vectors under %s" % directory)
		return 2
	var rules := MatchRules.new()
	var failures: Array[String] = []
	var readings: int = 0
	for name: String in vectors:
		var vector: Dictionary = vectors[name]
		if not vector.has_all(FIELDS) or (vector["readings"] as Array).is_empty():
			printerr("player_model_vectors_runner: %s is missing one of %s, or has no reading" % [name, FIELDS])
			return 2
		readings += (vector["readings"] as Array).size()
		failures += ModelConformance.check_vector(name, vector, rules)
	for failure: String in failures:
		print(failure)
	print("player model vectors: %d file(s), %d reading(s), %d failure(s)" % [vectors.size(), readings, failures.size()])
	return 1 if not failures.is_empty() else 0
