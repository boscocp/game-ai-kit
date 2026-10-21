# What each of the bot match's three techniques decides, measured (T51).
# Blue plays red over MATCHES seeded matches per pairing; red always has
# every technique on, and blue has one turned off at a time. The same seeds
# in every pairing, so each comparison is between the same matches with one
# switch changed.
#
# The claims are about the decisions, and stop there:
#
#   0. the mirror is fair: with the same techniques on both sides, blue's
#      mean margin of points held over red is within MIRROR_ERRORS standard
#      errors of zero. Every comparison below stands on it: twice it did
#      not hold, and blue won mirror matches 14-6 and 18-2;
#   1. claims: with them, blue's bots hold cover spots within a metre of
#      each other for at most CLAIMS_BUNCHED_ON seconds over all the
#      matches; without them, for at least CLAIMS_BUNCHED_OFF;
#   2. the commander: with it, blue's living bots are ordered to at least
#      COMMANDER_SPREAD times as many distinct points at once, on average,
#      as without it, when each bot heads for its own nearest point not its
#      team's;
#   3. retreat: blue's squads do retreat, and a retreating squad of two or
#      more always leaves someone covering -- it falls back in two waves,
#      never all at once;
#   4. honesty: no bot of either side, in any match, fires at an enemy it
#      cannot see along the line at the moment of the shot.
#
# Each is also asked of a planted case and must reject it: a blue team with
# a faster reaction and a steadier aim, for the mirror; the claims check
# of the matches without claims; a commander that wants every bot on one
# point; a retreat that moves the whole squad at once; a bot that shoots the
# nearest enemy through walls, and one that fires at whom it saw at its last
# decision without looking again.
#
# What the fighting makes of the decisions -- points held by each side,
# wins, the mean margin and its standard error over the seeds -- is printed
# and not claimed. The task first claimed the commander makes a team hold
# points longer, and retreat costs fewer bots a point lost. Measured on a
# fair mirror, the first is suggested and not shown (without it blue's
# margin was -80 +- 45, 1.8 errors), and the second is false: retreat
# costs the team the match. The owner chose on 2026-10-21 to say what was
# measured (docs/godot/botmatch.md) rather than tune until it passed.
#
#     ./scripts/godot --headless --path godot -s res://test/botmatch/botmatch_effects.gd
#
# Exit codes: 0 every claim held; 1 one did not, or a planted case passed;
# 2 a run with `-- --matches N`, which explores and claims nothing.
extends SceneTree

const MATCHES: int = 20
## The planted pairings are only asked to fail, so fewer matches do.
const PLANTED_MATCHES: int = 5
## Measured with the fair mirror: 0.0 s bunched with claims, 79 s without.
const CLAIMS_BUNCHED_ON: float = 10.0
const CLAIMS_BUNCHED_OFF: float = 40.0
const COMMANDER_SPREAD: float = 1.2
const MIRROR_ERRORS: float = 2.5
const PAIRINGS: Array[String] = ["everything", "no claims", "no commander", "no retreat"]
const PLANTED: Array[String] = ["commander on one point", "retreat in one wave", "sharper blue"]


## A bot that shoots the nearest living enemy, seen or not: the cheat the
## honesty count must catch.
class WallhackBot extends MatchBot:
	var world_ref: WeakRef

	## The honest list, then the cheat: aim at the nearest enemy, seen or not.
	func decide(now: float, visible: Array[int], positions: Dictionary, reaction: float,
			moving_in_retreat: bool) -> void:
		super(now, visible, positions, reaction, moving_in_retreat)
		if not alive() or action == RELOAD:
			return
		var world: BotMatch = world_ref.get_ref()
		var nearest: int = -1
		for other: MatchBot in world.bots:
			var nearer: bool = nearest == -1 or position.distance_to(other.position) < position.distance_to(world.bots[nearest].position)
			if other.team != team and other.alive() and nearer:
				nearest = other.id
		target = nearest
		action = SHOOT if nearest != -1 else action


## `-- --matches N` plays N instead, to explore.
var _matches: int = MATCHES


