# T19's step 6, held before any of T20's AIs exist: the simulation a league
# can be built on. Both sides are played by a scripted controller -- seeded,
# shown only its snapshot, answering only with commands -- on two small
# economies, for two minutes of match. Then five claims:
#
#   1. determinism: one seed played twice ends in one digest, and a second
#      seed in another, so a digest that never changes cannot pass;
#   2. nothing outside the interface: the recording, replayed with no
#      controller, reaches the match's digest -- and a match with one change
#      made behind the world's back does not. A snapshot holds nothing of
#      the world. Three commands a cheat would give are refused and leave the
#      digest as it was, beside one honest command that is not;
#   3. speed: the match runs at least ten times faster than real time;
#   4. fog: an enemy planted out of sight is not in the view, one planted in
#      sight is;
#   5. counters: every side decided, spent time and did work, and the totals
#      are the sums of the per-decision log.
#
#     ./scripts/godot --headless --path godot -s res://test/rts_simulation.gd
#
# Exit codes: 0 every claim held; 1 one did not.
extends SceneTree

const SEED: int = 19
const OTHER_SEED: int = 20
## Two minutes of match.
const TICKS: int = RtsWorld.TICKS_PER_SECOND * 120
const FASTER_THAN_REAL_TIME: float = 10.0


## A side played by a script: gather with every idle worker, train while there
## is money, and send soldiers at whatever enemy they can see, or towards the
## enemy's home once there are enough of them. Its own dice, from the seed, so
## the stream of commands is the same every time.
class ScriptedSide extends RtsController:
	var _dice := RandomNumberGenerator.new()
	var _enemy_home: Vector2i

	func _init(match_seed: int, side: int) -> void:
		_dice.seed = match_seed * 10 + side
		_enemy_home = Vector2i(55, 32) if side == RtsTestWorld.LEFT else Vector2i(8, 32)

	## Workers to the mines, buildings to training, soldiers at the enemy.
	func decide(view: RtsSnapshot) -> Array[RtsCommand]:
		var commands: Array[RtsCommand] = []
		commands.append_array(_put_workers_to_work(view))
		commands.append_array(_train(view))
		commands.append_array(_send_soldiers(view))
		return commands

	func _put_workers_to_work(view: RtsSnapshot) -> Array[RtsCommand]:
		var commands: Array[RtsCommand] = []
		var mines: Array[Dictionary] = view.mines()
		for worker: Dictionary in view.mine(RtsKinds.WORKER):
			work += 1
			if worker["order"] == RtsUnit.IDLE and not mines.is_empty():
				var mine: Dictionary = mines[_dice.randi_range(0, mines.size() - 1)]
				commands.append(RtsCommand.gather([worker["id"]] as Array[int], mine["id"]))
		return commands

	func _train(view: RtsSnapshot) -> Array[RtsCommand]:
		var commands: Array[RtsCommand] = []
		var workers: int = view.mine(RtsKinds.WORKER).size()
		for building: Dictionary in view.mine(RtsKinds.BASE) + view.mine(RtsKinds.BARRACKS):
			work += 1
			if not building["complete"] or building["queued"] > 0:
				continue
			if building["kind"] == RtsKinds.BASE and workers < 8:
				commands.append(RtsCommand.train(building["id"], RtsKinds.WORKER))
			elif building["kind"] == RtsKinds.BARRACKS and _dice.randf() < 0.8:
				commands.append(RtsCommand.train(building["id"], RtsKinds.SOLDIER))
		return commands

	func _send_soldiers(view: RtsSnapshot) -> Array[RtsCommand]:
		var idle: Array[int] = []
		for soldier: Dictionary in view.mine(RtsKinds.SOLDIER):
			work += 1
			if soldier["order"] == RtsUnit.IDLE:
				idle.append(soldier["id"])
		var enemies: Array[Dictionary] = view.enemies()
		if not idle.is_empty() and not enemies.is_empty():
			return [RtsCommand.attack(idle, enemies[0]["id"])]
		if idle.size() < 3:
			return []
		var near_home: Vector2i = _enemy_home + Vector2i(_dice.randi_range(-4, 4), _dice.randi_range(-4, 4))
		if view.graph.is_blocked(near_home):
			return []
		return [RtsCommand.move(idle, near_home)]


