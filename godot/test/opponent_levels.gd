# T37: the fixed opponent's three levels are ordered. Over 100 seeded fights
# of each pairing, each level beats the one below it at least 60 times.
# T40: and hard is hard enough -- it beats the owner's ghost at least
# `HARD_BEATS_THE_OWNER` times in 100. The ghost is T18's "ghost: nearest",
# built from the nine fights the owner recorded: of everything in the
# repository it is the nearest to a person who is learning, and it is the
# strongest of T18's imitations -- it beat medium 86 times in 100. A scripted
# stand-in was tried first, its table the owner's own choices counted by
# situation, and it could not tell T37's hard from T40's: both beat it 96 to
# 98 times. The ghost could: 56 before the retune, over 80 after.
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
# Before trusting each character it plays the planted pairings: a level
# against itself must not win 60, or the measure is leaning on something
# that is not the level -- the side, or the seed; and medium must not beat
# the ghost `HARD_BEATS_THE_OWNER` times, or the bar is one any level clears.
#
# Exit codes: 0 every pairing is ordered and hard beats the ghost, 1 one is
# not or a planted pairing passed, 2 the frame data or the cloned player
# could not be read.
extends SceneTree

const FIGHTS: int = 100
const WINS_NEEDED: int = 60
## 99 seconds at 60 frames a second.
const TIME_LIMIT: int = 5940
## Each pair is `[lower, higher]`.
const PAIRINGS: Array[Array] = [["easy", "medium"], ["medium", "hard"]]
## How many of `FIGHTS` hard must win against the owner's ghost, as each character.
const HARD_BEATS_THE_OWNER: int = 75
## The imitation of the owner that hard is measured against.
const GHOST: String = "ghost: nearest"

var _cloned: ClonedPlayer


func _init() -> void:
	quit(_run())


func _run() -> int:
	var data := FightData.read()
	_cloned = ClonedPlayer.load_from()
	if data.refusal != "" or not _cloned.is_loaded():
		printerr("opponent_levels: cannot fight -- %s%s" % [data.refusal, _cloned.error])
		return 2
	var failures: int = 0
	for character: String in data.character_names():
		failures += 0 if not_ordered_against_itself(character, data) else 1
		for pairing: Array in PAIRINGS:
			failures += 0 if ordered(pairing[0], pairing[1], character, data) else 1
		failures += 0 if hard_enough(character, data) else 1
	print("opponent levels: %d failure(s)" % failures)
	return 1 if failures > 0 else 0


## True, and said so, when medium does not beat itself `WINS_NEEDED` times
## as `character`: the planted pairing, which the measure must not pass.
func not_ordered_against_itself(character: String, data: FightData) -> bool:
	var won: int = wins("medium", "medium", character, data)
	var verdict: String = "ok" if won < WINS_NEEDED else "FAIL"
	print("%s: planted, medium against itself as the %s, wins %d of %d (must stay under %d)" % [verdict, character,
			won, FIGHTS, WINS_NEEDED])
	return won < WINS_NEEDED


## True, and said so, when hard beats the owner's ghost `HARD_BEATS_THE_OWNER`
## times as `character`, and medium does not -- the planted pairing.
func hard_enough(character: String, data: FightData) -> bool:
	var medium: int = wins("medium", GHOST, character, data)
	var planted: bool = medium < HARD_BEATS_THE_OWNER
	print("%s: planted, medium beats the owner's ghost as the %s %d of %d (must stay under %d)" % [
			"ok" if planted else "FAIL", character, medium, FIGHTS, HARD_BEATS_THE_OWNER])
	var won: int = wins("hard", GHOST, character, data)
	print("%s: hard beats the owner's ghost as the %s %d of %d (needs %d)" % [
			"ok" if won >= HARD_BEATS_THE_OWNER else "FAIL", character, won, FIGHTS, HARD_BEATS_THE_OWNER])
	return planted and won >= HARD_BEATS_THE_OWNER


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


## The player a name seats: the owner's ghost for `GHOST`, else the fixed
## opponent at that level.
func _player(name: String, data: FightData, chance_seed: int) -> FightOpponent:
	if name == GHOST:
		return FightCloneOpponent.new(GHOST, _cloned, data, chance_seed)
	return FightOpponent.new(name, data, chance_seed)


## Who wins one fight between `levels[0]` and `levels[1]` -- a level, or
## `GHOST` -- both playing `character`, their chances drawn from `fight`:
## 0, 1 or `FightState.DRAW`.
func winner_of(levels: Array[String], character: String, fight: int, data: FightData) -> int:
	var seats: Array[FightDelay] = []
	for side: int in range(2):
		var chance_seed: int = fight * 2 + side
		seats.append(FightDelay.new(_player(levels[side], data, chance_seed), side))
	var state: FightState = FightState.starting(data, character, character)
	while state.winner == FightState.NOBODY and state.frame < TIME_LIMIT:
		var inputs: Array[int] = [seats[0].input_for(state), seats[1].input_for(state)]
		state = FightRules.step(state, inputs, data)
	if state.winner != FightState.NOBODY:
		return state.winner
	var health: Array[int] = [state.fighters[0].health, state.fighters[1].health]
	return FightState.DRAW if health[0] == health[1] else (0 if health[0] > health[1] else 1)