func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() == 2 and arguments[0] == "--matches":
		_matches = int(arguments[1])
	var started: int = Time.get_ticks_msec()
	var totals: Dictionary = {}
	for pairing: String in PAIRINGS:
		totals[pairing] = _play(pairing, _matches)
		_report(pairing, totals[pairing])
	for pairing: String in PLANTED:
		totals[pairing] = _play(pairing, PLANTED_MATCHES)
		_report(pairing, totals[pairing])
	var failures: Array[String] = _mirror(totals) + _claims(totals) + _commander(totals) + _retreat(totals)
	failures += _honesty(totals)
	for failure: String in failures:
		print(failure)
	print("botmatch effects: %d pairings of %d matches, %.0f s, %d failure(s)" % [
			PAIRINGS.size(), _matches, (Time.get_ticks_msec() - started) / 1000.0, failures.size()])
	var explored: bool = _matches != MATCHES
	if explored:
		print("explored at %d matches: the claims hold only at %d, so this run exits 2" % [_matches, MATCHES])
	quit(2 if explored else (1 if not failures.is_empty() else 0))


# Blue's counts summed over the pairing's matches, both sides' unseen shots,
# and each match's margin of points held, blue's minus red's.
func _play(pairing: String, matches: int) -> Dictionary:
	var rules := MatchRules.new()
	var arena := BotArena.new(rules.body_radius)
	var sums: Dictionary = {"held": 0.0, "red held": 0.0, "bunched": 0.0, "deaths": 0, "lost": 0,
			"unseen": 0, "shots": 0, "ordered": 0.0, "seconds": 0.0, "retreats": 0, "uncovered": 0,
			"blue wins": 0, "red wins": 0, "margins": PackedFloat64Array()}
	for seed_value: int in range(1, matches + 1):
		var red := MatchTeam.new("red", BotMatch.RED, rules)
		var world := BotMatch.new(seed_value, _blue_for(pairing, rules), red, rules, arena)
		world.play_out()
		_add(sums, world)
	return sums


func _blue_for(pairing: String, rules: MatchRules) -> MatchTeam:
	var blue := MatchTeam.new("blue", BotMatch.BLUE, rules)
	blue.use_claims = pairing != "no claims"
	blue.use_commander = pairing != "no commander"
	blue.may_retreat = pairing != "no retreat"
	if pairing == "commander on one point":
		blue.bots_per_point = BotMatch.BOTS_A_SIDE * 10
	blue.retreat_in_one_wave = pairing == "retreat in one wave"
	if pairing == "sharper blue":
		blue.reaction = 0.0
		blue.aim_error = deg_to_rad(1.0)
	return blue


func _add(sums: Dictionary, world: BotMatch) -> void:
	var blue: MatchStats = world.stats[BotMatch.BLUE]
	var red: MatchStats = world.stats[BotMatch.RED]
	sums["held"] += blue.point_seconds
	sums["red held"] += red.point_seconds
	sums["bunched"] += blue.bunched_seconds
	sums["deaths"] += blue.deaths
	sums["lost"] += blue.points_lost
	sums["unseen"] += blue.shots_unseen + red.shots_unseen
	sums["shots"] += blue.shots + red.shots
	sums["ordered"] += blue.order_spread
	sums["seconds"] += world.time
	sums["retreats"] += blue.retreat_decisions
	sums["uncovered"] += blue.retreats_uncovered
	sums["blue wins"] += 1 if world.score[BotMatch.BLUE] > world.score[BotMatch.RED] else 0
	sums["red wins"] += 1 if world.score[BotMatch.RED] > world.score[BotMatch.BLUE] else 0
	# A packed array is a value: append to it, then put it back.
	var margins: PackedFloat64Array = sums["margins"]
	margins.append(blue.point_seconds - red.point_seconds)
	sums["margins"] = margins


func _report(pairing: String, sums: Dictionary) -> void:
	var margin: Vector2 = _mean_and_error(sums["margins"])
	var outcome: Array = [pairing, sums["held"], sums["red held"], sums["blue wins"], sums["red wins"], margin.x, margin.y]
	print("%-22s held blue %6.0f s, red %6.0f s; wins %d-%d; margin %+.1f +- %.1f s a match" % outcome)
	var decided: Array = ["", _spread(sums), sums["bunched"], sums["retreats"], sums["uncovered"], sums["deaths"],
			sums["lost"], sums["unseen"], sums["shots"]]
	print("%22s orders over %.2f points, bunched %.1f s, %d retreating decisions (%d uncovered), %d deaths, %d points lost; %d of %d shots unseen" % decided)


# The mean of `values` and its standard error, the spread of that mean over
# seeds: a difference of two such means within about two errors is noise.
static func _mean_and_error(values: PackedFloat64Array) -> Vector2:
	var count: int = values.size()
	if count < 2:
		return Vector2(values[0] if count == 1 else 0.0, 0.0)
	var mean: float = 0.0
	for value: float in values:
		mean += value / count
	var squares: float = 0.0
	for value: float in values:
		squares += (value - mean) * (value - mean)
	return Vector2(mean, sqrt(squares / (count - 1)) / sqrt(count))


