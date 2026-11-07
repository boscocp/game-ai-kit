## The civilians of a crowded level, walking in groups, and whether the
## player is hidden among them (T152).
##
## Each group is a flock -- `ai_steering`'s `Flock` (T150): separation,
## alignment and cohesion over the civilians of the same group within
## `sees_within` -- plus two forces of this game, added with them through
## `Steering.combined`: a seek towards the group's next point on its wander
## loop, and a separation from strangers -- the other groups, the player
## and the guards -- so a group parts round them. The steering is 2D, on the
## floor (x, z); the walls are not a steering force: a civilian's step is
## taken on the level's walk grid, sliding along a wall as the player does,
## so no one walks through a stall whatever the forces say. Every force is
## computed from one snapshot, each civilian's neighbours in id order, and
## only then are the steps taken, so two runs from one start agree.
##
## Hiding: the player is counted in the group with the most civilians near
## (at least `fewest` within `counts_within`). Walking upright with the
## group's heading blends in; sprinting, crouching, lying down, standing
## still or walking against it stands out. `weigh` scales a guard's sight
## certainty by the reading and names it in the percept, which
## `GuardSuspicion` asks the intruder network about as its `figure` sign.
## These are rules of this game, numbers in crowd.json; nothing is learned
## (invariant 6).
##
## Cost: O(n^2) a step for n civilians -- every one against every other;
## fine for the sixteen here. Use a neighbour grid
## (`godot/demos/flocking/neighbour_grid.gd`) for hundreds.
##
## When not to use it: a crowd that must queue, sit or go through doors. A
## flock wanders; it does not have errands.
class_name InfiltrationCrowd
extends RefCounted

const FILE: String = "res://game3d/infiltration/crowd.json"
## The readings, as the figure sign's values in intruder_network.json.
const BLENDS_IN: String = "blends_in"  # not shown: a value of the network's data
const STANDS_OUT: String = "stands_out"  # not shown: a value of the network's data
## Why the player blends in or stands out, as the view says it.
const IN_STEP: String = "walking in step"  # shown through tr()
const AGAINST: String = "walking against the group"  # shown through tr()
const STILL: String = "standing still"  # shown through tr()
const SPRINTING: String = "sprinting"  # shown through tr()
const LOW: String = "crouching or lying down"  # shown through tr()
## The order of the forces added for each civilian, as in crowd.json's weights.
enum Force { SEPARATION, ALIGNMENT, COHESION, WANDER, STRANGERS }


## Where the player stands among the civilians, one step: the group it is
## counted in (-1, none), why it blends in or stands out, the reading and
## what it does to a guard's certainty.
class Cover:
	var group: int = -1
	var reason: String = ""
	var figure: String = ""
	var scale: float = 1.0


var spec: Dictionary = {}
## Every civilian, by id, and the group it walks with.
var people: Array[SteeringVehicle] = []
var group_of: PackedInt32Array = PackedInt32Array()
## Each group's wander loop, and the index of the point it walks to.
var loops: Array[Array] = []
var heading_to: PackedInt32Array = PackedInt32Array()
var flock: Flock
var strangers: SeparationBehaviour
var wander: SeekBehaviour
var weights: PackedFloat64Array
## This step's reading of the player, as `cover` last made it.
var cover := Cover.new()


## The crowd `groups` describe -- each `people`, a `start` and a `loop` of
## points -- walking at `speed`, the player's walk.
func _init(groups: Array, speed: float, path: String = FILE) -> void:
	spec = JSON.parse_string(FileAccess.get_file_as_string(path))
	weights = PackedFloat64Array(spec["weights"])
	flock = Flock.new(float(spec["too_close"]), 1.0)
	strangers = SeparationBehaviour.new(float(spec["strangers_within"]))
	wander = SeekBehaviour.new(Vector2.ZERO)
	for index: int in range(groups.size()):
		_place_group(index, groups[index], speed)


# The civilians of group `index`, on a small ring round its start, facing
# its first point.
func _place_group(index: int, group: Dictionary, speed: float) -> void:
	var loop: Array[Vector2] = []
	for pair: Array in group["loop"]:
		loop.append(Vector2(float(pair[0]), float(pair[1])))
	loops.append(loop)
	heading_to.append(0)
	var start := Vector2(float(group["start"][0]), float(group["start"][1]))
	var count: int = int(group["people"])
	for person: int in range(count):
		var at: Vector2 = start + Vector2.from_angle(TAU * person / count) * float(spec["too_close"])
		var facing: Vector2 = Steering.direction_to(start, loop[0]) * speed * 0.5
		people.append(SteeringVehicle.new(at, facing, speed, float(spec["strongest"])))
		group_of.append(index)


## One step of `seconds` on `level`: each group turns to its next point when
## it is near the one it walks to; every civilian's force is taken from the
## same moment, with `others` -- the player and the guards, where they
## stand -- to keep clear of; then each steps along the walk grid.
func step(level: InfiltrationLevel, others: Array[Vector2], seconds: float) -> void:
	_advance_loops()
	var outsiders: Array[SteeringVehicle] = []
	for place: Vector2 in others:
		outsiders.append(SteeringVehicle.new(place, Vector2.ZERO, 0.0, 0.0))
	var pushes: Array[Vector2] = []
	for person: int in range(people.size()):
		pushes.append(force_on(person, outsiders))
	for person: int in range(people.size()):
		_walk(people[person], pushes[person], level, seconds)


## The force on civilian `person` now: its group's three flocking rules,
## its wander target and the strangers near it, weighed by crowd.json.
func force_on(person: int, outsiders: Array[SteeringVehicle]) -> Vector2:
	return Steering.combined(people[person], forces_on(person, outsiders), weights)


