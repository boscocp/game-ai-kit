# T70's properties: the infiltration level's guards, driven by scripted
# players over the two hand-made levels and three generated ones, the
# guards' code unchanged -- each claim first shown a planted case it must
# reject (invariant 4), and every claim that could pass untested counting
# how often it was exercised:
#
#   1. help is heard, not shared, and so is what it carries -- planted: a
#      broadcast to every guard; a call cut short reaches no one;
#   2. the search, staged by `HidingStage`: among guards who know the same
#      place, no two hold one spot and none holds one they searched --
#      planted: claims off inside the coordinator; a search is shared only
#      by what was heard -- planted: every searcher in one group, with
#      nothing heard; and with the belief, guards find a hidden player
#      sooner by MARGIN seconds -- planted: a belief that never spreads;
#   3. the quiet route and the loud one -- planted: guards blind to light,
#      who must alert on the quiet route where the honest ones do not;
#   4. the arbiter: at most one flanker, every shot on a decision taken
#      alert, and an alert guard able to shoot answered within its reaction
#      and a decision -- planted: two flanks granted; a guard that never
#      shoots; a guard that fires on a glimpse;
#   5. off-screen halving only lowers -- planted: the factor as a gain;
#   6. every decision is on the overlay, and done -- planted: a decision
#      taken outside the selector; an act that ignores the action;
#   7. portable: every claim runs on the second level and the generated
#      ones, the guards' scripts name no level, and each guard stands at its
#      level's post -- planted: a guard script naming the first level.
#
# Engine errors are counted (`PerceptionErrors`); read the output for
# SCRIPT ERROR too (CLAUDE.md's trap).
#
#     ./scripts/godot --headless --path godot -s res://test/infiltration/infiltration_properties.gd
#
# Exit codes: 0 every claim held and every planted case was caught; 1 not.
extends SceneTree

const HIDING_SEEDS: Array[int] = [1, 2, 3]

var _errors := PerceptionErrors.new()