static func _spread(sums: Dictionary) -> float:
	return float(sums["ordered"]) / maxf(float(sums["seconds"]), 1.0)


# --- the mirror ----------------------------------------------------------------


func _mirror(totals: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var margin: Vector2 = _mean_and_error(totals["everything"]["margins"])
	var numbers: Array = [margin.x, margin.y, MIRROR_ERRORS]
	if not _fair(totals["everything"]):
		failures.append("mirror: blue's margin %+.1f +- %.1f s a match, more than %.1f errors from zero" % numbers)
	if _fair(totals["sharper blue"]):
		failures.append("mirror: planted, a faster, steadier blue passed as an even match")
	return failures


static func _fair(sums: Dictionary) -> bool:
	var margin: Vector2 = _mean_and_error(sums["margins"])
	return absf(margin.x) <= MIRROR_ERRORS * maxf(margin.y, 1e-6)


# --- the claims ----------------------------------------------------------------


func _claims(totals: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var numbers: Array = [totals["everything"]["bunched"], totals["no claims"]["bunched"], CLAIMS_BUNCHED_ON, CLAIMS_BUNCHED_OFF]
	if not _claims_hold(totals["everything"], totals["no claims"]):
		failures.append("claims: bunched %.1f s with them, %.1f s without; needs <= %.0f and >= %.0f" % numbers)
	if _claims_hold(totals["no claims"], totals["no claims"]):
		failures.append("claims: planted, the matches without claims met the margin")
	return failures


static func _claims_hold(with_them: Dictionary, without: Dictionary) -> bool:
	return with_them["bunched"] <= CLAIMS_BUNCHED_ON and without["bunched"] >= CLAIMS_BUNCHED_OFF


# --- the commander -------------------------------------------------------------


func _commander(totals: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var numbers: Array = [_spread(totals["everything"]), _spread(totals["no commander"]), COMMANDER_SPREAD]
	if not _commander_holds(totals["everything"], totals["no commander"]):
		failures.append("commander: blue's orders spanned %.2f points with it, %.2f without; needs %.2f times" % numbers)
	if _commander_holds(totals["commander on one point"], totals["no commander"]):
		failures.append("commander: planted, a commander that wants every bot on one point spread its orders")
	return failures


static func _commander_holds(with_it: Dictionary, without: Dictionary) -> bool:
	return _spread(with_it) >= COMMANDER_SPREAD * _spread(without)


# --- the retreat ---------------------------------------------------------------


func _retreat(totals: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var numbers: Array = [totals["everything"]["retreats"], totals["everything"]["uncovered"]]
	if not _retreat_holds(totals["everything"]):
		failures.append("retreat: %d retreating decisions, %d with nobody covering; needs some, and none uncovered" % numbers)
	if _retreat_holds(totals["retreat in one wave"]):
		failures.append("retreat: planted, a squad falling back all at once passed as covered")
	return failures


static func _retreat_holds(with_it: Dictionary) -> bool:
	return int(with_it["retreats"]) > 0 and int(with_it["uncovered"]) == 0


# --- honesty -------------------------------------------------------------------


func _honesty(totals: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	for pairing: String in PAIRINGS:
		if totals[pairing]["unseen"] > 0:
			failures.append("honesty: %d shots at unseen enemies in '%s'" % [totals[pairing]["unseen"], pairing])
	var wallhack: int = _planted_cheat(true)
	var stale: int = _planted_cheat(false)
	print("honesty: planted, a wallhack bot fired %d shots at enemies it could not see; one that did not look again, %d" % [wallhack, stale])
	if wallhack == 0:
		failures.append("honesty: planted, a bot shooting through walls fired no unseen shot")
	if stale == 0:
		failures.append("honesty: planted, a bot firing on its last decision's sight fired no unseen shot")
	return failures


# One match with blue's first bot replaced by a cheat that never looks along
# the line again before it fires; its team's unseen shots. `wallhack` also
# picks its targets through walls; otherwise its targets are honest ones,
# from the last decision's sight, which may since have stepped behind cover.
func _planted_cheat(wallhack: bool) -> int:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", BotMatch.BLUE, rules),
			MatchTeam.new("red", BotMatch.RED, rules), rules)
	var cheat: MatchBot = WallhackBot.new() if wallhack else MatchBot.new()
	if wallhack:
		(cheat as WallhackBot).world_ref = weakref(world)
	cheat.checks_its_line = false
	world.replace_bot(0, cheat)
	world.play_out()
	return world.stats[BotMatch.BLUE].shots_unseen
