## From "half alarmed, half suspicious" back to one number: the centroid.
##
## Cut each output term off at its rule's strength, pile the cut shapes up,
## and find where the pile balances. Two rules firing at once land between
## their terms, never on either -- the whole of fuzzy logic in one number. The
## pile is measured at `samples` points, so the cost is samples x sets.
##
## When not to use it: an output that is a choice. The centroid of "flee" and
## "fight" is a unit standing still.
class_name FuzzyCentroid
extends RefCounted


## The `index`-th of an output's sample points, both ends included.
##
## Spelled `minimum + span * index / (samples - 1)` because the Python side
## spells it so, and two spellings of one sum can land on different doubles.
static func sample_point(output: FuzzyVariable, index: int) -> float:
	var span: float = output.maximum - output.minimum
	return output.minimum + span * index / float(output.samples - 1)


## How tall the pile is at one point: the highest cut shape there.
##
## Each term is cut at its strength (`min`) and the terms are combined by the
## highest (`max`). That pair is Mamdani's, and it is why a rule firing weakly
## can never outvote a strong one.
static func clipped_height(output: FuzzyVariable, strengths: Dictionary, point: float) -> float:
	var height: float = 0.0
	for one: FuzzySet in output.sets:
		var cut: float = minf(float(strengths.get(one.name, 0.0)), one.degree(point))
		height = maxf(height, cut)
	return height


## The balance point of the cut shapes, or NAN when no rule fired.
##
## NAN rather than the middle of the range: a rule base with a hole in it is a
## defect, and a number that looks like an answer hides it. NAN compares false
## against every threshold, so it can never pass for a decision.
static func of(output: FuzzyVariable, strengths: Dictionary) -> float:
	var weighted: float = 0.0
	var area: float = 0.0
	for index: int in range(output.samples):
		var point: float = sample_point(output, index)
		var height: float = clipped_height(output, strengths, point)
		weighted += height * point
		area += height
	if area == 0.0:
		return NAN
	return weighted / area
