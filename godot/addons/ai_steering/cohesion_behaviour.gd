## Cohesion: steer towards the neighbours' centre.
##
## The third of Reynolds' three flocking rules. The neighbours' positions
## are averaged, and the vehicle seeks that point at top speed -- seek's own
## sum, so like seek it never slows for the centre and swings through it;
## separation is what keeps it from arriving on top of anyone. With no
## neighbour there is no centre, and it asks for nothing. O(neighbours).
##
## The caller hands it `neighbours`, as `SeparationBehaviour` explains.
##
## When not to use it: a group that must arrive somewhere in order, or hold a
## shape. Cohesion only pulls everyone together; nothing in it says where.
class_name CohesionBehaviour
extends GakSteeringBehaviour

## The vehicles this one can see, handed over by the caller before each ask.
## The vehicle itself, if listed, is skipped.
var neighbours: Array[SteeringVehicle] = []
## The time constant of the turn, as seek's. Never under
## `Steering.SHORTEST_TIME`.
var time_to_target: float


func _init(within: float = 1.0) -> void:
	time_to_target = maxf(within, Steering.SHORTEST_TIME)


## Full speed towards the neighbours' centre; none without a neighbour.
func force(vehicle: SteeringVehicle) -> Vector2:
	var total := Vector2.ZERO
	var counted: int = 0
	for other: SteeringVehicle in neighbours:
		if other != vehicle:
			total += other.position
			counted += 1
	if counted == 0:
		return Vector2.ZERO
	var desired: Vector2 = Steering.direction_to(vehicle.position, total / counted) * vehicle.max_speed
	return Steering.towards_velocity(vehicle, desired, time_to_target)
