# T25: the league. Every team plays every other over a fixed set of seeds,
# from both seats, headless; the table of wins, losses and draws, a rating
# with its interval, and what each team's decisions cost.
#
#     ./scripts/godot --headless --path godot -s res://test/league_runner.gd [-- SEEDS]
#
# SEEDS defaults to `SEEDS`. What it asserts, each against a planted case
# that must fail it first (invariant 4):
#
# - the league played every game it scheduled, and there were some: a run
#   of no games proves nothing, and must not go green;
# - every game ends -- a winner, or a draw at the round limit -- and the
#   board refused none of its decisions;
# - the same seeds give the same table twice: the whole league is played
#   again and every game's result and decision count must match;
# - every team is credited the same number of games from each seat, as the
#   runner actually seated them;
# - no team exceeds the budget: no decision of a team that counts worlds --
#   the planner, GOAP -- does more than T11's per-call budget,
#   `PlannedBlue.BUDGET`, and the 95th percentile of
#   its decisions is inside `BUDGET_MS` on the clock -- the slowest is
#   printed, not held, since one spike measures the machine. A planted team
#   that spends twice the clock's budget must be caught.
#
# Not asserted, and said so when it runs: "T12's ordering holds with the
# human-likeness knobs on" -- the knobs are T25's step 5, not yet built.
#
# Exit codes: 0 every assertion held and every planted case was caught; 1
# otherwise.
extends SceneTree

const SEEDS: int = 5
## A decision's budget on the clock: one frame at 60 a second. A turn-based
## board has no frame to keep, but it is drawn in one -- the decision is made
## while the screen waits -- and T19 brings this league to real time, where
## a frame is the whole budget.
const BUDGET_MS: float = 16.7


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var seeds: int = int(arguments[0]) if not arguments.is_empty() and arguments[0].is_valid_int() else SEEDS
	quit(_run(seeds))


func _run(seeds: int) -> int:
	var failures: int = _planted_cases()
	var roster: Array[Array] = League.roster()
	var schedule: Array[Array] = League.schedule(roster.size(), seeds)
	var started: int = Time.get_ticks_msec()
	var first: Dictionary = _play_league(roster, schedule)
	failures += _said(_all_played(first, schedule))
	print("league: %d teams, %d games, %d seeds a seat, %.0f s" % [roster.size(), schedule.size(), seeds,
		(Time.get_ticks_msec() - started) / 1000.0])
	var second: Dictionary = _play_league(roster, schedule)
	failures += _said(_every_game_ended(first))
	failures += _said(_same_twice(first, second))
	failures += _said(_even_seats(first, roster.size()))
	failures += _within_budget(first, roster)
	_print_table(first, roster)
	_print_costs(first, roster)
	for absent: String in League.NOT_YET:
		print("not in the league yet -- " + absent)
	print("not asserted: T12's ordering with the human-likeness knobs on -- the knobs are T25's step 5, not built yet")
	print("league_runner: %d failure(s)" % failures)
	return 1 if failures > 0 else 0


# Every game of `schedule`: results in order, and each team's decisions.
static func _play_league(roster: Array[Array], schedule: Array[Array]) -> Dictionary:
	var results: Array[Dictionary] = []
	var costs: Array[Array] = []
	var deeds: Array[Dictionary] = []
	for _team: Array in roster:
		costs.append([])
		deeds.append({})
	for game: Array in schedule:
		var red := MeteredTeam.new((roster[game[0]][3] as Callable).call(game[2]))
		var blue := MeteredTeam.new((roster[game[1]][3] as Callable).call(game[2]))
		var result: Dictionary = TacticalMatch.play(red, blue, game[2])
		# Who sat where is read back off the seats, not the schedule, so a
		# runner that seated them the wrong way round is seen doing it.
		results.append({"red": _index_of(roster, red), "blue": _index_of(roster, blue), "seed": game[2], "winner": result["winner"],
			"rounds": result["rounds"], "decisions": result["decisions"], "refused": result["refused"].size()})
		costs[game[0]].append_array(red.decisions)
		costs[game[1]].append_array(blue.decisions)
		_count_deeds(deeds[game[0]], red.inner())
		_count_deeds(deeds[game[1]], blue.inner())
	return {"results": results, "costs": costs, "deeds": deeds}


