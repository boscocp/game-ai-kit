# T55: whether a clock handed its side anything, read from outside it.
#
# A clocked side is spied on twice (`spied`): outside the clock, what the
# match showed the side; inside, what the clock handed on and what the side
# inside gave back. `hands_over` then holds three things exactly:
#
#   - the enemy handed on at each decision is the enemy of the newest view
#     the match showed at least the delay before -- every field, so an enemy
#     handed at the place it stands now is refused, not only one handed too
#     soon; and no own unit's target names an enemy that view did not expose;
#   - every command that went out is one the side inside gave;
#   - no window holds more commands than the cap.
#
# `planted` builds a record of each kind of gift, and a fair one; the
# league refuses to judge anything until each gift is caught and the fair
# record passes.
extends RefCounted


# Writes down what a controller is handed and what it gives back.
class Spy:
	extends GakRtsController
	var inner: GakRtsController
	## Each view handed on: {tick, enemies (as text, to compare whole),
	## exposed (enemy ids and own targets), targets (own units' targets)}.
	var handed: Array[Dictionary] = []
	## Each command the side inside gave, as text, all decisions together.
	var produced: Array[String] = []

	func _init(watched: GakRtsController) -> void:
		inner = watched

	## The side inside's commands for `view`, with what it was shown and
	## what it gave written down.
	func decide(view: RtsSnapshot) -> Array[RtsCommand]:
		handed.append(Spy.written(view))
		inner.work = 0
		var given: Array[RtsCommand] = inner.decide(view)
		work = inner.work
		for command: RtsCommand in given:
			produced.append(var_to_str(command.to_dict()))
		return given

	## What `view` exposes of the enemy: its enemy units whole, and every
	## id it names -- the enemy's, and its own units' targets.
	static func written(view: RtsSnapshot) -> Dictionary:
		var exposed: Dictionary = {}
		var targets: Array[int] = []
		for unit: Dictionary in view.enemies():
			exposed[unit["id"]] = true
		for unit: Dictionary in view.mine():
			if int(unit.get("target", 0)) != 0:
				targets.append(int(unit["target"]))
				exposed[int(unit["target"])] = true
		var own: Dictionary = {}
		for unit: Dictionary in view.units:
			if unit["side"] == view.side or unit["side"] == RtsWorld.NEUTRAL:
				own[unit["id"]] = true
		return {"tick": view.tick, "enemies": var_to_str(view.enemies()), "exposed": exposed, "targets": targets, "own": own}


## `team` spied on twice when it has a clock: outside it, what the match
## showed the side; inside, what the clock handed on.
static func spied(team: GakRtsController) -> GakRtsController:
	var clock := team as RtsHumanClock
	if clock == null:
		return team
	clock.inner = Spy.new(clock.inner)
	return Spy.new(clock)


## Why the clocked `side` was handed something, or []: `side` holds its
## clock, views (the outer spy's `handed`), seat and given ({tick, command}
## of every command that went out, taken or refused).
static func hands_over(side: Dictionary) -> Array[String]:
	var clock: RtsHumanClock = side["clock"]
	var spy: Spy = clock.inner
	var failures: Array[String] = []
	var delay: int = roundi(clock.reaction_ms / 1000.0 * RtsWorld.TICKS_PER_SECOND)
	var wrong: String = handed_wrongly(spy.handed, side["views"], delay)
	if wrong != "":
		failures.append("claim 4: " + wrong)
	var foreign: String = not_given(side["given"], spy.produced)
	if foreign != "":
		failures.append("claim 4: " + foreign)
	var burst: int = RtsClockMeasure.busiest(side["given"], side["seat"], clock.window_seconds)
	if clock.most_actions > 0 and burst > clock.most_actions:
		failures.append("claim 4: %d commands in %.0f s, over the cap of %d" % [burst, clock.window_seconds, clock.most_actions])
	return failures


