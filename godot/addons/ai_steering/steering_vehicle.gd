## Something that steers: a point with a velocity, and two limits.
##
## Crude on purpose. No mass beyond 1, no wheels, no tyres, no drift -- a car
## here is a point that may change its velocity by at most `max_force` a
## second and never go faster than `max_speed`. That is Reynolds' vehicle
## (1999), and it is enough to show what every behaviour in this addon is
## for. It is not a driving simulator, and T23 says so where it races.
##
## One step is explicit Euler: the force changes the velocity, the velocity
## changes the position, both over `dt` seconds. Constant time a step.
##
## When not to use it: anything whose turning depends on its speed or its
## grip -- a real car model. Then the behaviours still say where to go, and
## the car model says how.
class_name SteeringVehicle
extends RefCounted

var position: Vector2
var velocity: Vector2
## The fastest it goes, in units a second.
var max_speed: float
## The most its velocity may change in a second: how hard it can turn and
## brake. A behaviour asking for more is clamped to this.
var max_force: float


func _init(at: Vector2, moving: Vector2, top_speed: float, strongest: float) -> void:
	position = at
	velocity = moving
	max_speed = top_speed
	max_force = strongest


## Move `dt` seconds under `force`, which is clamped to `max_force` first --
## the vehicle does what it can, not what it was asked.
func step(force: Vector2, dt: float) -> void:
	velocity = (velocity + Steering.clamped(force, max_force) * dt).limit_length(max_speed)
	position += velocity * dt


## Its speed: what `max_speed` caps and arrive brings to zero.
func speed() -> float:
	return velocity.length()
