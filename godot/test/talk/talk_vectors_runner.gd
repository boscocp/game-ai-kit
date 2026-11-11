# Play every recorded conversation in spec/vectors/talk/ through the game's
# own path, headless, and hold it to the vector: each turn's act or refusal,
# the rule that fired, trust and suspicion, and the outcome.
#
# The path is the game's: `TalkGuard` with a `RecordedRuntime` read from the
# recording file, `LlmConversation`, `LlmValidator`, `TalkRules` -- answers
# arriving frames after each line, as a live server's would. The other half
# is `python/tests/test_talk_vectors.py`, the same files against
# `gameaikit.talk`; `make test-talk-vectors` runs both.
#
#     ./scripts/godot --headless --path godot -s res://test/talk/talk_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/talk
#
# Exit codes: 0 every vector holds, 1 one did not, 2 the vectors could not be
# read -- which includes finding none at all.
extends SceneTree

## The fields of a turn a vector states, compared one by one.
const FIELDS: Array[String] = ["intent", "argument", "refusal_code", "rule", "trust", "suspicion"]
## How many frames a recorded answer may take before the turn counts as lost.
const PATIENCE_FRAMES: int = 30
## The types this runner reads, checked before it reads any (T121). Here a
## cast that fails is worse than a SCRIPT ERROR that exits 0: it aborts the
## awaiting `_run`, `quit` is never called, and the run hangs.
const SHAPE: Dictionary = {
	"recording": VectorShape.TEXT, "outcome": VectorShape.TEXT,
	"turns": [{"intent": VectorShape.TEXT, "argument": VectorShape.TEXT, "refusal_code": VectorShape.TEXT,
			"rule": VectorShape.TEXT, "trust": VectorShape.NUMBER, "suspicion": VectorShape.NUMBER}],
}
## The recording a vector names, as far as this runner reads it.
const RECORDING_SHAPE: Dictionary = {
	"language": VectorShape.TEXT, "turns": [{"player": VectorShape.TEXT, "raw": VectorShape.TEXT}],
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("talk_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	var directory: String = arguments[0]
	var names: PackedStringArray = DirAccess.get_files_at(directory)
	var vectors: Array[String] = []
	for name: String in names:
		if name.ends_with(".json"):
			vectors.append(name)
	if vectors.is_empty():
		printerr("talk_vectors_runner: no .json vectors under %s" % directory)
		quit(2)
		return
	var failures: Array[String] = []
	var turns: int = 0
	for name: String in vectors:
		var vector: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(name)))
		var why: String = VectorShape.why_not(vector, SHAPE, name)
		if why != "":
			printerr("talk_vectors_runner: %s is not a vector -- %s" % [name, why])
			quit(2)
			return
		turns += (vector["turns"] as Array).size()
		failures += await _failures_in(name, vector, directory.path_join("../../..").simplify_path())
	for failure: String in failures:
		print(failure)
	print("talk vectors: %d conversation(s), %d turn(s), %d failure(s)" % [vectors.size(), turns, failures.size()])
	quit(1 if not failures.is_empty() else 0)


# One recording played to its end, each turn against the vector's.
func _failures_in(name: String, vector: Dictionary, repo: String) -> Array[String]:
	var path: String = repo.path_join(vector["recording"])
	var recording: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var unreadable: String = VectorShape.why_not(recording, RECORDING_SHAPE, path)
	if unreadable != "":
		return ["%s: cannot read %s -- %s" % [name, path, unreadable]]
	var guard := TalkGuard.new(recording["language"])
	root.add_child(guard)
	guard.use_runtime(RecordedRuntime.from_file(path))
	var failures: Array[String] = []
	for index: int in (vector["turns"] as Array).size():
		if guard.say(recording["turns"][index]["player"]) != OK:
			failures.append("%s, turn %d: the guard would not listen" % [name, index + 1])
			break
		await _answered(guard)
		failures += _compare(name, index, guard.turns, vector["turns"][index])
	if guard.state["outcome"] != vector["outcome"]:
		failures.append("%s: outcome %s, the vector says %s" % [name, guard.state["outcome"], vector["outcome"]])
	guard.free()
	return failures


# Waits until the guard has ruled, PATIENCE_FRAMES frames at most.
func _answered(guard: TalkGuard) -> void:
	for frame: int in PATIENCE_FRAMES:
		if not guard.is_thinking():
			return
		await process_frame


func _compare(name: String, index: int, played: Array[Dictionary], wanted: Dictionary) -> Array[String]:
	if played.size() <= index:
		return ["%s, turn %d: no answer within %d frames" % [name, index + 1, PATIENCE_FRAMES]]
	var failures: Array[String] = []
	for field: String in FIELDS:
		# JSON's numbers parse as floats; the guard's are whole.
		var expected: Variant = int(wanted[field]) if wanted[field] is float else wanted[field]
		var found: String = str(played[index][field])
		if found != str(expected):
			failures.append("%s, turn %d: %s is %s, the vector says %s" % [name, index + 1, field, found, expected])
	return failures
