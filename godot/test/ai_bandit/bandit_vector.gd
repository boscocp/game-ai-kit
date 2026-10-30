## One bandit vector: the bandit it describes, the payoff each arm gives on
## each of its pulls, and the arm it claims is chosen on every pull.
##
## Apart from the runner, as every family here is: a runner is a `SceneTree`,
## hard to test, and a rule living there can be deleted with every gate
## green. `bandit_vector_test.gd` plants a case for each rule below.
##
## When not to use it: anything but `spec/vectors/bandit/`, whose README
## holds the shape.
class_name BanditVector
extends RefCounted

## The margin allowed on a sum: the payoffs are exact binary fractions, so
## the sums are exact, and this only forgives the printing.
const TOLERANCE: float = 1e-9
const VECTOR_KEYS: Array[String] = ["arms", "chosen", "description", "epsilon", "exploration", "payoffs", "policy",
		"pulls", "seed", "sums"]


## Why this dictionary is not a usable vector, or "" when it is one. A key
## nobody reads is refused: a misspelt claim would otherwise be dropped.
static func why_not_a_vector(vector: Dictionary) -> String:
	if _sorted_keys(vector) != VECTOR_KEYS:
		return "V1 its keys are %s, not %s" % [_sorted_keys(vector), VECTOR_KEYS]
	var settings: String = bandit_of(vector).problem()
	if settings != "":
		return "V2 its settings cannot work: " + settings
	var arm_count: int = int(vector["arms"])
	var payoffs: Array = vector["payoffs"]
	if payoffs.size() != arm_count or payoffs.any(func(sequence: Array) -> bool: return sequence.is_empty()):
		return "V3 it does not give every arm a payoff sequence"
	for sequence: Array in payoffs:
		if sequence.any(func(payoff: float) -> bool: return payoff < 0.0 or payoff > 1.0):
			return "V4 a payoff lies outside [0, 1], where UCB1's bound holds"
	if (vector["chosen"] as Array).is_empty():
		return "V5 it claims no pull"
	if (vector["pulls"] as Array).size() != arm_count or (vector["sums"] as Array).size() != arm_count:
		return "V6 its final pulls and sums do not name every arm"
	var counted: int = 0
	for pulled: Variant in vector["pulls"]:
		counted += int(pulled)
	if counted != (vector["chosen"] as Array).size():
		return "V7 its final pulls do not add up to the pulls it claims"
	return ""


## The bandit the vector describes, before its first pull.
static func bandit_of(vector: Dictionary) -> Bandit:
	return Bandit.new(int(vector["arms"]), vector["policy"], float(vector["exploration"]), float(vector["epsilon"]),
			int(vector["seed"]))


## Every claim in the vector that `bandit`, paid as the vector says, does not
## meet. The k-th pull of an arm pays its sequence's k-th payoff, from the
## start again when the sequence runs out. The first wrong choice ends it:
## after one, every later pull is paid differently and says nothing more.
static func wrong_claims(vector: Dictionary, bandit: Bandit) -> Array[String]:
	var wrong: Array[String] = []
	var pull: int = 0
	for claimed: Variant in vector["chosen"]:
		var arm: int = bandit.choose()
		if arm != int(claimed):
			wrong.append("pull %d: arm %d, not %d" % [pull, arm, int(claimed)])
			return wrong
		var sequence: Array = vector["payoffs"][arm]
		bandit.reward(arm, float(sequence[bandit.pulls[arm] % sequence.size()]))
		pull += 1
	for arm: int in range(bandit.arms()):
		if bandit.pulls[arm] != int(vector["pulls"][arm]):
			wrong.append("arm %d pulled %d times, not %d" % [arm, bandit.pulls[arm], int(vector["pulls"][arm])])
		if absf(bandit.sums[arm] - float(vector["sums"][arm])) > TOLERANCE:
			wrong.append("arm %d's sum %s, not %s" % [arm, bandit.sums[arm], vector["sums"][arm]])
	return wrong


static func _sorted_keys(table: Dictionary) -> Array:
	var keys: Array = table.keys()
	keys.sort()
	return keys
