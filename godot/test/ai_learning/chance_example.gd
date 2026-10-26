# The minimal example on docs/techniques/ai_learning.md, run by
# chance_example_test.gd. A unit of your own that asks a model Python
# fitted how likely an attack is to win, and only multiplies -- it never
# changes a weight.
extends Node

## One model as Python publishes it. Your game reads this from the JSON file
## your Python side wrote; it is here so the example runs on its own.
const PUBLISHED: Dictionary = {
	"kind": "logistic",
	"features": ["my_health", "their_health", "distance"],
	"weights": [0.05, -0.05, -0.2],
	"bias": 0.5,
}

var _model: LearnedModel


func _ready() -> void:
	_model = model_from(PUBLISHED)


## A model from one published entry, or null when the entry is not one.
static func model_from(entry: Dictionary) -> LearnedModel:
	if not LearnedModel.KINDS.has(entry.get("kind")):
		return null
	var features := PackedStringArray(entry.get("features", []))
	var weights := PackedFloat64Array(entry.get("weights", []))
	if features.is_empty() or features.size() != weights.size():
		return null
	return LearnedModel.new(entry["kind"], features, weights, float(entry.get("bias", 0.0)))


## How likely an attack is to win, 0 to 1, from the facts by name. A fact the
## model needs and was not given answers NAN, which no threshold passes.
func chance_to_win(facts: Dictionary) -> float:
	return _model.predict_named(facts)
