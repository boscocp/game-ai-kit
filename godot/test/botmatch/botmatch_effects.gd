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
#   3. retreat: blue's squads do fall back, and a squad of two or more with
#      a member falling back always leaves someone covering -- it falls
#      back in two waves, never all at once (since T65 each bot weighs
#      falling back, and the waves are the squad's coordination);
#   4. honesty: no bot of either side, in any match, fires at an enemy it
#      cannot see along the line at the moment of the shot, and none fires
#      while it sprints, with some sprinting done (T66);
#   5. aim (T66): blue aiming where a shot is worth the most damage does at
#      least AIM_BETTER times the damage a shot of a blue that always aims
#      at the head;
#   6. ammunition (T66): a blue that always goes back to its base for
#      rounds holds less than one that weighs it, by MIRROR_ERRORS standard
#      errors of the two margins;
#   7. the mirror on the other arena (T66): the same agents, on the yards,
#      are as fair as on the lanes -- the map is in the data, not the code.
#      It is claim 0's check, `_fair`, asked of another arena, so claim 0's
#      planted sharper blue is its planted case too. And on the yards too
#      nobody fires unseen or sprinting, and a retreat always leaves
#      someone covering (T67);
#   8. portability (T67): on RANDOM_ARENAS arenas made by `RandomArena`,
#      random within the mirror and never seen before, every match plays to
#      its end, every point is taken at least once, and nobody fires at an
#      enemy unseen or while sprinting;
#   9. regeneration (T68): after a hit, a bot's health does not come back
#      before the rules' delay, never passes its whole, and does come back
#      to it -- the rule stepped alone, as a match steps it;
#  10. healing weighed (T68): a blue that weighs when to break off to heal
#      holds points at least as long as one that never breaks off to heal
#      and one that always does below a fixed health -- neither holds more
#      than it by MIRROR_ERRORS standard errors of the two margins.
#
#      **What this claim cannot catch, said outright: a weighing that does
#      nothing.** Never healing put in the weigher's place passes it. The
#      wave 76 review asked for the stronger claim -- weighing holds longer
#      than each -- and it was written and measured, once the health an
#      errand gains was priced by the bot's exposure: weighing +10.0 +- 22.7
#      s a match, never healing +25.4 +- 23.7, below half -53.1 +- 20.8. It
#      failed for both (0.5 errors the wrong way; 2.1 errors, short of 2.5),
#      and the owner's rule is to say so rather than tune until it passes.
#      So the weak claim is held, the strong one printed, and the planted
#      case is one the weak claim can reject: always going back for rounds.
#
#  11. falling back weighed (T65): blue falls back at least
#      FALL_BACKS_A_MATCH times a match on average, and of its fall-backs
#      from a point it held, the share followed by that point neutralised
#      within MatchFallBacks.LOST_WITHIN seconds is at most LOST_SHARE --
#      half the share today's retreat measured before the change. The two
#      planted cases: a blue that never falls back (the no-retreat
#      pairing) fails the first; one that prices the point it gives up at
#      nothing fails the second. And the T65 claim -- everything holds points
#      longer than any one technique off, by MIRROR_ERRORS combined errors --
#      is printed, and claimed only once a measured run supports it.
#
# Each is also asked of a planted case and must reject it: a blue team with
# a faster reaction and a steadier aim, for the mirror; the claims check
# of the matches without claims; a commander that wants every bot on one
# point; a retreat that moves the whole squad at once; a bot that shoots the
# nearest enemy through walls, and one that keeps firing at whom it saw for
# a second after without looking again; a blue that always aims at the
# head put in aiming by worth's place; the weighing blue put in always going
# back's; the matches without claims in the claims' place; a random
# arena with one point walled in, for portability; regeneration with no
# delay; always going back put in the weighing healer's place; and, for
# falling back, the blue that never does and one that prices at nothing
# the point it gives up.
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
## The planted sharper blue, against the mirror: with the lanes' fewer
## fights, five matches left its margin inside the errors (+80 +- 76 s);
## and always going back, five of which held less at only 2.2 errors.
## In T67 ten, and then twenty, passed it as even (+64 +- 44, +17 +- 28)
## -- not for want of matches: its power holders went back half full and
## stood at the base all match, a fault in the errand's facts, now fixed.
const SHARPER_MATCHES: int = 10
const ALWAYS_BACK_MATCHES: int = 10
## The yards' mirror: as many matches as the lanes' claims. Its matches
## swing more (+-250 s), and ten measured blue 7-3 at 1.5 errors after two
## mirror faults were fixed, and 9-1 before: a fault would show, noise less.
## When T67's weighing bots failed it at 20 (+100.1 +- 32.4 s), the cause
## was a fault -- red perceived blue's new posture, blue red's old one --
## and it was fixed rather than the count raised (the owner's rule).
const YARDS_MATCHES: int = 20
## Measured on the lanes: 4.70 damage a shot by worth, 3.73 always the head.
## Arenas made at random, one match each: enough to meet several maps, few
## enough to keep the run in minutes.
const RANDOM_ARENAS: int = 6
const AIM_BETTER: float = 1.1

