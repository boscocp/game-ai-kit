## A group on one move order walks as a flock: the flow field says where,
## Reynolds' three rules say how, among the group.
##
## T151. The core walks each unit alone along the field, and a group files
## into a column on every cell's middle. With this crowd switched on, every
## unit of a group's move order -- two or more units of one side sent to one
## cell -- adds to the field's heading the three forces of T150's `Flock`:
## away from groupmates too close, towards their heading, towards their
## middle. Only groupmates count. An enemy walking the other way through the
## same gap is not a neighbour, and nobody pushes against it, which is how
## T19's armies jammed when the core nudged units on a move order
## (`RtsWorld._keep_apart`, `test/rts/rts_flock_gap.gd`).
##
## Every force comes from one moment: `before_moves` works out all of them
## from where everybody stood before the tick, in id order, and only then
## does anybody step. Neighbours come from the world's own spatial hash,
## sorted by id; a velocity is how far the unit went last tick. So two runs
## from one seed agree, with the flock on as with it off.
##
## Cost: one hash question and O(groupmates in sight) a flocking unit every
## `DECIDE_EVERY` ticks, and a step each tick -- counted in the simulation's
## share of the frame, since the world calls it inside `step`. Measured on
## the budget's two hundred shields: 2.7 ms a tick, the column 1.1, the
## share 4.0 (`make test-rts-flock`).
##
## When not to use it: a group that must arrive in order, or hold a line --
## a flock has no places. The last straight stretch to the goal stays the
## core's, so the group still arrives where it was sent.
class_name RtsFlock
extends GakRtsCrowd

## How far a unit sees its groupmates, and how close is too close, in cells.
## Separation's push fades to nothing at `TOO_CLOSE` while cohesion pulls
## at full strength, so a flock stands well inside it: measured, twelve
## shields walk 0.53 cells from their nearest groupmate, the column 0.28 --
## and a shield is drawn three quarters of a cell wide.
const SIGHT: float = 2.0
const TOO_CLOSE: float = 1.0
## How hard a unit may turn: the most its velocity changes in a second, in
## top speeds. Four turns it about in half a second, which keeps it on a
## field whose arrows bend at every cell.
const TURN: float = 4.0
## One tick. The time each rule is given to turn the velocity to what it
## wants, as Shiffman's flock steers a frame at a time (T150's demo, and
## its review): the turn's rate is then `TURN` alone, one knob, not two.
const TIME_TO_TARGET: float = 1.0 / RtsWorld.TICKS_PER_SECOND
## The weights, in `Flock.Rule` order, then the field's. Separation counts
## most, as in Shiffman's; the field counts as much as the other two, so the
## group goes where it was sent.
const FLOCK_WEIGHTS: Array[float] = [1.5, 1.0, 1.0]
const FIELD_WEIGHT: float = 1.0
## Ticks between two decisions of one unit's three forces, each unit on its
## own tick of the cycle, as `RtsOrders.LOOK_EVERY` spreads its looks. Every
## tick, two hundred units asking cost more than the simulation's whole
## share of the frame (measured: 4.2 ms against 4.0).
const DECIDE_EVERY: int = 3
## The rules' names, in `Flock.Rule` order: the overlay's keys.
const RULES: Array[String] = ["separation", "alignment", "cohesion"]

## Off, the core's column; on, the flock. A key in the game switches it.
var on: bool = false
## The unit whose forces the game draws, by id; 0 for none.
var watched: int = 0
## What the watched unit last decided, while it flocks: its three forces,
## unweighted, in `Flock.Rule` order, and the groupmates it counted. Empty
## when it does not flock.
var watched_forces: Array[Vector2] = []
var watched_counted: Array[int] = []

var _flock := Flock.new(TOO_CLOSE, TIME_TO_TARGET, PackedFloat64Array(FLOCK_WEIGHTS))
# The world's board, for the walls a step may not cross. Not the world:
# the world holds its crowd, and a crowd holding the world back is a cycle
# that is never freed.
var _graph: GakGridGraph
# Id -> the vehicle a flocking unit was this tick, and its three forces.
var _vehicles: Dictionary = {}
var _forces: Dictionary = {}
# Id -> where it stood a tick ago: its velocity, without a field for one.
var _was: Dictionary = {}


