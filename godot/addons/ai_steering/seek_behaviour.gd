## Seek: full speed at a point.
##
## The desired velocity points at the target at the vehicle's top speed, and
## the force is what turns the current velocity into it. That is all, and it
## is the defect worth seeing: nothing in it ever asks for less than full
## speed, so a vehicle seeking a point that does not move drives through it,
## turns, drives through it again, and never stops.
## `test/steering_properties.gd` measures exactly that. Constant time.
##
## When not to use it: a target to stop at. That is `ArriveBehaviour`, which
## differs by the few lines that slow down.
class_name SeekBehaviour
extends SteeringBehaviour

var target: Vector2


func _init(where: Vector2) -> void:
	target = where


## Full speed towards the target, from wherever the vehicle is.
func force(vehicle: SteeringVehicle) -> Vector2:
	var desired: Vector2 = Steering.direction_to(vehicle.position, target) * vehicle.max_speed
	return Steering.towards_velocity(vehicle, desired)
