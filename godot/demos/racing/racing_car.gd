## A car, crude on purpose: a position, a heading, a speed, and the limits of
## `RacingPhysics` that nothing driving it can lift.
##
## **Not a driving simulator.** No wheels, no tyre slip, no weight moving
## under braking: the lesson here is the driver, and tyre models are a
## different hobby (T54 is where they come in). What the car keeps is the one
## limit a racing driver lives by -- grip. Speed times turn rate is the
## sideways acceleration, and the car will not turn tighter than its grip
## holds: asked to, it turns as tight as it can and runs wide, which is
## understeer. A step is explicit Euler and constant time.
##
## When not to use it: a car that should slide, spin or be pushed by another.
## Then it needs real physics, and the driver above it stays the same.
class_name RacingCar
extends RefCounted

var physics: RacingPhysics
var position: Vector2
## The way the car points, in radians; 0 is along +x.
var heading: float
## Metres a second, never below zero and never above the top speed.
var speed: float = 0.0
## The turn rate the car actually took on its last step, radians a second,
## and the sideways acceleration that asked of its tyres: speed times turn,
## at the speed it was going then. A collision afterwards changes the speed,
## not what the tyres held.
var turn: float = 0.0
var sideways: float = 0.0


func _init(car_physics: RacingPhysics, at: Vector2, facing: float) -> void:
	physics = car_physics
	position = at
	heading = facing


## Move `dt` seconds. The driver asks for a speed and a turn rate; the car
## gives what its limits allow: speed changes by at most the engine or the
## brakes, and the turn is held to the grip at the new speed.
func step(wanted_speed: float, wanted_turn: float, on_track: bool, dt: float) -> void:
	var ceiling: float = physics.top_speed if on_track else physics.off_track_speed
	var goal: float = clampf(wanted_speed, 0.0, ceiling)
	if goal > speed:
		speed = minf(goal, speed + physics.acceleration * dt)
	else:
		speed = maxf(goal, speed - physics.braking * dt)
	var most: float = turn_limit()
	turn = clampf(wanted_turn, -most, most)
	sideways = speed * absf(turn)
	heading += turn * dt
	position += velocity() * dt


## The tightest the car can turn now, in radians a second: its turn rate, or
## less once speed times turn would ask more than the grip holds.
func turn_limit() -> float:
	if speed <= 0.0:
		return physics.turn_rate
	return minf(physics.turn_rate, physics.grip / speed)


## Where the car is going, in metres a second.
func velocity() -> Vector2:
	return Vector2.from_angle(heading) * speed


## The sideways acceleration it took on its last step: what the grip caps.
func sideways_acceleration() -> float:
	return sideways
