# Run the conformance vectors in spec/vectors/forest against ai_learning's
# LearnedForest: the vote half. The fit half is Python's (`make test-python`),
# because only Python fits (invariant 6).
#
#     python3 scripts/godot_checked.py res://test/ai_learning/forest_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/forest
#
# Each vector's model goes through `ModelFile` first, as a published forest
# does, so a vector the reader would refuse fails here rather than being
# asked anyway.
#
# Exit codes: 0 every claim holds, 1 one failed, 2 the vectors could not be
# read -- which includes finding fewer than the two there are.
extends SceneTree

const NAMES: Array[String] = ["three-trees", "a-tied-vote"]


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("forest_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(directory: String) -> int:
	var vectors: Array[Dictionary] = []
	for name: String in NAMES:
		var read: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(name + ".json")))
		if not read is Dictionary or read.get("cases", []).is_empty():
			printerr("forest_vectors_runner: %s under %s could not be read" % [name, directory])
			return 2
		vectors.append(read)
	if not planted_claims_fail(vectors[1]):
		return 1
	var failures: Array[String] = []
	for index: int in range(vectors.size()):
		failures.append_array(vector_failures(NAMES[index], vectors[index]))
	for failure: String in failures:
		print(failure)
	print("forest vectors: %d vector(s), %d failure(s)" % [vectors.size(), failures.size()])
	return 1 if not failures.is_empty() else 0


## True, and said so, when wrong claims planted in a vector are caught: one
## tree's vote changed, a tally off by one, and a tie settled by whichever
## tree voted first rather than by `classes`. A runner that passed those
## would pass anything.
func planted_claims_fail(vector: Dictionary) -> bool:
	var wrong_vote: Dictionary = vector.duplicate(true)
	wrong_vote["cases"][1]["votes"][3] = "high"
	var wrong_tally: Dictionary = vector.duplicate(true)
	var tally: Dictionary = wrong_tally["cases"][1]["tally"]
	tally[tally.keys()[0]] = int(tally.values()[0]) + 1
	var first_voter: Dictionary = vector.duplicate(true)
	first_voter["cases"][0]["likeliest"] = first_voter["cases"][0]["votes"][0]
	var caught: bool = [wrong_vote, wrong_tally, first_voter].all(
		func(wrong: Dictionary) -> bool: return not vector_failures("planted", wrong).is_empty())
	print("%s: planted, a wrong vote, a wrong tally and a tie given to the first voter %s" % [
		"ok" if caught else "FAIL", "are caught" if caught else "pass unnoticed"])
	return caught


## Every claim of one vector the forest, loaded through `ModelFile`, does not meet.
func vector_failures(name: String, vector: Dictionary) -> Array[String]:
	var published := ModelFile.from_dictionary({"models": {name: vector["model"]}}, name)
	if not published.is_loaded():
		return ["%s: the model file refuses it: %s" % [name, published.error]] as Array[String]
	var forest: LearnedForest = published.forest(name)
	var failures: Array[String] = []
	for case: Dictionary in vector["cases"]:
		failures.append_array(_case_failures(name, forest, case))
	return failures


# The claims of one question the forest does not meet.
func _case_failures(name: String, forest: LearnedForest, case: Dictionary) -> Array[String]:
	var situation: Dictionary = case["situation"]
	var cast: PackedStringArray = forest.votes(situation)
	var claims: Array[Array] = [["votes", Array(cast), case["votes"]],
		["tally", forest.tally_of(cast), case["tally"]], ["likeliest", forest.likeliest(situation), case["likeliest"]]]
	var failures: Array[String] = []
	for claim: Array in claims:
		if not _same(claim[1], claim[2]):
			failures.append("%s %s: %s is %s, not %s" % [name, situation, claim[0], claim[1], claim[2]])
	return failures


# Equal: words as words, a tally's counts as whole numbers -- JSON reads them as floats.
func _same(found: Variant, expected: Variant) -> bool:
	if found is String:
		return found == expected
	if found.size() != expected.size():
		return false
	if found is Dictionary:
		return found.keys().all(func(key: Variant) -> bool: return expected.has(key) and int(found[key]) == int(expected[key]))
	for index: int in range(found.size()):
		if str(found[index]) != str(expected[index]):
			return false
	return true
