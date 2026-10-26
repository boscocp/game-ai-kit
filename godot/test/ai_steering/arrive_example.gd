# The minimal example on docs/techniques/ai_steering.md, run by
# arrive_example_test.gd. A node of your own that drives itself to a point
# and stops there.
extends Node2D

## Where it is going. Set it from anything: a click, a waypoint, a path.
var target: Vector2 = Vector2(300, 200)

## The point the forces move: top speed 120 a second, and it may change its
## velocity by at most 240 a second.
var vehicle := SteeringVehicle.new(Vector2.ZERO, Vector2.ZERO, 120.0, 240.0)


func _physics_process(delta: float) -> void:
	# Brake from 100 units out. Seek here instead, and it overshoots forever.
	var arrive := ArriveBehaviour.new(target, 100.0)
	vehicle.step(arrive.force(vehicle), delta)
	position = vehicle.position
