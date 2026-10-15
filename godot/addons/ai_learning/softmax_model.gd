## A model that picks one of several answers: multinomial logistic regression,
## read back in, for situations written as words (T18).
##
## T6's `LearnedModel` answers one question with one number. This one answers
## "which of these?" with a probability for each: every answer has a score,
## its bias plus a weight for each word in the situation, and the scores are
## turned into probabilities that sum to 1 by the softmax -- each score's
## exponential over the sum of all of them. With two answers it is exactly
## the logistic of T6; softmax is what the sigmoid becomes past two.
##
## The situation is words, not numbers -- `{"distance": "close", ...}` -- and
## each "feature=word" pair is a column with a weight per answer, present or
## absent. So a prediction adds six weights per answer, one per feature: the
## whole of inference, which is why it costs microseconds. A word the model
## never saw in fitting has no column, adds nothing, and leaves the answer to
## the other features; it is not an error, because a situation the player
## never met is exactly the one a model is for.
##
## The fitting happened in Python (`gameaikit.cloning`): invariant 6.
##
## Complexity: answers * features additions, and one exponential per answer.
##
## When not to use it: answers that interact -- "a low when close, unless
## cornered" is a product of two words, and this model only adds them. That
## needs a hidden layer, or the product written in as a feature of its own.
class_name SoftmaxModel
extends RefCounted

## The answers, in the order of `weights` and `bias`.
var classes: PackedStringArray
## The columns, each "feature=word", in the order of each answer's weights.
var columns: PackedStringArray
## One row per answer, one weight per column.
var weights: Array[PackedFloat64Array] = []
## One per answer: its score when no column is present.
var bias: PackedFloat64Array

var _column_of: Dictionary = {}


## A model scoring `answer_names` from `column_names`, by `answer_weights` (one
## row per answer) and `answer_bias`. The sizes are checked by `ClonedPlayer`
## before this is built.
func _init(answer_names: PackedStringArray, column_names: PackedStringArray,
		answer_weights: Array[PackedFloat64Array], answer_bias: PackedFloat64Array) -> void:
	classes = answer_names
	columns = column_names
	weights = answer_weights
	bias = answer_bias
	for index: int in range(columns.size()):
		_column_of[columns[index]] = index


## The column a feature's word would be written as.
static func column(feature: String, word: String) -> String:
	return "%s=%s" % [feature, word]


## Each answer's score in `situation` -- `{feature: word}` -- before the
## softmax: its bias plus the weight of every column the situation has.
func scores(situation: Dictionary) -> PackedFloat64Array:
	var present: Array[int] = []
	for feature: String in situation:
		var found: int = _column_of.get(column(feature, situation[feature]), -1)
		if found >= 0:
			present.append(found)
	var totals := PackedFloat64Array()
	for answer: int in range(classes.size()):
		var total: float = bias[answer]
		for index: int in present:
			total += weights[answer][index]
		totals.append(total)
	return totals


## How likely each answer is in `situation`, as `{answer: probability}`;
## they sum to 1. The largest score is taken off every score before the
## exponential, which changes no probability and keeps `exp` from
## overflowing on a large one.
func probabilities(situation: Dictionary) -> Dictionary:
	var totals: PackedFloat64Array = scores(situation)
	var largest: float = totals[0]
	for total: float in totals:
		largest = maxf(largest, total)
	var exponentials := PackedFloat64Array()
	var sum: float = 0.0
	for total: float in totals:
		exponentials.append(exp(total - largest))
		sum += exponentials[-1]
	var chances: Dictionary = {}
	for answer: int in range(classes.size()):
		chances[classes[answer]] = exponentials[answer] / sum
	return chances


## The likeliest answer in `situation`; of equal ones, the first in `classes`.
func likeliest(situation: Dictionary) -> String:
	var chances: Dictionary = probabilities(situation)
	var best: String = classes[0]
	for answer: String in classes:
		if chances[answer] > chances[best]:
			best = answer
	return best
