# T70's properties: the infiltration level's guards, driven by scripted
# players over the two hand-made levels and three generated ones, the
# guards' code unchanged -- each claim first shown a planted case it must
# reject (invariant 4):
#
#   1. help is heard, not shared -- planted: a broadcast to every guard;
#      and a call cut short (its caller downed) reaches no one;
#   2. the search is divided -- on a search staged by `HidingStage` -- no
#      two guards hold one spot, and every spot a
#      sight line reached is marked -- planted: claims off inside the
#      coordinator; and with the belief on, guards find a hidden player
#      sooner than with it off, by MARGIN seconds on average -- planted: a
#      belief that never spreads, which must lose the margin;
#   3. the quiet route and the loud one: a player crouched in the shadows
#      finishes a level with no guard alert, and the same route walked
#      upright and sprinting brings one to alert -- planted: guard types
#      blind to light, which must alert on the quiet route;
#   4. the arbiter: at most one flanker, every shot fired by an alert guard,
#      and a guard alert and able to shoot is answered by a shot within its
#      reaction and a decision -- planted: two flanks granted;
#   5. off-screen halving only lowers: no guard more aware with it on than
#      off, and the panel says it is on -- planted: the factor as a gain;
#   6. every decision is on the overlay -- planted: a decision taken
#      outside the selector;
#   7. portable: every claim runs on the second level and the generated
#      ones, and the guards' scripts name no level -- planted: guards whose
#      posts are read from the first level's file.
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
	failures.append_array(_watched_on_loud_runs(levels, "the arbiter", func() -> Callable: return FightClaims.arbiter_holds({}),
		func(world: InfiltrationWorld) -> void: world.arbiter = FightClaims.two_flankers))
	failures.append_array(LevelClaims.halving(levels, trails))
	failures.append_array(_watched_on_loud_runs(levels, "every decision on the overlay", func() -> Callable: return TeamClaims.decisions_recorded,
		func(world: InfiltrationWorld) -> void: world.decide = TeamClaims.decide_outside))
	failures.append_array(LevelClaims.portable(levels))
	if _errors.count > 0:
		failures.append("%d engine error(s) during the claims" % _errors.count)
	for failure: String in failures:
		print(failure)
	print("infiltration properties: %d failure(s)" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _help(levels: Array[InfiltrationLevel]) -> Array[String]:
	var failures: Array[String] = _watched_on_loud_runs(levels, "help is heard, not shared", func() -> Callable: return TeamClaims.help_is_heard,
		func(world: InfiltrationWorld) -> void: world.sounds.hearing = func(_length: float, _radius: float, _factor: float) -> float: return 1.0)
	var cut: Array[int] = []
	var honest: Array[String] = []
	for level: InfiltrationLevel in levels:
		var world: InfiltrationWorld = InfiltrationWorld.make(level, InfiltrationRules.read(), 1)
		_add(honest, InfiltrationRuns.play(world, ScriptedPlayer.new("loud"), TeamClaims.cut_calls_short(cut)))
	if cut.is_empty():
		honest.append("no call for help was ever started, so none was cut short")
	print("a call cut short reaches no one: %d call(s) cut, %s" % [cut.size(), "holds" if honest.is_empty() else "FAILS"])
	for finding: String in honest:
		failures.append("a call cut short: %s" % finding)
	return failures


func _search(levels: Array[InfiltrationLevel]) -> Array[String]:
	var failures: Array[String] = _watched_on_hiding_runs(levels, "the search is divided", TeamClaims.search_is_divided,
		func(world: InfiltrationWorld) -> void: world.coordinator = func(spots: Array[Dictionary], costs: Array[PackedFloat64Array], _claims: bool, weights: SearchCoordinator.Weights) -> PackedInt32Array:
			return SearchCoordinator.assign(spots, costs, false, weights))
	failures.append_array(LevelClaims.belief_margin(levels, HIDING_SEEDS))
	return failures


# A watcher held on a loud run and a hiding run of every level, honest and
# with `plant` applied to the world.
func _watched_on_loud_runs(levels: Array[InfiltrationLevel], claim: String, watcher: Callable, plant: Callable) -> Array[String]:
	var honest: Array[String] = []
	var planted: Array[String] = []
	for level: InfiltrationLevel in levels:
		for mode: String in ["loud", "hide"]:
			_add(honest, InfiltrationRuns.play(InfiltrationWorld.make(level, InfiltrationRules.read(), 1), ScriptedPlayer.new(mode), watcher.call()))
			var world: InfiltrationWorld = InfiltrationWorld.make(level, InfiltrationRules.read(), 1)
			plant.call(world)
			_add(planted, InfiltrationRuns.play(world, ScriptedPlayer.new(mode), watcher.call()))
	return LevelClaims.pair(claim, honest, planted)


func _watched_on_hiding_runs(levels: Array[InfiltrationLevel], claim: String, watcher: Callable, plant: Callable) -> Array[String]:
	var honest: Array[String] = []
	var planted: Array[String] = []
	for level: InfiltrationLevel in levels:
		for seed_value: int in HIDING_SEEDS:
			_add(honest, _staged_run(level, seed_value, watcher, Callable()))
			_add(planted, _staged_run(level, seed_value, watcher, plant))
	return LevelClaims.pair(claim, honest, planted)


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


static func _add(found: Array[String], finding: String) -> void:
	if finding != "":
		found.append(finding)