## Measured with the fair mirror: 0.0 s bunched with claims, 79 s without.
const CLAIMS_BUNCHED_ON: float = 10.0
const CLAIMS_BUNCHED_OFF: float = 40.0
## The commander's orders must span this many times the points of each bot
## going to its own nearest. 1.2 was set in T51, when the commander made
## 1.29 times; on the lanes it makes 2.0 times, and the planted commander on
## one point made 1.19, 1.24 and 1.29 times in three runs -- passing 1.2 in
## the last. 1.5 asks more of the commander and rejects the plant.
const COMMANDER_SPREAD: float = 1.5
const MIRROR_ERRORS: float = 2.5
## Falling back weighed (T65). At least this many fall-backs a match: the
## weighing must do something, T68's hole.
const FALL_BACKS_A_MATCH: float = 1.0
## Half the share measured before the change: today's retreat, at 581820e (wave 96's play), lost a held point within 8 s after 95 of its 298 fall-backs from one, 0.319.
const LOST_SHARE: float = 0.159
## The planted blue that prices the point at nothing plays this many.
const POINT_FREE_MATCHES: int = 10
const PAIRINGS: Array[String] = ["everything", "no claims", "no commander", "no retreat"]
const PLANTED: Array[String] = ["commander on one point", "retreat in one wave", "sharper blue",
		"always the head", "never resupply", "always resupply", "the point priced at nothing"]
## The two healers the weighing one is held against (T68): as many matches
## as the pairings above, for their margins are compared with its.
const HEALERS: Array[String] = ["never heals", "heals below half"]
## How long a regeneration is stepped, after a hit at its start.
const REGENERATION_SECONDS: float = 20.0


## A bot that shoots the nearest living enemy, seen or not: the cheat the
## honesty count must catch.
class WallhackBot extends MatchBot:
	var world_ref: WeakRef

	## The honest list, then the cheat: aim at the nearest enemy, seen or not.
	func decide(percepts: MatchPercepts, reaction: float) -> void:
		super(percepts, reaction)
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


## A bot that keeps firing at whom it saw for up to STALE_FOR seconds after
## the enemy left its sight, without looking again: the second cheat the
## honesty count must catch. One decision's staleness, 0.2 s, was too little
## on the lanes: an enemy seldom stepped behind cover in so short a time,
## and the planted bot fired no unseen shot at all.
class StaleSightBot extends MatchBot:
	const STALE_FOR: float = 1.0
	var _last_target: int = -1
	var _last_seen: float = -INF

	## The honest list; then, with nobody in sight, the last enemy it saw.
	func decide(percepts: MatchPercepts, reaction: float) -> void:
		super(percepts, reaction)
		var now: float = percepts.now
		if target != -1:
			_last_target = target
			_last_seen = now
		elif alive() and ammo > 0 and action != RELOAD and now - _last_seen <= STALE_FOR:
			target = _last_target
			action = SHOOT


