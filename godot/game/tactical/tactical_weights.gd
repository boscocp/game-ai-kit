## The tactical game's weights: a model file, and the four numbers this game
## needs from it that are not weights.
##
## `ModelFile` checks what every model file has. This checks what only this
## game's file has -- the `feature_conventions` block `gameaikit.tactical.report`
## publishes, held to the same rules that module holds it to (W6, W7) -- so
## the addon can load anybody's file and this game still refuses one that
## would feed its models a feature they were never fitted on.
##
## When not to use it: a model file from any other game. Load that with
## `ModelFile` and check its own fields the way this one does.
class_name TacticalWeights
extends RefCounted

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

## The refusals this game adds, each a key with named placeholders: its
## code (W6, W7) stays outside it, untranslated, and the English is the
## Python side's own sentence. Shown on the skirmish's panel when blue
## cannot think, so each is translated where it is shown (`error_shown`).
const RUN_TRAIN: String = "{error} -- run `make train`"  # shown through tr()
const NO_BLOCK: String = "the file publishes no feature_conventions block"  # shown through tr()
const NOT_WHOLE: String = "feature_conventions.{name} is {value}, and the game needs a positive whole number"  # shown through tr()
const REVERSED: String = "feature_conventions says the cheapest ground ({cheapest}) costs more than the dearest ({dearest})"  # shown through tr()

## Why these weights are unusable, or "" when they loaded. One sentence, as
## `ModelFile.error` is, and that sentence when the file itself was refused.
## English: the tests and the Python side compare it.
var error: String = ""

# The refusal as words to translate: [code ("" for none), key, values,
# where it came from ("" for nowhere)]; empty for an addon's own sentence.
var _error_words: Array = []

## Convention name to value, from the file's `feature_conventions` block.
var conventions: Dictionary = {}

# The checked file, or null on any refusal: `model()` then answers null for
# every name, so nothing predicts from a file this game turned down.
var _file: ModelFile = null


## The weights at `path`, loaded and checked.
##
## Never null and never half built: on any refusal the result carries `error`
## and no models at all.
static func load_from(path: String) -> TacticalWeights:
	var file: ModelFile = ModelFile.load_from(path)
	if file.error.begins_with("M1 "):
		return _refused_with(["", RUN_TRAIN, {error = file.error}, ""])
	return over(file, path)


## The same checks, over content already in hand -- for a test, and for a
## conformance vector that carries its own models.
static func from_dictionary(data: Dictionary, source: String) -> TacticalWeights:
	return over(ModelFile.from_dictionary(data, source), source)


## This game's checks, on top of a file the addon has already loaded.
static func over(file: ModelFile, source: String) -> TacticalWeights:
	if not file.is_loaded():
		return _refused(file.error)
	var wrong: Array = _why_conventions_are_wrong(file.extra)
	if not wrong.is_empty():
		wrong[3] = source
		return _refused_with(wrong)
	var loaded := TacticalWeights.new()
	loaded._file = file
	loaded.conventions = file.extra["feature_conventions"]
	return loaded


## `error` in the language chosen, for the screen: this game's sentences
## translated, their codes and values as they are; an addon's sentence
## (`ModelFile`'s M codes) as the addon wrote it.
func error_shown() -> String:
	if _error_words.is_empty():
		return error
	return _words(_error_words, true)


## True when there are models to predict with.
func is_loaded() -> bool:
	return error == ""


## The model published under this name, or null.
func model(name: String) -> LearnedModel:
	return _file.model(name) if _file != null else null


## The names the file publishes, sorted, or none on a refused file.
func model_names() -> PackedStringArray:
	return _file.model_names() if _file != null else PackedStringArray()


## What wrote the file, or "" on a refused one.
func generated_by() -> String:
	return _file.generated_by if _file != null else ""


## A published convention, or -1 when this file has none by that name.
##
## Every name in `REQUIRED_CONVENTIONS` is present on a loaded file, so -1
## means a caller asked for something nobody publishes -- a typo, and one that
## would otherwise read as a very small radius.
func convention(name: String) -> int:
	return int(conventions.get(name, -1))


# The conventions block: present, every required number a positive whole one,
# and the terrain range the right way round -- as [code, key, values, ""],
# or empty when it is sound. The sentences are the Python side's own
# (`report._check_conventions`), so one code means one rule in both
# languages.
static func _why_conventions_are_wrong(extra: Dictionary) -> Array:
	if not (extra.get("feature_conventions") is Dictionary):
		return ["W6", NO_BLOCK, {}, ""]
	var published: Dictionary = extra["feature_conventions"]
	for name: String in REQUIRED_CONVENTIONS:
		var value: Variant = published.get(name)
		if not _is_a_whole_number(value) or float(value) <= 0.0:
			return _not_a_convention(name, value)
	# Each number is sound on its own and the pair can still be nonsense.
	# Reversed, a feature that clamps terrain between them clamps with a
	# minimum above its maximum -- which `clampi` answers rather than refuses,
	# so every cell on the board would come back as the same wrong number.
	var ground: Dictionary = {cheapest = str(published["cheapest_ground"]), dearest = str(published["dearest_ground"])}
	if int(published["cheapest_ground"]) > int(published["dearest_ground"]):
		return ["W7", REVERSED, ground, ""]
	return []


# The W6 sentence for one value, out of line so the loop above stays three
# deep.
static func _not_a_convention(name: String, value: Variant) -> Array:
	return ["W6", NOT_WHOLE, {name = name, value = JSON.stringify(value)}, ""]


# A number with no fraction. JSON hands every number over as a float, so
# `2` arrives as 2.0, and that is whole; 2.5 is not a radius.
static func _is_a_whole_number(value: Variant) -> bool:
	if not (value is float or value is int):
		return false
	return is_finite(float(value)) and float(value) == floorf(float(value))


# A refusal in this game's words: the English `error`, and the words kept to
# translate it where it is shown.
static func _refused_with(words: Array) -> TacticalWeights:
	var refused: TacticalWeights = _refused(_words(words, false))
	refused._error_words = words
	return refused


# [code, key, values, source] as one sentence, translated or in English.
static func _words(words: Array, translated: bool) -> String:
	var key: String = words[1]
	var sentence: String = (TranslationServer.translate(key) if translated else key).format(words[2])
	if words[0] != "":
		sentence = "%s %s" % [words[0], sentence]
	return sentence if words[3] == "" else "%s (%s)" % [sentence, words[3]]


# The result of a refusal: an error, and nothing to predict with.
static func _refused(reason: String) -> TacticalWeights:
	var refused := TacticalWeights.new()
	refused.error = reason
	return refused