func _init() -> void:
	var failures: Array[String] = []
	var played: RtsMatch = _play(SEED)
	failures.append_array(_deterministic(played))
	failures.append_array(_only_through_the_door(played))
	failures.append_array(_fast_enough())
	failures.append_array(_fogged())
	failures.append_array(_counted(played))
	for failure: String in failures:
		print(failure)
	print("rts simulation: %d failure(s)" % failures.size())
	quit(1 if not failures.is_empty() else 0)


# A match from `match_seed`, both sides scripted, played to the end. When
# `meddle` is true one change is made to the world behind its back half way.
func _play(match_seed: int, meddle: bool = false) -> RtsMatch:
	var sides: Dictionary = {RtsTestWorld.LEFT: ScriptedSide.new(match_seed, RtsTestWorld.LEFT),
		RtsTestWorld.RIGHT: ScriptedSide.new(match_seed, RtsTestWorld.RIGHT)}
	var played := RtsMatch.new(RtsTestWorld.economies(match_seed), match_seed, sides)
	if not meddle:
		played.play(TICKS)
		return played
	played.play(TICKS / 2)
	played.world.resources[RtsTestWorld.LEFT] += 1000
	played.play(TICKS - TICKS / 2)
	return played


# Claim 1, with a planted second seed. A match where nothing happened would
# also agree with itself, so the match must show it was played.
func _deterministic(played: RtsMatch) -> Array[String]:
	var failures: Array[String] = []
	var again: RtsMatch = _play(SEED)
	if again.world.digest() != played.world.digest():
		failures.append("one seed, two digests: %s and %s" % [played.world.digest(), again.world.digest()])
	if _play(OTHER_SEED).world.digest() == played.world.digest():
		failures.append("seeds %d and %d end in one digest: the digest is not reading the match" % [SEED, OTHER_SEED])
	var trained: int = played.world.units().size() - RtsTestWorld.economies(SEED).units().size()
	print("determinism: %d commands accepted, %d refused, %d units more than at the start, digest %s" % [
		played.accepted.size(), played.refused.size(), trained, played.world.digest().left(16)])
	if played.accepted.size() < 20 or trained <= 0:
		failures.append("the match barely happened: %d commands, %d units trained" % [played.accepted.size(), trained])
	return failures


# Claim 2: the replay, the planted meddling, the snapshot, and the refusals.
func _only_through_the_door(played: RtsMatch) -> Array[String]:
	var failures: Array[String] = []
	var fresh: RtsWorld = RtsTestWorld.economies(SEED)
	var refusal: String = RtsMatch.replay(fresh, played.recording())
	if refusal != "" or fresh.digest() != played.world.digest():
		failures.append("the replay did not reach the match (%s)" % refusal)
	var meddled: RtsMatch = _play(SEED, true)
	var replayed: RtsWorld = RtsTestWorld.economies(SEED)
	RtsMatch.replay(replayed, meddled.recording())
	if replayed.digest() == meddled.world.digest():
		failures.append("money given behind the world's back was not seen by the replay")
	failures.append_array(_snapshot_holds_no_world(played.world))
	failures.append_array(_cheats_refused())
	print("interface: the replay agrees, the meddled match does not, the cheats are refused")
	return failures


# Every property of a snapshot is a plain value, a read-only copy, or a graph
# that is not the world's own.
func _snapshot_holds_no_world(world: RtsWorld) -> Array[String]:
	var failures: Array[String] = []
	var view: RtsSnapshot = RtsSnapshot.of(world, RtsTestWorld.LEFT)
	for property: Dictionary in view.get_property_list():
		var value: Variant = view.get(property["name"])
		if value is RtsWorld or value is RtsUnit:
			failures.append("a snapshot's %s is a piece of the world" % property["name"])
	if is_same(view.graph, world.graph):
		failures.append("a snapshot's graph is the world's own")
	if not view.units.is_read_only() or (not view.units.is_empty() and not view.units[0].is_read_only()):
		failures.append("a snapshot's units can be written to")
	return failures