## `-- --matches N` plays N instead, to explore.
var _matches: int = MATCHES
## Serial, one shard of the matches, or the merge of every shard's (T72).
var _shards: EffectShards = null


func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.find("--matches") != -1 and arguments.find("--matches") + 1 < arguments.size():
		_matches = int(arguments[arguments.find("--matches") + 1])
	_shards = EffectShards.from_arguments(arguments)
	var started: int = Time.get_ticks_msec()
	var totals: Dictionary = {}
	for pairing: String in PAIRINGS:
		totals[pairing] = _play(pairing, _matches)
		_report(pairing, totals[pairing])
	for pairing: String in PLANTED:
		totals[pairing] = _play(pairing, _planted_matches(pairing))
		_report(pairing, totals[pairing])
	for pairing: String in HEALERS:
		totals[pairing] = _play(pairing, _matches)
		_report(pairing, totals[pairing])
	totals["the yards"] = _play("the yards", YARDS_MATCHES)
	_report("the yards", totals["the yards"])
	for pairing: String in ["random arenas", "a point walled in"]:
		totals[pairing] = _play(pairing, RANDOM_ARENAS if pairing == "random arenas" else 1)
		_report(pairing, totals[pairing])
	if _shards.mode == EffectShards.Mode.SHARD:
		quit(_shards.write())
		return
	var failures: Array[String] = _shards.findings() + _mirror(totals) + _claims(totals) + _commander(totals) + _retreat(totals)
	failures += _honesty(totals) + _aim(totals) + _ammunition(totals) + _portability(totals)
	failures += _regeneration() + _healing(totals) + _falling_back(totals)
	_print_team_claim(totals)
	_print_dying(totals["everything"])
	for failure: String in failures:
		print(failure)
	print("botmatch effects: %d pairings of %d matches, %.0f s, %d failure(s)" % [
			PAIRINGS.size(), _matches, (Time.get_ticks_msec() - started) / 1000.0, failures.size()])
	var explored: bool = _matches != MATCHES
	if explored:
		print("explored at %d matches: the claims hold only at %d, so this run exits 2" % [_matches, MATCHES])
	quit(2 if explored else (1 if not failures.is_empty() else 0))


# How many matches a planted pairing plays: enough for its effect to show.
static func _planted_matches(pairing: String) -> int:
	if pairing == "sharper blue":
		return SHARPER_MATCHES
	if pairing == "the point priced at nothing":
		return POINT_FREE_MATCHES
	return ALWAYS_BACK_MATCHES if pairing == "always resupply" else PLANTED_MATCHES


# Blue's counts summed over the pairing's matches, both sides' unseen shots,
# and each match's margin of points held, blue's minus red's.
func _play(pairing: String, matches: int) -> Dictionary:
	var rules := MatchRules.new()
	var sums: Dictionary = {"untaken": 0, "unfinished": 0, "held": 0.0, "red held": 0.0, "bunched": 0.0, "deaths": 0, "lost": 0,
			"unseen": 0, "shots": 0, "sprinting shots": 0, "sprinted": 0.0,
			"blue shots": 0, "blue damage": 0, "dry": 0.0, "power": 0, "regenerated": 0, "healed at base": 0, "hiding": 0.0, "deaths near base": 0, "deaths far": 0,
			"base metre seconds": 0.0, "living seconds": 0.0, "matches": 0, "ordered": 0.0, "seconds": 0.0, "retreats": 0, "uncovered": 0,
			"blue wins": 0, "red wins": 0, "margins": PackedFloat64Array(),
			"fall backs": 0, "fall backs held": 0, "fall backs lost": 0,
			"dying samples": PackedFloat64Array(), "dying deaths": PackedFloat64Array()}
	for seed_value: int in range(1, matches + 1):
		if _shards.mode == EffectShards.Mode.MERGE:
			_shards.merge_into(sums, pairing, seed_value)
		if not _shards.plays(pairing, seed_value):
			continue
		var red := MatchTeam.new("red", BotMatch.RED, rules)
		var arena: BotArena = _arena_for(pairing, seed_value, rules)
		var world := BotMatch.new(seed_value, _blue_for(pairing, rules), red, rules, arena)
		# Dying is sampled on the mirror alone: both sides, every technique on.
		world.fall_back_counts.samples_dying = pairing == "everything"
		world.play_out()
		var into: Dictionary = _shards.sums_for(sums)
		_add(into, world)
		_shards.keep(pairing, seed_value, into)
	return sums


