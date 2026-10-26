## Pursue: seek where the quarry will be, not where it is.
##
## A vehicle that seeks a moving target trails behind it, always aiming at a
## place the target has left. Pursue guesses ahead: the quarry's position plus
## its velocity times how long the chase would take at top speed -- the
## distance over `max_speed` -- and never further ahead than
## `max_prediction` seconds, because a guess about the far future is a guess
## about a target that will have turned. Then it seeks that point. Constant
## time.
##
## When not to use it: a quarry that changes direction more often than the
## prediction looks ahead. Then the guess is wrong every time, and plain
## seek, which is never wrong about where the target is now, does better.
class_name PursueBehaviour
extends SteeringBehaviour

var quarry_position: Vector2
var quarry_velocity: Vector2
## The furthest ahead it guesses, in seconds.
var max_prediction: float
## The time constant, in seconds, of the change to the velocity it wants:
## seek's knob, handed on to the seek it runs; never under
## `Steering.SHORTEST_TIME`.
var time_to_target: float


func _init(at: Vector2, moving: Vector2, look_ahead: float = 1.0, within: float = 1.0) -> void:
	quarry_position = at
	quarry_velocity = moving
	max_prediction = look_ahead
	time_to_target = maxf(within, Steering.SHORTEST_TIME)


## Where the quarry will be when the chase arrives: what seek is aimed at.
func predicted(vehicle: SteeringVehicle) -> Vector2:
	var seconds: float = max_prediction
	if vehicle.max_speed > 0.0:
		seconds = minf(vehicle.position.distance_to(quarry_position) / vehicle.max_speed, max_prediction)
	return quarry_position + quarry_velocity * seconds


## Seek, aimed at the prediction.
func force(vehicle: SteeringVehicle) -> Vector2:
	return SeekBehaviour.new(predicted(vehicle), time_to_target).force(vehicle)