func _initialize() -> void:
	OS.add_logger(_errors)
	var failures: Array[String] = []
	var counter: String = _errors.self_check()
	if counter != "":
		failures.append(counter)
	var levels: Array[InfiltrationLevel] = InfiltrationRuns.levels()
	var trails: Array = LevelClaims.quiet_trails(levels)
	failures.append_array(_help(levels))
	failures.append_array(_search(levels))
	failures.append_array(LevelClaims.quiet_and_loud(levels, trails))
	failures.append_array(_arbiter(levels))
	failures.append_array(LevelClaims.halving(levels, trails))
	failures.append_array(_overlay(levels))
	failures.append_array(LevelClaims.portable(levels))
	if _errors.count > 0:
		failures.append("%d engine error(s) during the claims" % _errors.count)
	for failure: String in failures:
		print(failure)
	print("infiltration properties: %d failure(s)" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _help(levels: Array[InfiltrationLevel]) -> Array[String]:
	var failures: Array[String] = _on_loud_runs(levels, "help is heard, not shared", func() -> Callable: return TeamClaims.help_is_heard,
		[func(world: InfiltrationWorld) -> void: world.sounds.hearing = func(_length: float, _radius: float, _factor: float) -> float: return 1.0])
	var cut: Array[int] = []
	var honest: Array[String] = []
	for level: InfiltrationLevel in levels:
		for mode: String in ["loud", "hide"]:
			var world: InfiltrationWorld = InfiltrationWorld.make(level, InfiltrationRules.read(), 1)
			_add(honest, InfiltrationRuns.play(world, ScriptedPlayer.new(mode), TeamClaims.cut_calls_short(cut)))
	failures.append_array(_exercised("a call cut short reaches no one", honest, cut.size(), "call(s) cut"))
	return failures


func _search(levels: Array[InfiltrationLevel]) -> Array[String]:
	var counts: Dictionary = {}
	var honest: Array[String] = []
	var planted: Array[String] = []
	for level: InfiltrationLevel in levels:
		for seed_value: int in HIDING_SEEDS:
			_add(honest, _staged_run(level, seed_value, TeamClaims.search_is_divided(counts), Callable()))
			_add(planted, _staged_run(level, seed_value, TeamClaims.search_is_divided({}), _with_claims_off))
	var failures: Array[String] = LevelClaims.pair("the search is divided", honest, planted)
	failures.append_array(_exercised("  searched together", [], int(counts.get("shared", 0)), "decision(s) with two or more searching one place"))
	failures.append_array(_shared_by_what_was_heard(levels))
	failures.append_array(LevelClaims.belief_margin(levels, HIDING_SEEDS))
	return failures


# Two searches at once, staged by two calls each heard only nearby: no
# guard is sent by a belief it never heard. Planted: every searcher in one
# group, whatever it knows.
func _shared_by_what_was_heard(levels: Array[InfiltrationLevel]) -> Array[String]:
	var honest: Array[String] = []
	var planted: Array[String] = []
	for level: InfiltrationLevel in levels:
		for seed_value: int in HIDING_SEEDS:
			_add(honest, _two_calls_run(level, seed_value, Callable()))
			_add(planted, _two_calls_run(level, seed_value, _in_one_group))
	return LevelClaims.pair("a search is shared only by what was heard", honest, planted)


static func _in_one_group(world: InfiltrationWorld) -> void:
	world.team.search.group_of = TeamClaims.one_group


static func _two_calls_run(level: InfiltrationLevel, seed_value: int, plant: Callable) -> String:
	var world: InfiltrationWorld = InfiltrationWorld.make(level, InfiltrationRules.read(), seed_value)
	if plant.is_valid():
		plant.call(world)
	if not HidingStage.stage_two_calls(world, seed_value):
		return ""
	return InfiltrationRuns.play(world, ScriptedPlayer.new("still"), TeamClaims.search_is_divided({}),
		func(seen: InfiltrationWorld) -> bool: return seen.time > LevelClaims.SEARCH_FOR)


# Planted: the coordinator with its claims switched off inside it.
static func _with_claims_off(world: InfiltrationWorld) -> void:
	world.coordinator = _claims_off


static func _claims_off(spots: Array[Dictionary], costs: Array[PackedFloat64Array], _claims: bool, weights: SearchCoordinator.Weights) -> PackedInt32Array:
	return SearchCoordinator.assign(spots, costs, false, weights)


func _arbiter(levels: Array[InfiltrationLevel]) -> Array[String]:
	var shots: Array[int] = [0]
	var counting: Callable = func(world: InfiltrationWorld) -> void: world.act = func(guard: InfiltrationGuard, seen: InfiltrationWorld, seconds: float) -> void:
		var before: int = seen.shots.size()
		GuardActs.carry(guard, seen, seconds)
		shots[0] += seen.shots.size() - before
	var failures: Array[String] = _on_loud_runs(levels, "the arbiter", func() -> Callable: return FightClaims.arbiter_holds({}), [
		func(world: InfiltrationWorld) -> void: world.arbiter = FightClaims.two_flankers,
		func(world: InfiltrationWorld) -> void: world.decide = FightClaims.never_shoots,
		func(world: InfiltrationWorld) -> void: world.decide = FightClaims.shoots_on_a_glimpse,
	], counting)
	failures.append_array(_exercised("  shots fired", [], shots[0], "shot(s)"))
	return failures


func _overlay(levels: Array[InfiltrationLevel]) -> Array[String]:
	return _on_loud_runs(levels, "every decision on the overlay, and done", func() -> Callable: return TeamClaims.decisions_recorded, [
		func(world: InfiltrationWorld) -> void: world.decide = TeamClaims.decide_outside,
		func(world: InfiltrationWorld) -> void: world.act = TeamClaims.act_regardless,
	])


# A watcher held on a loud run and a hiding run of every level: honest
# (with `honest_change` applied when valid), and once with each of `plants`,
# each of which must be caught on some run.
func _on_loud_runs(levels: Array[InfiltrationLevel], claim: String, watcher: Callable, plants: Array,
		honest_change: Callable = Callable()) -> Array[String]:
	var honest: Array[String] = []
	var caught: Array[String] = []
	for level: InfiltrationLevel in levels:
		for mode: String in ["loud", "hide"]:
			_add(honest, _run(level, mode, watcher.call(), honest_change))
	for index: int in range(plants.size()):
		if _plant_caught(levels, watcher, plants[index]):
			caught.append("plant %d caught" % index)
		elif plants.size() > 1:
			honest.append("plant %d of %d passed" % [index + 1, plants.size()])
	var none: Array[String] = []
	return LevelClaims.pair(claim, honest, caught if caught.size() == plants.size() else none)


# True when `plant` brings the watcher a finding on some loud or hiding run.
static func _plant_caught(levels: Array[InfiltrationLevel], watcher: Callable, plant: Callable) -> bool:
	for case: Array in _loud_cases(levels):
		if _run(case[0], case[1], watcher.call(), plant) != "":
			return true
	return false


# Every level, played loud and hiding.
static func _loud_cases(levels: Array[InfiltrationLevel]) -> Array:
	var cases: Array = []
	for level: InfiltrationLevel in levels:
		cases.append([level, "loud"])
		cases.append([level, "hide"])
	return cases


static func _run(level: InfiltrationLevel, mode: String, watcher: Callable, change: Callable) -> String:
	var world: InfiltrationWorld = InfiltrationWorld.make(level, InfiltrationRules.read(), 1)
	if change.is_valid():
		change.call(world)
	return InfiltrationRuns.play(world, ScriptedPlayer.new(mode), watcher)


# A search staged by `HidingStage` on `level`, `plant` applied when valid,
# watched by `watcher` for SEARCH_FOR seconds.
static func _staged_run(level: InfiltrationLevel, seed_value: int, watcher: Callable, plant: Callable) -> String:
	var world: InfiltrationWorld = InfiltrationWorld.make(level, InfiltrationRules.read(), seed_value)
	if plant.is_valid():
		plant.call(world)
	if not HidingStage.stage(world, seed_value):
		return ""
	return InfiltrationRuns.play(world, ScriptedPlayer.new("still"), watcher,
		func(seen: InfiltrationWorld) -> bool: return seen.time > LevelClaims.SEARCH_FOR)


# A claim that holds only if it was exercised: `count` printed, and none a
# finding.
static func _exercised(claim: String, honest: Array[String], count: int, what: String) -> Array[String]:
	print("%s: %d %s, %s" % [claim, count, what, "holds" if honest.is_empty() and count > 0 else "FAILS"])
	var failures: Array[String] = []
	for finding: String in honest:
		failures.append("%s: %s" % [claim.strip_edges(), finding])
	if count == 0:
		failures.append("%s: never exercised" % claim.strip_edges())
	return failures


static func _add(found: Array[String], finding: String) -> void:
	if finding != "":
		found.append(finding)