# The lanes, the yards, an arena made from the seed -- or, planted, one
# with its point C walled in by a box no bot can stand near.
static func _arena_for(pairing: String, seed_value: int, rules: MatchRules) -> BotArena:
	if pairing == "the yards":
		return BotArena.new(rules.body_radius, BotArena.YARDS)
	if pairing != "random arenas" and pairing != "a point walled in":
		return BotArena.new(rules.body_radius, BotArena.ARENA)
	var data: Dictionary = RandomArena.make(seed_value, rules.body_radius)
	if pairing == "a point walled in":
		var point: Dictionary = data["points"][2]
		(data["boxes"] as Array).append({"x": point["x"], "z": point["z"], "width": 7, "depth": 7, "height": 5.0})
	return BotArena.new(rules.body_radius, data)


func _blue_for(pairing: String, rules: MatchRules) -> MatchTeam:
	var blue := MatchTeam.new("blue", BotMatch.BLUE, rules)
	blue.use_claims = pairing != "no claims"
	blue.use_commander = pairing != "no commander"
	blue.may_retreat = pairing != "no retreat"
	if pairing == "commander on one point":
		blue.bots_per_point = BotMatch.BOTS_A_SIDE * 10
	blue.retreat_in_one_wave = pairing == "retreat in one wave"
	blue.prices_the_point = pairing != "the point priced at nothing"
	blue.aims_by_worth = pairing != "always the head"
	if pairing == "never resupply":
		blue.resupply_rule = MatchSupply.NEVER
	if pairing == "always resupply":
		blue.resupply_rule = MatchSupply.ALWAYS
	if pairing == "never heals":
		blue.heal_rule = MatchSupply.NEVER
	if pairing == "heals below half":
		blue.heal_rule = MatchSupply.ALWAYS
	if pairing == "sharper blue":
		blue.reaction = 0.0
		blue.aim_error = deg_to_rad(1.0)
		blue.turn_rate *= 2.0
	return blue


# Every stat kept here must be a sum or an appended margin: the sharded run
# adds each match's counts back with `EffectShards.add`, which refuses any
# other kind rather than summing a maximum (T72).
func _add(sums: Dictionary, world: BotMatch) -> void:
	var blue: MatchStats = world.stats[BotMatch.BLUE]
	var red: MatchStats = world.stats[BotMatch.RED]
	sums["held"] += blue.point_seconds
	sums["red held"] += red.point_seconds
	sums["bunched"] += blue.bunched_seconds
	sums["deaths"] += blue.deaths
	sums["lost"] += blue.points_lost
	sums["unseen"] += blue.shots_unseen + red.shots_unseen
	sums["sprinting shots"] += blue.shots_sprinting + red.shots_sprinting
	sums["sprinted"] += blue.sprint_seconds + red.sprint_seconds
	sums["blue shots"] += blue.shots
	sums["blue damage"] += blue.damage
	sums["dry"] += blue.dry_seconds
	sums["power"] += blue.power_taken
	sums["regenerated"] += blue.regenerated
	sums["healed at base"] += blue.healed_at_base
	sums["hiding"] += blue.hiding_seconds
	sums["deaths near base"] += blue.deaths_near_base
	sums["deaths far"] += blue.deaths_far
	sums["base metre seconds"] += blue.base_metre_seconds
	sums["living seconds"] += blue.living_seconds
	sums["matches"] += 1
	sums["untaken"] += Array(world.times_taken).count(0)
	# A script error aborts the match where it happens and the run carries
	# on (CLAUDE.md's trap): a match not over is how one shows here.
	sums["unfinished"] += 0 if world.over() else 1
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
	_add_fall_backs(sums, blue, red)


