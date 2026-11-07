## One fitted model, read back in: what it looks at, and what it concludes.
##
## The arithmetic is one line -- `w·x + b` -- plus a squash through a sigmoid
## when the question is yes-or-no. That is the whole of inference: the
## expensive half of machine learning is the fitting, which happened in
## Python. Complexity is one multiply-add per feature, so here it is four.
##
## When not to use it: a model that is not one number per feature -- a tree
## (`LearnedTree` reads one), a hidden layer, anything with structure.
class_name LearnedModel
extends RefCounted

## A yes-or-no question. The answer is a probability between 0 and 1.
const LOGISTIC: String = "logistic"

## A how-much question. The answer is the number itself.
const LINEAR: String = "linear"

## The kinds this type can evaluate. A file naming any other is refused by
## `ModelFile` rather than guessed at here.
const KINDS: Array[String] = [LOGISTIC, LINEAR]

## What the model does with `w·x + b`: `LOGISTIC` or `LINEAR`.
var kind: String

## The feature names, in weight order. The order is the contract with the
## Python side and it is published in the weights file, never assumed.
var features: PackedStringArray

## One weight per feature, applying to **raw game numbers**. The scaling used
## during fitting was folded back in before publication, so there is no
## scaler here and no second place for the arithmetic to be wrong.
var weights: PackedFloat64Array

var bias: float


func _init(model_kind: String, model_features: PackedStringArray,
		model_weights: PackedFloat64Array, model_bias: float) -> void:
	kind = model_kind
	features = model_features
	weights = model_weights
	bias = model_bias


## What this model says about one row, given in `features` order.
##
## A row of the wrong length answers NAN, and that is the fail-loud choice
## rather than a missing one: NAN compares false against any threshold, so a
## row this model cannot read can never come back as "attack". Padding the row
## with zeros would also have produced a number, and a number is
## indistinguishable from an answer.
func predict(row: PackedFloat64Array) -> float:
	if row.size() != weights.size():
		return NAN
	var total: float = bias
	for index: int in range(weights.size()):
		total += weights[index] * row[index]
	return sigmoid(total) if kind == LOGISTIC else total


## The same, from a dictionary of feature name to value.
##
## This is the call the game should make. The weight order lives in the
## published file; a caller that builds its own array has quietly taken a copy
## of that order, and a copy is a thing that can fall behind. A name the model
## does not know, or one it knows and was not given, answers NAN.
func predict_named(values: Dictionary) -> float:
	var row := PackedFloat64Array()
	for name: String in features:
		if not values.has(name):
			return NAN
		row.append(float(values[name]))
	return predict(row)


## The logistic squash, in the two branches the Python side needs.
##
## **The branches are not needed here, and this comment used to claim they
## were.** Measured on the pinned engine: `exp` saturates to `inf` rather than
## raising, so the naive `1.0 / (1.0 + exp(-value))` returns 1.0 at a logit of
## +1000 and 0.0 at -1000 -- the correctly rounded answers. In Python the same
## spelling raises `OverflowError` around -710, which is a training run dying
## two thousand steps in because one row was unusual.
##
## They stay because this file is read beside `gameaikit.training.descent` and
## the conformance vectors hold the two to the same answers: one shape, two
## languages. That is a reason, and "it would overflow" was not one.
static func sigmoid(value: float) -> float:
	if value >= 0.0:
		return 1.0 / (1.0 + exp(-value))
	var swung: float = exp(value)
	return swung / (1.0 + swung)
