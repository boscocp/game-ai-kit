# The minimal example on docs/techniques/ai_learning.md, run by
# chance_example_test.gd. A unit of your own that asks a model Python
# fitted how likely an attack is to win, and only multiplies -- it never
# changes a weight.
extends Node

## Where your Python side wrote the model file. This one is the kit's,
## written by hand beside this example: one model, nothing else.
const MODEL_PATH: String = "res://test/ai_learning/chance_model.json"

var _model: LearnedModel


func _ready() -> void:
	_model = model_from(MODEL_PATH)


## The `chance` model in the file at `path`, or null when the file is
## refused -- whole, with the reason in one sentence, never filled in with a
## guess.
static func model_from(path: String) -> LearnedModel:
	var published: ModelFile = ModelFile.load_from(path)
	if not published.is_loaded():
		push_warning(published.error)
		return null
	return published.model("chance")


## How likely an attack is to win, 0 to 1, from the facts by name. A fact the
## model needs and was not given answers NAN, which no threshold passes.
func chance_to_win(facts: Dictionary) -> float:
	return _model.predict_named(facts)
