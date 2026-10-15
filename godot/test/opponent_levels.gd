# T37: the fixed opponent's three levels are ordered. Over 100 seeded fights
# of each pairing, each level beats the one below it at least 60 times.
#
#     ./scripts/godot --headless --path godot -s res://test/opponent_levels.gd
#
# Every fight is a mirror -- both fighters the same character -- so what is
# measured is the level and not the character: the lancer and the dancer are
# not meant to be even, and a hard dancer losing to a medium lancer would say
# nothing about the levels. Both mirrors are played, so a level that is only
# better with one character's moves is caught. The stronger level plays player
# one in half the fights and player two in the other half.
#
# A fight that reaches the time limit, 99 seconds as in an arcade, is won by
# the one with more health; equal health is a draw, and a draw is no win.
#
# Before trusting itself it plays the planted pairing: a level against itself
# must not win 60, or the measure is leaning on something that is not the
# level -- the side, or the seed.
#
# Exit codes: 0 every pairing is ordered, 1 one is not or the planted pairing
# was, 2 the frame data could not be read.
extends SceneTree

const FIGHTS: int = 100
const WINS_NEEDED: int = 60
## 99 seconds at 60 frames a second.
const TIME_LIMIT: int = 5940
## Each pair is `[lower, higher]`.
const PAIRINGS: Array[Array] = [["easy", "medium"], ["medium", "hard"]]


func _init() -> void:
	quit(_run())


func _run() -> int:
	var data := FightData.read()
	if data.refusal != "":
		printerr("opponent_levels: the frame data was refused: %s" % data.refusal)
		return 2
	var failures: int = 0
	var planted: int = wins("medium", "medium", "lancer", data)
	print("planted: medium against itself, as the lancer, wins %d of %d" % [planted, FIGHTS])
	if planted >= WINS_NEEDED:
		print("FAIL: a level beat itself %d times; the measure is not measuring the level" % planted)
		failures += 1
	for character: String in data.character_names():
		for pairing: Array in PAIRINGS:
			failures += 0 if ordered(pairing[0], pairing[1], character, data) else 1
	print("opponent levels: %d failure(s)" % failures)
	return 1 if failures > 0 else 0


## True, and said so, when `higher` beats `lower` at least `WINS_NEEDED`
## times as `character`.
func ordered(lower: String, higher: String, character: String, data: FightData) -> bool:
	var won: int = wins(higher, lower, character, data)
	var verdict: String = "ok" if won >= WINS_NEEDED else "FAIL"
	print("%s: %s beats %s as the %s %d of %d (needs %d)" % [verdict, higher, lower, character, won, FIGHTS,
			WINS_NEEDED])
	return won >= WINS_NEEDED


## How many of `FIGHTS` seeded mirror fights `higher` wins against `lower`.
func wins(higher: String, lower: String, character: String, data: FightData) -> int:
	var won: int = 0
	for fight: int in range(FIGHTS):
		var higher_side: int = fight % 2
		var levels: Array[String] = [higher, lower]
		if higher_side == 1:
			levels.reverse()
		if winner_of(levels, character, fight, data) == higher_side:
			won += 1
	return won


## Who wins one fight between `levels[0]` and `levels[1]`, both playing
## `character`, their chances drawn from `fight`: 0, 1 or `FightState.DRAW`.
func winner_of(levels: Array[String], character: String, fight: int, data: FightData) -> int:
	var seats: Array[FightDelay] = []
	for side: int in range(2):
		seats.append(FightDelay.new(FightOpponent.new(levels[side], data, fight * 2 + side), side))
	var state: FightState = FightState.starting(data, character, character)
	while state.winner == FightState.NOBODY and state.frame < TIME_LIMIT:
		var inputs: Array[int] = [seats[0].input_for(state), seats[1].input_for(state)]
		state = FightRules.step(state, inputs, data)
	if state.winner != FightState.NOBODY:
		return state.winner
	var health: Array[int] = [state.fighters[0].health, state.fighters[1].health]
	return FightState.DRAW if health[0] == health[1] else (0 if health[0] > health[1] else 1)
