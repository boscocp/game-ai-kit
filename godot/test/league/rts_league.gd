# T55's acceptance: T25's league on the RTS board, both scores per team with
# their uncertainty, and the clock's knobs held to being limits.
#
#   1. every team plays the queues over the seed set, from both seats -- or,
#      with `full`, every other team -- and every match ends;
#   2. strength: Bradley-Terry with bootstrap intervals (`LeagueRating`),
#      the first team, the queues, at 0;
#   3. human-likeness on the clock's two measures (`RtsClockMeasure`): the
#      median reaction and the commands a minute, each with a bootstrap
#      interval, the busiest five seconds, and each one's distance from the
#      clock's reference -- the owner's recordings, or the stand-in, named;
#   4. every knob costs strength and hands nothing over. Costs: each
#      clocked team against its plain twin, on the same dice and seat, scores
#      no more over the seed set, and its clock changed the side's play, or
#      the knob did nothing. Hands nothing over, in every match a clock
#      plays (`rts_clock_audit.gd`): the enemy handed on is exactly the one
#      the world showed the delay before, own targets included; no command
#      goes out that the side inside did not give; no window holds more
#      commands than the cap. What each saw, earned and ordered by the same
#      moments is printed beside it, not held: a side that sees a raid late
#      keeps its squads forward and sees more of the enemy, which is play,
#      not a gift. Planted records of each kind are refused first.
#
# With `quick`, only claim 4's second half, on one match for each of
# `QUICK_TEAMS`: the module's gate, seconds long, where the whole league
# is minutes.
#
#     ./scripts/godot --headless --path godot -s res://test/league/rts_league.gd -- [seeds] [full | quick]
#
# Exit codes: 0 every claim held; 1 one did not.
extends SceneTree

const DEFAULT_SEEDS: int = 2
## Bootstrap draws for the human-likeness intervals, from a fixed seed.
const RESAMPLES: int = 200
const BOOTSTRAP_SEED: int = 55
## What a side is held to having no more of, read at the same moment.
const COUNTS: Array[String] = ["seen", "earned", "orders"]


const Audit := preload("res://test/league/rts_clock_audit.gd")
## The quick check's matches: each clocked team that must bite against the
## queues, on one dice from the west seat.
const QUICK_TEAMS: Array[String] = ["late", "tight cap"]


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var seeds: int = int(arguments[0]) if not arguments.is_empty() else DEFAULT_SEEDS
	var failures: Array[String] = _planted()
	if failures.is_empty() and arguments.has("quick"):
		failures.append_array(_quick(RtsHumanClock.knob_values()))
	elif failures.is_empty():
		var clock: Dictionary = RtsHumanClock.knob_values()
		print("the clock's reference: %.0f ms, %d commands in %.0f s -- %s" % [clock["reaction_ms"],
			clock["most_actions"], clock["window_seconds"], clock["source"]])
		var full: bool = arguments.has("full")
		var games: Array[Array] = League.schedule(RtsRoster.rows().size(), seeds) if full else _against_the_queues(seeds)
		var played: Array[Dictionary] = _play(games, clock)
		failures.append_array(_every_match_counted(played, games.size()))
		_print_strength(played)
		_print_likeness(played, clock)
		failures.append_array(_knobs_are_limits(played))
	for failure: String in failures:
		print(failure)
	print("rts league: %d failure(s)" % failures.size())
	quit(1 if not failures.is_empty() else 0)


# Every team but the queues against them, `seeds` dice from both seats:
# [west team, east team, dice], as `League.schedule` writes a game.
static func _against_the_queues(seeds: int) -> Array[Array]:
	var games: Array[Array] = []
	for team: int in range(1, RtsRoster.rows().size()):
		for dice: int in range(seeds):
			games.append([team, 0, dice])
			games.append([0, team, dice])
	return games


# Claim 1: each game played to its end on the world of its dice.
func _play(games: Array[Array], clock: Dictionary) -> Array[Dictionary]:
	var teams: Array[Array] = RtsRoster.rows()
	var played: Array[Dictionary] = []
	for game: Array in games:
		var dice: int = game[2] % League.SEAT_OFFSET
		var west: GakRtsController = Audit.spied(teams[game[0]][RtsRoster.MAKE].call(RtsScenario.WEST, dice * 7 + 1, clock))
		var east: GakRtsController = Audit.spied(teams[game[1]][RtsRoster.MAKE].call(RtsScenario.EAST, dice * 7 + 2, clock))
		var match_record: Dictionary = play_one(west, east, game[2] + 1)
		match_record.merge({"west_team": game[0], "east_team": game[1], "dice": game[2]})
		played.append(match_record)
	return played


