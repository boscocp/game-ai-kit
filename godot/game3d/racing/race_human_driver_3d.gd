## You, as a driver: the held keys, turned into what the AI asks of the
## same car -- a wheel angle and two pedals.
##
## The car answers both with the same physics: turn in too fast and the
## front tyres slide, brake too late and you run wide. The wheel goes over
## in `STEER_SECONDS`, not at once, and full lock is held to what the AI's
## measured slip makes worth turning at your speed, so a held key does not
## simply spin the car. The help the AI also has: where you must already be
## braking, from the same speed profile at `ADVICE_MARGIN` of the grip.
## A human has no knobs, so this driver's level is a name only, and its
## `used` stays empty. Constant time a frame, but for that profile.
##
## When not to use it: an analogue pad, whose half-pressed trigger asks for
## half -- then the keys' all-or-nothing becomes a fraction.
class_name RaceHumanDriver3D
extends RaceDriver3D

const STEER_SECONDS: float = 0.25
const ADVICE_MARGIN: float = 0.9

## What is held now, set by whoever reads the keyboard: -1 right, 1 left.
var held_steer: float = 0.0
var held_throttle: bool = false
var held_brake: bool = false
var _wheel: float = 0.0


func _init(known: Dictionary) -> void:
	super(RaceLevel3D.new("you", 0.0, ADVICE_MARGIN, 0.0), known)


## The wheel and pedals the held keys ask for, and where you must be braking.
func decide(view: RaceView3D) -> void:
	used = {}
	limits = speed_limits(view, ADVICE_MARGIN)
	target_speed = limits[0]
	braking_in = -1.0
	for index: int in range(limits.size()):
		if limits[index] < view.speed and view.line_forward[index] >= 0.0:
			braking_in = view.line_forward[index]
			break
	_wheel = move_toward(_wheel, clampf(held_steer, -1.0, 1.0), view.step / STEER_SECONDS)
	steer = _wheel * steer_limit(view.speed)
	throttle = 1.0 if held_throttle else 0.0
	brake = 1.0 if held_brake else 0.0
	aim_forward = 10.0
	aim_left = 0.0
	line_error = -view.cross_track
