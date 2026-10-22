## The infiltration properties measured over whole runs of each level: the
## quiet route and the loud one, the halving, the belief's margin in a
## search, and portability -- each with its planted case.
##
## When not to use it: as the guards' code. These only measure them.
class_name LevelClaims
extends RefCounted

## Seconds by which guards with a belief must, on average, find a hidden
## player sooner than guards without one. Set from what was measured; see
## `docs/godot/infiltration.md`.
const MARGIN: float = 5.0
## Seconds after hiding a search is given before it counts as failed.
const SEARCH_FOR: float = 60.0
## The guards' own scripts, which must name no level.
const GUARD_SCRIPTS: Array[String] = ["infiltration_guard", "guard_choice", "guard_acts", "guard_eyes", "guard_team",
	"guard_search", "guard_ways_out", "infiltration_senses", "level_sounds", "guard_mind", "guard_type"]


## A claim held: no findings for the honest runs, at least one for the
## planted; printed either way.
static func pair(claim: String, honest: Array[String], planted: Array[String]) -> Array[String]:
	print("%s: %s; planted %s" % [claim, "holds" if honest.is_empty() else "FAILS", "caught" if not planted.is_empty() else "NOT CAUGHT"])
	var failures: Array[String] = []
	for finding: String in honest:
		failures.append("%s: %s" % [claim, finding])
	if planted.is_empty():
		failures.append("%s: the planted case passed" % claim)
	return failures


## The quiet player's trail on each level, for the replays.
static func quiet_trails(levels: Array[InfiltrationLevel]) -> Array:
	var trails: Array = []
	for level: InfiltrationLevel in levels:
		var quiet := ScriptedPlayer.new("quiet")
		InfiltrationRuns.play(InfiltrationWorld.make(level, InfiltrationRules.read(), 1), quiet, InfiltrationRuns.nothing)
		trails.append(quiet.trail)
	return trails


## The quiet route finishes with no guard alert, and the same route walked
## loudly brings one to alert. Planted: guards whose sight is a plain
## yes-or-no -- the accumulator off -- must alert on the quiet route on
## every level the quiet half is held on: the glimpses a quiet route gives
## are what the accumulator lets fade. (On a generated level the sneak may
## never be glimpsed at all -- generated 3 -- and there the plant has
## nothing to bite on; the generated levels are printed, not held.)
##
## **This claim does not show the light term**, and says so. Measured
## (2026-10-22): the scripted sneak keeps out of every zone, so guards
## blind to light (`blind_to_light`) do not alert on its route either;
## routed through zones where they are dark instead, the honest guards
## alerted on two levels. The blind guards' runs are printed, not held.
##
## **The quiet half is held on the hand-made levels and printed on the
## generated ones.** Measured (2026-10-22): on a generated level the
## scripted sneak -- a heuristic, not a person -- can find no way past a
## patrol that noticed it and follows, and is caught; that is the guards
## working and the test player failing, and no number here can tell the
## two apart. The loud half is held everywhere.
static func quiet_and_loud(levels: Array[InfiltrationLevel], trails: Array) -> Array[String]:
	var honest: Array[String] = []
	var bites: int = 0
	var held: int = 0
	for index: int in range(levels.size()):
		var level: InfiltrationLevel = levels[index]
		var found: Array[String] = _quiet_run(level, Callable())
		print("  quiet route on %s: %s" % [level.name, "no guard alert, finished" if found.is_empty() else "; ".join(found)])
		if index < InfiltrationLevel.HAND_MADE.size():
			honest.append_array(found)
		if InfiltrationRuns.highest_phase(level, InfiltrationRules.read(), ScriptedPlayer.new("replay", trails[index])) < 3:
			honest.append("%s: the quiet route walked loudly brought no guard to alert" % level.name)
		if not found.is_empty() or index >= InfiltrationLevel.HAND_MADE.size():
			continue
		held += 1
		var plain: Array[String] = _quiet_run(level, _a_plain_sight_test)
		bites += 1 if not plain.is_empty() else 0
		var blind: Array[String] = _quiet_run(level, blind_to_light)
		print("    a plain yes-or-no sight test there: %s" % ("; ".join(plain) if not plain.is_empty() else "no alert -- did not bite"))
		print("    guards blind to light there (printed): %s" % ("; ".join(blind) if not blind.is_empty() else "no alert"))
	var caught: Array[String] = []
	if held > 0 and bites == held:
		caught.append("a plain sight test alerted on every level the quiet route held")
	return pair("the quiet route and the loud one", honest, caught)


