## The learned evaluation's weights, read from the file Python wrote.
##
## `checkers_weights.json` is `gameaikit.checkers.report`'s output: the weights
## fitted to self-play results, the hand-written ones beside them, and the
## match between the two. The game reads it and never writes it, and
## `check_no_training.py` trains again from the seed and compares (N7), so the
## file is the pipeline's, not one typed by hand.
##
## A file whose features are not the evaluation's, in that order, is refused
## rather than read: three numbers multiplied against the wrong counts would
## play a game, and nobody would know why it was strange.
##
## When not to use it: weights that change during play. Those are training,
## and training is Python's (invariant 6).
class_name CheckersWeights
extends RefCounted

const PATH: String = "res://game/checkers/checkers_weights.json"

static var _published: Dictionary = {}


## Everything the file says, read once. Empty when the file is missing,
## unreadable, or names other features.
static func published() -> Dictionary:
	if _published.is_empty():
		_published = read(PATH)
	return _published


## The learned weights, in the order of `CheckersEvaluation.FEATURES`; empty
## when there is no usable file.
static func learned() -> Array[float]:
	var weights: Array[float] = []
	weights.assign(published().get("learned", {}).get("weights", []))
	return weights


## The file at `path`, parsed, or empty when it is not a weights file for
## these features with a number for each.
static func read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	var named: Array = (parsed as Dictionary).get("features", [])
	var weights: Array = (parsed as Dictionary).get("learned", {}).get("weights", [])
	if named != Array(CheckersEvaluation.FEATURES) or weights.size() != named.size():
		return {}
	if not weights.all(func(weight: Variant) -> bool: return weight is float or weight is int):
		return {}
	return parsed