# The roster index of the team in `seat`, by the name it gives itself.
static func _index_of(roster: Array[Array], seat: MeteredTeam) -> int:
	for index: int in range(roster.size()):
		if (roster[index][3] as Callable).call(0).controller_name() == seat.controller_name():
			return index
	return -1


# Add what a T15 team chose its walkers' deeds as to `into`; nothing for a
# team that has no deeds.
static func _count_deeds(into: Dictionary, team: BlueController) -> void:
	var technique := team as TechniqueTeam
	if technique == null:
		return
	for deed: String in technique.deed_counts:
		into[deed] = into.get(deed, 0) + technique.deed_counts[deed]


# Print each complaint, and count them.
static func _said(complaints: Array[String]) -> int:
	for complaint: String in complaints:
		printerr("league_runner: " + complaint)
	return complaints.size()


# A run that played fewer games than it scheduled, or none, in words.
static func _all_played(league: Dictionary, schedule: Array[Array]) -> Array[String]:
	var played: int = league["results"].size()
	if played == 0:
		return ["no games were played, and a league of none says nothing"]
	if played != schedule.size():
		return ["%d games played of %d scheduled" % [played, schedule.size()]]
	return []


# Each game that did not end, or that had a decision refused, in words.
static func _every_game_ended(league: Dictionary) -> Array[String]:
	var found: Array[String] = []
	for result: Dictionary in league["results"]:
		if result["winner"] == TacticalVictory.NOBODY:
			found.append("game %s did not end" % [result])
		if result["refused"] > 0:
			found.append("%d decision(s) refused by the board in %s" % [result["refused"], result])
	return found


# Each game the two runs played differently, in words.
static func _same_twice(first: Dictionary, second: Dictionary) -> Array[String]:
	var found: Array[String] = []
	for index: int in range(first["results"].size()):
		var one: Dictionary = first["results"][index]
		var other: Dictionary = second["results"][index]
		if one["winner"] != other["winner"] or one["decisions"] != other["decisions"] or one["rounds"] != other["rounds"]:
			found.append("the same seeds gave two games: %s, then %s" % [one, other])
	return found


# Each team credited more games from one seat than the other, in words.
static func _even_seats(league: Dictionary, teams: int) -> Array[String]:
	var seats: Array[Array] = []
	for _team: int in range(teams):
		seats.append([0, 0])
	for result: Dictionary in league["results"]:
		seats[result["red"]][0] += 1
		seats[result["blue"]][1] += 1
	var found: Array[String] = []
	for team: int in range(teams):
		if seats[team][0] != seats[team][1]:
			found.append("team %d played %d games as red and %d as blue" % [team, seats[team][0], seats[team][1]])
	return found


static func _within_budget(league: Dictionary, roster: Array[Array]) -> int:
	var failures: int = 0
	for team: int in range(roster.size()):
		var unit: String = (roster[team][3] as Callable).call(0).work_unit()
		var over: Array[String] = _over_budget(league["costs"][team], unit)
		for said: String in over:
			printerr("league_runner: %s: %s" % [roster[team][0], said])
		failures += over.size()
	return failures


# What in `decisions` broke a budget, in words; empty when nothing did. The
# clock is held at the 95th percentile, not the slowest decision: one call
# in thousands lands on a collection or another process, and a bar a single
# spike can break measures the machine. Work is held at every decision --
# it is counted, not timed, and the same on every machine.
static func _over_budget(decisions: Array, unit: String) -> Array[String]:
	var times: Array = decisions.map(func(decision: Dictionary) -> float: return decision["usec"] / 1000.0)
	times.sort()
	var most_work: int = 0
	for decision: Dictionary in decisions:
		most_work = maxi(most_work, decision["work"])
	var over: Array[String] = []
	var typical: float = _percentile(times, 0.95)
	if typical > BUDGET_MS:
		over.append("its decisions took %.1f ms at the 95th percentile, over the budget of %.1f" % [typical, BUDGET_MS])
	if unit == "worlds" and most_work > PlannedBlue.BUDGET:
		over.append("one decision did %d work, over T11's budget of %d" % [most_work, PlannedBlue.BUDGET])
	return over


