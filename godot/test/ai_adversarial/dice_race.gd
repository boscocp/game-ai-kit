# A toy game with dice, for the addon's own tests and vectors, so that they
# depend on no example's rules (T86). Its Python twin is
# `gameaikit.adversarial.toy_games.DiceRace`, written to the same order:
# the search's draws index into these lists, and a different order is a
# different search.
#
# Two runners, each to reach GOAL squares. On your turn walk one square,
# certain, or roll: half the time nothing, a quarter of the time two squares,
# a quarter of the time four squares *and you go again* -- chance, and a
# side that may move twice running.
extends AdversarialGame

## The squares a runner must reach to win.
const GOAL: int = 6
## The roll's three faces, in their fixed order.
const ROLL_FACES: Array[Dictionary] = [
	{"chance": 0.5, "squares": 0, "again": false},
	{"chance": 0.25, "squares": 2, "again": false},
	{"chance": 0.25, "squares": 4, "again": true},
]


## A position: each runner's squares, and whose turn it is, 0 or 1.
class Race extends RefCounted:
	var squares: Array[int]
	var player: int

	func _init(reached: Array[int], to_play: int) -> void:
		squares = reached
		player = to_play


# Whose turn it is; after a roll of four, still the same runner's.
func to_move(state: RefCounted) -> int:
	return (state as Race).player


# Walk, then roll, while nobody has arrived.
func actions(state: RefCounted) -> Array:
	return [] if is_terminal(state) else ["walk", "roll"]


# Without chance a roll is its first face, nothing: what a search that
# reads only `result` assumes.
func result(state: RefCounted, action: Variant) -> RefCounted:
	return outcomes(state, action)[0]["state"]


# A walk is certain; a roll is one of the three faces, by its chance.
func outcomes(state: RefCounted, action: Variant) -> Array:
	if action == "walk":
		return [{"probability": 1.0, "state": _advanced(state as Race, 1, false)}]
	var faces: Array = []
	for face: Dictionary in ROLL_FACES:
		var landed: Race = _advanced(state as Race, face["squares"], face["again"])
		faces.append({"probability": face["chance"], "state": landed})
	return faces


# Over when a runner has reached the goal.
func is_terminal(state: RefCounted) -> bool:
	return (state as Race).squares.max() >= GOAL


# Won 1, lost -1; unfinished, the lead as a share of the goal.
func evaluate(state: RefCounted, player: int) -> float:
	var race := state as Race
	var lead: int = race.squares[player] - race.squares[1 - player]
	if is_terminal(race):
		return 1.0 if lead > 0 else -1.0
	return float(lead) / GOAL


# The race after the runner to move goes `squares` on; the turn passes
# unless `again`.
func _advanced(race: Race, squares: int, again: bool) -> Race:
	var moved: Array[int] = race.squares.duplicate()
	moved[race.player] += squares
	return Race.new(moved, race.player if again else 1 - race.player)
