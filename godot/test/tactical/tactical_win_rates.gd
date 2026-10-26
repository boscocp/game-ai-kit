# How the tactical board's controllers do against each other, measured: for
# each pairing, seeded games to the end, who won, in how many rounds, what
# was left unspent, and how often a piece did nothing.
#
#     ./scripts/godot --headless --path godot -s res://test/tactical/tactical_win_rates.gd \
#         [-- GAMES] [--pairings rr,rl,...] [--at-most|--at-least PAIRING:OUTCOME:COUNT ...]
#
# `--pairings` plays only those (T47's sweep plays the rules' mirror alone,
# at 100 games); a limit on a pairing not played cannot be read.
#
# PAIRING is `rr` (rules red, rules blue), `rl` (rules red, learned blue),
# `lr`, `rp` (rules red, planned blue, T11) or `pr`. OUTCOME is a count of
# games -- `red`, `blue` or `draw` -- or, since T45, what a side did:
# `red-stuck-percent` and `blue-stuck-percent` (the share of its walker
# decisions that stayed for want of a nearer walk), `stuck-percent` (the
# larger of the two: both sides must keep moving), and `red-funds-left` and
# `blue-funds-left` (funds unspent at the end, averaged over the games),
# `at-the-limit` (games settled by score or drawn at the round limit rather
# than at a workshop -- T47's rule turns stalemates into wins, and this is
# how many it did), `red-ford-games` and `blue-ford-games` (games in which
# that side walked over a ford, T48 -- the reference asks both crossings to
# be used -- this counts stepping onto one, not a whole crossing), and
# since T46 `red-flips-percent`, `blue-flips-percent` and `flips-percent` (the
# larger): of a side's walks that ended nearer the nearest enemy walker or
# further from it, the share that went the other way from the same walker's
# walk on its side's turn before -- in, then out, or out, then in. Measured
# by distance and not read from the reasons, so a walk that stood its ground
# and went elsewhere is counted, and the rules are measured the same way.
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
const OUTCOMES: Array[String] = ["red", "blue", "draw", "at-the-limit", "red-stuck-percent", "blue-stuck-percent",
	"stuck-percent", "red-funds-left", "blue-funds-left", "red-flips-percent", "blue-flips-percent",
	"flips-percent", "red-ford-games", "blue-ford-games"]


func _init() -> void:
	# The reasons are read in English, whatever the machine's locale (T79).
	TranslationServer.set_locale("en")
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var games: int = int(arguments[0]) if not arguments.is_empty() and arguments[0].is_valid_int() else DEFAULT_GAMES
	var limits: Array[Array] = _limits(arguments)
	if limits.has([]):
		printerr("tactical_win_rates: a limit reads PAIRING:OUTCOME:COUNT, PAIRING one of %s, OUTCOME one of %s" % [", ".join(PAIRINGS), ", ".join(OUTCOMES)])
		quit(2)
		return
	var played: Array[String] = _pairings_asked(arguments)
	if played.is_empty() or limits.any(func(limit: Array) -> bool: return not limit[0] in played):
		printerr("tactical_win_rates: --pairings names pairings from %s, and every limit's pairing must be played" % ", ".join(PAIRINGS))
		quit(2)
		return
	var tallies: Dictionary = {}
	for pairing: String in played:
		tallies[pairing] = _measure_pairing(pairing, games)
	var broken: int = 0
	for limit: Array in limits:
		broken += 0 if _holds(limit, tallies[limit[0]][limit[1]]) else 1
	quit(1 if broken > 0 else 0)


# The pairings `--pairings` names, all of them when it is not given, or []
# when it names one that does not exist.
static func _pairings_asked(arguments: PackedStringArray) -> Array[String]:
	var at: int = arguments.find("--pairings")
	if at == -1:
		return PAIRINGS.duplicate()
	var asked: Array[String] = []
	for name: String in (arguments[at + 1] if at + 1 < arguments.size() else "").split(","):
		if not name in PAIRINGS:
			return []
		asked.append(name)
	return asked


# One pairing, measured: its first letter is red's controller, its second
# blue's -- r rules, l learned, p planner.
func _measure_pairing(pairing: String, games: int) -> Dictionary:
	var names: Dictionary = {"r": "rules", "l": "learned", "p": "planner"}
	return _measure("%s (red) v %s (blue)" % [names[pairing[0]], names[pairing[1]]],
		_controller(pairing[0]), _controller(pairing[1]), games)


