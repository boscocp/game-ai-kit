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
static var _read_yet: bool = false


## Everything the file says, read once -- once even when it is missing, which
## the panel would otherwise ask the disk about on every refresh. Empty when
## the file is missing, unreadable, or names other features.
static func published() -> Dictionary:
	if not _read_yet:
		_published = read(PATH)
		_read_yet = true
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
	if not parsed is Dictionary or not parsed.get("learned") is Dictionary:
		return {}
	var named: Variant = parsed.get("features")
	var weights: Variant = parsed["learned"].get("weights")
	if not named is Array or not weights is Array:
		return {}
	if named != Array(CheckersEvaluation.FEATURES) or (weights as Array).size() != (named as Array).size():
		return {}
	if not (weights as Array).all(func(weight: Variant) -> bool: return weight is float or weight is int):
		return {}
	return parsed
