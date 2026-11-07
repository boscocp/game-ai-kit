## Loads a model file, or says in one sentence why it will not.
##
## Everything here is about refusing. A model built from a half-read file
## predicts from zeros, and nobody can tell that from a decision -- so a file
## with anything wrong with it yields no models at all and an `error` to put
## on screen. The rules are in `_why_wrong`, each with a code, and
## `from_dictionary` is public so a test can plant each one.
##
## The format, which `gameaikit.training.model_file` writes: a JSON object
## whose `models` maps a name to `kind`, `features`, `weights` and `bias` --
## or, for a decision tree (T113), `kind`, `features`, `classes` and `nodes`.
## Anything else at the top level is the publishing game's, and is handed to
## it unread in `extra` -- what those fields must hold is that game's rule to
## check, on top of this one. Complexity: one pass over the numbers.
##
## When not to use it: a model that is neither one weight per feature nor a
## single tree.
class_name ModelFile
extends RefCounted

## The fields every published model carries.
const MODEL_FIELDS: Array[String] = ["kind", "features", "weights", "bias"]
## The fields a published tree carries instead.
const TREE_FIELDS: Array[String] = ["kind", "features", "classes", "nodes"]

## Why this file is unusable, or "" when it loaded. One sentence, not a list:
## the first thing wrong with a weights file is the thing to fix, and a screen
## full of consequences buries it.
var error: String = ""

## What wrote the file. Carried so a reader can tell a published artifact from
## a table somebody typed.
var generated_by: String = ""

## Every top-level field but `models`, as the file wrote it and unchecked.
## Where a game publishes the numbers it needs that are not weights -- a
## radius, a sentinel -- and checks them itself, because only that game knows
## what they mean. Empty on a refused file.
var extra: Dictionary = {}

# Model name to LearnedModel. Private: `model()` is how it is read, so an
# absent name answers null rather than whatever a dictionary lookup does.
var _models: Dictionary = {}
# Model name to LearnedTree, read by `tree()` for the same reason.
var _trees: Dictionary = {}


## The model file at `path`, loaded and checked.
##
## Never null and never half built: on any refusal the result carries `error`
## and no models at all.
static func load_from(path: String) -> ModelFile:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _refused("M1 no model file at %s" % path)
	return from_text(file.get_as_text(), path)


## The same checks, over the text of a file already in hand -- one a game
## keeps inside a resource, say, rather than at a path.
static func from_text(text: String, source: String) -> ModelFile:
	# `JSON.new().parse()` rather than the static `JSON.parse_string()`.
	# Measured on the pinned engine: the static one prints an engine error to
	# the console on bad input and then returns null, so a file this type is
	# about to refuse politely has already filled the log on its way past --
	# and a log full of errors during a normal run is a log nobody reads.
	# This form returns the code and hands over the parser's own message,
	# which is more than the static one tells the caller anyway.
	# The line is counted from 1 here, as an editor and the Python side count
	# it: measured on the pinned engine, `get_error_line()` counts from 0.
	var reader := JSON.new()
	if reader.parse(text) != OK:
		return _refused("M2 %s is not JSON: %s, at line %d" % [
			source, reader.get_error_message(), reader.get_error_line() + 1,
		])
	if not (reader.data is Dictionary):
		return _refused("M2 %s is JSON, but not an object" % source)
	return from_dictionary(reader.data, source)


## The same checks, over content already in hand.
static func from_dictionary(data: Dictionary, source: String) -> ModelFile:
	var wrong: String = _why_wrong(data)
	if wrong != "":
		return _refused("%s (%s)" % [wrong, source])

	var loaded := ModelFile.new()
	loaded.generated_by = str(data.get("generated_by", "unknown"))
	loaded.extra = data.duplicate(true)
	loaded.extra.erase("models")
	for name: String in data["models"]:
		var entry: Dictionary = data["models"][name]
		if entry["kind"] == LearnedTree.KIND:
			loaded._trees[name] = LearnedTree.from_entry(entry)
		else:
			loaded._models[name] = _model_from(entry)
	return loaded


