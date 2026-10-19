# T12: the difficulty levels are a ladder. Each level plays each other level
# over a fixed set of seeds, from both seats, and the harder one must win
# more often than the easier one by at least `MARGIN` games in every
# hundred; every level must also beat T30's rules -- the floor -- in at
# least `FLOOR_WINS` of `FLOOR_GAMES` games from each seat, so that "easy"
# still means "better than rules".
#
#     ./scripts/godot --headless --path godot -s res://test/difficulty_matches.gd
#
# About ten minutes: a game between levels takes about a second.
#
# Both seats, because they are not even: blue moves second and is given a
# shield for it (T47), and a measure from one seat would credit a level with
# its chair. Draws count for neither. The levels' noise is drawn from seeds
# of their own, different for each game and never the board's dice.
#
# Why 15 in every hundred: over 100 games two equal sides still come apart
# by about 10 -- the standard deviation of the difference -- and the first
# margin, 10, was cleared by the planted pairing below at 55 to 44. That run
# also had hard, then at a noise of 0.5 apart from normal, beating it only 55
# to 43: two levels the measure could not tell apart, and the presets were
# moved, not the bar. The gaps measured when they were chosen are near 30.
#
# Before trusting the measure it plays the planted pairing: normal against
# itself must not clear the margin, or the measure is leaning on something
# that is not the level.
#
# Exit codes: 0 the ladder and the floor hold and the planted pairing does
# not, 1 otherwise.
extends SceneTree

## Games from each seat for each pairing of levels.
const GAMES: int = 50
## How many more of every hundred games the harder level must win.
const MARGIN: int = 15
## Games from each seat against the rules, and how many of them each level
## must win.
const FLOOR_GAMES: int = 25
const FLOOR_WINS: int = 20


func _init() -> void:
	quit(_run())


func _run() -> int:
	var levels: Array[Difficulty] = Difficulty.presets()
	var failures: int = 0
	failures += 0 if _not_ordered_against_itself(Difficulty.named("normal")) else 1
	for lower: int in range(levels.size()):
		failures += 0 if _above_the_rules(levels[lower]) else 1
		for higher: int in range(lower + 1, levels.size()):
			failures += 0 if _ordered(levels[lower], levels[higher]) else 1
	print("difficulty matches: %d failure(s)" % failures)
	return 1 if failures > 0 else 0


## True, and said so, when `higher` wins at least `MARGIN` more of every
## hundred games against `lower` than `lower` wins against it.
func _ordered(lower: Difficulty, higher: Difficulty) -> bool:
	var won: Array[int] = _wins(higher, lower)
	var lead: float = 100.0 * (won[0] - won[1]) / (2 * GAMES)
	var held: bool = lead >= MARGIN
	print("%s: %s beats %s %d to %d in %d games, %.0f more in every hundred (needs %d)" % [
		"ok" if held else "FAIL", higher.name, lower.name, won[0], won[1], 2 * GAMES, lead, MARGIN])
	return held


## True, and said so, when `level` against itself does not clear the margin:
## the planted pairing, which the measure must not pass.
func _not_ordered_against_itself(level: Difficulty) -> bool:
	var won: Array[int] = _wins(level, level)
	var lead: float = 100.0 * absi(won[0] - won[1]) / (2 * GAMES)
	print("%s: planted, %s against itself, %d to %d, %.0f apart in every hundred (must stay under %d)" % [
		"ok" if lead < MARGIN else "FAIL", level.name, won[0], won[1], lead, MARGIN])
	return lead < MARGIN


## True, and said so, when `level` beats the rules `FLOOR_WINS` times in
## `FLOOR_GAMES` from each seat.
func _above_the_rules(level: Difficulty) -> bool:
	var held: bool = true
	for seat: int in range(TacticalScenario.FACTIONS):
		var won: int = 0
		for game: int in range(FLOOR_GAMES):
			var seats: Array[BlueController] = [RuleBasedBlue.new(), RuleBasedBlue.new()]
			seats[seat] = LeveledBlue.new(level, 7919 * game + seat)
			won += 1 if TacticalMatch.play(seats[0], seats[1], game)["winner"] == seat else 0
		print("%s: %s as %s beats the rules %d of %d (needs %d)" % ["ok" if won >= FLOOR_WINS else "FAIL", level.name,
			TacticalStatus.side_name(seat), won, FLOOR_GAMES, FLOOR_WINS])
		held = held and won >= FLOOR_WINS
	return held


## [games `one` won, games `other` won] over `GAMES` seeds, each played with
## `one` as red and again as blue.
func _wins(one: Difficulty, other: Difficulty) -> Array[int]:
	var won: Array[int] = [0, 0]
	for played: int in range(GAMES * TacticalScenario.FACTIONS):
		var winner: int = _winner(one, other, played / TacticalScenario.FACTIONS, played % TacticalScenario.FACTIONS)
		if winner != -1:
			won[winner] += 1
	return won


# Who wins game `game` with `one` in `seat` and `other` in the other: 0 for
# `one`, 1 for `other`, -1 for a draw. Each side's noise has a seed of its
# own, and neither is the board's.
func _winner(one: Difficulty, other: Difficulty, game: int, seat: int) -> int:
	var seats: Array[BlueController] = [null, null]
	seats[seat] = LeveledBlue.new(one, 4 * game + seat)
	seats[1 - seat] = LeveledBlue.new(other, 4 * game + 2 + seat)
	var winner: int = TacticalMatch.play(seats[0], seats[1], game)["winner"]
	if winner == seat:
		return 0
	return 1 if winner == 1 - seat else -1
