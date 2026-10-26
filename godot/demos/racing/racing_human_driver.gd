## You, as a driver: what the held keys ask of the car, every step.
##
## The AI and you make the same two requests of the same car -- a speed and
## a turn rate -- and the car answers both with the same limits. Throttle
## asks for the top speed, the brake for none, and neither lets the car
## roll slower by `COAST` a second, as a car does with the foot off. Left
## and right ask for up to the full turn rate, the wheel going over in
## `STEER_SECONDS` rather than at once, so a tap is a small correction. You
## get no grip the AI does not: turn in too fast and the car holds you to a
## wider line, onto the grass.
##
## And one help the AI also has: where you must be braking. The track's
## speed limit at `ADVICE_MARGIN` of the grip, carried back from the next
## corner, as the AI's is -- the first point ahead slower than you are now.
## A human has no knobs, so this driver's level is a name only. Constant
## time a step, but for that point, which looks ahead as the AI's does.
##
## When not to use it: an analogue pad, whose half-pressed trigger asks for
## half -- then the keys' all-or-nothing becomes a fraction.
class_name RacingHumanDriver
extends RacingDriver

## Metres a second the car loses every second with no pedal pressed.
const COAST: float = 4.0
## Seconds the wheel takes from straight to full lock.
const STEER_SECONDS: float = 0.15
## The grip your braking advice assumes you dare: a little under all of it.
const ADVICE_MARGIN: float = 0.9

## What is held now, set by whoever reads the keyboard: -1 left, 1 right.
var throttle: bool = false
var brake: bool = false
var steer: float = 0.0
## Where the wheel is now, from -1 to 1: it follows `steer`, not at once.
var wheel: float = 0.0


func _init() -> void:
	super(RacingLevel.new("you", 0.0, ADVICE_MARGIN, 0.0), 0)  # shown through tr()


## The speed and turn the held keys ask for, and where you must be braking.
func decide(car: RacingCar, track: RacingTrack, index: int, _time: float) -> void:
	decided_at = index
	used = {}
	if brake:
		target_speed = 0.0
	elif throttle:
		target_speed = car.physics.top_speed
	else:
		target_speed = maxf(car.speed - COAST * RacingRace.DT, 0.0)
	wheel = move_toward(wheel, clampf(steer, -1.0, 1.0), RacingRace.DT / STEER_SECONDS)
	wanted_turn = wheel * car.physics.turn_rate
	aim = car.position + Vector2.from_angle(car.heading) * 10.0
	braking_point = _braking_point(car, track, index, ADVICE_MARGIN)
