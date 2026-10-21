# What each of the bot match's three techniques does, measured (T51). Blue
# plays red over MATCHES seeded matches per pairing; red always has every
# technique on, and blue has one turned off at a time. The same seeds in
# every pairing, so each comparison is between the same matches with one
# switch changed.
#
#   1. claims: with them, blue's bots hold cover spots within a metre of
#      each other for at most CLAIMS_BUNCHED_ON seconds over all the matches;
#      without them, for at least CLAIMS_BUNCHED_OFF;
#   2. the commander: with it, blue holds points for at least
#      COMMANDER_MARGIN times as long as without it;
#   3. retreat: with it, blue loses at most RETREAT_RATIO times as many bots
#      per point lost as without it;
#   4. honesty: no bot of either side, in any match, fires at an enemy not in
#      its own sight row. A planted bot that fires at the nearest enemy
#      whatever it sees must be caught by the same count.
#
# Each of 1-3 is also asked of a pairing against itself -- the same matches
# twice -- and must fail there: a margin met by two identical runs is a
# margin that measures nothing. Every number it compares is printed.
#
#     ./scripts/godot --headless --path godot -s res://test/botmatch/botmatch_effects.gd
#
# Exit codes: 0 every claim held; 1 one did not, or a planted case passed.
extends SceneTree

const MATCHES: int = 20
## `-- --matches N` plays N instead, to explore; the claims are only
## checked at MATCHES.
const CLAIMS_BUNCHED_ON: float = 60.0
const CLAIMS_BUNCHED_OFF: float = 600.0
const COMMANDER_MARGIN: float = 1.1
const RETREAT_RATIO: float = 0.8
const PAIRINGS: Array[String] = ["everything", "no claims", "no commander", "no retreat"]


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


var _matches: int = MATCHES


func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() == 2 and arguments[0] == "--matches":
		_matches = int(arguments[1])
	var started: int = Time.get_ticks_msec()
	var totals: Dictionary = {}
	for pairing: String in PAIRINGS:
		totals[pairing] = _play(pairing)
		_report(pairing, totals[pairing])
	var failures: Array[String] = _claims(totals) + _commander(totals) + _retreat(totals)
	failures += _honesty(totals)
	for failure: String in failures:
		print(failure)
	print("botmatch effects: %d pairings of %d matches, %.0f s, %d failure(s)" % [
			PAIRINGS.size(), _matches, (Time.get_ticks_msec() - started) / 1000.0, failures.size()])
	var explored: bool = _matches != MATCHES
	if explored:
		print("explored at %d matches: the claims hold only at %d, so this run exits 2" % [_matches, MATCHES])
	quit(2 if explored else (1 if not failures.is_empty() else 0))


# Blue's counts summed over the pairing's matches, and both sides' unseen shots.
func _play(pairing: String) -> Dictionary:
	var rules := MatchRules.new()
	var arena := BotArena.new(rules.body_radius)
	var sums: Dictionary = {"held": 0.0, "bunched": 0.0, "deaths": 0, "lost": 0, "unseen": 0, "shots": 0}
	for seed_value: int in range(1, _matches + 1):
		var blue := MatchTeam.new("blue", BotMatch.BLUE, rules)
		blue.use_claims = pairing != "no claims"
		blue.use_commander = pairing != "no commander"
		blue.may_retreat = pairing != "no retreat"
		var world := BotMatch.new(seed_value, blue, MatchTeam.new("red", BotMatch.RED, rules), rules, arena)
		world.play_out()
		var stats: MatchStats = world.stats[BotMatch.BLUE]
		sums["held"] += stats.point_seconds
		sums["bunched"] += stats.bunched_seconds
		sums["deaths"] += stats.deaths
		sums["lost"] += stats.points_lost
		sums["unseen"] += stats.shots_unseen + world.stats[BotMatch.RED].shots_unseen
		sums["shots"] += stats.shots + world.stats[BotMatch.RED].shots
	return sums


func _report(pairing: String, sums: Dictionary) -> void:
	print("%-13s blue held %6.0f s, bunched %6.1f s, %4d deaths, %3d points lost (%.1f a point); %d of %d shots unseen" % [
			pairing, sums["held"], sums["bunched"], sums["deaths"], sums["lost"], _per_point(sums),
			sums["unseen"], sums["shots"]])


static func _per_point(sums: Dictionary) -> float:
	return float(sums["deaths"]) / maxf(float(sums["lost"]), 1.0)


# --- the claims ----------------------------------------------------------------


func _claims(totals: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var numbers: Array = [totals["everything"]["bunched"], totals["no claims"]["bunched"], CLAIMS_BUNCHED_ON, CLAIMS_BUNCHED_OFF]
	if not _claims_hold(totals["everything"], totals["no claims"]):
		failures.append("claims: bunched %.1f s with them, %.1f s without; needs <= %.0f and >= %.0f" % numbers)
	if _claims_hold(totals["no claims"], totals["no claims"]):
		failures.append("claims: planted, the same matches twice met the margin")
	return failures


static func _claims_hold(with_them: Dictionary, without: Dictionary) -> bool:
	return with_them["bunched"] <= CLAIMS_BUNCHED_ON and without["bunched"] >= CLAIMS_BUNCHED_OFF


# --- the commander -------------------------------------------------------------


func _commander(totals: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var numbers: Array = [totals["everything"]["held"], totals["no commander"]["held"], COMMANDER_MARGIN]
	if not _commander_holds(totals["everything"], totals["no commander"]):
		failures.append("commander: blue held %.0f s with it, %.0f s without; needs %.2f times" % numbers)
	if _commander_holds(totals["everything"], totals["everything"]):
		failures.append("commander: planted, the same matches twice met the margin")
	return failures


static func _commander_holds(with_it: Dictionary, without: Dictionary) -> bool:
	return with_it["held"] >= COMMANDER_MARGIN * float(without["held"])


# --- the retreat ---------------------------------------------------------------


func _retreat(totals: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var numbers: Array = [_per_point(totals["everything"]), _per_point(totals["no retreat"]), RETREAT_RATIO]
	if not _retreat_holds(totals["everything"], totals["no retreat"]):
		failures.append("retreat: %.1f bots lost a point with it, %.1f without; needs at most %.2f times" % numbers)
	if _retreat_holds(totals["everything"], totals["everything"]):
		failures.append("retreat: planted, the same matches twice met the margin")
	return failures


static func _retreat_holds(with_it: Dictionary, without: Dictionary) -> bool:
	return _per_point(with_it) <= RETREAT_RATIO * _per_point(without)


# --- honesty -------------------------------------------------------------------


func _honesty(totals: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	for pairing: String in PAIRINGS:
		if totals[pairing]["unseen"] > 0:
			failures.append("honesty: %d shots at unseen enemies in '%s'" % [totals[pairing]["unseen"], pairing])
	var cheated: int = _wallhack_match()
	if cheated == 0:
		failures.append("honesty: planted, a bot shooting through walls fired no unseen shot")
	print("honesty: a planted wallhack bot fired %d shots at enemies it did not see" % cheated)
	return failures


# One match with blue's first bot replaced by the cheat; red's unseen shots.
func _wallhack_match() -> int:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", BotMatch.BLUE, rules),
			MatchTeam.new("red", BotMatch.RED, rules), rules)
	var cheat := WallhackBot.new()
	cheat.world_ref = weakref(world)
	world.replace_bot(0, cheat)
	world.play_out()
	return world.stats[BotMatch.BLUE].shots_unseen