# The value `fraction` of the way up `sorted`, which is sorted; 0 for none.
static func _percentile(sorted: Array, fraction: float) -> float:
	return sorted[int(fraction * (sorted.size() - 1))] if not sorted.is_empty() else 0.0


# Each assertion's planted case, which it must catch; a failure for each it
# does not.
static func _planted_cases() -> int:
	var failures: int = 0
	var slow := MeteredTeam.new(_Slow.new())
	TacticalMatch.play(slow, RuleBasedBlue.new(), 0)
	if _over_budget(slow.decisions, "").is_empty():
		printerr("league_runner: the planted slow team was not caught over budget")
		failures += 1
	var greedy: Array = [{"usec": 0, "work": PlannedBlue.BUDGET + 1}]
	if _over_budget(greedy, "worlds").is_empty():
		printerr("league_runner: a decision of %d worlds was not caught over T11's budget" % (PlannedBlue.BUDGET + 1))
		failures += 1
	var unrepeatable: Array[Dictionary] = []
	for _time: int in range(2):
		var result: Dictionary = TacticalMatch.play(_Unrepeatable.new(), RuleBasedBlue.new(), 0)
		unrepeatable.append({"winner": result["winner"], "decisions": result["decisions"], "rounds": result["rounds"]})
	if _same_twice({"results": [unrepeatable[0]]}, {"results": [unrepeatable[1]]}).is_empty():
		printerr("league_runner: the planted unrepeatable team played the same game twice, so the check cannot see one")
		failures += 1
	var refused: Dictionary = TacticalMatch.play(_Refusing.new(), RuleBasedBlue.new(), 0)
	var with_refusal: Dictionary = {"results": [{"winner": refused["winner"], "refused": refused["refused"].size()}]}
	if _every_game_ended(with_refusal).is_empty() or _every_game_ended({"results": [{"winner": TacticalVictory.NOBODY, "refused": 0}]}).is_empty():
		printerr("league_runner: a refused decision or an unended game was not caught")
		failures += 1
	if _all_played({"results": []}, []).is_empty():
		printerr("league_runner: a league of no games was not caught")
		failures += 1
	var lopsided: Dictionary = {"results": [{"red": 0, "blue": 1}, {"red": 0, "blue": 1}]}
	if _even_seats(lopsided, 2).is_empty():
		printerr("league_runner: a team always red was not caught")
		failures += 1
	if failures == 0:
		print("planted cases: the slow team, a decision over T11's worlds, the unrepeatable team, a refused walk, an unended game, a league of none and a team always red were each caught")
	return failures


static func _print_table(league: Dictionary, roster: Array[Array]) -> void:
	var teams: int = roster.size()
	var games: Array[Array] = []
	var tally: Array[Array] = []
	for _team: int in range(teams):
		tally.append([0, 0, 0])
	for result: Dictionary in league["results"]:
		var score: float = 0.5
		if result["winner"] != TacticalVictory.DRAW:
			score = 1.0 if result["winner"] == TacticalScenario.RED else 0.0
		games.append([result["red"], result["blue"], score])
		_tally(tally, result)
	var ratings: Array[float] = LeagueRating.fit(games, teams)
	var bars: Array[Array] = LeagueRating.intervals(games, teams)
	print("\nthe table: Bradley-Terry ratings on the Elo scale, %s at 0, with 95%% bootstrap intervals" % roster[0][0])
	print("  %-18s %5s %5s %5s %7s  %s" % ["team", "won", "lost", "drawn", "rating", "95% interval"])
	var order: Array = range(teams)
	order.sort_custom(func(one: int, other: int) -> bool: return ratings[one] > ratings[other])
	for team: int in order:
		print("  %-18s %5d %5d %5d %+7.0f  %+.0f to %+.0f" % [roster[team][0], tally[team][0], tally[team][1],
			tally[team][2], ratings[team], bars[team][0], bars[team][1]])


