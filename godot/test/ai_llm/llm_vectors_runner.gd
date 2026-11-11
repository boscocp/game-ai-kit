# Run the conformance vectors in spec/vectors/llm against ai_llm's LlmValidator.
#
# Each file declares one game and lists raw replies, each claiming the code
# of the first rule it breaks or the speech, intent and argument the game
# may act on. `python/tests/test_llm_vectors.py` holds gameaikit.llm to the
# same files; `make test-llm-vectors` runs both.
#
#     ./scripts/godot --headless --path godot -s res://test/ai_llm/llm_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/llm
#
# Exit codes: 0 every case passes, 1 a case failed, 2 the vectors could not be
# read -- which includes finding none at all, and a game the validator refuses.
extends SceneTree

## The types this runner reads, checked before it reads any (T121): a cast
## that fails in a `-s` script is a SCRIPT ERROR the run would survive.
## `format_controls` is Python's alone, and still held to its types.
const SHAPE: Dictionary = {
	"declaration": {"intents": {"*": [VectorShape.TEXT]}, "fallback_speech": VectorShape.TEXT,
			"secrets?": [VectorShape.TEXT]},
	"cases": [{"raw": VectorShape.TEXT, "why": VectorShape.TEXT, "refused?": VectorShape.TEXT,
			"accepted?": {"speech": VectorShape.TEXT, "intent": VectorShape.TEXT, "argument": VectorShape.TEXT}}],
	"format_controls?": {"runs": [[VectorShape.TEXT]], "unicode": VectorShape.TEXT, "why": VectorShape.TEXT},
}


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("llm_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(directory: String) -> int:
	var files: PackedStringArray = _vector_files(directory)
	if files.is_empty():
		printerr("llm_vectors_runner: no .json vectors under %s" % directory)
		return 2
	var failures: Array[String] = []
	var cases: int = 0
	for name: String in files:
		var vector: Dictionary = _read_vector(directory.path_join(name))
		var why: String = VectorShape.why_not(vector, SHAPE, name)
		if why != "":
			printerr("llm_vectors_runner: %s" % why)
			return 2
		var validator: LlmValidator = validator_of(vector["declaration"])
		var unusable: String = validator.problem()
		if unusable != "":
			printerr("llm_vectors_runner: %s declares a game the validator refuses: %s" % [name, unusable])
			return 2
		cases += (vector["cases"] as Array).size()
		failures += _failures_in(name, validator, vector["cases"])
	for failure: String in failures:
		print(failure)
	print("llm vectors: %d file(s), %d case(s), %d failure(s)" % [
		files.size(), cases, failures.size()])
	return 1 if not failures.is_empty() else 0


# Every case in one file whose answer is not the one it claims.
func _failures_in(name: String, validator: LlmValidator, cases: Array) -> Array[String]:
	var failures: Array[String] = []
	for case: Dictionary in cases:
		var got: String = answer(validator, case["raw"])
		if got != claimed(case):
			failures.append("%s: %s\n  claimed %s, got %s" % [name, case["why"], claimed(case), got])
		# A game shows the refusal: it never quotes a secret or markup the
		# model wrote in a key, an intent or an argument (T93's review).
		var refusal: String = validator.validate(case["raw"]).refusal
		if validator.gives_away_a_secret(refusal) or refusal.contains("[b]"):
			failures.append("%s: %s\n  the refusal quotes the model: %s" % [name, case["why"], refusal])
	return failures


## The validator for a vector file's game.
static func validator_of(declaration: Dictionary) -> LlmValidator:
	return LlmValidator.new(declaration["intents"], declaration["fallback_speech"],
		PackedStringArray(declaration.get("secrets", [])))


## What LlmValidator makes of one raw reply, in the string `claimed` writes.
static func answer(validator: LlmValidator, raw_text: String) -> String:
	var reply: LlmReply = validator.validate(raw_text)
	if not reply.is_accepted():
		return reply.refusal_code()
	return JSON.stringify([reply.speech, reply.intent, reply.argument])


## What the vector claims for the same case.
static func claimed(case: Dictionary) -> String:
	if case.has("refused"):
		return case["refused"]
	var accepted: Dictionary = case["accepted"]
	return JSON.stringify([accepted["speech"], accepted["intent"], accepted["argument"]])


func _vector_files(directory: String) -> PackedStringArray:
	var folder: DirAccess = DirAccess.open(directory)
	if folder == null:
		return PackedStringArray()
	var found := PackedStringArray()
	for name: String in folder.get_files():
		if name.ends_with(".json"):
			found.append(name)
	found.sort()
	return found


# The vector at this path, or {} when it cannot be read as an object.
func _read_vector(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var reader := JSON.new()
	if reader.parse(file.get_as_text()) != OK:
		return {}
	return reader.data if reader.data is Dictionary else {}
