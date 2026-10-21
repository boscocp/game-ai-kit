## Loads `weights.json`, or says in one sentence why it will not.
##
## Everything here is about refusing. A model built from a half-read file
## predicts from zeros, and nobody can tell that from a decision -- so a file
## with anything wrong with it yields no models at all and an `error` to put
## on screen. The rules are in `_why_wrong`, each with a code, and
## `from_dictionary` is public so a test can plant each one.
##
## When not to use it: any format but the one `gameaikit.tactical.report`
## writes, which that module's header describes.
class_name ModelFile
extends RefCounted

## The fields every published model carries.
const MODEL_FIELDS: Array[String] = ["kind", "features", "weights", "bias"]

## Numbers the game needs that are not weights: how close a unit must be to
## count as nearby, what a unit with no friends reports, and the range of
## ground the data was gathered on. Required, because the alternative is each
## reader inventing its own and quietly feeding the model a different feature.
const REQUIRED_CONVENTIONS: Array[String] = [
	"nearby_radius",
	"reinforcement_distance_when_alone",
	"cheapest_ground",
	"dearest_ground",
]

## Why this file is unusable, or "" when it loaded. One sentence, not a list:
## the first thing wrong with a weights file is the thing to fix, and a screen
## full of consequences buries it.
var error: String = ""

## Feature name to value, from the file's `feature_conventions` block.
var conventions: Dictionary = {}

## What wrote the file. Carried so a reader can tell a published artifact from
## a table somebody typed.
var generated_by: String = ""

# Model name to LearnedModel. Private: `model()` is how it is read, so an
# absent name answers null rather than whatever a dictionary lookup does.
var _models: Dictionary = {}


## The weights at `path`, loaded and checked.
##
## Never null and never half built: on any refusal the result carries `error`
## and no models at all.
static func load_from(path: String) -> ModelFile:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _refused("M1 no weights file at %s -- run `make train`" % path)
	# `JSON.new().parse()` rather than the static `JSON.parse_string()`.
	# Measured on the pinned engine: the static one prints an engine error to
	# the console on bad input and then returns null, so a file this type is
	# about to refuse politely has already filled the log on its way past --
	# and a log full of errors during a normal run is a log nobody reads.
	# This form returns the code and hands over the parser's own message,
	# which is more than the static one tells the caller anyway.
	var reader := JSON.new()
	if reader.parse(file.get_as_text()) != OK:
		return _refused("M2 %s is not JSON: %s, at line %d" % [
			path, reader.get_error_message(), reader.get_error_line(),
		])
	if not (reader.data is Dictionary):
		return _refused("M2 %s is JSON, but not an object" % path)
	return from_dictionary(reader.data, path)


## The same checks, over content already in hand.
static func from_dictionary(data: Dictionary, source: String) -> ModelFile:
	var wrong: String = _why_wrong(data)
	if wrong != "":
		return _refused("%s (%s)" % [wrong, source])

	var loaded := ModelFile.new()
	loaded.generated_by = str(data.get("generated_by", "unknown"))
	loaded.conventions = data["feature_conventions"]
	for name: String in data["models"]:
		loaded._models[name] = _model_from(data["models"][name])
	return loaded


## True when there are models to predict with.
func is_loaded() -> bool:
	return error == ""


## The model published under this name, or null.
func model(name: String) -> LearnedModel:
	return _models.get(name)


## A published convention, or -1 when this file has none by that name.
##
## Every name in `REQUIRED_CONVENTIONS` is present on a loaded file, so -1
## means a caller asked for something nobody publishes -- a typo, and one that
## would otherwise read as a very small radius.
func convention(name: String) -> int:
	return int(conventions.get(name, -1))


## The names this file publishes, sorted. For a report, and for a test that
## wants to assert what is in there without knowing the order.
func model_names() -> PackedStringArray:
	var names := PackedStringArray(_models.keys())
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
	return _why_conventions_are_wrong(data)


# One model: present, the right shape, and every number a number.
static func _why_model_is_wrong(name: String, entry: Variant) -> String:
	# M10 rather than a second M4. Two rules shared that code until a review
	# pointed out that a test asserting `contains("M4")` could not tell which
	# of them had fired -- and a planted case that cannot name its rule is
	# half a planted case. The numbering is identifiers, not an order.
	if not (entry is Dictionary):
		return "M10 model `%s` is not an object" % name
	for field: String in MODEL_FIELDS:
		if not entry.has(field):
			return "M4 model `%s` has no `%s`" % [name, field]
	if not LearnedModel.KINDS.has(str(entry["kind"])):
		return "M5 model `%s` is of kind `%s`, which nothing here can evaluate" % [
			name, entry["kind"],
		]
	var features: String = _why_features_are_wrong(name, entry["features"])
	if features != "":
		return features
	return _why_weights_are_wrong(name, entry)


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


# The conventions block: present, and every required number a positive one.
static func _why_conventions_are_wrong(data: Dictionary) -> String:
	if not (data.get("feature_conventions") is Dictionary):
		return "M9 the file publishes no feature_conventions block"
	var published: Dictionary = data["feature_conventions"]
	for name: String in REQUIRED_CONVENTIONS:
		var value: Variant = published.get(name)
		if not _is_a_number(value) or float(value) <= 0.0:
			return _not_a_convention(name, value)
	# Each number is sound on its own and the pair can still be nonsense.
	# Reversed, a feature that clamps terrain between them clamps with a
	# minimum above its maximum -- which `clampi` answers rather than refuses,
	# so every cell on the board would come back as the same wrong number.
	if int(published["cheapest_ground"]) > int(published["dearest_ground"]):
		return "M9 feature_conventions says the cheapest ground (%s) costs more than the dearest (%s)" % [
			published["cheapest_ground"], published["dearest_ground"],
		]
	return ""


# The M9 sentence, out of line for the same reason as M8's.
static func _not_a_convention(name: String, value: Variant) -> String:
	return "M9 feature_conventions.%s is %s, and a game needs a positive number" % [
		name, JSON.stringify(value),
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
