## You, as a driver: what the held keys ask of the car, every step.
##
## The AI and you make the same two requests of the same car -- a speed and
## a turn rate -- and the car answers both with the same limits. Throttle
## asks for the top speed, the brake for none, neither for the speed you
## have; left and right ask for the full turn rate. You get no grip the AI
## does not: turn in too fast and the car holds you to a wider line, onto
## the grass. A human has no knobs, so this driver's level is a name only.
## Constant time a step.
##
## When not to use it: an analogue pad, whose half-pressed trigger asks for
## half -- then the keys' all-or-nothing becomes a fraction.
class_name RacingHumanDriver
extends RacingDriver

## What is held now, set by whoever reads the keyboard: -1 left, 1 right.
var throttle: bool = false
var brake: bool = false
var steer: float = 0.0


func _init() -> void:
	super(RacingLevel.new("you", 0.0, 1.0, 0.0), 0)


## The speed and turn the held keys ask for. Nothing is aimed at, so the
## point drawn is just ahead of the car, where it is pointing.
func decide(car: RacingCar, _track: RacingTrack, index: int, _time: float) -> void:
	decided_at = index
	used = {}
	if brake:
		target_speed = 0.0
	elif throttle:
		target_speed = car.physics.top_speed
	else:
		target_speed = car.speed
	wanted_turn = clampf(steer, -1.0, 1.0) * car.physics.turn_rate
	aim = car.position + Vector2.from_angle(car.heading) * 10.0
	braking_point = -1
