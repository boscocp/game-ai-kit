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

## Every field read from a vector and its type, checked before any is read
## (T121): a cast that fails in a `-s` script is a SCRIPT ERROR the run
## survives, printing "0 failure(s)".
const SHAPE: Dictionary = {
	"description": VectorShape.TEXT, "last_step": VectorShape.NUMBER,
	"events": [{"step": VectorShape.NUMBER, "kind": VectorShape.TEXT, "points?": VectorShape.NUMBER,
			"team?": VectorShape.NUMBER}],
	"readings": [{"step": VectorShape.NUMBER, "counts": {"*": VectorShape.NUMBER}, "share": VectorShape.NUMBER,
			"hit_rate": VectorShape.NUMBER, "row": VectorShape.NUMBER, "aim_error_degrees": VectorShape.NUMBER,
			"held": VectorShape.FLAG}],
}


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
		var why: String = VectorShape.why_not(vector, SHAPE, name)
		if why != "" or (vector["readings"] as Array).is_empty():
			printerr("player_model_vectors_runner: %s" % (why if why != "" else name + " has no reading"))
			return 2
		readings += (vector["readings"] as Array).size()
		failures += ModelConformance.check_vector(name, vector, rules)
	for failure: String in failures:
		print(failure)
	print("player model vectors: %d file(s), %d reading(s), %d failure(s)" % [vectors.size(), readings, failures.size()])
	return 1 if not failures.is_empty() else 0