## True when there are models to predict with.
func is_loaded() -> bool:
	return error == ""


## The weighted model published under this name, or null -- null for a tree.
func model(name: String) -> LearnedModel:
	return _models.get(name)


## The tree published under this name, or null -- null for a weighted model.
func tree(name: String) -> LearnedTree:
	return _trees.get(name)


## The names this file publishes, trees and weighted models alike, sorted.
## For a report, and for a test that wants to assert what is in there
## without knowing the order.
func model_names() -> PackedStringArray:
	var names := PackedStringArray(_models.keys() + _trees.keys())
	names.sort()
	return names


# What is wrong with this content, as the sentence to show, or "".
static func _why_wrong(data: Dictionary) -> String:
	if not (data.get("models") is Dictionary) or data["models"].is_empty():
		return "M3 the file publishes no models"
	for name: String in data["models"]:
		var wrong: String = _why_model_is_wrong(name, data["models"][name])
		if wrong != "":
			return wrong
	# There is no M9. It was a rule about one game's own fields, which that
	# game now checks over `extra`; the codes are identifiers, not a count.
	return ""


# One model: present, the right shape, and every number a number.
static func _why_model_is_wrong(name: String, entry: Variant) -> String:
	# M10 rather than a second M4. Two rules shared that code until a review
	# pointed out that a test asserting `contains("M4")` could not tell which
	# of them had fired -- and a planted case that cannot name its rule is
	# half a planted case. The numbering is identifiers, not an order.
	# The kind is read before the other fields, because which fields a
	# model must have depends on it: a tree has no weights to miss.
	if not (entry is Dictionary):
		return "M10 model `%s` is not an object" % name
	if not entry.has("kind"):
		return "M4 model `%s` has no `kind`" % name
	var kind: String = str(entry["kind"])
	if not (LearnedModel.KINDS.has(kind) or kind == LearnedTree.KIND):
		return "M5 model `%s` is of kind `%s`, which nothing here can evaluate" % [name, kind]
	for field: String in TREE_FIELDS if kind == LearnedTree.KIND else MODEL_FIELDS:
		if not entry.has(field):
			return "M4 model `%s` has no `%s`" % [name, field]
	var features: String = _why_features_are_wrong(name, entry["features"])
	if features != "":
		return features
	if kind == LearnedTree.KIND:
		return _why_tree_is_wrong(name, entry)
	return _why_weights_are_wrong(name, entry)


# A tree: its answers named, then every node a sound test or leaf. The
# nodes are walked once, first to last, each checked whole before the next,
# so the first wrong node is the one reported -- as the Python side does.
static func _why_tree_is_wrong(name: String, entry: Dictionary) -> String:
	var classes: Variant = entry["classes"]
	if not (classes is Array) or (classes as Array).is_empty() or not _distinct_words(classes):
		return "M11 tree `%s` does not name its answers: `classes` must be distinct words" % name
	var nodes: Variant = entry["nodes"]
	if not (nodes is Array) or (nodes as Array).is_empty():
		return "M12 tree `%s` has no nodes" % name
	for index: int in range(nodes.size()):
		var where: String = "tree `%s` node %d" % [name, index]
		var wrong: String = _why_node_is_wrong(where, index, nodes[index], entry["features"], classes, nodes.size())
		if wrong != "":
			return wrong
	return ""


# One node: a leaf with sound counts, or a test on a known feature pointing
# forwards. Forwards only -- every child after its parent -- is what makes a
# walk end: a file whose children point back could send it round for ever.
static func _why_node_is_wrong(where: String, index: int, node: Variant, features: Array, classes: Array,
		size: int) -> String:
	if not (node is Dictionary) or node.has("counts") == node.has("feature"):
		return "M12 %s is neither a test nor a leaf" % where
	if node.has("counts"):
		return _why_counts_are_wrong(where, node["counts"], classes)
	if node.has("is") == node.has("at_most") or not node.has_all(["yes", "no"]):
		return "M12 %s is a test without one `is` or `at_most`, and a `yes` and a `no`" % where
	if not features.has(node["feature"]):
		return "M13 %s asks about %s, which is not among its features" % [where, JSON.stringify(node["feature"])]
	if node.has("is") and not (node["is"] is String):
		return "M13 %s compares with %s, which is not a word" % [where, JSON.stringify(node["is"])]
	if node.has("at_most") and not _is_a_number(node["at_most"]):
		return "M13 %s compares with %s, which is not a finite number" % [where, JSON.stringify(node["at_most"])]
	for child: Variant in [node["yes"], node["no"]]:
		if not _is_whole(child) or not (index < float(child) and float(child) < size):
			return "M14 %s points at %s, which is not a later node" % [where, JSON.stringify(child)]
	return ""


