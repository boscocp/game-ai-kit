# Run the conformance vectors in spec/vectors/adversarial against ai_adversarial:
# `xorshift.json` against `GakXorshift`, the `mcts-*.json` files against
# `MonteCarloSearch` on the test folder's Nim and dice race, and
# `expectiminimax-dice-race.json` against `ExpectiminimaxSearch` (T88,
# through `ExpectiminimaxVector`). Python reads the
# same files in `make test-python`, so the two searches cannot part by one
# draw without one of them going red.
#
# Thin for the same reason as the others: every rule it applies lives in
# `MctsVector`, where `mcts_vector_test.gd` hands it broken vectors and a
# planted search and watches it object.
#
#     ./scripts/godot --headless --path godot -s res://test/ai_adversarial/mcts_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/adversarial
#
# Exit codes: 0 every vector passes, 1 a claim failed, 2 the vectors could not
# be read -- which includes finding none at all.
extends SceneTree

const SEARCH_FILES: Array[String] = ["mcts-dice-race.json", "mcts-nim.json"]
const EXPECTIMINIMAX_FILE: String = "expectiminimax-dice-race.json"


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("mcts_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(directory: String) -> int:
	var draws: Variant = _read(directory.path_join("xorshift.json"))
	var unreadable: String = VectorShape.why_not(draws, MctsVector.DRAWS_SHAPE, "xorshift.json")
	if unreadable != "" or (draws["cases"] as Array).is_empty():
		printerr("mcts_vectors_runner: xorshift.json under %s is missing or claims nothing -- %s" % [directory, unreadable])
		return 2
	var failures: Array[String] = []
	for wrong: String in MctsVector.wrong_draws(draws):
		failures.append("xorshift.json: " + wrong)
	var cases: int = 0
	for name: String in SEARCH_FILES:
		var vector: Variant = _read(directory.path_join(name))
		var why: String = MctsVector.why_not_a_vector(vector, name) if vector is Dictionary else "missing, or not JSON"
		if why != "":
			printerr("mcts_vectors_runner: %s is not a search vector -- %s" % [name, why])
			return 2
		cases += (vector["cases"] as Array).size()
		for wrong: String in MctsVector.wrong_claims(vector, MctsVector.addon_search()):
			failures.append("%s: %s" % [name, wrong])
	var expected: Variant = _read(directory.path_join(EXPECTIMINIMAX_FILE))
	var refused: String = "missing, or not JSON"
	if expected is Dictionary:
		refused = ExpectiminimaxVector.why_not_a_vector(expected, EXPECTIMINIMAX_FILE)
	if refused != "":
		printerr("mcts_vectors_runner: %s is not an expectiminimax vector -- %s" % [EXPECTIMINIMAX_FILE, refused])
		return 2
	for wrong: String in ExpectiminimaxVector.wrong_claims(expected, ExpectiminimaxVector.addon_search()):
		failures.append("%s: %s" % [EXPECTIMINIMAX_FILE, wrong])
	for failure: String in failures:
		print(failure)
	print("adversarial vectors: %d draw case(s), %d search case(s), %d expectiminimax case(s), %d failure(s)" % [
			(draws["cases"] as Array).size(), cases, (expected["cases"] as Array).size(), failures.size()])
	return 1 if not failures.is_empty() else 0


func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))
