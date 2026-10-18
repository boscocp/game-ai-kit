# How the tactical board's controllers do against each other, measured: for
# each pairing, seeded games to the end, who won, in how many rounds, what
# was left unspent, and how often a piece did nothing.
#
#     ./scripts/godot --headless --path godot -s res://test/tactical_win_rates.gd \
#         [-- GAMES] [--at-most|--at-least PAIRING:OUTCOME:COUNT ...]
#
# PAIRING is `rr` (rules red, rules blue), `rl` (rules red, learned blue),
# `lr`, `rp` (rules red, planned blue, T11) or `pr`. OUTCOME is a count of
# games -- `red`, `blue` or `draw` -- or, since T45, what a side did:
# `red-stuck-percent` and `blue-stuck-percent` (the share of its walker
# decisions that stayed for want of a nearer walk), `stuck-percent` (the
# larger of the two: both sides must keep moving), and `red-funds-left` and
# `blue-funds-left` (funds unspent at the end, averaged over the games), and
# since T46 `red-flips-percent`, `blue-flips-percent` and `flips-percent` (the
# larger): of a side's walker decisions that went at a fight or away from one,
# the share that did the opposite of the same walker's decision on its side's
# turn before -- advanced then retreated, or the other way round.
# Compared unrounded: 5.4% is over a limit of 5. Each `--at-most` or `--at-least` is a limit a tuning task states as its acceptance -- `--at-most rr:red:28`
# with 40 games says the side moving first wins at most 70% of the rules'
# mirror, and a band takes one of each.
#
# It exists so that a change to the game's rules or to a controller is
# judged by numbers rather than by one game watched (T44, which found 20
# draws in 20 learned-against-rules games this way).
#
# Exit codes: 0 played, and every limit held (or none given); 1 a limit was
# broken, each one printed; 2 a limit could not be read.
extends SceneTree

const DEFAULT_GAMES: int = 20
const PAIRINGS: Array[String] = ["rr", "rl", "lr", "rp", "pr"]
const OUTCOMES: Array[String] = ["red", "blue", "draw", "red-stuck-percent", "blue-stuck-percent",
	"stuck-percent", "red-funds-left", "blue-funds-left", "red-flips-percent", "blue-flips-percent",
	"flips-percent"]


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var games: int = int(arguments[0]) if not arguments.is_empty() and arguments[0].is_valid_int() else DEFAULT_GAMES
	var limits: Array[Array] = _limits(arguments)
	if limits.has([]):
		printerr("tactical_win_rates: a limit reads PAIRING:OUTCOME:COUNT, PAIRING one of %s, OUTCOME one of %s" % [", ".join(PAIRINGS), ", ".join(OUTCOMES)])
		quit(2)
		return
	var tallies: Dictionary = {
		"rr": _measure("rules (red) v rules (blue)", RuleBasedBlue.new(), RuleBasedBlue.new(), games),
		"rl": _measure("rules (red) v learned (blue)", RuleBasedBlue.new(), LearnedBlue.new(), games),
		"lr": _measure("learned (red) v rules (blue)", LearnedBlue.new(), RuleBasedBlue.new(), games),
		"rp": _measure("rules (red) v planner (blue)", RuleBasedBlue.new(), PlannedBlue.new(), games),
		"pr": _measure("planner (red) v rules (blue)", PlannedBlue.new(), RuleBasedBlue.new(), games),
	}
	var broken: int = 0
	for limit: Array in limits:
		broken += 0 if _holds(limit, tallies[limit[0]][limit[1]]) else 1
	quit(1 if broken > 0 else 0)


# True when `counted` keeps within `limit`; said on stderr when it does not.
static func _holds(limit: Array, counted: float) -> bool:
	if (limit[3] and counted <= limit[2]) or (not limit[3] and counted >= limit[2]):
		return true
	printerr("tactical_win_rates: %s %s %.1f, and the limit is %s %d" % [
		limit[0], limit[1], counted, "at most" if limit[3] else "at least", limit[2]])
	return false


# Every limit as [pairing, outcome, count, true for at most]; an unreadable
# one as [].
static func _limits(arguments: PackedStringArray) -> Array[Array]:
	var found: Array[Array] = []
	for index: int in range(arguments.size()):
		if not arguments[index] in ["--at-most", "--at-least"]:
			continue
		# A limit with nothing after it is unreadable, not absent: dropping
		# it would pass a run the caller meant to hold to something.
		var given: String = arguments[index + 1] if index + 1 < arguments.size() else ""
		var parts: PackedStringArray = given.split(":")
		var readable: bool = parts.size() == 3 and parts[0] in PAIRINGS and parts[1] in OUTCOMES and parts[2].is_valid_int()
		found.append([parts[0], parts[1], int(parts[2]), arguments[index] == "--at-most"] if readable else [])
	return found


