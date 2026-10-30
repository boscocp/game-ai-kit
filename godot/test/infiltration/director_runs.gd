## Runs of the infiltration level with the director on (T90), stepped by
## hand so every step can be watched: what each guard believed before and
## after the director acted, whether the route it gave a guard was that
## guard's beat (or, called back, none), whether the player could see a
## guard the moment it was sent, and how long the director spent in each
## phase.
##
## `director_test.gd` holds its claims on these runs, and
## `director_measure.gd` prints them over more levels.
##
## When not to use it: in the game. A run here has no view.
class_name DirectorRuns
extends RefCounted


## The rules with the director on.
static func rules() -> InfiltrationRules:
	var found := InfiltrationRules.read()
	found.use_director = true
	return found


## Play the scripted player `mode` on `level` for at most `steps` steps.
## `planted` may replace the director's seams, `send` and `pick`, with a
## cheat; a planted run stops at its first finding. What was found and
## measured.
static func run(level: InfiltrationLevel, mode: String, steps: int, planted: Dictionary = {}) -> Dictionary:
	var world: InfiltrationWorld = InfiltrationWorld.make(level, rules(), 1)
	var orders: DirectorOrders = world.director
	world.director = null
	orders.send = planted.get("send", orders.send)
	orders.pick = planted.get("pick", orders.pick)
	var player := ScriptedPlayer.new(mode)
	var found: Dictionary = {"level": level.name, "player": mode, "belief": [] as Array[String],
		"route": [] as Array[String], "seen_sent": [] as Array[String], "seconds": {}, "peaks": 0, "relaxes": 0}
	for step: int in range(steps):
		world.step(player.intent(world))
		if world.outcome != "" or (not planted.is_empty() and findings(found) > 0):
			break
		var before: Array = beliefs(world)
		var orders_before: int = orders.orders.size()
		orders.step(world)
		_watch(world, orders, orders_before, before, found)
	found["ended"] = "%s at %.0f s" % [world.outcome if world.outcome != "" else "still playing", world.time]
	found["sent"] = orders.orders.filter(func(order: Dictionary) -> bool: return order["order"] == "send").size()
	found["recalled"] = orders.orders.size() - int(found["sent"])
	return found


## How many findings `run` holds, of every kind.
static func findings(run: Dictionary) -> int:
	return (run["belief"] as Array).size() + (run["route"] as Array).size() + (run["seen_sent"] as Array).size()


## One run as a line of the measurement.
static func line(run: Dictionary) -> String:
	var seconds: PackedStringArray = []
	for phase: String in Director.PHASES:
		seconds.append("%s %.1f" % [phase, float(run["seconds"].get(phase, 0.0))])
	return "%s, %s player, %s: %s s; peaks %d, relaxes %d, sent %d, called back %d" % [run["level"], run["player"],
		run["ended"], ", ".join(seconds), run["peaks"], run["relaxes"], run["sent"], run["recalled"]]


## What every guard believes: both beliefs and its memory of the player.
static func beliefs(world: InfiltrationWorld) -> Array:
	var all: Array = []
	for guard: InfiltrationGuard in world.guards:
		all.append([guard.belief.shares, guard.particles.shares, guard.mind.memory.known, guard.mind.memory.place])
	return all


static func _watch(world: InfiltrationWorld, orders: DirectorOrders, orders_before: int, before: Array, found: Dictionary) -> void:
	var phase: String = orders.pacing.phase
	found["seconds"][phase] = float(found["seconds"].get(phase, 0.0)) + world.rules.step_seconds
	if orders.pacing.steps_in_phase == 0:
		var counted: String = {Director.PHASES[1]: "peaks", Director.PHASES[3]: "relaxes"}.get(phase, "")
		if counted != "":
			found[counted] = int(found[counted]) + 1
	if beliefs(world) != before:
		found["belief"].append("%s at %.1f s: a guard's belief changed when the director acted" % [world.level.name, world.time])
	for order: Dictionary in orders.orders.slice(orders_before):
		_watch_order(world, order, found)


# A send gives the guard its beat and is not in the player's view; a recall
# leaves it no route.
static func _watch_order(world: InfiltrationWorld, order: Dictionary, found: Dictionary) -> void:
	var guard: InfiltrationGuard = world.guard(int(order["guard"]))
	var where: String = "%s at %.1f s: guard %d" % [world.level.name, world.time, guard.id]
	var sent: bool = order["order"] == "send"
	if (sent and guard.route != guard.beat) or (not sent and not guard.route.is_empty()):
		found["route"].append("%s given a route that is not its order's: %s" % [where, guard.route])
	if sent and DirectorOrders.player_sees(world, guard.position):
		found["seen_sent"].append("%s sent in the player's view" % where)
