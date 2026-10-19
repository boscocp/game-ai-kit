## Arrive: seek, but slow down inside a braking radius and stop.
##
## Outside `braking_radius` this is seek. Inside it the desired speed falls
## in proportion to the distance left -- half way in, half speed -- so the
## vehicle asks to be stopped exactly as it reaches the target. Those few
## lines are the whole difference between an AI that looks competent and one
## that looks drunk. Constant time.
##
## The velocity is asked to change within `time_to_target` seconds rather
## than at once (Millington's form). Without it the slow-down is a spring
## too soft for its mass and the vehicle rocks past the target before it
## settles; with it, the approach is damped and it comes to rest.
##
## When not to use it: a target that moves fast. Arrive aims at where it is,
## not where it will be -- pursue first, and arrive only at the last metre.
class_name ArriveBehaviour
extends SteeringBehaviour

var target: Vector2
## Where slowing starts, in units from the target.
var braking_radius: float
## Seconds the vehicle is given to reach the velocity it wants.
var time_to_target: float


func _init(where: Vector2, slowing_from: float, within: float = 0.1) -> void:
	target = where
	braking_radius = slowing_from
	time_to_target = within


## Towards the target at a speed that falls to zero as the distance does.
func force(vehicle: SteeringVehicle) -> Vector2:
	var distance: float = vehicle.position.distance_to(target)
	var speed: float = vehicle.max_speed
	if distance < braking_radius:
		speed *= distance / braking_radius
	var desired: Vector2 = Steering.direction_to(vehicle.position, target) * speed
	return Steering.clamped((desired - vehicle.velocity) / time_to_target, vehicle.max_force)