# Play `games` seeded games and print what happened, each side counted on
# its own -- the two controllers share nothing, and a figure added up over
# both credits one side with the other's habits (wave 47's review).
# Returns the tally.
func _measure(label: String, red: BlueController, blue: BlueController, games: int) -> Dictionary:
	var tally: Dictionary = {"red": 0, "blue": 0, "draw": 0}
	var rounds: int = 0
	var unspent: Dictionary = {0: 0, 1: 0}
	var counted: Array[Dictionary] = [_empty_count(), _empty_count()]
	for dice: int in range(games):
		var last: Array = [null]
		var result: Dictionary = TacticalMatch.play(_Counting.new(red, counted[0]), _Counting.new(blue, counted[1]), dice,
			func(state: BoardState) -> void: last[0] = state)
		tally[_side_word(result["winner"])] += 1
		rounds += result["rounds"]
		for side: int in unspent:
			unspent[side] += (last[0] as BoardState).funds_of(side)
	print("%s, %d games: red %d, blue %d, draws %d; %.1f rounds on average" % [
		label, games, tally["red"], tally["blue"], tally["draw"], float(rounds) / games])
	for side: int in range(2):
		var name: String = TacticalStatus.side_name(side)
		_print_side(name, counted[side], float(unspent[side]) / games)
		tally[name + "-stuck-percent"] = 100.0 * counted[side]["stuck"] / maxi(counted[side]["decisions"], 1)
		tally[name + "-funds-left"] = float(unspent[side]) / games
		tally[name + "-flips-percent"] = 100.0 * counted[side]["flips"] / maxi(counted[side]["fight decisions"], 1)
	tally["stuck-percent"] = maxf(tally["red-stuck-percent"], tally["blue-stuck-percent"])
	tally["flips-percent"] = maxf(tally["red-flips-percent"], tally["blue-flips-percent"])
	return tally


static func _empty_count() -> Dictionary:
	return {"decisions": 0, "stuck": 0, "built": 0, "build turns": 0, "why not built": {},
		"fight decisions": 0, "flips": 0}


static func _print_side(side: String, counted: Dictionary, funds_left: float) -> void:
	print("    %s: %.0f funds left at the end on average; %d of %d walker decisions stayed for want of a nearer walk; built or bought on %d of %d workshop turns; %d flips in %d decisions at or away from a fight" % [
		side, funds_left, counted["stuck"], counted["decisions"], counted["built"], counted["build turns"],
		counted["flips"], counted["fight decisions"]])
	for why: String in counted["why not built"]:
		if counted["why not built"][why] == 0:
			continue
		print("        built nothing %d times: %s" % [counted["why not built"][why], why])


static func _side_word(winner: int) -> String:
	if winner == TacticalVictory.DRAW:
		return "draw"
	return TacticalStatus.side_name(winner)


# A controller that asks another and counts what it answered.
class _Counting extends BlueController:
	var _inner: BlueController
	var _counted: Dictionary
	# The turn the workshop was last asked in, and why it built nothing then
	# ("" when it built): `BlueTurn` asks a boxed-in workshop twice in one
	# turn (T45), and that is still one workshop turn.
	var _asked_on: int = -1
	var _missed_because: String = ""
	# Each walker's last fight decision, as [turn, "at" or "away"].
	var _last_fight: Dictionary = {}

	func _init(inner: BlueController, counted: Dictionary) -> void:
		_inner = inner
		_counted = counted

	## The inner controller's start of turn.
	func begin_turn(state: BoardState) -> void:
		_inner.begin_turn(state)

	## The inner controller's plan.
	func plan_lines() -> Array[String]:
		return _inner.plan_lines()

	## The inner controller's name.
	func controller_name() -> String:
		return _inner.controller_name()

	## The inner controller's line.
	func describe() -> String:
		return _inner.describe()

	## The inner build, counted, with why when it is none.
	func decide_build(state: BoardState, workshop_id: int) -> TacticalDecision:
		var decision: TacticalDecision = _inner.decide_build(state, workshop_id)
		var built: bool = decision.order != null or decision.upgrade != null
		if state.turn_number == _asked_on:
			_count_second_asking(built)
			return decision
		_asked_on = state.turn_number
		_counted["build turns"] += 1
		_missed_because = "" if built else decision.reason.trim_prefix("builds nothing: ")
		if built:
			_counted["built"] += 1
		else:
			_counted["why not built"][_missed_because] = _counted["why not built"].get(_missed_because, 0) + 1
		return decision

	# A decision at a fight or away from one, and whether it reverses the
	# same walker's on its side's previous turn. Read from the reason: a
	# retreat says "retreats" or "stays, out of the reach"; going at a fight
	# says "to attack" or "joins the fight".
	func _count_flip(state: BoardState, unit_id: int, reason: String) -> void:
		var away: bool = reason.begins_with("retreats") or reason.begins_with("stays, out of the reach")
		var at: bool = reason.contains("to attack the") or reason.contains("joins the fight")
		if not (away or at):
			return
		_counted["fight decisions"] += 1
		var kind: String = "away" if away else "at"
		var before: Array = _last_fight.get(unit_id, [])
		var reversed: bool = not before.is_empty() and before[0] == state.turn_number - TacticalScenario.FACTIONS and before[1] != kind
		_counted["flips"] += 1 if reversed else 0
		_last_fight[unit_id] = [state.turn_number, kind]

	# The same turn asked again: a build now takes back the miss counted
	# the first time.
	func _count_second_asking(built: bool) -> void:
		if not built or _missed_because == "":
			return
		_counted["built"] += 1
		_counted["why not built"][_missed_because] -= 1
		_missed_because = ""

	## The inner walk, counted, and whether it was stuck.
	func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
		var decision: TacticalDecision = _inner.decide_move(state, unit_id)
		_count_flip(state, unit_id, decision.reason)
		_counted["decisions"] += 1
		if decision.reason.begins_with("stays: no walk this turn"):
			_counted["stuck"] += 1
		return decision

	## The inner attack, uncounted.
	func decide_attack(state: BoardState, unit_id: int) -> TacticalDecision:
		return _inner.decide_attack(state, unit_id)