# Three cheats, each refused with the digest untouched; and an honest order,
# accepted, so a door that refuses everything cannot pass.
func _cheats_refused() -> Array[String]:
	var failures: Array[String] = []
	var world: RtsWorld = RtsTestWorld.economies(SEED)
	var theirs: RtsUnit = _first(world, RtsTestWorld.RIGHT, RtsKinds.WORKER)
	var my_worker: RtsUnit = _first(world, RtsTestWorld.LEFT, RtsKinds.WORKER)
	var my_base: RtsUnit = _first(world, RtsTestWorld.LEFT, RtsKinds.BASE)
	world.resources[RtsTestWorld.LEFT] = 10
	var cheats: Dictionary = {
		"moving an enemy unit": RtsCommand.move([theirs.id] as Array[int], Vector2i(20, 20)),
		"training without the money": RtsCommand.train(my_base.id, RtsKinds.WORKER),
		"attacking a unit out of sight": RtsCommand.attack([my_worker.id] as Array[int], theirs.id),
	}
	for label: String in cheats:
		var before: String = world.digest()
		var refusal: String = world.command(RtsTestWorld.LEFT, cheats[label])
		if refusal == "" or world.digest() != before:
			failures.append("%s was let through (%s)" % [label, refusal if refusal != "" else "accepted"])
	var honest: String = world.command(RtsTestWorld.LEFT, RtsCommand.move([my_worker.id] as Array[int], Vector2i(10, 20)))
	if honest != "":
		failures.append("an honest move was refused: %s" % honest)
	return failures


# Claim 3: the match, timed. Played on its own, so the timing is of one match.
func _fast_enough() -> Array[String]:
	var started: int = Time.get_ticks_usec()
	_play(SEED)
	var seconds: float = (Time.get_ticks_usec() - started) / 1000000.0
	var ratio: float = (float(TICKS) / RtsWorld.TICKS_PER_SECOND) / seconds
	print("speed: %d s of match in %.2f s, %.1f times real time" % [
		TICKS / RtsWorld.TICKS_PER_SECOND, seconds, ratio])
	if ratio < FASTER_THAN_REAL_TIME:
		return ["the match ran %.1f times real time, under %.0f" % [ratio, FASTER_THAN_REAL_TIME]]
	return []


# Claim 4: one enemy soldier far from every unit the left side has, one
# beside its base. The first must be missing from its view, the second there.
func _fogged() -> Array[String]:
	var failures: Array[String] = []
	var world: RtsWorld = RtsTestWorld.economies(SEED)
	var hidden: RtsUnit = world.add_unit(RtsKinds.SOLDIER, RtsTestWorld.RIGHT, Vector2i(40, 8))
	var seen: RtsUnit = world.add_unit(RtsKinds.SOLDIER, RtsTestWorld.RIGHT, Vector2i(12, 34))
	var shown: Array[int] = []
	for unit: Dictionary in RtsSnapshot.of(world, RtsTestWorld.LEFT).units:
		shown.append(unit["id"])
	if hidden.id in shown:
		failures.append("an enemy out of sight is in the view")
	if not seen.id in shown:
		failures.append("an enemy in sight is missing from the view")
	print("fog: out of sight %s, in sight %s" % [
		"shown" if hidden.id in shown else "hidden", "shown" if seen.id in shown else "hidden"])
	return failures


# Claim 5: every side's totals are non-zero and are the sums of its log.
func _counted(played: RtsMatch) -> Array[String]:
	var failures: Array[String] = []
	for side: int in played.counters:
		failures.append_array(_miscounted(played, side))
		print("counters: side %d made %d decisions, %d us, %d work" % [side,
			played.counters[side]["decisions"], played.counters[side]["microseconds"], played.counters[side]["work"]])
	return failures


# Each of `side`'s totals that is zero, or is not the sum of its log.
func _miscounted(played: RtsMatch, side: int) -> Array[String]:
	var failures: Array[String] = []
	var sums: Dictionary = _log_sums(played, side)
	for counter: String in sums:
		var total: int = played.counters[side][counter]
		if total <= 0 or total != sums[counter]:
			failures.append("side %d's %s: total %d, log %d" % [side, counter, total, sums[counter]])
	return failures


# `side`'s decisions, microseconds and work, added up from the log itself.
func _log_sums(played: RtsMatch, side: int) -> Dictionary:
	var sums: Dictionary = {"decisions": 0, "microseconds": 0, "work": 0}
	for decision: Dictionary in played.decisions.filter(func(entry: Dictionary) -> bool: return entry["side"] == side):
		sums["decisions"] += 1
		sums["microseconds"] += decision["microseconds"]
		sums["work"] += decision["work"]
	return sums


func _first(world: RtsWorld, side: int, kind: String) -> RtsUnit:
	for unit: RtsUnit in world.units():
		if unit.side == side and unit.kind == kind:
			return unit
	return null