## Why `handed` is not what the clock owed its side, or "": at each decision,
## the enemy of the newest of `views` at least `delay` ticks old (none
## before there is one), and own targets only among what that view exposed.
static func handed_wrongly(handed: Array[Dictionary], views: Array[Dictionary], delay: int) -> String:
	var owed: Dictionary = {"enemies": var_to_str([] as Array[Dictionary]), "exposed": {}}
	var next: int = 0
	for decision: Dictionary in handed:
		while next < views.size() and views[next]["tick"] <= decision["tick"] - delay:
			owed = views[next]
			next += 1
		if decision["enemies"] != owed["enemies"]:
			return "at tick %d the enemy handed on was not the enemy the world showed %d ticks before" % [decision["tick"], delay]
		var told: Array = decision["targets"].filter(func(id: int) -> bool:
			return not decision["own"].has(id) and not owed["exposed"].has(id))
		if not told.is_empty():
			return "at tick %d an own unit's target named enemy %d, not shown %d ticks before" % [decision["tick"], told[0], delay]
	return ""


## Why `given` holds a command not among `produced` (each as text), counting
## repeats, or "".
static func not_given(given: Array[Dictionary], produced: Array[String]) -> String:
	var left: Dictionary = {}
	for command: String in produced:
		left[command] = left.get(command, 0) + 1
	for entry: Dictionary in given:
		var command: String = var_to_str(entry["command"])
		if left.get(command, 0) == 0:
			return "a command went out that the side inside did not give: %s" % command
		left[command] -= 1
	return ""


## The planted records `hands_over` must refuse, and a fair one it must
## pass; [] when each was judged rightly.
static func planted() -> Array[String]:
	var raider: Dictionary = {"id": 7, "side": 1, "kind": RtsKinds.RUNNER, "position": Vector2(5, 5)}
	var moved: Dictionary = {"id": 7, "side": 1, "kind": RtsKinds.RUNNER, "position": Vector2(6, 5)}
	var views: Array[Dictionary] = [_seen(0, [], []), _seen(30, [raider], []), _seen(60, [moved], [])]
	var fair: Dictionary = _side([_seen(0, [], []), _seen(30, [], []), _seen(60, [raider], [])], views, 2)
	if not hands_over(fair).is_empty():
		return ["planted: a fair clock was refused: " + ", ".join(hands_over(fair))]
	var gifts: Dictionary = {
		"an enemy handed on as soon as it was seen": _side([_seen(0, [], []), _seen(30, [raider], [])], views, 2),
		"an enemy handed where it stands now": _side([_seen(0, [], []), _seen(30, [], []), _seen(60, [moved], [])], views, 2),
		"an own unit's target naming a hidden enemy": _side([_seen(0, [], []), _seen(30, [], [7])], views, 2),
		"a command the side inside never gave": _side([_seen(0, [], [])], views, 2, 1),
		"three commands in a second under a cap of two": _side([_seen(0, [], [])], views, 3, 3),
	}
	for label: String in gifts:
		if hands_over(gifts[label]).is_empty():
			return ["planted: %s passed the check" % label]
	return []


# A written view at `tick` showing `enemies`, its own unit 1 targeting
# `targets`.
static func _seen(tick: int, enemies: Array, targets: Array) -> Dictionary:
	var typed: Array[Dictionary] = []
	typed.assign(enemies)
	var exposed: Dictionary = {}
	for unit: Dictionary in typed:
		exposed[unit["id"]] = true
	var aimed: Array[int] = []
	aimed.assign(targets)
	for id: int in aimed:
		exposed[id] = true
	return {"tick": tick, "enemies": var_to_str(typed), "exposed": exposed, "targets": aimed, "own": {1: true}}


# A clocked side, 500 ms late with a cap of two in a second, handed
# `handed` while the match showed `views`; it gave `sent` commands in the
# first second, of which the side inside produced `made` (default all).
static func _side(handed: Array, views: Array[Dictionary], sent: int, made: int = -1) -> Dictionary:
	var clock := RtsHumanClock.new(Spy.new(GakRtsController.new()), 500.0, 2, 1.0)
	var spy: Spy = clock.inner
	spy.handed.assign(handed)
	var given: Array[Dictionary] = []
	for index: int in range(sent):
		var command: Dictionary = RtsCommand.move([1] as Array[int], Vector2i(index, 0)).to_dict()
		given.append({"tick": index * 10, "side": 0, "command": command})
		if made < 0 or index < made:
			spy.produced.append(var_to_str(command))
	return {"clock": clock, "views": views, "seat": 0, "given": given}
