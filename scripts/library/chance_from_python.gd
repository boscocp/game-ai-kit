# The second example on docs/techniques/using-the-library.md, run by
# scripts/library_check.py in a project that has never seen this kit.
# A node of your own that reads the model your Python side wrote, and
# only multiplies: nothing in the game changes a weight.
extends Node

## Where the training script wrote its file, run from the project's folder.
const MODEL_PATH: String = "res://chance_model.json"

## How likely a healthy attacker is to beat a hurt one, 0 to 1; NAN when
## the file was refused, which no threshold passes.
var chance: float = NAN


func _ready() -> void:
	var published: ModelFile = ModelFile.load_from(MODEL_PATH)
	if not published.is_loaded():
		push_warning(published.error)
		return
	var model: LearnedModel = published.model("chance")
	chance = model.predict_named({"my_health": 85.0, "their_health": 30.0})
