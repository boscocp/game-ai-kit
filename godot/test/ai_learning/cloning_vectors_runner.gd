# Run the conformance vectors in spec/vectors/cloning against ai_learning's
# SoftmaxModel and CaseTable.
#
#     ./scripts/godot --headless --path godot -s res://test/ai_learning/cloning_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/cloning
#
# Exit codes: 0 every claim holds, 1 one failed, 2 the vectors could not be
# read -- which includes finding fewer than the two there are.
extends SceneTree

const TOLERANCE: float = 1e-12


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("cloning_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(directory: String) -> int:
	var softmax: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("softmax-by-hand.json")))
	var ghost: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("ghost-by-hand.json")))
	if not softmax is Dictionary or not ghost is Dictionary or softmax["cases"].is_empty() or ghost["cases"].is_empty():
		printerr("cloning_vectors_runner: the two vectors under %s could not be read" % directory)
		return 2
	if not planted_vectors_fail(softmax, ghost):
		return 1
	var failures: Array[String] = softmax_failures(softmax) + ghost_failures(ghost)
	for failure: String in failures:
		print(failure)
	print("cloning vectors: 2 vector(s), %d failure(s)" % failures.size())
	return 1 if not failures.is_empty() else 0


## True, and said so, when a wrong claim planted in each vector is caught:
## a likeliest answer changed, and a nearest distance changed. A runner that
## passed those would pass anything.
func planted_vectors_fail(softmax: Dictionary, ghost: Dictionary) -> bool:
	var wrong_softmax: Dictionary = softmax.duplicate(true)
	wrong_softmax["cases"][0]["likeliest"] = "nobody's answer"
	var wrong_ghost: Dictionary = ghost.duplicate(true)
	wrong_ghost["cases"][0]["distance"] = int(wrong_ghost["cases"][0]["distance"]) + 1
	var caught: bool = not softmax_failures(wrong_softmax).is_empty() and not ghost_failures(wrong_ghost).is_empty()
	print("%s: planted, a wrong likeliest and a wrong distance %s" % ["ok" if caught else "FAIL",
		"are caught" if caught else "pass unnoticed"])
	return caught


## Every claim of the softmax vector `SoftmaxModel` does not meet.
func softmax_failures(vector: Dictionary) -> Array[String]:
	var weights: Array[PackedFloat64Array] = []
	for row: Array in vector["model"]["weights"]:
		weights.append(PackedFloat64Array(row))
	var model := SoftmaxModel.new(PackedStringArray(vector["model"]["classes"]),
			PackedStringArray(vector["model"]["columns"]), weights, PackedFloat64Array(vector["model"]["bias"]))
	var failures: Array[String] = []
	for case: Dictionary in vector["cases"]:
		failures.append_array(_softmax_case(model, case))
	return failures


# The claims of one softmax case the model does not meet.
func _softmax_case(model: SoftmaxModel, case: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var chances: Dictionary = model.probabilities(case["situation"])
	var claimed: Dictionary = case["probabilities"]
	for answer: String in claimed:
		if absf(chances[answer] - float(claimed[answer])) > TOLERANCE:
			failures.append("softmax %s: %s is %s, not %s" % [case["situation"], answer, chances[answer], claimed[answer]])
	if model.likeliest(case["situation"]) != case["likeliest"]:
		failures.append("softmax %s: likeliest is not %s" % [case["situation"], case["likeliest"]])
	return failures


## Every claim of the ghost vector `CaseTable` does not meet.
func ghost_failures(vector: Dictionary) -> Array[String]:
	var table := CaseTable.new(PackedStringArray(vector["features"]), vector["table"])
	var failures: Array[String] = []
	for case: Dictionary in vector["cases"]:
		failures.append_array(_ghost_case(table, case))
	return failures


# The claims of one ghost case the table does not meet.
func _ghost_case(table: CaseTable, case: Dictionary) -> Array[String]:
	var nearest: Dictionary = table.nearest(case["situation"])
	var claims: Array[Array] = [["exact", table.exact(case["situation"]), case["exact"]],
		["distance", nearest["distance"], int(case["distance"])], ["nearest", nearest["counts"], case["nearest"]]]
	var failures: Array[String] = []
	for claim: Array in claims:
		if not _same(claim[1], claim[2]):
			failures.append("ghost %s: %s is %s, not %s" % [case["situation"], claim[0], claim[1], claim[2]])
	return failures


# Equal as numbers: JSON reads every count back as a float.
func _same(found: Variant, expected: Variant) -> bool:
	if found is Dictionary:
		if found.size() != expected.size():
			return false
		return found.keys().all(func(key: Variant) -> bool: return expected.has(key) and int(found[key]) == int(expected[key]))
	return int(found) == int(expected)