# Planted: the accumulator off -- a guard alert the moment it perceives
# anything at all.
static func _a_plain_sight_test(world: InfiltrationWorld) -> void:
	world.rules.use_accumulator = false


# The quiet player on `level`, `change` applied to the world when valid:
# what went wrong -- an alert, or not finishing -- or nothing.
static func _quiet_run(level: InfiltrationLevel, change: Callable) -> Array[String]:
	var world: InfiltrationWorld = InfiltrationWorld.make(level, InfiltrationRules.read(), 1)
	if change.is_valid():
		change.call(world)
	var found: Array[String] = []
	_add(found, InfiltrationRuns.play(world, ScriptedPlayer.new("quiet"), _no_alert))
	if found.is_empty() and world.outcome != "escaped":
		found.append("%s: the quiet player did not finish (%s)" % [level.name, world.outcome if world.outcome != "" else "out of time"])
	return found


static func _no_alert(world: InfiltrationWorld) -> String:
	for guard: InfiltrationGuard in world.guards:
		if guard.alert():
			return "guard %d reached alert" % guard.id
	return ""


## Planted: every guard's type made blind to light -- the dark hides
## nothing from its eye, and its rate's rules have no light in them.
static func blind_to_light(world: InfiltrationWorld) -> void:
	var data: Dictionary = GuardType.read_file()
	for guard: InfiltrationGuard in world.guards:
		var row: Dictionary = (data["guards"][guard.type.name] as Dictionary).duplicate(true)
		row["vision"]["dark_share"] = 1.0
		for rule: Dictionary in row["rate"]["rules"]:
			rule["if"] = (rule["if"] as Array).filter(func(condition: Array) -> bool: return condition[0] != "light")
		row["rate"]["rules"] = (row["rate"]["rules"] as Array).filter(func(rule: Dictionary) -> bool: return not (rule["if"] as Array).is_empty())
		guard.type = GuardType.from_row(guard.type.name, row)
		guard.mind.type = guard.type


## Off-screen halving only lowers, on each level's quiet route crept
## along, and the panel says when it is on; planted, the factor as a gain.
static func halving(levels: Array[InfiltrationLevel], trails: Array) -> Array[String]:
	var honest: Array[String] = []
	var planted: Array[String] = []
	for index: int in range(levels.size()):
		var trail: Array[Vector2i] = trails[index]
		var finding: String = FightClaims.only_lowers(FightClaims.awareness_reached(levels[index], trail, true),
			FightClaims.awareness_reached(levels[index], trail, false))
		_add(honest, "%s: %s" % [levels[index].name, finding] if finding != "" else "")
		_add(planted, FightClaims.only_lowers(FightClaims.awareness_reached(levels[index], trail, true, FightClaims.halving_as_gain),
			FightClaims.awareness_reached(levels[index], trail, false, FightClaims.halving_as_gain)))
	var world: InfiltrationWorld = InfiltrationWorld.make(levels[0], InfiltrationRules.read(), 1)
	if not InfiltrationText.panel(world, 0).contains("off-screen halving on"):
		honest.append("the panel does not say the halving is on")
	return pair("off-screen halving only lowers", honest, planted)


## Seconds until a hidden player is found -- a guard within reach of it or
## seeing it -- on `level`, staged from `seed_value`; SEARCH_FOR when not
## found, NAN when the level gave no place to stage it. `change` alters the
## rules. The staging (`HidingStage`): the player lies prone at a hiding
## place no guard watches, and a radio report says it was seen a few metres
## away -- a real event, heard by whoever the hearing reaches.
static func found_after(level: InfiltrationLevel, seed_value: int, change: Callable) -> float:
	var rules: InfiltrationRules = InfiltrationRules.read()
	change.call(rules)
	var world: InfiltrationWorld = InfiltrationWorld.make(level, rules, seed_value)
	if not HidingStage.stage(world, seed_value):
		return NAN
	var found: Array[float] = [INF]
	var watch: Callable = func(seen: InfiltrationWorld) -> String:
		if HidingStage.found(seen):
			found[0] = minf(found[0], seen.time)
		return ""
	var stop: Callable = func(seen: InfiltrationWorld) -> bool:
		return found[0] != INF or seen.time > SEARCH_FOR
	InfiltrationRuns.play(world, ScriptedPlayer.new("still"), watch, stop)
	return minf(found[0], SEARCH_FOR)


