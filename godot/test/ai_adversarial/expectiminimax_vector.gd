## One expectiminimax vector (T88): a position of the dice race, a depth,
## and the expected value of every root move it claims, the move chosen and
## the positions visited.
##
## Apart from the runner, as `MctsVector` is: a rule living in a
## `SceneTree` can be deleted with every gate green.
## `expectiminimax_vector_test.gd` plants a case for each rule below, and a
## search that reads no dice.
##
## When not to use it: anything but `spec/vectors/adversarial/`'s
## `expectiminimax-*.json`, whose shape the README holds.
class_name ExpectiminimaxVector
extends RefCounted

## The margin a value may differ by: the vectors are exact fractions
## written as floats, the search sums floats.
const TOLERANCE: float = 1e-9
const VECTOR_KEYS: Array[String] = ["cases", "description", "game"]
const CASE_KEYS: Array[String] = ["action", "depth", "name", "positions", "state", "values"]


## Why this dictionary is not a usable expectiminimax vector, or "" when it
## is one. A key nobody reads is refused: a misspelt claim would otherwise
## be dropped.
static func why_not_a_vector(vector: Dictionary) -> String:
	if _sorted_keys(vector) != VECTOR_KEYS:
		return "E1 its keys are %s, not %s" % [_sorted_keys(vector), VECTOR_KEYS]
	if vector["game"] != "dice_race":
		return "E2 it names a game other than the dice race: %s" % vector["game"]
	if (vector["cases"] as Array).is_empty():
		return "E3 it claims nothing"
	for case: Dictionary in vector["cases"]:
		if _sorted_keys(case) != CASE_KEYS:
			return "E4 a case's keys are %s, not %s" % [_sorted_keys(case), CASE_KEYS]
		if int(case["depth"]) < 1:
			return "E5 %s: a depth below one searches nothing" % case["name"]
	return ""


## The search the addon builds, as a `make` for `wrong_claims`: the
## position searched to the case's depth and no further.
static func addon_search() -> Callable:
	return func(game: GakAdversarialGame, state: RefCounted, depth: int) -> AdversarialResult:
		return ExpectiminimaxSearch.new(game, state).search_to(depth)


## Every claim in the vector that the search `make` builds does not meet:
## the values first, then the move and the positions visited.
static func wrong_claims(vector: Dictionary, make: Callable) -> Array[String]:
	var game: GakAdversarialGame = MctsVector.game_of(vector["game"])
	var wrong: Array[String] = []
	for case: Dictionary in vector["cases"]:
		var start: RefCounted = MctsVector.state_of(vector["game"], case["state"])
		var found: AdversarialResult = make.call(game, start, int(case["depth"]))
		wrong += _against(found, case)
	return wrong


static func _against(found: AdversarialResult, case: Dictionary) -> Array[String]:
	var values: Array = found.considered.map(func(entry: Dictionary) -> float: return entry["value"])
	var claimed: Array = case["values"]
	if values.size() != claimed.size():
		return ["%s: %d moves, not %d" % [case["name"], values.size(), claimed.size()]]
	var wrong: Array[String] = []
	for index: int in range(values.size()):
		if absf(values[index] - float(claimed[index])) > TOLERANCE:
			wrong.append("%s: move %d is worth %f, not %f" % [case["name"], index, values[index], claimed[index]])
	if found.action != case["action"]:
		wrong.append("%s: chose %s, not %s" % [case["name"], found.action, case["action"]])
	if found.positions != int(case["positions"]):
		wrong.append("%s: visited %d positions, not %d" % [case["name"], found.positions, int(case["positions"])])
	return wrong


static func _sorted_keys(dictionary: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key: Variant in dictionary.keys():
		keys.append(str(key))
	keys.sort()
	return keys
