## Alignment: steer towards the neighbours' average heading.
##
## The second of Reynolds' three flocking rules. Each neighbour's heading --
## its velocity's direction, not its speed -- is added; the sum's direction
## at top speed is the velocity wanted, and the force is what turns the
## vehicle's velocity into it (`Steering.towards_velocity`, as seek's is).
## Headings rather than velocities, so a slow neighbour counts as much as a
## fast one and the flock keeps flying instead of agreeing to stop.
## Neighbours that are still, or whose headings cancel exactly, give it
## nothing to align with, and it asks for nothing. O(neighbours).
##
## The caller hands it `neighbours`, as `SeparationBehaviour` explains.
##
## When not to use it: a group that must keep its places -- a column, a
## formation. Alignment agrees on a heading, never on who goes where.
class_name AlignmentBehaviour
extends GakSteeringBehaviour

## The vehicles this one can see, handed over by the caller before each ask.
## The vehicle itself, if listed, is skipped.
var neighbours: Array[SteeringVehicle] = []
## The time constant of the turn, as seek's: about two-thirds of the gap to
## the velocity wanted closes in it. Never under `Steering.SHORTEST_TIME`.
var time_to_target: float


func _init(within: float = 1.0) -> void:
	time_to_target = maxf(within, Steering.SHORTEST_TIME)


## Towards the neighbours' average heading, at top speed; none without one.
func force(vehicle: SteeringVehicle) -> Vector2:
	var headings := Vector2.ZERO
	for other: SteeringVehicle in neighbours:
		if other != vehicle:
			headings += Steering.direction_to(Vector2.ZERO, other.velocity)
	var heading: Vector2 = Steering.direction_to(Vector2.ZERO, headings)
	if heading == Vector2.ZERO:
		return Vector2.ZERO
	return Steering.towards_velocity(vehicle, heading * vehicle.max_speed, time_to_target)