## The flocking units' forces, from where everybody stands now: a third of
## them decide afresh each tick, by id, and the rest keep what they decided.
func before_moves(world: RtsWorld) -> void:
	_graph = world.graph
	if not on:
		_vehicles.clear()
		_forces.clear()
		_was.clear()
		watched_forces = []
		watched_counted = []
		return
	var groups: Dictionary = _groups(world)
	var vehicles: Dictionary = {}
	for key: Vector3i in groups:
		for member: RtsUnit in groups[key]:
			vehicles[member.id] = _vehicle(member)
	_vehicles = vehicles
	var forces: Dictionary = {}
	for key: Vector3i in groups:
		for member: RtsUnit in groups[key]:
			var due: bool = (world.tick + member.id) % DECIDE_EVERY == 0 or not _forces.has(member.id)
			forces[member.id] = _decide(world, member, key) if due else _forces[member.id]
	_forces = forces
	watched_forces.assign(_forces.get(watched, []))
	if watched_forces.is_empty():
		watched_counted = []
	_was.clear()
	for id: int in _vehicles:
		_was[id] = (_vehicles[id] as SteeringVehicle).position


## A flocking unit's step: the field's heading and the three rules, added
## and clamped, turned into a velocity no faster than its stride. Anybody
## else, or a step that would cross a wall, is the core's straight step.
##
## The heading is the arrow of the cell the unit stands in -- from that
## cell's middle to the next one's -- not the line from the unit to the next
## middle. Every unit seeking that one point is the column again: measured,
## a flock seeking it stood its twelve 0.26 cells apart, the column 0.28.
func step_to(unit: RtsUnit, waypoint: Vector2, stride: float) -> Vector2:
	if not _forces.has(unit.id):
		return super.step_to(unit, waypoint, stride)
	var vehicle: SteeringVehicle = _vehicles[unit.id]
	var middle: Vector2 = unit.position.floor() + Vector2(0.5, 0.5)
	var heading: Vector2 = Steering.direction_to(middle, waypoint) * vehicle.max_speed
	var forces: Array[Vector2] = [Steering.towards_velocity(vehicle, heading, TIME_TO_TARGET)]
	forces.append_array(_forces[unit.id])
	var force: Vector2 = Steering.combined(vehicle, forces, _weights())
	var velocity: Vector2 = (vehicle.velocity + force * TIME_TO_TARGET).limit_length(vehicle.max_speed)
	var to: Vector2 = unit.position + velocity * TIME_TO_TARGET
	if not _may_step(Vector2i(unit.position.floor()), Vector2i(to.floor())):
		return super.step_to(unit, waypoint, stride)
	return to


# The group of every unit on a move order, by side and goal; only groups of
# two or more. Units in id order, as `RtsWorld.units` hands them.
func _groups(world: RtsWorld) -> Dictionary:
	var groups: Dictionary = {}
	for unit: RtsUnit in world.units():
		if unit.order != RtsCommand.MOVE or unit.health <= 0:
			continue
		var key := Vector3i(unit.side, unit.goal.x, unit.goal.y)
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(unit)
	for key: Vector3i in groups.keys():
		if (groups[key] as Array).size() < 2:
			groups.erase(key)
	return groups


# `unit` as a vehicle: where it stands, the velocity of its last tick, its
# kind's top speed and `TURN` of it.
func _vehicle(unit: RtsUnit) -> SteeringVehicle:
	var speed: float = RtsKinds.of(unit.kind, "speed")
	var velocity: Vector2 = (unit.position - _was.get(unit.id, unit.position)) * RtsWorld.TICKS_PER_SECOND
	return SteeringVehicle.new(unit.position, velocity.limit_length(speed), speed, speed * TURN)


# `member`'s three forces, from the groupmates of `key` the hash finds in
# sight, in id order.
func _decide(world: RtsWorld, member: RtsUnit, key: Vector3i) -> Array[Vector2]:
	var neighbours: Array[SteeringVehicle] = []
	var counted: Array[int] = []
	for id: int in world.spatial.near(member.position, SIGHT):
		var other: RtsUnit = world.unit(id)
		if id != member.id and _vehicles.has(id) and Vector3i(other.side, other.goal.x, other.goal.y) == key:
			neighbours.append(_vehicles[id])
			counted.append(id)
	_flock.see(neighbours)
	var decided: Array[Vector2] = _flock.forces(_vehicles[member.id])
	if member.id == watched:
		watched_counted = counted
	return decided


# The field's weight, then the flock's: the order `step_to` adds them in.
static func _weights() -> PackedFloat64Array:
	var weights := PackedFloat64Array([FIELD_WEIGHT])
	weights.append_array(PackedFloat64Array(FLOCK_WEIGHTS))
	return weights


# True when a unit may go from cell `from` into cell `to`: open, and, on a
# diagonal, both cells it slips between open too -- the board is
# four-connected, and a flock must not cut a corner the field cannot.
func _may_step(from: Vector2i, to: Vector2i) -> bool:
	if not _graph.contains(to) or _graph.is_blocked(to):
		return false
	if from.x == to.x or from.y == to.y:
		return true
	return not _graph.is_blocked(Vector2i(to.x, from.y)) and not _graph.is_blocked(Vector2i(from.x, to.y))
