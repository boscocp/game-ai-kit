## Avoid: swerve from the first round obstacle the vehicle is about to hit.
##
## The vehicle looks ahead along its velocity -- `look_ahead` units at top
## speed, less as it slows -- and asks of each obstacle whether that stretch
## passes within its radius. Of those that do, the nearest along the stretch
## is the threat (the first listed, on a tie), and the force pushes sideways,
## at full strength, to the side of the stretch the centre is not on. Only
## sideways: a push straight back would brake the vehicle in front of the
## obstacle, and added to seek, which pulls straight on, the two would stall
## there -- the first version did exactly that. Head-on, with the centre on
## the line and no side to choose, it turns left. A vehicle going nowhere
## sees nothing ahead and asks for nothing. O(obstacles).
##
## It only swerves. It does not know where the vehicle wants to go; added to
## seek or arrive with `Steering.combined`, the two together go round.
##
## It never brakes, so `look_ahead` has to be long enough to swerve in at
## top speed: measured with a radius-5 obstacle, a look-ahead of 2 cut 1.3
## into it, and one of 4 or more did not touch it.
##
## When not to use it: walls, corridors, anything not round, or many
## obstacles close together. A circle is a poor wall, and two obstacles
## pushing opposite ways leave the vehicle between them. A flow field or a
## navigation mesh is the answer there.
class_name AvoidBehaviour
extends GakSteeringBehaviour

## Each obstacle's centre, and its radius at the same index.
var centres: Array[Vector2] = []
var radii: PackedFloat64Array = PackedFloat64Array()
## How far ahead it looks at top speed, in units.
var look_ahead: float


func _init(obstacle_centres: Array[Vector2], obstacle_radii: PackedFloat64Array, distance: float) -> void:
	centres = obstacle_centres.duplicate()
	radii = obstacle_radii.duplicate()
	look_ahead = distance


## Full force away from the first obstacle ahead; none when the way is clear.
func force(vehicle: SteeringVehicle) -> Vector2:
	var heading: Vector2 = vehicle.velocity.normalized()
	if heading == Vector2.ZERO or vehicle.max_speed <= 0.0:
		return Vector2.ZERO
	var reach: float = look_ahead * minf(vehicle.speed() / vehicle.max_speed, 1.0)
	var threat: int = _first_threat(vehicle.position, heading, reach)
	if threat < 0:
		return Vector2.ZERO
	# The part of "from the centre to the vehicle" across the heading: which
	# side of the line the vehicle should pass on.
	var from_centre: Vector2 = vehicle.position - centres[threat]
	var across: Vector2 = from_centre - heading * from_centre.dot(heading)
	if across.length() < 1e-6:
		across = Vector2(heading.y, -heading.x)
	return across.normalized() * vehicle.max_force


# The index of the obstacle the stretch ahead meets first, or -1.
func _first_threat(from: Vector2, heading: Vector2, reach: float) -> int:
	var first: int = -1
	var first_along: float = INF
	for index: int in range(centres.size()):
		var closest: Vector2 = _closest_on_stretch(from, heading, reach, centres[index])
		var along: float = (closest - from).dot(heading)
		if closest.distance_to(centres[index]) <= radii[index] and along < first_along:
			first = index
			first_along = along
	return first


# The point of the stretch from `from`, `reach` long along `heading`, nearest
# to `centre`.
static func _closest_on_stretch(from: Vector2, heading: Vector2, reach: float, centre: Vector2) -> Vector2:
	return from + heading * clampf((centre - from).dot(heading), 0.0, reach)
