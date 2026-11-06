## One adversarial vector: the game and the search it describes, and the
## visits and means it claims at the root after so many iterations.
##
## Apart from the runner, as every family here is: a runner is a `SceneTree`,
## hard to test, and a rule living there can be deleted with every gate
## green. `mcts_vector_test.gd` plants a case for each rule below, and a
## search whose draws differ.
##
## When not to use it: anything but `spec/vectors/adversarial/`, whose README
## holds the shape.
class_name MctsVector
extends RefCounted

## The margin a mean may differ by: the same sums in the same order.
const TOLERANCE: float = 1e-9
const VECTOR_KEYS: Array[String] = ["cases", "description", "game"]
const CASE_KEYS: Array[String] = ["action", "exploration", "means", "name", "playout_limit", "seed",
		"state", "steps", "visits"]
const NIM: Script = preload("res://test/ai_adversarial/nim_example.gd")
const DICE_RACE: Script = preload("res://test/ai_adversarial/dice_race.gd")
const GAMES: Array[String] = ["dice_race", "nim"]


## Why this dictionary is not a usable search vector, or "" when it is one.
## A key nobody reads is refused: a misspelt claim would otherwise be dropped.
static func why_not_a_vector(vector: Dictionary) -> String:
	if _sorted_keys(vector) != VECTOR_KEYS:
		return "A1 its keys are %s, not %s" % [_sorted_keys(vector), VECTOR_KEYS]
	if not vector["game"] in GAMES:
		return "A2 it names a game the tests do not have: %s" % vector["game"]
	if (vector["cases"] as Array).is_empty():
		return "A3 it claims nothing"
	for case: Dictionary in vector["cases"]:
		if _sorted_keys(case) != CASE_KEYS:
			return "A4 a case's keys are %s, not %s" % [_sorted_keys(case), CASE_KEYS]
		if (case["visits"] as Array).size() != (case["means"] as Array).size():
			return "A5 %s: visits and means name different numbers of moves" % case["name"]
		if _sum(case["visits"]) != _sum(case["steps"]):
			return "A6 %s: the visits do not add up to the iterations" % case["name"]
	return ""


## The search the addon builds, as a `make` for `wrong_claims`.
static func addon_search() -> Callable:
	return func(game: GakAdversarialGame, state: RefCounted, from_seed: int, exploration: float,
			limit: int) -> MonteCarloSearch:
		return MonteCarloSearch.new(game, state, from_seed, exploration, limit)


## Every claim in the vector the search `make` builds does not meet: the
## visits first, which move if one draw moves, then the means and the move.
static func wrong_claims(vector: Dictionary, make: Callable) -> Array[String]:
	var game: GakAdversarialGame = game_of(vector["game"])
	var wrong: Array[String] = []
	for case: Dictionary in vector["cases"]:
		var search: MonteCarloSearch = _search_for(case, vector["game"], game, make)
		var found: MctsResult = search.result()
		for iterations: Variant in case["steps"]:
			found = search.step(int(iterations))
		wrong += _against(found, case)
	return wrong


# The search a case describes, built by `make`, before any step.
static func _search_for(case: Dictionary, name: String, game: GakAdversarialGame, make: Callable) -> MonteCarloSearch:
	var start: RefCounted = state_of(name, case["state"])
	return make.call(game, start, int(case["seed"]), float(case["exploration"]), int(case["playout_limit"]))


## Every draw `xorshift.json` claims that `GakXorshift` does not make.
static func wrong_draws(vector: Dictionary) -> Array[String]:
	var wrong: Array[String] = []
	for case: Dictionary in vector["cases"]:
		var generator := GakXorshift.new(int(case["seed"]))
		var drawn: Array = []
		for _draw: Variant in case["draws"]:
			drawn.append(generator.next())
		if drawn != (case["draws"] as Array).map(func(number: Variant) -> int: return int(number)):
			wrong.append("seed %d: drew %s, not %s" % [int(case["seed"]), drawn, case["draws"]])
	return wrong


## The test folder's own game for a vector's `game`.
static func game_of(name: String) -> GakAdversarialGame:
	return NIM.new() if name == "nim" else DICE_RACE.new()


## The game's own state for a vector's `state`.
static func state_of(name: String, written: Dictionary) -> RefCounted:
	if name == "nim":
		return NIM.Pile.new(int(written["sticks"]), int(written["player"]))
	var squares: Array[int] = []
	for reached: Variant in written["squares"]:
		squares.append(int(reached))
	return DICE_RACE.Race.new(squares, int(written["player"]))


static func _against(found: MctsResult, case: Dictionary) -> Array[String]:
	var visits: Array = found.considered.map(func(entry: Dictionary) -> int: return entry["visits"])
	var claimed: Array = (case["visits"] as Array).map(func(count: Variant) -> int: return int(count))
	if visits != claimed:
		return ["%s: visits %s, not %s" % [case["name"], visits, claimed]]
	var wrong: Array[String] = []
	for index: int in range(visits.size()):
		var mean: float = found.considered[index]["mean"]
		if absf(mean - float(case["means"][index])) > TOLERANCE:
			wrong.append("%s: mean %d is %f, not %f" % [case["name"], index, mean, case["means"][index]])
	if not _same_action(found.action, case["action"]):
		wrong.append("%s: chose %s, not %s" % [case["name"], found.action, case["action"]])
	return wrong


# JSON has no integers: Nim's take 2 comes back as 2.0.
static func _same_action(chosen: Variant, claimed: Variant) -> bool:
	if chosen is int:
		return claimed is float and int(claimed) == chosen
	return chosen == claimed


static func _sum(numbers: Array) -> int:
	var total: int = 0
	for number: Variant in numbers:
		total += int(number)
	return total


static func _sorted_keys(dictionary: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key: Variant in dictionary.keys():
		keys.append(str(key))
	keys.sort()
	return keys