# A leaf's counts: answers the tree names, whole numbers, at least one row.
static func _why_counts_are_wrong(where: String, counts: Variant, classes: Array) -> String:
	if not (counts is Dictionary) or (counts as Dictionary).is_empty():
		return "M15 %s counts nothing" % where
	var total: float = 0.0
	for name: Variant in counts:
		if not classes.has(name):
			return "M15 %s counts %s, which is not among its classes" % [where, JSON.stringify(name)]
		if not _is_whole(counts[name]) or float(counts[name]) < 0.0:
			return "M15 %s counts %s, which is not a whole number of rows" % [where, JSON.stringify(counts[name])]
		total += float(counts[name])
	return "M15 %s counts nothing" % where if total == 0.0 else ""


# A finite number with nothing after the point: a count, or a node's index.
static func _is_whole(value: Variant) -> bool:
	return _is_a_number(value) and float(value) == floorf(float(value))


# A non-empty list of words, none of them twice.
static func _distinct_words(list: Array) -> bool:
	var seen: Dictionary = {}
	for item: Variant in list:
		if not (item is String) or seen.has(item):
			return false
		seen[item] = true
	return true


# The feature names: a non-empty list of distinct strings.
static func _why_features_are_wrong(name: String, given: Variant) -> String:
	if not (given is Array) or (given as Array).is_empty():
		return "M6 model `%s` lists no features" % name
	var seen: Dictionary = {}
	for feature: Variant in given:
		if not (feature is String):
			return "M6 model `%s` has a feature name that is not a string" % name
		if seen.has(feature):
			return "M6 model `%s` lists the feature `%s` twice" % [name, feature]
		seen[feature] = true
	return ""


# The weights: one per feature, and every one of them a finite number.
static func _why_weights_are_wrong(name: String, entry: Dictionary) -> String:
	var features: Array = entry["features"]
	if not (entry["weights"] is Array) or (entry["weights"] as Array).size() != features.size():
		return "M7 model `%s` has %s weights for %d features" % [
			name, _size_of(entry["weights"]), features.size(),
		]
	var numbers: Array = (entry["weights"] as Array).duplicate()
	numbers.append(entry["bias"])
	for number: Variant in numbers:
		if not _is_a_number(number):
			return _not_a_number(name, number)
	return ""


# The M8 sentence, out of line so the loop above stays three deep.
static func _not_a_number(name: String, number: Variant) -> String:
	return "M8 model `%s` publishes %s, which is not a finite number" % [
		name, JSON.stringify(number),
	]


# A finite int or float. `is_finite` is the half that matters: a JSON file can
# carry `1e400`, which parses to INF and multiplies every feature into one.
static func _is_a_number(value: Variant) -> bool:
	if not (value is float or value is int):
		return false
	return is_finite(float(value))


# How many entries, for a message, whatever was actually there.
static func _size_of(value: Variant) -> String:
	return str((value as Array).size()) if value is Array else "no"


# The result of a refusal: an error, and nothing to predict with.
static func _refused(reason: String) -> ModelFile:
	var refused := ModelFile.new()
	refused.error = reason
	return refused


# The model itself, built once the content above has been checked.
static func _model_from(entry: Dictionary) -> LearnedModel:
	var weights := PackedFloat64Array()
	for weight: Variant in entry["weights"]:
		weights.append(float(weight))
	return LearnedModel.new(
		str(entry["kind"]),
		PackedStringArray(entry["features"]),
		weights,
		float(entry["bias"]),
	)
