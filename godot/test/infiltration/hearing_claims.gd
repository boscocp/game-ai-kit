## The claim that a guard hears a player walking behind it (T81).
##
## One guard at a time, alone on its level and frozen where it stands, the
## player walking to and fro behind it, out of its sight, along the grid's
## axis nearest to straight behind -- so 3 m away is 3 m along the floor, the
## way the sound is measured (a diagonal 3 m is 4 along a 4-connected floor,
## T69's diamond, and is not this claim's): how long until the
## guard's phase is past unaware. Standing at 1 m and 3 m it must be within
## NOTICE_WITHIN; crouched at 1 m, inside the creep's radius, it must be
## noticed within WATCH_FOR and no sooner than standing there; crouched at
## 3 m, outside that radius, and prone anywhere, never within WATCH_FOR --
## those two hold by the events' data, and are kept to catch a change to it.
## The guard is frozen so that turning to the sound does not end the trial
## by sight: what is measured is what it heard.
##
## When not to use it: as the level's sound. This only tests it.
class_name HearingClaims
extends RefCounted

## The Last of Us perceives a seen player in "around 1 or 2 seconds for
## the typical NPC" [McIntosh 2015]; no source opened gives a time for
## hearing footsteps, so the kit takes the upper end for them too.
const NOTICE_WITHIN: float = 2.0
## How long a trial watches before it calls the guard deaf to it.
const WATCH_FOR: float = 10.0
## Steps each way before the player turns back: standing, 0.45 m a step,
## so it walks between the spot and 0.9 m further on.
const TURN_EVERY: int = 2


## How long until guard `index` of `level` is past unaware, the player
## walking at `stance` `distance` metres behind it: INF when it never is
## within WATCH_FOR, -1 when the trial could not be made (no floor there, or
## the guard saw the player). `holding` false is the planted case: each
## sound heard for the one step it arrives in, as in wave 80.
static func time_to_notice(level: InfiltrationLevel, index: int, distance: float, stance: String, holding: bool) -> float:
	var rules: InfiltrationRules = InfiltrationRules.read()
	var world: InfiltrationWorld = InfiltrationWorld.make(level, rules, 1, [level.guard_specs[index]])
	world.sounds.holding = holding
	world.act = func(_guard: InfiltrationGuard, _world: InfiltrationWorld, _seconds: float) -> void: pass
	var guard: InfiltrationGuard = world.guards[0]
	var away: Vector2 = _behind_on_the_grid(guard.facing)
	var spot: Vector2 = guard.position + away * distance
	var reach: float = TURN_EVERY * float(rules.stances[stance]["speed"]) * rules.step_seconds
	if not level.walkable(level.cell_of(spot)) or not level.walkable(level.cell_of(spot + away * reach)):
		return -1.0
	world.player.position = spot
	var intent := PlayerIntent.new()
	intent.stance = stance
	var steps: int = 0
	while world.time < WATCH_FOR:
		intent.direction = away if (steps / TURN_EVERY) % 2 == 0 else -away
		world.step(intent)
		steps += 1
		if guard.percept.sight.perceived():
			return -1.0
		if guard.mind.phase() > 0:
			return world.time
	return INF


# The axis of the grid most nearly behind a guard facing `facing`: a sound's
# way is measured along the floor's four directions (T69's diamond), so a
# player straight along an axis is `distance` from the guard both ways.
static func _behind_on_the_grid(facing: float) -> Vector2:
	var behind: Vector2 = -Vector2.from_angle(facing)
	return Vector2(signf(behind.x), 0.0) if absf(behind.x) >= absf(behind.y) else Vector2(0.0, signf(behind.y))


## Every guard of every level that can be tried, by `holding`: a row per
## guard, {level, guard, "standing 1", "standing 3", "crouched 1",
## "crouched 3", "prone 1"}
## in seconds -- a guard with any trial that could not be made is left out.
static func trials(levels: Array[InfiltrationLevel], holding: bool) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for level: InfiltrationLevel in levels:
		for index: int in range(level.guard_specs.size()):
			found.append(_row(level, index, holding))
	return found.filter(func(row: Dictionary) -> bool: return not row.values().has(-1.0))


static func _row(level: InfiltrationLevel, index: int, holding: bool) -> Dictionary:
	var row: Dictionary = {"level": level.name, "guard": index}
	for key: Array in [["standing", 1.0], ["standing", 3.0], ["crouched", 1.0], ["crouched", 3.0], ["prone", 1.0]]:
		row["%s %d" % [key[0], int(key[1])]] = time_to_notice(level, index, key[1], key[0], holding)
	return row


## The findings for `rows`: a standing player noticed within NOTICE_WITHIN
## at 1 m and 3 m; crouched at 1 m noticed, no sooner than standing; crouched
## at 3 m and prone, never.
static func heard(rows: Array[Dictionary]) -> Array[String]:
	if rows.is_empty():
		return ["no guard could be tried: no floor behind any of them"]
	var failures: Array[String] = []
	for row: Dictionary in rows:
		failures.append_array(_findings_for(row))
	return failures


static func _findings_for(row: Dictionary) -> Array[String]:
	var who: String = "%s guard %d" % [row["level"], row["guard"]]
	var failures: Array[String] = []
	for key: String in ["standing 1", "standing 3"]:
		if float(row[key]) > NOTICE_WITHIN:
			failures.append("%s: %s m behind it, noticed at %s, over %.1f s" % [who, key, _seconds(row[key]), NOTICE_WITHIN])
	if float(row["crouched 1"]) == INF:
		failures.append("%s: crouched at 1 m, inside the creep's radius, never noticed" % who)
	elif float(row["crouched 1"]) < float(row["standing 1"]):
		failures.append("%s: crouched at 1 m noticed sooner than standing" % who)
	if float(row["crouched 3"]) != INF:
		failures.append("%s: crouched at 3 m, outside the creep's radius, noticed at %s" % [who, _seconds(row["crouched 3"])])
	if float(row["prone 1"]) != INF:
		failures.append("%s: prone at 1 m noticed at %s" % [who, _seconds(row["prone 1"])])
	return failures


## One line per trial row, for the printout.
static func lines(rows: Array[Dictionary]) -> Array[String]:
	var printed: Array[String] = []
	for row: Dictionary in rows:
		printed.append("  %s guard %d: standing 1 m %s, 3 m %s; crouched 1 m %s, 3 m %s; prone 1 m %s" % [
			row["level"], row["guard"], _seconds(row["standing 1"]), _seconds(row["standing 3"]),
			_seconds(row["crouched 1"]), _seconds(row["crouched 3"]), _seconds(row["prone 1"])])
	return printed


static func _seconds(value: Variant) -> String:
	return "never" if float(value) == INF else "%.1f s" % float(value)