# Claim 4's second half alone, on one match for each of `QUICK_TEAMS`.
func _quick(clock: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var names: Array[String] = RtsRoster.names()
	var games: Array[Array] = []
	for team: String in QUICK_TEAMS:
		games.append([names.find(team), 0, 0])
	var clocked: Array[Dictionary] = _clocked_sides(_play(games, clock))
	for side: Dictionary in clocked:
		failures.append_array(Audit.hands_over(side))
	print("hands nothing over: checked in %d clocked sides, one match each" % clocked.size())
	return failures


## One match between `west` and `east` on the world of `world_seed`, watched:
## {score to west, minutes, ticks, and per side {seen, earned, orders,
## reactions, busiest, timeline, given (taken or refused), clock, views}}
## -- clock the side's `RtsHumanClock`, or null, and views what the match
## showed it, as `Audit.Spy.handed` writes them.
static func play_one(west: GakRtsController, east: GakRtsController, world_seed: int) -> Dictionary:
	var world: RtsWorld = RtsScenario.start(world_seed)
	var played := RtsMatch.new(world, world_seed, {RtsScenario.WEST: west, RtsScenario.EAST: east})
	var watched: Dictionary = RtsClockMeasure.play_watched(played)
	var won: int = RtsVictory.winner(world)
	var record: Dictionary = {"score": 0.5 if won == RtsVictory.DRAW else (1.0 if won == RtsScenario.WEST else 0.0),
		"minutes": world.tick / 60.0 / RtsWorld.TICKS_PER_SECOND, "ticks": world.tick}
	for side: int in [RtsScenario.WEST, RtsScenario.EAST]:
		record[side] = {"seen": watched[side]["seen"].size(), "earned": world.delivered.get(side, 0),
			"orders": RtsClockMeasure.ticks_of(played.accepted, side).size(),
			"reactions": RtsClockMeasure.reactions(watched[side]["sightings"], played.accepted, side),
			"busiest": RtsClockMeasure.busiest(played.accepted, side), "timeline": watched[side]["timeline"],
			"given": _given(played, side)}
		var outside := played.controllers[side] as Audit.Spy
		record[side]["clock"] = outside.inner as RtsHumanClock if outside != null else null
		record[side]["views"] = outside.handed if outside != null else []
	return record


# Every command `side` gave in `played`, taken or refused: {tick, side,
# command}.
static func _given(played: RtsMatch, side: int) -> Array[Dictionary]:
	var given: Array[Dictionary] = []
	for entry: Dictionary in played.accepted + played.refused:
		if int(entry["side"]) == side:
			given.append({"tick": entry["tick"], "side": side, "command": entry["command"]})
	given.sort_custom(func(one: Dictionary, other: Dictionary) -> bool: return one["tick"] < other["tick"])
	return given


# Claim 1's count: as many matches as scheduled, and each team as many from
# each seat.
func _every_match_counted(played: Array[Dictionary], scheduled: int) -> Array[String]:
	if played.size() != scheduled or played.is_empty():
		return ["claim 1: %d matches played, %d scheduled" % [played.size(), scheduled]]
	for team: int in range(RtsRoster.rows().size()):
		var as_west: int = played.filter(func(one: Dictionary) -> bool: return one["west_team"] == team).size()
		var as_east: int = played.filter(func(one: Dictionary) -> bool: return one["east_team"] == team).size()
		if as_west != as_east:
			return ["claim 1: %s played %d as west and %d as east" % [RtsRoster.names()[team], as_west, as_east]]
	print("played: %d matches, %d teams, every one to its end" % [played.size(), RtsRoster.rows().size()])
	return []


# Claim 2: the strength score.
func _print_strength(played: Array[Dictionary]) -> void:
	var games: Array[Array] = []
	for one: Dictionary in played:
		games.append([one["west_team"], one["east_team"], one["score"]])
	var teams: int = RtsRoster.rows().size()
	var ratings: Array[float] = LeagueRating.fit(games, teams)
	var spans: Array[Array] = LeagueRating.intervals(games, teams)
	print("\nstrength (Bradley-Terry, Elo scale, the queues at 0; 95% bootstrap interval, a difference from the queues):")
	for team: int in range(teams):
		print("  %-12s %+5.0f  (%+.0f to %+.0f)" % [RtsRoster.names()[team], ratings[team], spans[team][0], spans[team][1]])


# Claim 3: the human-likeness score, each measure with its interval and its
# distance from the reference.
func _print_likeness(played: Array[Dictionary], clock: Dictionary) -> void:
	print("\nhuman-likeness (median, 95%% bootstrap interval, distance from the reference: %.0f ms, %d in %.0f s):" % [
		clock["reaction_ms"], clock["most_actions"], clock["window_seconds"]])
	print("  %-12s %-26s %-24s %s" % ["team", "reaction, ms", "commands a minute", "busiest 5 s"])
	for team: int in range(RtsRoster.rows().size()):
		var waits: Array = []
		var rates: Array = []
		var busiest: int = 0
		for side: Dictionary in _sides_of(played, team):
			waits.append_array(side["reactions"].map(func(ticks: int) -> float: return ticks * 1000.0 / RtsWorld.TICKS_PER_SECOND))
			rates.append(side["orders"] / side["minutes"])
			busiest = maxi(busiest, side["busiest"])
		var reaction: Array[float] = _with_interval(waits)
		var rate: Array[float] = _with_interval(rates)
		print("  %-12s %5.0f (%5.0f-%5.0f) %+6.0f  %5.1f (%5.1f-%5.1f)    %3d %+d" % [RtsRoster.names()[team],
			reaction[0], reaction[1], reaction[2], reaction[0] - clock["reaction_ms"], rate[0], rate[1], rate[2],
			busiest, busiest - clock["most_actions"]])


# Every side `team` played.
static func _sides_of(played: Array[Dictionary], team: int) -> Array[Dictionary]:
	var sides: Array[Dictionary] = []
	for one: Dictionary in played:
		if one["west_team"] == team:
			sides.append(_side_of(one, RtsScenario.WEST))
		if one["east_team"] == team:
			sides.append(_side_of(one, RtsScenario.EAST))
	return sides


# What `side` did in the match `one`, with the match's minutes and ticks,
# its score, its seat, its dice and whom it played.
static func _side_of(one: Dictionary, side: int) -> Dictionary:
	var measured: Dictionary = (one[side] as Dictionary).duplicate()
	measured.merge({"minutes": one["minutes"], "ticks": one["ticks"], "seat": side, "dice": one.get("dice", -1),
		"opponent": one.get("east_team" if side == RtsScenario.WEST else "west_team", -1),
		"score": one["score"] if side == RtsScenario.WEST else 1.0 - one["score"]})
	return measured


# [median, low, high]: the median of `values` and the middle 95% of the
# medians of `RESAMPLES` draws with replacement.
static func _with_interval(values: Array) -> Array[float]:
	if values.is_empty():
		return [0.0, 0.0, 0.0]
	var draws := RandomNumberGenerator.new()
	draws.seed = BOOTSTRAP_SEED
	var medians: Array = []
	for _resample: int in range(RESAMPLES):
		var drawn: Array = []
		for _value: int in range(values.size()):
			drawn.append(values[draws.randi_range(0, values.size() - 1)])
		medians.append(RtsClockMeasure.median(drawn))
	medians.sort()
	return [RtsClockMeasure.median(values), medians[int(0.025 * RESAMPLES)], medians[int(0.975 * RESAMPLES) - 1]]


# Claim 4: each knob's team against its plain twin.
func _knobs_are_limits(played: Array[Dictionary]) -> Array[String]:
	var failures: Array[String] = []
	var names: Array[String] = RtsRoster.names()
	for pair: Array in RtsRoster.knobs():
		var summed: Dictionary = paired_totals(_sides_of(played, names.find(pair[0])), _sides_of(played, names.find(pair[1])))
		_print_pair(pair[0], pair[1], summed)
		failures.append_array(costs_strength(pair[0], summed))
	for side: Dictionary in _clocked_sides(played):
		failures.append_array(Audit.hands_over(side))
	var reference_cap: Dictionary = paired_totals(_sides_of(played, names.find("capped")), _sides_of(played, names.find("commander")))
	_print_pair("capped", "commander", reference_cap)
	if reference_cap["changed"] == 0:
		print("note: the reference cap never bound in these matches: no side gave that many commands in five seconds")
	print("hands nothing over: checked in %d clocked sides" % _clocked_sides(played).size())
	return failures


# Every side a clock played, from every match.
static func _clocked_sides(played: Array[Dictionary]) -> Array[Dictionary]:
	var sides: Array[Dictionary] = []
	for one: Dictionary in played:
		var seats: Array = [RtsScenario.WEST, RtsScenario.EAST].filter(func(seat: int) -> bool: return one[seat]["clock"] != null)
		for seat: int in seats:
			sides.append(_side_of(one, seat))
	return sides


## The clocked `sides` against the `plain` ones on the same dice, seat and
## opponent, each pair read at the shorter match's end: {score and
## plain_score (whole matches), each of `COUNTS` and its plain_ twin, waits
## and plain_waits (every reaction), changed (what the clocks held, dropped
## or showed late), pairs}.
static func paired_totals(sides: Array[Dictionary], plain: Array[Dictionary]) -> Dictionary:
	var summed: Dictionary = {"score": 0.0, "plain_score": 0.0, "waits": [], "plain_waits": [], "changed": 0, "pairs": 0}
	for count: String in COUNTS:
		summed[count] = 0
		summed["plain_" + count] = 0
	for side: Dictionary in sides:
		var twins: Array = plain.filter(func(twin: Dictionary) -> bool:
			return twin["dice"] == side["dice"] and twin["seat"] == side["seat"] and twin["opponent"] == side["opponent"])
		for twin: Dictionary in twins:
			_add_pair(summed, side, twin)
	return summed


# One pair into `summed`, its counts read at the shorter match's end.
static func _add_pair(summed: Dictionary, side: Dictionary, twin: Dictionary) -> void:
	var moment: int = mini(side["ticks"], twin["ticks"])
	var mine: Dictionary = RtsClockMeasure.at(side["timeline"], moment)
	var theirs: Dictionary = RtsClockMeasure.at(twin["timeline"], moment)
	for count: String in COUNTS:
		summed[count] += mine[count]
		summed["plain_" + count] += theirs[count]
	summed["score"] += side["score"]
	summed["plain_score"] += twin["score"]
	summed["waits"].append_array(side["reactions"])
	summed["plain_waits"].append_array(twin["reactions"])
	var clock: RtsHumanClock = side["clock"]
	if clock != null:
		summed["changed"] += clock.delayed + clock.dropped + clock.stale
	summed["pairs"] += 1


## Why `summed` (`paired_totals`) shows a clock that costs no strength, or
## [] when it costs some: it scored more than its plain twin, had no pair
## to compare, or changed nothing.
static func costs_strength(label: String, summed: Dictionary) -> Array[String]:
	if summed["pairs"] == 0:
		return ["claim 4: %s had no match to compare with its plain twin" % label]
	var failures: Array[String] = []
	if summed["score"] > summed["plain_score"]:
		failures.append("claim 4: %s scored %.1f, more than %.1f without it" % [label, summed["score"], summed["plain_score"]])
	if summed["changed"] == 0:
		failures.append("claim 4: %s changed nothing: its clock held no command and showed no enemy late" % label)
	return failures


func _print_pair(on: String, off: String, summed: Dictionary) -> void:
	var line: String = "knob: %-12s vs %-10s %d pairs, score %.1f / %.1f" % [on, off, summed["pairs"], summed["score"], summed["plain_score"]]
	for count: String in COUNTS:
		line += ", %s %d / %d" % [count, summed[count], summed["plain_" + count]]
	print(line + ", reaction %.0f / %.0f ms, changed %d" % [
		RtsClockMeasure.median(summed["waits"]) * 1000.0 / RtsWorld.TICKS_PER_SECOND,
		RtsClockMeasure.median(summed["plain_waits"]) * 1000.0 / RtsWorld.TICKS_PER_SECOND, summed["changed"]])


# The planted records each check must refuse, before it judges a real one.
static func _planted() -> Array[String]:
	var fair: Dictionary = {"score": 2.0, "plain_score": 3.0, "changed": 5, "pairs": 4}
	var cases: Dictionary = {"scored more": {"score": 3.5}, "changed nothing": {"changed": 0}, "had no pair": {"pairs": 0}}
	if not costs_strength("planted", fair).is_empty():
		return ["planted: a fair clock was refused: " + ", ".join(costs_strength("planted", fair))]
	for label: String in cases:
		var planted: Dictionary = fair.duplicate(true)
		planted.merge(cases[label], true)
		if costs_strength("planted", planted).is_empty():
			return ["planted: a clock that %s passed the strength check" % label]
	return Audit.planted()