# Blue's fall-backs, and both sides' dying by band (T65). Each match's table
# is appended, and summed band by band when printed: a sharded run can only
# append arrays (T72).
static func _add_fall_backs(sums: Dictionary, blue: MatchStats, red: MatchStats) -> void:
	sums["fall backs"] += blue.fall_backs
	sums["fall backs held"] += blue.fall_backs_held
	sums["fall backs lost"] += blue.fall_backs_lost
	sums["dying samples"] = _appended(sums["dying samples"], blue.dying_samples, red.dying_samples)
	sums["dying deaths"] = _appended(sums["dying deaths"], blue.dying_deaths, red.dying_deaths)


# `into` with one more table on its end, `one` and `other` added band by band.
static func _appended(into: PackedFloat64Array, one: PackedFloat64Array, other: PackedFloat64Array) -> PackedFloat64Array:
	for index: int in range(one.size()):
		into.append(one[index] + other[index])
	return into


func _report(pairing: String, sums: Dictionary) -> void:
	# A shard's sums are empty: its matches are kept, not added (T72).
	if _shards.mode == EffectShards.Mode.SHARD:
		return
	var margin: Vector2 = _mean_and_error(sums["margins"])
	var outcome: Array = [pairing, sums["held"], sums["red held"], sums["blue wins"], sums["red wins"], margin.x, margin.y]
	print("%-22s held blue %6.0f s, red %6.0f s; wins %d-%d; margin %+.1f +- %.1f s a match" % outcome)
	var decided: Array = ["", _spread(sums), sums["bunched"], sums["retreats"], sums["uncovered"], sums["deaths"],
			sums["lost"], sums["unseen"], sums["shots"]]
	print("%22s orders over %.2f points, bunched %.1f s, %d retreating decisions (%d uncovered), %d deaths, %d points lost; %d of %d shots unseen" % decided)
	print("%22s %.0f s sprinted, %d shots while sprinting" % ["", sums["sprinted"], sums["sprinting shots"]])
	var supplied: Array = ["", _per_shot(sums), _per_match(sums, "dry"), _per_match(sums, "power")]
	print("%22s blue: %.2f damage a shot, %.1f s dry a match, power weapon taken %.1f a match" % supplied)
	var healed: Array = ["", _per_match(sums, "regenerated"), _per_match(sums, "healed at base"), _per_match(sums, "hiding")]
	print("%22s blue: %.0f health regenerated, %.0f healed at the base, %.1f s hiding a match" % healed)
	var where: Array = ["", sums["deaths near base"], MatchStats.NEAR_BASE, sums["deaths far"],
			float(sums["base metre seconds"]) / maxf(float(sums["living seconds"]), 1.0)]
	print("%22s blue: %d deaths within %.0f m of its base, %d further; living, %.1f m from it on average" % where)
	var fell: Array = ["", sums["fall backs"], _per_match(sums, "fall backs"), sums["fall backs held"],
			sums["fall backs lost"], MatchFallBacks.LOST_WITHIN, _lost_share(sums)]
	print("%22s blue: %d fall-backs (%.1f a match), %d from a held point, %d of those lost it within %.0f s (share %.3f)" % fell)


# Of the fall-backs from a held point, the share followed by losing it.
static func _lost_share(sums: Dictionary) -> float:
	return float(sums["fall backs lost"]) / maxf(float(sums["fall backs held"]), 1.0)


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


static func _per_shot(sums: Dictionary) -> float:
	return float(sums["blue damage"]) / maxf(float(sums["blue shots"]), 1.0)


