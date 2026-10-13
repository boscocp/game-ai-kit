## IF distance IS near AND light IS bright THEN alertness IS alarmed.
##
## Names rather than objects, so a rule reads the way it reads aloud and the
## rule base can say which name it could not find. AND is the smallest degree
## of the conditions and OR the largest -- Zadeh's choice, and the textbook's.
## One connective per rule. A strength costs one lookup per condition.
##
## When not to use it: as the whole decision. Rules conclude amounts, not acts.
class_name FuzzyRule
extends RefCounted

const AND: String = "and"
const OR: String = "or"
const CONNECTIVES: Array[String] = [AND, OR]

## Each condition is `[variable, set]`.
var conditions: Array[PackedStringArray]

## `[variable, set]`: the output term this rule makes true, as far as it is.
var conclusion: PackedStringArray

var connective: String


func _init(rule_conditions: Array[PackedStringArray], rule_conclusion: PackedStringArray,
		rule_connective: String = AND) -> void:
	conditions = rule_conditions
	conclusion = rule_conclusion
	connective = rule_connective


## How true the IF half is, given every input's degrees by variable and set.
##
## `min` for AND and `max` for OR. Others exist -- a product for AND is
## smoother -- and none is more right; the vectors pin this one. A rule with
## no conditions answers NAN; a rule base refuses one before asking.
func strength(degrees: Dictionary) -> float:
	if conditions.is_empty():
		return NAN
	var truths: Array[float] = []
	for condition: PackedStringArray in conditions:
		truths.append(float(degrees[condition[0]][condition[1]]))
	return truths.min() if connective == AND else truths.max()
