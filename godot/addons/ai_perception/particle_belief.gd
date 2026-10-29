## Where the guards believe the target is, as a cloud of particles: each
## one a guess at the node the target stands on.
##
## `BeliefMap` spreads its shares blindly along the edges and zeroes what a
## guard sees; it has no model of how a person moves, and nothing for what a
## guard did not hear. A particle filter has both [Thrun 2002; AIMA 4th ed.,
## ch. 14, "Approximate inference in DBNs"]. Over the same graph -- a
## neighbour list, no level in it -- each step with the target unperceived:
##
## 1. **transition**: each particle walks on (`walk_on`) to a neighbour other
##    than the one it came from, else turns (`turn`) to any neighbour, back
##    included, else stays. A person walks on; the grid's even spread does
##    not know that. On a graph "heading" can only mean "not back".
## 2. **sensor**: a particle on a node a guard sees, when it saw no one,
##    weighs 0; one on a node from which the guard would have heard it, when
##    it heard nothing, weighs `unheard`; any other weighs 1. The soft factor
##    is there because a target lying still makes no sound.
## 3. **resampling**: systematic, every step -- one draw, then `count`
##    evenly spaced marks along the weights. If every weight is 0, the
##    target has been looked for everywhere a particle was: the cloud is
##    reseeded evenly over the unseen nodes, and `reseeded` says so.
##
## A sighting or a report collapses the cloud onto its node (`collapse`).
## `shares` answers what `BeliefMap.shares` does -- the share of the cloud on
## each node -- so a game can search from either.
##
## **No training (invariant 6).** Every probability above is a constant set
## before the game starts, and none is changed by what happens. The weights
## are rebuilt from those constants each step, never accumulated from one
## step to the next; that is inference -- filtering, in AIMA's word -- not a
## fit.
##
## Every draw comes from `ParticleDraws`, seeded, so a cloud is the same in
## `gameaikit.perception.particles` draw for draw.
##
## O(count + |seen| + |unheard|) a step, plus O(V) to count the shares.
##
## **Fewer particles than nodes** leaves nodes with no share at all: the
## even start and every reseed then land on a stripe of the graph, and one
## particle can outweigh a node's even share. Give it at least one particle
## a node -- the infiltration level gives two.
##
## When not to use it: a level small enough that `BeliefMap` covers every
## node -- the exact answer, no draws, nothing to seed. Or a target that
## moves in no pattern at all: the transition model is the whole advantage.
class_name ParticleBelief
extends RefCounted

## How likely a particle walks on, to a neighbour other than the one it came from.
const WALK_ON: float = 0.7
## How likely it turns instead, to any neighbour. What is left, it stays.
const TURN: float = 0.2
## What a particle weighs where a guard would have heard it and heard nothing.
const UNHEARD: float = 0.3
## How many particles, unless the game says otherwise.
const COUNT: int = 256

var neighbours: Array[PackedInt32Array] = []
## The knobs, each a fixed number; the vectors set them, a game rarely should.
var walk_on: float = WALK_ON
var turn: float = TURN
var unheard: float = UNHEARD
## Each particle's node, and the node it came from (-1: no heading yet).
var nodes: PackedInt32Array = PackedInt32Array()
var came_from: PackedInt32Array = PackedInt32Array()
## What the last weighing gave each particle, summing to one; all 0 when it
## reseeded. Indexed by the particles as they were weighed, before the
## resampling that followed -- `weights[i]` is not `nodes[i]`'s weight now
## (after resampling every particle weighs the same). After a collapse, even.
var weights: PackedFloat64Array = PackedFloat64Array()
## The share of the cloud on each node, summing to one.
var shares: PackedFloat64Array = PackedFloat64Array()
## The nodes whose particles a guard's sight emptied in the last step, for
## the overlay to flash.
var emptied: PackedInt32Array = PackedInt32Array()
## True when the last step had to reseed the cloud.
var reseeded: bool = false

var _count: int = COUNT
var _draws: ParticleDraws


## A cloud of `count` particles spread evenly over a graph of
## `graph_neighbours`, drawing from `from_seed`: nothing is known yet.
func _init(graph_neighbours: Array[PackedInt32Array], count: int = COUNT, from_seed: int = 1) -> void:
	neighbours = graph_neighbours
	_count = maxi(count, 1)
	_draws = ParticleDraws.new(from_seed)
	_place_evenly(_all_nodes())
	weights = _even_weights(nodes.size())


## Every particle on `node`, with no heading: the target was perceived
## there, or a guard reported it there.
func collapse(node: int) -> void:
	nodes = PackedInt32Array()
	nodes.resize(_count)
	nodes.fill(node)
	came_from = PackedInt32Array()
	came_from.resize(_count)
	came_from.fill(-1)
	weights = _even_weights(_count)
	emptied = PackedInt32Array()
	reseeded = false
	_count_shares()


