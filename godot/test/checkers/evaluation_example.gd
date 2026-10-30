# The minimal example on docs/techniques/learned_evaluation.md, run by
# evaluation_example_test.gd. The evaluation a game of your own hands its
# search: counts your game takes of a position, each times a weight Python
# fitted to results. Here it only multiplies.
extends RefCounted

var _model: LearnedModel


## The weights in the file Python wrote at `path`: its `features`, and the
## `weights` under `learned`, one per feature, in that order. `is_ready()` is
## false when the file is not one.
func _init(path: String) -> void:
	var reader := JSON.new()
	if reader.parse(FileAccess.get_file_as_string(path)) != OK or not reader.data is Dictionary:
		return
	var published: Dictionary = reader.data
	if not published.get("learned") is Dictionary:
		return
	var features := PackedStringArray(published.get("features", []))
	var weights := PackedFloat64Array(published["learned"].get("weights", []))
	if not features.is_empty() and features.size() == weights.size():
		_model = LearnedModel.new(LearnedModel.LINEAR, features, weights, 0.0)


## True when the weights were read.
func is_ready() -> bool:
	return _model != null


## How good a position is for one player: `counts` by feature name, each
## that player's minus the opponent's. Your `GakAdversarialGame.evaluate`
## returns this for a game that is not over.
func score(counts: Dictionary) -> float:
	return _model.predict_named(counts)