## The five forces on civilian `person`, unweighted, in `Force` order --
## what the view could draw, so a person sees which one pulls which way.
func forces_on(person: int, outsiders: Array[SteeringVehicle]) -> Array[Vector2]:
	var vehicle: SteeringVehicle = people[person]
	flock.see(group_near(person))
	var found: Array[Vector2] = flock.forces(vehicle)
	wander.target = loops[group_of[person]][heading_to[group_of[person]]]
	found.append(wander.force(vehicle))
	var near: Array[SteeringVehicle] = outsiders.duplicate()
	near.append_array(strangers_near(person))
	strangers.neighbours = near
	found.append(strangers.force(vehicle))
	return found


## The civilians of `person`'s group it can see, by id, itself left out.
func group_near(person: int) -> Array[SteeringVehicle]:
	var near: Array[SteeringVehicle] = []
	for other: int in range(people.size()):
		var seen: bool = people[person].position.distance_to(people[other].position) <= float(spec["sees_within"])
		if other != person and group_of[other] == group_of[person] and seen:
			near.append(people[other])
	return near


## The civilians of other groups within `strangers_within` of `person`, by id.
func strangers_near(person: int) -> Array[SteeringVehicle]:
	var near: Array[SteeringVehicle] = []
	for other: int in range(people.size()):
		var close: bool = people[person].position.distance_to(people[other].position) < float(spec["strangers_within"])
		if group_of[other] != group_of[person] and close:
			near.append(people[other])
	return near


## The middle of group `group`: the mean of its civilians' places.
func middle_of(group: int) -> Vector2:
	var total := Vector2.ZERO
	var count: int = 0
	for person: int in range(people.size()):
		if group_of[person] == group:
			total += people[person].position
			count += 1
	return total / maxi(count, 1)


## The heading of group `group`: its civilians' headings added, as a unit
## vector; zero when none moves.
func heading_of(group: int) -> Vector2:
	var total := Vector2.ZERO
	for person: int in range(people.size()):
		if group_of[person] == group:
			total += Steering.direction_to(Vector2.ZERO, people[person].velocity)
	return Steering.direction_to(Vector2.ZERO, total)


# Each group whose middle is near the point it walks to turns to the next.
func _advance_loops() -> void:
	for group: int in range(loops.size()):
		var target: Vector2 = loops[group][heading_to[group]]
		if middle_of(group).distance_to(target) <= float(spec["next_point_within"]):
			heading_to[group] = (heading_to[group] + 1) % loops[group].size()


# One civilian's step: its velocity from `push`, then the move it asks for
# taken along the walk grid -- the whole of it, or sliding along x or z --
# and its velocity kept to the move it really made.
static func _walk(vehicle: SteeringVehicle, push: Vector2, level: InfiltrationLevel, seconds: float) -> void:
	var before: Vector2 = vehicle.position
	vehicle.step(push, seconds)
	var wanted: Vector2 = vehicle.position - before
	vehicle.position = before
	for attempt: Vector2 in [wanted, Vector2(wanted.x, 0.0), Vector2(0.0, wanted.y)]:
		if attempt != Vector2.ZERO and level.arena.walkable(before, before + attempt):
			vehicle.position = before + attempt
			break
	vehicle.velocity = (vehicle.position - before) / seconds


## Read where `player` stands among the civilians under `rules`, after its
## move of `seconds`: the group it is counted in, the reason, the reading.
func read_cover(player: InfiltrationPlayer, rules: InfiltrationRules, seconds: float) -> Cover:
	cover = Cover.new()
	cover.group = group_counting(player.position)
	if cover.group == -1:
		return cover
	cover.reason = reason_for(player, rules, seconds, heading_of(cover.group))
	cover.figure = BLENDS_IN if cover.reason == IN_STEP else STANDS_OUT
	cover.scale = float(spec["certainty_scale"][cover.figure])
	return cover


## The group with the most civilians within `counts_within` of `place`, if
## at least `fewest`; the first of equal ones; -1 none.
func group_counting(place: Vector2) -> int:
	var counts: Dictionary[int, int] = {}
	for person: int in range(people.size()):
		if people[person].position.distance_to(place) <= float(spec["counts_within"]):
			counts[group_of[person]] = counts.get(group_of[person], 0) + 1
	var best: int = -1
	for group: int in range(loops.size()):
		if counts.get(group, 0) >= int(spec["fewest"]) and (best == -1 or counts[group] > counts[best]):
			best = group
	return best


## Why `player` blends in with a group heading `heading`, or stands out:
## the sprint, a low stance, standing still, or its own heading against
## the group's by more than `in_step_degrees`.
func reason_for(player: InfiltrationPlayer, rules: InfiltrationRules, seconds: float, heading: Vector2) -> String:
	if player.sprinting:
		return SPRINTING
	if player.stance != "standing":  # not shown: an identifier
		return LOW
	if player.motion(rules, seconds) <= 0.0:
		return STILL
	var off: float = rad_to_deg(absf(Vector2.from_angle(player.facing).angle_to(heading))) if heading != Vector2.ZERO else 180.0
	return IN_STEP if off <= float(spec["in_step_degrees"]) else AGAINST


## A guard's look, `percept`, weighed by this step's cover: when its eye
## picked the player out of a group, its certainty is scaled, at most 1,
## and the reading and its reason are written into the percept.
func weigh(percept: GuardPercept) -> void:
	if cover.group == -1 or not percept.sight.perceived():
		return
	percept.sight.certainty = minf(percept.sight.certainty * cover.scale, 1.0)
	percept.figure = cover.figure
	percept.crowd_reason = cover.reason