## One step with the target unperceived: move every particle, weigh it by
## the nodes a guard saw (`seen`) and would have heard it from
## (`unheard_from`), and resample -- or reseed when nothing is left.
func step_unseen(seen: PackedInt32Array, unheard_from: PackedInt32Array) -> void:
	for index: int in range(nodes.size()):
		_move(index)
	var raw: PackedFloat64Array = _weigh(_as_set(seen), _as_set(unheard_from))
	var total: float = 0.0
	for weight: float in raw:
		total += weight
	reseeded = total <= 0.0
	if reseeded:
		var unseen: PackedInt32Array = _unseen(_as_set(seen))
		_place_evenly(unseen if not unseen.is_empty() else _all_nodes())
		weights = PackedFloat64Array()
		weights.resize(nodes.size())
	else:
		var normalised := PackedFloat64Array()
		for weight: float in raw:
			normalised.append(weight / total)
		weights = normalised
		_resample()
	_count_shares()


# The transition model, for one particle: walk on, else turn, else stay.
# One uniform draw always; a second only when there is a choice to make.
func _move(index: int) -> void:
	var here: int = nodes[index]
	var edges: PackedInt32Array = neighbours[here]
	var chance: float = _draws.uniform()
	var choices := PackedInt32Array()
	if chance < walk_on:
		choices = _ahead(edges, came_from[index])
	elif chance < walk_on + turn:
		choices = edges
	if choices.is_empty():
		return
	nodes[index] = choices[_draws.index(choices.size())]
	came_from[index] = here


# Where walking on can go from a node with `edges`, having come from
# `behind`: every neighbour but that one -- or, at a dead end, back.
static func _ahead(edges: PackedInt32Array, behind: int) -> PackedInt32Array:
	var ahead := PackedInt32Array()
	for next: int in edges:
		if next != behind:
			ahead.append(next)
	return ahead if not ahead.is_empty() else edges


# The sensor model: each particle's weight, before it is normalised; and
# which seen nodes held a particle, in the order first met.
func _weigh(seen: Dictionary[int, bool], heard_from: Dictionary[int, bool]) -> PackedFloat64Array:
	var raw := PackedFloat64Array()
	emptied = PackedInt32Array()
	for node: int in nodes:
		if seen.has(node) and not emptied.has(node):
			emptied.append(node)
		if seen.has(node):
			raw.append(0.0)
		else:
			raw.append(unheard if heard_from.has(node) else 1.0)
	return raw


# Systematic resampling: one draw places the first mark in [0, 1/n), the
# rest follow 1/n apart, and each mark takes the particle whose stretch of
# the running total it falls in.
func _resample() -> void:
	var stride: float = 1.0 / nodes.size()
	var start: float = _draws.uniform() * stride
	var source: int = 0
	var reached: float = weights[0]
	var picked := PackedInt32Array()
	var picked_from := PackedInt32Array()
	for index: int in range(nodes.size()):
		var mark: float = start + index * stride
		while mark > reached and source < nodes.size() - 1:
			source += 1
			reached += weights[source]
		picked.append(nodes[source])
		picked_from.append(came_from[source])
	nodes = picked
	came_from = picked_from


# `_count` particles spread over `candidates` in order, as evenly as they
# divide; no draw is spent.
func _place_evenly(candidates: PackedInt32Array) -> void:
	nodes = PackedInt32Array()
	came_from = PackedInt32Array()
	if candidates.is_empty():
		_count_shares()
		return
	for index: int in range(_count):
		# Whole-number division on purpose: Python's `//`, the same answer.
		@warning_ignore("integer_division")
		nodes.append(candidates[index * candidates.size() / _count])
		came_from.append(-1)
	_count_shares()


func _count_shares() -> void:
	shares = PackedFloat64Array()
	shares.resize(neighbours.size())
	for node: int in nodes:
		shares[node] += 1.0 / nodes.size()


func _unseen(seen: Dictionary[int, bool]) -> PackedInt32Array:
	var found := PackedInt32Array()
	for node: int in range(neighbours.size()):
		if not seen.has(node):
			found.append(node)
	return found


func _all_nodes() -> PackedInt32Array:
	return _unseen({})


static func _even_weights(size: int) -> PackedFloat64Array:
	var even := PackedFloat64Array()
	even.resize(size)
	even.fill(1.0 / maxf(size, 1.0))
	return even


# A set made first: asking the array `has` for every particle would be
# O(count x |nodes|).
static func _as_set(listed: PackedInt32Array) -> Dictionary[int, bool]:
	var found: Dictionary[int, bool] = {}
	for node: int in listed:
		found[node] = true
	return found
