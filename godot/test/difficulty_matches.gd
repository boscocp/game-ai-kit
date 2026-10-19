# T12: the difficulty levels are a ladder. Each level plays each other level
# over a fixed set of seeds, from both seats, and the harder one must win
# more often than the easier one by at least `MARGIN` games in every
# hundred; every level must also beat T30's rules -- the floor -- in at
# least `FLOOR_WINS` of `FLOOR_GAMES` games from each seat, so that "easy"
# still means "better than rules".
#
#     ./scripts/godot --headless --path godot -s res://test/difficulty_matches.gd
#     ./scripts/godot --headless --path godot -s res://test/difficulty_matches.gd \
#         -- --measure HORIZON,DEPTH,NOISE HORIZON,DEPTH,NOISE [GAMES]
#
# About fifteen minutes: 575 games, about one and a half seconds each.
#
# `--measure` plays any two points on the knobs against each other, `GAMES`
# (default `GAMES`) from each seat, the same seeds as the ladder, and prints
# the count; it asserts nothing and exits 0. It is how the numbers in
# `Difficulty.presets` and T12's record were measured, and how to measure a
# level before it is added.
#
# Both seats, because they are not even: blue moves second and is given a
# shield for it (T47), and a measure from one seat would credit a level with
# its chair. Each game rolls dice of its own -- the two seats do not replay
# one board's dice, which tied the pair of games together and made two
# equal levels look apart by 23 in a hundred. Draws count for neither. The
# levels' noise is drawn from seeds of their own, never the board's dice.
#
# Why 15 in every hundred: over 100 games two equal sides still come apart
# by about 10 -- the standard deviation of the difference -- and the first
# margin, 10, was cleared by the planted pairing below at 55 to 44. Twice a
# pairing of levels the measure could not tell apart was found this way,
# and both times the presets were moved, not the bar.
#
# Measured when the presets were last chosen (wave 55, after its review):
# normal beat easy 70 to 29, hard beat normal 59 to 40 -- the thinnest step,
# 19 against 15 -- and hard beat easy 76 to 24; every level beat the rules
# 25 of 25 from each seat; the planted mirror came apart by 10.
#
# Before trusting the measure it plays two planted pairings: normal against
# itself must not clear the margin, or the measure is leaning on something
# that is not the level; and the rules against themselves must not clear the
# floor, or the floor is one anything clears.
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
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() >= 3 and arguments[0] == "--measure":
		quit(_measure(arguments))
		return
	quit(_run())


# `--measure`: two points on the knobs, played and counted.
func _measure(arguments: PackedStringArray) -> int:
	var one: Difficulty = _point(arguments[1])
	var games: int = int(arguments[3]) if arguments.size() > 3 else GAMES
	if one != null and arguments[2] == "rules":
		print("%s against the rules: %d as red, %d as blue, of %d each" % [one.name, _wins_against_the_rules(one, 0, games),
			_wins_against_the_rules(one, 1, games), games])
		return 0
	var other: Difficulty = _point(arguments[2])
	if one == null or other == null:
		printerr("difficulty_matches: a point reads HORIZON,DEPTH,NOISE, such as 0,2,1.0; the second may be rules")
		return 2
	var won: Array[int] = _wins(one, other, games)
	print("%s against %s: %d to %d in %d games" % [one.name, other.name, won[0], won[1], 2 * games])
	return 0


# A point on the knobs, "HORIZON,DEPTH,NOISE", or null.
static func _point(written: String) -> Difficulty:
	var parts: PackedStringArray = written.split(",")
	if parts.size() != 3 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_float():
		return null
	return Difficulty.new(written, int(parts[0]), int(parts[1]), float(parts[2]))


func _run() -> int:
	var levels: Array[Difficulty] = Difficulty.presets()
	var failures: int = 0
	failures += 0 if _not_ordered_against_itself(Difficulty.named("normal")) else 1
	failures += 0 if _the_rules_do_not_clear_the_floor() else 1
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


## True, and said so, when the rules do not beat themselves `FLOOR_WINS`
## times in `FLOOR_GAMES` from either seat: the floor's planted pairing.
func _the_rules_do_not_clear_the_floor() -> bool:
	var won: Array[int] = [0, 0]
	for game: int in range(FLOOR_GAMES):
		var winner: int = TacticalMatch.play(RuleBasedBlue.new(), RuleBasedBlue.new(), game)["winner"]
		if winner >= 0:
			won[winner] += 1
	# Either seat reaching the floor would pass the rules for that seat, as
	# `_above_the_rules` judges a level seat by seat.
	var cleared: bool = won[0] >= FLOOR_WINS or won[1] >= FLOOR_WINS
	print("%s: planted, the rules against themselves win %d as red and %d as blue of %d (neither may reach %d)" % [
		"ok" if not cleared else "FAIL", won[0], won[1], FLOOR_GAMES, FLOOR_WINS])
	return not cleared


## True, and said so, when `level` beats the rules `FLOOR_WINS` times in
## `FLOOR_GAMES` from each seat.
func _above_the_rules(level: Difficulty) -> bool:
	var held: bool = true
	for seat: int in range(TacticalScenario.FACTIONS):
		var won: int = _wins_against_the_rules(level, seat, FLOOR_GAMES)
		print("%s: %s as %s beats the rules %d of %d (needs %d)" % ["ok" if won >= FLOOR_WINS else "FAIL", level.name,
			TacticalStatus.side_name(seat), won, FLOOR_GAMES, FLOOR_WINS])
		held = held and won >= FLOOR_WINS
	return held


## How many of `games` games `level` wins against the rules from `seat`.
func _wins_against_the_rules(level: Difficulty, seat: int, games: int) -> int:
	var won: int = 0
	for game: int in range(games):
		var seats: Array[BlueController] = [RuleBasedBlue.new(), RuleBasedBlue.new()]
		seats[seat] = LeveledBlue.new(level, 7919 * game + seat)
		won += 1 if TacticalMatch.play(seats[0], seats[1], game)["winner"] == seat else 0
	return won


## [games `one` won, games `other` won] over `games` seeds, each played with
## `one` as red and again as blue.
func _wins(one: Difficulty, other: Difficulty, games: int = GAMES) -> Array[int]:
	var won: Array[int] = [0, 0]
	for played: int in range(games * TacticalScenario.FACTIONS):
		var winner: int = _winner(one, other, played, played % TacticalScenario.FACTIONS)
		if winner != -1:
			won[winner] += 1
	return won


# Who wins game `game` -- its dice seeded `game` -- with `one` in `seat` and
# `other` in the other: 0 for `one`, 1 for `other`, -1 for a draw. Each
# side's noise has a seed of its own, and neither is the board's.
func _winner(one: Difficulty, other: Difficulty, game: int, seat: int) -> int:
	var seats: Array[BlueController] = [null, null]
	seats[seat] = LeveledBlue.new(one, 4 * game + seat)
	seats[1 - seat] = LeveledBlue.new(other, 4 * game + 2 + seat)
	var winner: int = TacticalMatch.play(seats[0], seats[1], game)["winner"]
	if winner == seat:
		return 0
	return 1 if winner == 1 - seat else -1