## With the belief on, a hidden player is found MARGIN seconds sooner on
## average than with it off; planted, a belief that never spreads loses it.
static func belief_margin(levels: Array[InfiltrationLevel], seeds: Array[int]) -> Array[String]:
	var means: Dictionary = {}
	var changes: Dictionary = {
		"on": func(rules: InfiltrationRules) -> void: pass,
		"off": func(rules: InfiltrationRules) -> void: rules.use_belief = false,
		"never spreads": func(rules: InfiltrationRules) -> void: rules.spread = 0.0,
	}
	for name: String in changes:
		means[name] = _mean_found(levels, seeds, changes[name])
	print("found after hiding, on average: belief on %.1f s, off %.1f s, never spreading %.1f s (%d runs each)" % [
		means["on"][0], means["off"][0], means["never spreads"][0], means["on"][1]])
	var honest: Array[String] = []
	if float(means["on"][0]) + MARGIN > float(means["off"][0]):
		honest.append("with the belief, %.1f s; without, %.1f s: not %.1f s sooner" % [means["on"][0], means["off"][0], MARGIN])
	var planted: Array[String] = []
	if float(means["never spreads"][0]) + MARGIN > float(means["off"][0]):
		planted.append("a belief that never spreads lost the margin")
	return pair("the belief finds a hidden player sooner", honest, planted)


# The mean of `found_after` over every level and seed where the player
# hid, and how many runs that is.
static func _mean_found(levels: Array[InfiltrationLevel], seeds: Array[int], change: Callable) -> Array:
	var times: Array[float] = []
	for level: InfiltrationLevel in levels:
		for seed_value: int in seeds:
			times.append(found_after(level, seed_value, change))
	var staged: Array = times.filter(func(seconds: float) -> bool: return not is_nan(seconds))
	var total: float = staged.reduce(func(sum: float, seconds: float) -> float: return sum + seconds, 0.0)
	return [total / maxf(staged.size(), 1.0), staged.size()]


## Portable: the guards' own scripts name no level, and on every other
## level each guard stands at that level's post. Planted: one of the guards'
## scripts as it would read with a line that loads the first level's file.
static func portable(levels: Array[InfiltrationLevel]) -> Array[String]:
	var honest: Array[String] = []
	for script: String in GUARD_SCRIPTS:
		honest.append_array(_levels_named(script, _script_text(script)))
	for level: InfiltrationLevel in levels.slice(1):
		honest.append_array(_posts_are_the_levels(InfiltrationWorld.make(level, InfiltrationRules.read(), 1)))
	var reading_a_level: String = _script_text("infiltration_guard") + "\nvar post_from := InfiltrationLevel.read(\"res://game3d/infiltration/levels/the_warehouse.json\")\n"
	return pair("portable", honest, _levels_named("infiltration_guard", reading_a_level))


static func _script_text(script: String) -> String:
	return FileAccess.get_file_as_string("res://game3d/infiltration/%s.gd" % script)


static func _levels_named(script: String, text: String) -> Array[String]:
	var found: Array[String] = []
	for named: String in ["levels/", "the_warehouse", "the_courtyard", "WAREHOUSE", "COURTYARD"]:
		if text.contains(named):
			found.append("%s.gd names %s" % [script, named])
	return found


static func _posts_are_the_levels(world: InfiltrationWorld) -> Array[String]:
	var found: Array[String] = []
	if world.guards.size() != world.level.guard_specs.size():
		return ["%s: %d guards for %d posts" % [world.level.name, world.guards.size(), world.level.guard_specs.size()]]
	for guard: InfiltrationGuard in world.guards:
		var spec: Dictionary = world.level.guard_specs[guard.id]
		if guard.post != spec["post"] or not world.level.walkable(world.level.cell_of(guard.position)):
			found.append("%s: guard %d stands at %s, not at its level's post" % [world.level.name, guard.id, guard.position])
	return found


static func _add(found: Array[String], finding: String) -> void:
	if finding != "":
		found.append(finding)
