# How the tactical board's controllers do against each other, measured: for
# each pairing, seeded games to the end, who won, in how many rounds, what
# was left unspent, and how often a piece did nothing.
#
#     ./scripts/godot --headless --path godot -s res://test/tactical_win_rates.gd \
#         [-- GAMES] [--at-most PAIRING:OUTCOME:COUNT ...]
#
# PAIRING is `rr` (rules red, rules blue), `rl` (rules red, learned blue) or
# `lr`; OUTCOME is `red`, `blue` or `draw`. Each `--at-most` is a limit a
# tuning task states as its acceptance -- `--at-most rr:red:28` with 40
# games says the side moving first wins at most 70% of the rules' mirror.
#
# It exists so that a change to the game's rules or to a controller is
# judged by numbers rather than by one game watched (T44, which found 20
# draws in 20 learned-against-rules games this way).
#
# Exit codes: 0 played, and every limit held (or none given); 1 a limit was
# broken, each one printed; 2 a limit could not be read.
extends SceneTree

const DEFAULT_GAMES: int = 20
const PAIRINGS: Array[String] = ["rr", "rl", "lr"]


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var games: int = int(arguments[0]) if not arguments.is_empty() and arguments[0].is_valid_int() else DEFAULT_GAMES
	var limits: Array[Array] = _limits(arguments)
	if limits.has([]):
		printerr("tactical_win_rates: a limit reads PAIRING:OUTCOME:COUNT, PAIRING one of %s" % ", ".join(PAIRINGS))
		quit(2)
		return
	var tallies: Dictionary = {
		"rr": _measure("rules (red) v rules (blue)", RuleBasedBlue.new(), RuleBasedBlue.new(), games),
		"rl": _measure("rules (red) v learned (blue)", RuleBasedBlue.new(), LearnedBlue.new(), games),
		"lr": _measure("learned (red) v rules (blue)", LearnedBlue.new(), RuleBasedBlue.new(), games),
	}
	var broken: int = 0
	for limit: Array in limits:
		if tallies[limit[0]][limit[1]] > limit[2]:
			printerr("tactical_win_rates: %s %s %d, and the limit is %d" % [limit[0], limit[1], tallies[limit[0]][limit[1]], limit[2]])
			broken += 1
	quit(1 if broken > 0 else 0)


# Every `--at-most` as [pairing, outcome, count]; an unreadable one as [].
static func _limits(arguments: PackedStringArray) -> Array[Array]:
	var found: Array[Array] = []
	for index: int in range(arguments.size() - 1):
		if arguments[index] != "--at-most":
			continue
		var parts: PackedStringArray = arguments[index + 1].split(":")
		var readable: bool = parts.size() == 3 and parts[0] in PAIRINGS and parts[1] in ["red", "blue", "draw"] and parts[2].is_valid_int()
		found.append([parts[0], parts[1], int(parts[2])] if readable else [])
	return found


# Play `games` seeded games and print what happened; return the tally.
func _measure(label: String, red: BlueController, blue: BlueController, games: int) -> Dictionary:
	var tally: Dictionary = {"red": 0, "blue": 0, "draw": 0}
	var rounds: int = 0
	var unspent: Dictionary = {0: 0, 1: 0}
	var counted: Dictionary = {"decisions": 0, "stuck": 0, "built": 0, "build turns": 0, "why not built": {}}
	for dice: int in range(games):
		var last: Array = [null]
		var result: Dictionary = TacticalMatch.play(_counting(red, counted), _counting(blue, counted), dice,
			func(state: BoardState) -> void: last[0] = state)
		tally[_side_word(result["winner"])] += 1
		rounds += result["rounds"]
		for side: int in unspent:
			unspent[side] += (last[0] as BoardState).funds_of(side)
	print("%s, %d games: red %d, blue %d, draws %d; %.1f rounds on average" % [
		label, games, tally["red"], tally["blue"], tally["draw"], float(rounds) / games])
	print("    funds left at the end, on average: red %.0f, blue %.0f" % [
		float(unspent[0]) / games, float(unspent[1]) / games])
	print("    walker decisions that stayed for want of a nearer walk: %d of %d; builds: %d of %d workshop turns" % [
		counted["stuck"], counted["decisions"], counted["built"], counted["build turns"]])
	for why: String in counted["why not built"]:
		print("    built nothing %d times: %s" % [counted["why not built"][why], why])
	return tally


static func _side_word(winner: int) -> String:
	if winner == TacticalVictory.DRAW:
		return "draw"
	return TacticalStatus.side_name(winner)


static func _counting(inner: BlueController, counted: Dictionary) -> BlueController:
	return _Counting.new(inner, counted)


# A controller that asks another and counts what it answered.
class _Counting extends BlueController:
	var _inner: BlueController
	var _counted: Dictionary

	func _init(inner: BlueController, counted: Dictionary) -> void:
		_inner = inner
		_counted = counted

	## The inner controller's name.
	func controller_name() -> String:
		return _inner.controller_name()

	## The inner controller's line.
	func describe() -> String:
		return _inner.describe()

	## The inner build, counted, with why when it is none.
	func decide_build(state: BoardState, workshop_id: int) -> TacticalDecision:
		var decision: TacticalDecision = _inner.decide_build(state, workshop_id)
		_counted["build turns"] += 1
		if decision.order != null:
			_counted["built"] += 1
		else:
			var why: String = decision.reason.trim_prefix("builds nothing: ")
			_counted["why not built"][why] = _counted["why not built"].get(why, 0) + 1
		return decision

	## The inner walk, counted, and whether it was stuck.
	func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
		var decision: TacticalDecision = _inner.decide_move(state, unit_id)
		_counted["decisions"] += 1
		if decision.reason.begins_with("stays: no walk this turn"):
			_counted["stuck"] += 1
		return decision

	## The inner attack, uncounted.
	func decide_attack(state: BoardState, unit_id: int) -> TacticalDecision:
		return _inner.decide_attack(state, unit_id)
