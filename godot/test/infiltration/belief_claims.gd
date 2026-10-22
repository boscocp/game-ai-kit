## The stealth property about the shared belief: honest on any graph.
##
## While the target is perceived the belief is all on the perceived node;
## while it is not, it is zero on every node a guard sees, sums to one, and
## moves only along edges -- and a step that would clear it all reseeds it
## evenly over the unseen nodes [Isla 2013; McIntosh 2015]. The step is a
## Callable, so `awareness_properties.gd` can hand it the real one and a
## planted one that leaks through a wall (invariant 4).
##
## When not to use it: as a belief. These only test one.
class_name BeliefClaims
extends RefCounted

const STEPS: int = 30
const PERCEIVED_SHARE: float = 0.15
const SEEN_SHARE: float = 0.3
const TOLERANCE: float = 1e-9


## The belief is honest over `seeds` generated levels. `unseen_step` is
## called as (belief, seen nodes, spread).
static func is_honest(unseen_step: Callable, seeds: int) -> Array[String]:
	for seed_value: int in range(1, seeds + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var level: GridGraph = StealthWorlds.scattered(rng)
		var cells: Array[Vector2i] = StealthWorlds.free_cells(level)
		if cells.size() < 2:
			continue
		var wrong: String = _one_run(BeliefMap.new(StealthWorlds.neighbour_list(level, cells)), unseen_step, rng)
		if wrong != "":
			return ["seed %d: %s" % [seed_value, wrong]]
	return []


static func _one_run(belief: BeliefMap, unseen_step: Callable, rng: RandomNumberGenerator) -> String:
	for step: int in range(STEPS):
		var wrong: String = _one_step(belief, unseen_step, rng)
		if wrong != "":
			return "step %d: %s" % [step, wrong]
	return ""


# One step: perceived at a random node, or unseen with a random sight.
static func _one_step(belief: BeliefMap, unseen_step: Callable, rng: RandomNumberGenerator) -> String:
	var count: int = belief.shares.size()
	if rng.randf() < PERCEIVED_SHARE:
		var node: int = rng.randi_range(0, count - 1)
		belief.collapse(node)
		return "" if belief.shares[node] == 1.0 else "perceived at %d, and the belief is not all there" % node
	var before: PackedFloat64Array = belief.shares.duplicate()
	var seen: PackedInt32Array = _random_seen(rng, count)
	unseen_step.call(belief, seen, rng.randf())
	return _why_not_honest(belief, before, seen)


# About SEEN_SHARE of `count` nodes, as the guards' sight this step.
static func _random_seen(rng: RandomNumberGenerator, count: int) -> PackedInt32Array:
	var seen := PackedInt32Array()
	for node: int in range(count):
		if rng.randf() < SEEN_SHARE:
			seen.append(node)
	return seen


# What is wrong with `belief` after an unseen step from `before`, or "".
static func _why_not_honest(belief: BeliefMap, before: PackedFloat64Array, seen: PackedInt32Array) -> String:
	var total: float = 0.0
	for node: int in range(belief.shares.size()):
		total += belief.shares[node]
		if seen.has(node) and belief.shares[node] != 0.0:
			return "node %d is seen and keeps a share" % node
		if not belief.reseeded and belief.shares[node] > 0.0 and not _reachable_in_one(belief, before, node):
			return "node %d got a share from no neighbour" % node
	if seen.size() < belief.shares.size() and absf(total - 1.0) > 1e-6:
		return "the shares sum to %f" % total
	return _why_not_even(belief, seen) if belief.reseeded else ""


# A reseeded belief must be even over the nodes no guard sees.
static func _why_not_even(belief: BeliefMap, seen: PackedInt32Array) -> String:
	var even: float = 1.0 / maxf(belief.shares.size() - seen.size(), 1.0)
	for node: int in range(belief.shares.size()):
		if not seen.has(node) and absf(belief.shares[node] - even) > TOLERANCE:
			return "reseeded unevenly: node %d holds %f, not %f" % [node, belief.shares[node], even]
	return ""


# True when `node` held a share or is next to a node that did.
static func _reachable_in_one(belief: BeliefMap, before: PackedFloat64Array, node: int) -> bool:
	if before[node] > 0.0:
		return true
	for other: int in range(before.size()):
		if before[other] > 0.0 and belief.neighbours[other].has(node):
			return true
	return false


## The honest unseen step.
static func honest_step(belief: BeliefMap, seen: PackedInt32Array, spread: float) -> void:
	belief.step_unseen(seen, spread)


## Planted: diffusion through a wall -- each node also hands a share to the
## node half the graph away, an edge the level does not have.
static func through_a_wall(belief: BeliefMap, seen: PackedInt32Array, spread: float) -> void:
	var leaked := PackedFloat64Array()
	leaked.resize(belief.shares.size())
	var half: int = maxi(floori(belief.shares.size() / 2.0), 1)
	for node: int in range(belief.shares.size()):
		leaked[node] += belief.shares[node] * 0.9
		leaked[(node + half) % belief.shares.size()] += belief.shares[node] * 0.1
	belief.shares = leaked
	belief.step_unseen(seen, spread)