static func _per_match(sums: Dictionary, key: String) -> float:
	return float(sums[key]) / maxf(float(sums["matches"]), 1.0)


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
	var yards: Vector2 = _mean_and_error(totals["the yards"]["margins"])
	if not _fair(totals["the yards"]):
		failures.append("mirror: on the yards blue's margin %+.1f +- %.1f s a match, more than %.1f errors" % [yards.x, yards.y, MIRROR_ERRORS])
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
	# Planted: the matches without claims put where the claims should be.
	if _claims_hold(totals["no claims"], totals["everything"]):
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
	if not _retreat_holds(totals["the yards"]):
		failures.append("retreat: on the yards, %d retreating decisions, %d uncovered" % [totals["the yards"]["retreats"], totals["the yards"]["uncovered"]])
	if _retreat_holds(totals["retreat in one wave"]):
		failures.append("retreat: planted, a squad falling back all at once passed as covered")
	return failures


static func _retreat_holds(with_it: Dictionary) -> bool:
	return int(with_it["retreats"]) > 0 and int(with_it["uncovered"]) == 0


# --- aim and ammunition (T66) ----------------------------------------------------


func _aim(totals: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var numbers: Array = [_per_shot(totals["everything"]), _per_shot(totals["always the head"]), AIM_BETTER]
	if not _aim_holds(totals["everything"], totals["always the head"]):
		failures.append("aim: %.2f damage a shot by worth, %.2f always the head; needs %.2f times" % numbers)
	# Planted: always the head put where aiming by worth should be. Asked of
	# itself, x >= 1.1 x, it could never pass, so it planted nothing.
	if _aim_holds(totals["always the head"], totals["everything"]):
		failures.append("aim: planted, always aiming at the head passed as aiming by worth")
	return failures


static func _aim_holds(by_worth: Dictionary, head: Dictionary) -> bool:
	return _per_shot(by_worth) >= AIM_BETTER * _per_shot(head)


func _ammunition(totals: Dictionary) -> Array[String]:
	# Never going back is printed and not claimed: a bot dies, and comes
	# back full, before it runs dry -- three runs measured it 1.2, 4.6 and
	# 8.6 s dry a match, against 1.1, 0.1 and 0.2 weighing.
	var failures: Array[String] = []
	if not _holds_less(totals["always resupply"], totals["everything"]):
		failures.append("ammunition: always going back held no less than weighing it")
	# Planted: the weighing blue put where always going back should be.
	if _holds_less(totals["everything"], totals["always resupply"]):
		failures.append("ammunition: planted, weighing passed as holding less than always going back")
	return failures


# Whether `fewer`'s mean margin is below `more`'s by MIRROR_ERRORS of the
# two standard errors combined.
static func _holds_less(fewer: Dictionary, more: Dictionary) -> bool:
	var low: Vector2 = _mean_and_error(fewer["margins"])
	var high: Vector2 = _mean_and_error(more["margins"])
	return high.x - low.x > MIRROR_ERRORS * sqrt(low.y * low.y + high.y * high.y)


# --- health (T68) ---------------------------------------------------------------


func _regeneration() -> Array[String]:
	var failures: Array[String] = []
	var found: String = regeneration_fault(MatchRules.new())
	print("regeneration: %s" % (found if found != "" else "nothing before the delay, never past whole, back to whole"))
	if found != "":
		failures.append("regeneration: %s" % found)
	# Planted: health that starts to come back at once.
	var at_once := MatchRules.new()
	at_once.regeneration_delay = 0.0
	if regeneration_fault(at_once) == "":
		failures.append("regeneration: planted, health that came back at once passed")
	return failures


## What is wrong with regeneration under `rules`, or "": a bot hit half a
## step before the clock starts, stepped by the match's own step for
## REGENERATION_SECONDS. Judged against the delay the match is played
## with, MatchRules' own -- so a rules file that drops it is caught too.
static func regeneration_fault(rules: MatchRules) -> String:
	var delay: float = MatchRules.new().regeneration_delay
	var bot := MatchBot.new()
	bot.health = 30
	bot.hurt_at = -rules.step / 2.0
	var now: float = 0.0
	while now < REGENERATION_SECONDS:
		var before: int = bot.health
		MatchHealth.regenerate(rules, bot, now, rules.step)
		if bot.health > before and now - bot.hurt_at < delay:
			return "health came back %.2f s after the hit, before the %.0f s delay" % [now - bot.hurt_at, delay]
		if bot.health > rules.health:
			return "health %d, past its whole %d" % [bot.health, rules.health]
		now += rules.step
	if bot.health != mini(rules.regeneration_to, rules.health):
		return "health %d after %.0f s, never back to whole" % [bot.health, REGENERATION_SECONDS]
	return ""


func _healing(totals: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	for healer: String in HEALERS:
		var ahead: float = _errors_ahead(totals["everything"], totals[healer])
		print("healing: weighing ahead of a blue that %s by %+.1f errors (printed, not claimed)" % [healer, ahead])
	if not _heals_as_long(totals["everything"], totals):
		failures.append("healing: a fixed healer held more than weighing, by %.1f errors" % MIRROR_ERRORS)
	# Planted: always going back for rounds, which holds less, put in the
	# weighing healer's place. Never healing would pass, and is no plant.
	if _heals_as_long(totals["always resupply"], totals):
		failures.append("healing: planted, always going back passed as holding as long as the fixed healers")
	return failures


# Whether `weigher` holds no less than every fixed healer, by the margins.
func _heals_as_long(weigher: Dictionary, totals: Dictionary) -> bool:
	for healer: String in HEALERS:
		if _holds_less(weigher, totals[healer]):
			return false
	return true


# By how many combined standard errors `one`'s mean margin is above
# `other`'s.
static func _errors_ahead(one: Dictionary, other: Dictionary) -> float:
	var high: Vector2 = _mean_and_error(one["margins"])
	var low: Vector2 = _mean_and_error(other["margins"])
	return (high.x - low.x) / maxf(sqrt(low.y * low.y + high.y * high.y), 1e-6)


# --- portability (T67) ---------------------------------------------------------


func _portability(totals: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var random: Dictionary = totals["random arenas"]
	var counted: String = "%d random arenas, %d points never taken, %d matches unfinished" % [
			random["matches"], random["untaken"], random["unfinished"]]
	print("portability: %s" % counted)
	if not _plays_everywhere(random, RANDOM_ARENAS):
		failures.append("portability: on %s" % counted)
	if _plays_everywhere(totals["a point walled in"], 1):
		failures.append("portability: planted, an arena with a point walled in had every point taken")
	return failures


static func _plays_everywhere(sums: Dictionary, matches: int) -> bool:
	return int(sums["matches"]) == matches and int(sums["untaken"]) == 0 and int(sums["unfinished"]) == 0


# --- honesty -------------------------------------------------------------------


# Every pairing played by honest bots, on every arena.
func _honest_pairings() -> Array[String]:
	var all: Array[String] = PAIRINGS.duplicate()
	all.append_array(["the yards", "random arenas"])
	return all


func _honesty(totals: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	for pairing: String in _honest_pairings():
		if totals[pairing]["unseen"] > 0:
			failures.append("honesty: %d shots at unseen enemies in '%s'" % [totals[pairing]["unseen"], pairing])
	failures.append_array(_sprint(totals))
	var wallhack: int = _planted_cheat(true)
	var stale: int = _planted_cheat(false)
	print("honesty: planted, a wallhack bot fired %d shots at enemies it could not see; one that kept firing a second after, %d" % [wallhack, stale])
	if wallhack == 0:
		failures.append("honesty: planted, a bot shooting through walls fired no unseen shot")
	if stale == 0:
		failures.append("honesty: planted, a bot firing on stale sight fired no unseen shot")
	return failures


# No shot while sprinting, in any pairing -- and some sprinting, or that
# would hold of a match nobody ran in. The planted shot forced through a
# sprint is botmatch_test.gd's.
func _sprint(totals: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	for pairing: String in _honest_pairings():
		var sums: Dictionary = totals[pairing]
		var counted: Array = [sums["sprinting shots"], sums["sprinted"], pairing]
		if sums["sprinting shots"] > 0 or sums["sprinted"] <= 0.0:
			failures.append("sprint: %d shots while sprinting, %.0f s sprinted, in '%s'" % counted)
	return failures


# One match with blue's first bot replaced by a cheat that never looks along
# the line again before it fires; its team's unseen shots. `wallhack` also
# picks its targets through walls; otherwise its targets are honest ones,
# from the last decision's sight, which may since have stepped behind cover.
func _planted_cheat(wallhack: bool) -> int:
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", BotMatch.BLUE, rules),
			MatchTeam.new("red", BotMatch.RED, rules), rules)
	var cheat: MatchBot = WallhackBot.new() if wallhack else StaleSightBot.new()
	if wallhack:
		(cheat as WallhackBot).world_ref = weakref(world)
	cheat.checks_its_line = false
	world.replace_bot(0, cheat)
	world.play_out()
	return world.stats[BotMatch.BLUE].shots_unseen


# --- dying, measured (T65) -------------------------------------------------------


# The share of bots in each band of health and exposure that died within
# MatchFallBacks.DYING_WITHIN seconds, over both sides of the mirror: the
# table `rules.json` keeps, printed as its JSON.
func _print_dying(sums: Dictionary) -> void:
	var bands: int = MatchFallBacks.HEALTH_BANDS * MatchFallBacks.EXPOSURE_BANDS
	var samples: PackedFloat64Array = _by_band(sums["dying samples"], bands)
	var deaths: PackedFloat64Array = _by_band(sums["dying deaths"], bands)
	var rows: Array[String] = []
	var counts: Array[String] = []
	for health_band: int in range(MatchFallBacks.HEALTH_BANDS):
		var cells: Array[String] = []
		for exposure_band: int in range(MatchFallBacks.EXPOSURE_BANDS):
			var index: int = health_band * MatchFallBacks.EXPOSURE_BANDS + exposure_band
			cells.append("%.4f" % (deaths[index] / maxf(samples[index], 1.0)))
			counts.append("%d/%d" % [deaths[index], samples[index]])
		rows.append("[%s]" % ", ".join(cells))
	print("dying within %.0f s, by health tenth (rows) and exposure 0, 0.5, 1: [%s]" % [MatchFallBacks.DYING_WITHIN, ", ".join(rows)])
	print("dying, deaths/samples by band: %s" % " ".join(counts))


# The tables appended match by match, added band by band.
static func _by_band(tables: PackedFloat64Array, bands: int) -> PackedFloat64Array:
	var total := PackedFloat64Array()
	total.resize(bands)
	total.fill(0.0)
	for index: int in range(tables.size()):
		total[index % bands] += tables[index]
	return total


# --- falling back weighed (T65) ---------------------------------------------------


func _falling_back(totals: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var everything: Dictionary = totals["everything"]
	var numbers: Array = [_per_match(everything, "fall backs"), FALL_BACKS_A_MATCH, _lost_share(everything), LOST_SHARE]
	if not _falls_back(everything) or not _keeps_points(everything):
		failures.append("falling back: %.1f fall-backs a match (needs >= %.1f), a held point lost after %.3f of them (needs <= %.3f)" % numbers)
	# Planted: a blue that never falls back, and one that gives points up.
	if _falls_back(totals["no retreat"]):
		failures.append("falling back: planted, a blue that never falls back passed as falling back")
	if _keeps_points(totals["the point priced at nothing"]):
		failures.append("falling back: planted, a blue pricing the point at nothing passed as keeping its points")
	return failures


static func _falls_back(sums: Dictionary) -> bool:
	return _per_match(sums, "fall backs") >= FALL_BACKS_A_MATCH


static func _keeps_points(sums: Dictionary) -> bool:
	return _lost_share(sums) <= LOST_SHARE


# T65's claim, printed: everything ahead of each one-off pairing, in
# combined standard errors. Claimed only once a measured run supports it.
func _print_team_claim(totals: Dictionary) -> void:
	for pairing: String in ["no claims", "no commander", "no retreat"]:
		var ahead: float = _errors_ahead(totals["everything"], totals[pairing])
		print("team: everything ahead of %s by %+.1f errors (printed, not claimed; T65 asks %.1f)" % [pairing, ahead, MIRROR_ERRORS])
