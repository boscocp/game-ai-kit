# Run the conformance vectors in spec/vectors/tree against ai_learning's
# LearnedTree: the walk half. The fit half is Python's (`make test-python`),
# because only Python fits (invariant 6).
#
#     python3 scripts/godot_checked.py res://test/ai_learning/tree_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/tree
#
# Each vector's model goes through `ModelFile` first, as a published tree
# does, so a vector the reader would refuse fails here rather than being
# walked anyway.
#
# Exit codes: 0 every claim holds, 1 one failed, 2 the vectors could not be
# read -- which includes finding fewer than the three there are.
extends SceneTree

const NAMES: Array[String] = ["fit-by-hand", "fit-capped", "fit-a-tie"]


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("tree_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(directory: String) -> int:
	var vectors: Array[Dictionary] = []
	for name: String in NAMES:
		var read: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(name + ".json")))
		if not read is Dictionary or read.get("cases", []).is_empty():
			printerr("tree_vectors_runner: %s under %s could not be read" % [name, directory])
			return 2
		vectors.append(read)
	if not planted_claims_fail(vectors[0]):
		return 1
	var failures: Array[String] = []
	for index: int in range(vectors.size()):
		failures.append_array(vector_failures(NAMES[index], vectors[index]))
	for failure: String in failures:
		print(failure)
	print("tree vectors: %d vector(s), %d failure(s)" % [vectors.size(), failures.size()])
	return 1 if not failures.is_empty() else 0


## True, and said so, when wrong claims planted in a vector are caught: a
## path that went the other way, a leaf's count changed, and an answer
## where the walk could not finish. A runner that passed those would pass anything.
func planted_claims_fail(vector: Dictionary) -> bool:
	var wrong_path: Dictionary = vector.duplicate(true)
	wrong_path["cases"][0]["path"] = [0, 1]
	var wrong_count: Dictionary = vector.duplicate(true)
	var counts: Dictionary = wrong_count["cases"][0]["counts"]
	counts[counts.keys()[0]] = int(counts.values()[0]) + 1
	var wrong_answer: Dictionary = vector.duplicate(true)
	wrong_answer["cases"][3]["likeliest"] = "high"
	var caught: bool = [wrong_path, wrong_count, wrong_answer].all(
		func(wrong: Dictionary) -> bool: return not vector_failures("planted", wrong).is_empty())
	print("%s: planted, a wrong path, a wrong count and an answer from an unfinished walk %s" % [
		"ok" if caught else "FAIL", "are caught" if caught else "pass unnoticed"])
	return caught


## Every claim of one vector the tree, loaded through `ModelFile`, does not meet.
func vector_failures(name: String, vector: Dictionary) -> Array[String]:
	var published := ModelFile.from_dictionary({"models": {name: vector["model"]}}, name)
	if not published.is_loaded():
		return ["%s: the model file refuses it: %s" % [name, published.error]] as Array[String]
	var tree: LearnedTree = published.tree(name)
	var failures: Array[String] = []
	for case: Dictionary in vector["cases"]:
		failures.append_array(_case_failures(name, tree, case))
	return failures


# The claims of one walk the tree does not meet.
func _case_failures(name: String, tree: LearnedTree, case: Dictionary) -> Array[String]:
	var situation: Dictionary = case["situation"]
	var claims: Array[Array] = [["path", Array(tree.path(situation)), case["path"]],
		["counts", tree.counts(situation), case["counts"]], ["likeliest", tree.likeliest(situation), case["likeliest"]]]
	var failures: Array[String] = []
	for claim: Array in claims:
		if not _same(claim[1], claim[2]):
			failures.append("%s %s: %s is %s, not %s" % [name, situation, claim[0], claim[1], claim[2]])
	return failures


# Equal, with every number compared as a whole one: JSON reads them as floats.
func _same(found: Variant, expected: Variant) -> bool:
	if found is String:
		return found == expected
	if found.size() != expected.size():
		return false
	if found is Dictionary:
		return found.keys().all(func(key: Variant) -> bool: return expected.has(key) and int(found[key]) == int(expected[key]))
	for index: int in range(found.size()):
		if int(found[index]) != int(expected[index]):
			return false
	return true
