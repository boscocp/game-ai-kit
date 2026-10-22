## The stealth properties about what a guard knows: nothing it did not
## perceive, phases read from its own row, and an honest belief.
##
## Each claim takes the technique as a Callable, so `awareness_properties.gd`
## can hand it the real one, which must pass, and a planted one, which must
## not (invariant 4). Each returns its findings, one line each.
##
## When not to use it: as a guard. These only watch one.
class_name KnowledgeClaims
extends RefCounted

const STEPS: int = 40
const STEP_SECONDS: float = 0.5
const SPREAD: float = 0.5
const TOLERANCE: float = 1e-9


## Nothing known that was not perceived: over `seeds` generated levels, a
## target wanders past a guard, and on every step its percept is empty the
## awareness does not rise, the memory does not change, and the belief only
## spreads. `update` is called as (mind, belief, percept, walk, seen nodes,
## now); the honest one reads nothing of the walk but its cell names.
##
## A claim watched only on empty steps, or never on one, proves nothing: the
## steps of each kind are counted, and none of either is a finding.
static func knows_only_perceived(type: GuardType, update: Callable, seeds: int) -> Array[String]:
	var counted: Dictionary = {"empty": 0, "perceived": 0}
	for seed_value: int in range(1, seeds + 1):
		var found: String = _one_wander(type, update, seed_value, counted)
		if found != "":
			return ["seed %d: %s" % [seed_value, found]]
	if counted["empty"] == 0 or counted["perceived"] == 0:
		return ["the walks gave %d empty and %d perceived steps; the claim needs both" % [counted["empty"], counted["perceived"]]]
	return []


static func _one_wander(type: GuardType, update: Callable, seed_value: int, counted: Dictionary) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var walk: StealthWalk = StealthWalk.make(rng)
	if walk == null:
		return ""
	var mind := GuardMind.new(type)
	var belief := BeliefMap.new(walk.neighbours)
	for step: int in range(STEPS):
		walk.wander(rng)
		var percept: GuardPercept = walk.percept(type)
		var before: Dictionary = _snapshot(mind, belief)
		var seen: PackedInt32Array = walk.seen_nodes(type)
		update.call(mind, belief, percept, walk, seen, step * STEP_SECONDS)
		var empty: bool = not percept.sight.perceived() and percept.loudness <= 0.0
		counted["empty" if empty else "perceived"] += 1
		var wrong: String = _learned_from_nothing(before, mind, belief, seen) if empty else ""
		if wrong != "":
			return "step %d: %s" % [step, wrong]
	return ""


static func _snapshot(mind: GuardMind, belief: BeliefMap) -> Dictionary:
	return {"sight": mind.awareness["sight"].value, "sound": mind.awareness["sound"].value,
		"memory": [mind.memory.known, mind.memory.place, mind.memory.at], "shares": belief.shares.duplicate()}


# What an empty step changed that it should not have, or "".
static func _learned_from_nothing(before: Dictionary, mind: GuardMind, belief: BeliefMap,
		seen: PackedInt32Array) -> String:
	for stimulus: String in GuardMind.STIMULI:
		if mind.awareness[stimulus].value > float(before[stimulus]) + TOLERANCE:
			return "%s awareness rose with nothing perceived" % stimulus
	if [mind.memory.known, mind.memory.place, mind.memory.at] != before["memory"]:
		return "the memory changed with nothing perceived"
	var expected := BeliefMap.new(belief.neighbours)
	expected.shares = before["shares"]
	expected.step_unseen(seen, SPREAD)
	for node: int in range(expected.shares.size()):
		if absf(expected.shares[node] - belief.shares[node]) > TOLERANCE:
			return "the belief did more than spread with nothing perceived"
	return ""


## The honest update: the mind steps on its percept, and the belief
## collapses on the cell the eye put the target in, or else spreads.
static func honest_update(mind: GuardMind, belief: BeliefMap, percept: GuardPercept, walk: StealthWalk,
		seen: PackedInt32Array, now: float) -> void:
	mind.step(percept, now, STEP_SECONDS)
	if percept.sight.perceived():
		belief.collapse(walk.cells.find(Vector2i(percept.seen_place)))
	else:
		belief.step_unseen(seen, SPREAD)


## Planted: the honest update, and then the guard is told where the target
## really is -- Welsh's "2-3 s of knowing", every step.
static func cheating_update(mind: GuardMind, belief: BeliefMap, percept: GuardPercept, walk: StealthWalk,
		seen: PackedInt32Array, now: float) -> void:
	honest_update(mind, belief, percept, walk, seen, now)
	mind.memory.remember(Vector2(walk.cells[walk.target]), now, "cheat")
	belief.collapse(walk.target)


## The phases follow the thresholds: `phase_of` (number, row) reads every
## number as the row's thresholds say; falling from an alert, every phase
## in between is passed through, one at most a step; and the caution floor
## holds for the row's seconds after the alert.
static func phases_follow(row: Dictionary, phase_of: Callable) -> Array[String]:
	var found: Array[String] = []
	for hundredth: int in range(101):
		var number: float = hundredth / 100.0 * float(row["peak"])
		if int(phase_of.call(number, row)) != _phase_by_hand(number, row):
			found.append("%.2f reads as phase %d, the row says %d" % [number, phase_of.call(number, row), _phase_by_hand(number, row)])
			return found
	found.append_array(_falls_through_every_phase(row, phase_of))
	return found


# The phase by a loop of its own, so the claim does not ask `Awareness`
# what `Awareness` says.
static func _phase_by_hand(number: float, row: Dictionary) -> int:
	var count: int = 0
	for index: int in range(1, (row["phases"] as Array).size()):
		if number >= float(row["phases"][index]["at"]) * float(row["peak"]):
			count = index
	return count


static func _falls_through_every_phase(row: Dictionary, phase_of: Callable) -> Array[String]:
	var awareness := Awareness.new()
	awareness.step(row, true, 1000.0, 1.0, 0.0)
	var held_until: float = float(row["caution"]["seconds"])
	var floor_value: float = float(row["caution"]["floor"]) * float(row["peak"])
	var last: int = int(phase_of.call(awareness.value, row))
	for second: int in range(1, 400):
		awareness.step(row, false, 0.0, 7.0, second * 7.0)
		var now_phase: int = int(phase_of.call(awareness.value, row))
		if now_phase < last - 1:
			return ["falling skipped from phase %d to %d" % [last, now_phase]]
		if second * 7.0 < held_until and awareness.value < floor_value - TOLERANCE:
			return ["below the caution floor %.1f s after the alert" % (second * 7.0)]
		last = now_phase
	return [] if last == 0 else ["it never fell back to the first phase"]
