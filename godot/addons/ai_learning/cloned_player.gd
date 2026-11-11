## A recorded player, published: the model fitted to its decisions and the
## table of its cases, loaded from `clone_weights.json`, or refused (T18).
##
## Both come out of one Python run over the same recorded rows, which is why
## they share a file: the cloned model and the ghost are two ways of using
## one player's play, and a comparison between them only means something if
## neither was built from more of it than the other.
##
## Like `ModelFile`, it is about refusing: a file with anything wrong with it
## gives no model and no table, and an `error` with a code, because a model
## built from a half-read file plays, and nobody can tell that from a clone.
##
## When not to use it: weights for anything but situations written as words.
class_name ClonedPlayer
extends RefCounted

## The fields the file must have.
const FIELDS: Array[String] = ["generated_by", "trained_on", "features", "classes", "model", "cases"]

## Why the file is unusable, or "" when it loaded.
var error: String = ""
## What wrote it, and the recordings it was fitted on, for the panel.
var generated_by: String = ""
var trained_on: Dictionary = {}
## The model and the ghost's table; null when refused.
var model: SoftmaxModel
var cases: CaseTable


## The cloned player at `path`, loaded and checked; never half built.
static func load_from(path: String) -> ClonedPlayer:
	if not FileAccess.file_exists(path):
		return _refused("C1 no cloned player at %s -- run `make train-clone`" % path)
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return _refused("C2 %s is not JSON: %s" % [path, parser.get_error_message()])
	return from_dictionary(parser.data)


## The cloned player in `data`, as the file holds it, or refused. Public so a
## test can plant each refusal.
static func from_dictionary(data: Variant) -> ClonedPlayer:
	var wrong: String = _why_wrong(data)
	if wrong != "":
		return _refused(wrong)
	var loaded: ClonedPlayer = new()
	loaded.generated_by = data["generated_by"]
	loaded.trained_on = data["trained_on"]
	var weights: Array[PackedFloat64Array] = []
	for row: Array in data["model"]["weights"]:
		weights.append(PackedFloat64Array(row))
	loaded.model = SoftmaxModel.new(PackedStringArray(data["classes"]), PackedStringArray(data["model"]["columns"]),
			weights, PackedFloat64Array(data["model"]["bias"]))
	loaded.cases = CaseTable.new(PackedStringArray(data["features"]), data["cases"])
	return loaded


## True when the file loaded.
func is_loaded() -> bool:
	return error == ""


# The first thing wrong with `data`, with its code, or "".
static func _why_wrong(data: Variant) -> String:
	if not data is Dictionary:
		return "C3 the file is not a JSON object"
	for field: String in FIELDS:
		if not data.has(field):
			return "C3 no \"%s\" in the file" % field
	for field: String in ["features", "classes"]:
		if not _all_words(data[field]) or data[field].is_empty():
			return "C4 \"%s\" is not a list of words" % field
	var wrong: String = _why_model_is_wrong(data["model"], data["classes"].size())
	return wrong if wrong != "" else _why_cases_are_wrong(data["cases"], data["features"].size())


# What is wrong with the model block, for `answers` answers, or "".
static func _why_model_is_wrong(model: Variant, answers: int) -> String:
	if not model is Dictionary or not model.has_all(["columns", "weights", "bias"]):
		return "C3 \"model\" needs \"columns\", \"weights\" and \"bias\""
	if not _all_words(model["columns"]):
		return "C4 \"columns\" is not a list of words"
	if not model["weights"] is Array or not model["bias"] is Array:
		return "C5 the weights and the bias are not lists"
	var sizes: Array[int] = [model["weights"].size(), model["bias"].size(), answers]
	if sizes[0] != answers or sizes[1] != answers:
		return "C5 the model has %d weight rows and %d biases for %d answers" % sizes
	if not _all_numbers(model["bias"]):
		return "C6 a bias is not a number"
	for row: Variant in model["weights"]:
		if not row is Array or row.size() != model["columns"].size():
			return "C5 a weight row is not one number per column (%d columns)" % model["columns"].size()
		if not _all_numbers(row):
			return "C6 a weight is not a number"
	return ""


# What is wrong with the cases, each keyed by `words` words, or "".
static func _why_cases_are_wrong(cases: Variant, words: int) -> String:
	if not cases is Dictionary:
		return "C4 \"cases\" is not a table"
	for key: Variant in cases:
		if not key is String or key.split(CaseTable.JOINER).size() != words:
			return "C7 the case \"%s\" is not %d words" % [key, words]
		if not cases[key] is Dictionary or not _all_numbers(cases[key].values()):
			return "C7 the case \"%s\" does not count its answers in numbers" % key
	return ""


static func _all_words(list: Variant) -> bool:
	return list is Array and list.all(func(item: Variant) -> bool: return item is String)


static func _all_numbers(list: Variant) -> bool:
	return list is Array and list.all(func(item: Variant) -> bool: return item is float or item is int)


static func _refused(reason: String) -> ClonedPlayer:
	var refused: ClonedPlayer = new()
	refused.error = reason
	return refused