static func _tally(tally: Array[Array], result: Dictionary) -> void:
	if result["winner"] == TacticalVictory.DRAW:
		tally[result["red"]][2] += 1
		tally[result["blue"]][2] += 1
		return
	var winning: int = result["red"] if result["winner"] == TacticalScenario.RED else result["blue"]
	var losing: int = result["blue"] if winning == result["red"] else result["red"]
	tally[winning][0] += 1
	tally[losing][1] += 1


static func _print_costs(league: Dictionary, roster: Array[Array]) -> void:
	print("\nwhat a decision costs: milliseconds on this machine (mean, 95th percentile, slowest; budget %.1f), and work where the technique counts it" % BUDGET_MS)
	for team: int in range(roster.size()):
		var decisions: Array = league["costs"][team]
		var times: Array = decisions.map(func(decision: Dictionary) -> float: return decision["usec"] / 1000.0)
		times.sort()
		var work: int = 0
		var replanned: int = 0
		for decision: Dictionary in decisions:
			work += decision["work"]
			replanned += 1 if decision["replanned"] else 0
		var unit: String = (roster[team][3] as Callable).call(0).work_unit()
		var counted: String = "nothing it counts"
		if unit != "" and work > 0:
			counted = "%.1f %s a decision" % [float(work) / decisions.size(), unit]
		if replanned > 0:
			counted += "; a plan made before %d of its %d decisions" % [replanned, decisions.size()]
		print("  %-18s %d decisions; %6.2f %6.2f %6.2f ms; %s" % [roster[team][0], decisions.size(), _mean(times),
			_percentile(times, 0.95), times.back() if not times.is_empty() else 0.0, counted])
		print("  %-18s delegates %s" % ["", roster[team][2]])
		if not league["deeds"][team].is_empty():
			print("  %-18s deeds: %s" % ["", _shares(league["deeds"][team])])


# Each deed's share of the walker decisions, largest first, as "siege 41%".
static func _shares(counts: Dictionary) -> String:
	var total: int = 0
	for deed: String in counts:
		total += counts[deed]
	var names: Array = counts.keys()
	names.sort_custom(func(one: String, other: String) -> bool: return counts[one] > counts[other])
	return ", ".join(names.map(func(deed: String) -> String: return "%s %.0f%%" % [deed, 100.0 * counts[deed] / total]))


static func _mean(values: Array) -> float:
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / maxi(values.size(), 1)


# Spends twice the clock's budget on every walk: the slow team a budget check
# must catch.
class _Slow extends RuleBasedBlue:
	## The rules' walk, after waiting twice the budget.
	func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
		var until: int = Time.get_ticks_usec() + int(2000.0 * BUDGET_MS)
		while Time.get_ticks_usec() < until:
			pass
		return super.decide_move(state, unit_id)


# Remembers across games: every second one made holds every walker, so its
# two games on one seed differ -- certainly, not by luck -- which is what a
# determinism check must catch.
class _Unrepeatable extends RuleBasedBlue:
	static var _made: int = 0
	var _holds: bool

	func _init() -> void:
		_made += 1
		_holds = _made % 2 == 0

	## The rules' walk in its first game, a hold in its second.
	func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
		if _holds:
			return TacticalDecision.hold(unit_id, "stays, because a game before this one said so", state.unit_by_id(unit_id).cell)
		return super.decide_move(state, unit_id)


# Walks every walker into the rock at (2, 3): a decision the board refuses.
class _Refusing extends RuleBasedBlue:
	## A walk nothing can take.
	func decide_move(_state: BoardState, unit_id: int) -> TacticalDecision:
		return TacticalDecision.walk(unit_id, [Vector2i(2, 3)] as Array[Vector2i], "walks into rock", Vector2i(2, 3))