static func _controller(letter: String) -> BlueController:
	if letter == "l":
		return LearnedBlue.new()
	if letter == "p":
		return PlannedBlue.new()
	return RuleBasedBlue.new()


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
	var tally: Dictionary = {"red": 0, "blue": 0, "draw": 0, "at-the-limit": 0}
	var rounds: int = 0
	var unspent: Dictionary = {0: 0, 1: 0}
	var counted: Array[Dictionary] = [_empty_count(), _empty_count()]
	for dice: int in range(games):
		var last: Array = [null]
		var result: Dictionary = TacticalMatch.play(_Counting.new(red, counted[0]), _Counting.new(blue, counted[1]), dice,
			func(state: BoardState) -> void: last[0] = state)
		tally[_side_word(result["winner"])] += 1
		tally["at-the-limit"] += 1 if result["at_the_limit"] else 0
		rounds += result["rounds"]
		for side: int in unspent:
			unspent[side] += (last[0] as BoardState).funds_of(side)
	print("%s, %d games: red %d, blue %d, draws %d; %.1f rounds on average; %d settled at the round limit" % [
		label, games, tally["red"], tally["blue"], tally["draw"], float(rounds) / games, tally["at-the-limit"]])
	for side: int in range(2):
		var name: String = TacticalStatus.side_name(side)
		_print_side(name, counted[side], float(unspent[side]) / games)
		tally[name + "-stuck-percent"] = 100.0 * counted[side]["stuck"] / maxi(counted[side]["decisions"], 1)
		tally[name + "-funds-left"] = float(unspent[side]) / games
		tally[name + "-flips-percent"] = 100.0 * counted[side]["flips"] / maxi(counted[side]["walks in or out"], 1)
		tally[name + "-ford-games"] = counted[side]["ford games"]
	tally["stuck-percent"] = maxf(tally["red-stuck-percent"], tally["blue-stuck-percent"])
	tally["flips-percent"] = maxf(tally["red-flips-percent"], tally["blue-flips-percent"])
	return tally


static func _empty_count() -> Dictionary:
	return {"decisions": 0, "stuck": 0, "built": 0, "build turns": 0, "why not built": {},
		"walks in or out": 0, "flips": 0, "ford games": 0}


static func _print_side(side: String, counted: Dictionary, funds_left: float) -> void:
	print("    %s: %.0f funds left at the end on average; %d of %d walker decisions stayed for want of a nearer walk; built or bought on %d of %d workshop turns; %d flips in %d walks nearer or further from the nearest enemy walker; onto a ford in %d games" % [
		side, funds_left, counted["stuck"], counted["decisions"], counted["built"], counted["build turns"],
		counted["flips"], counted["walks in or out"], counted["ford games"]])
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
	# True once this side has walked over a ford in this game; a `_Counting`
	# is made for each side of each game.
	var _forded: bool = false
	# Each walker's last walk that went nearer or further, as [turn, "in" or
	# "out"].
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

	# The first walk this game that enters a ford.
	func _count_ford(decision: TacticalDecision) -> void:
		if _forded or decision.move == null:
			return
		for cell: Vector2i in decision.move.path:
			if TacticalScenario.MAP[cell.y][cell.x] == TacticalRules.FORD:
				_forded = true
				_counted["ford games"] += 1
				return

	# A walk nearer the nearest enemy walker or further from it, and whether
	# it reverses the same walker's walk on its side's previous turn.
	func _count_flip(state: BoardState, unit_id: int, decision: TacticalDecision) -> void:
		var unit: Unit = state.unit_by_id(unit_id)
		var enemy: Unit = _nearest_enemy_walker(state, unit)
		if decision.move == null or enemy == null:
			return
		var before: int = TacticalCombat.distance(unit.cell, enemy.cell)
		var after: int = TacticalCombat.distance(decision.move.destination(unit.cell), enemy.cell)
		if after == before:
			return
		_counted["walks in or out"] += 1
		var kind: String = "in" if after < before else "out"
		var last: Array = _last_fight.get(unit_id, [])
		var reversed: bool = not last.is_empty() and last[0] == state.turn_number - TacticalScenario.FACTIONS and last[1] != kind
		_counted["flips"] += 1 if reversed else 0
		_last_fight[unit_id] = [state.turn_number, kind]

	static func _nearest_enemy_walker(state: BoardState, unit: Unit) -> Unit:
		var nearest: Unit = null
		for other: Unit in state.units:
			if other.faction == unit.faction or not other.type.mobile:
				continue
			if nearest == null or TacticalCombat.distance(unit.cell, other.cell) < TacticalCombat.distance(unit.cell, nearest.cell):
				nearest = other
		return nearest

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
		_count_flip(state, unit_id, decision)
		_count_ford(decision)
		_counted["decisions"] += 1
		if decision.reason.begins_with("stays: no walk this turn"):
			_counted["stuck"] += 1
		return decision

	## The inner attack, uncounted.
	func decide_attack(state: BoardState, unit_id: int) -> TacticalDecision:
		return _inner.decide_attack(state, unit_id)
