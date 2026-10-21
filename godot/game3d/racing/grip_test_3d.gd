## Before the race, a driver measures the car it was given.
##
## The speed profile needs two numbers: how hard the car can corner and how
## hard it can brake. T23 read them off its car. Here the tyres decide them
## -- slip, load moving forward under braking, grip shared between braking
## and turning -- and no number on the car's sheet is what the car will do.
## So each car, before the race, is driven on a test pad of the track's own
## tarmac through two runs, and the driver keeps what it saw:
##
##   * **braking**: from `BRAKE_FROM` to `BRAKE_TO` with the pedal down,
##     the speed lost over the time it took;
##   * **cornering**: at a steady `HOLD_SPEED`, the wheels turned slowly to
##     `FULL_LOCK`; the sideways acceleration -- speed times the yaw rate,
##     what the car's own motion says -- smoothed, and its peak. Past it the
##     front tyres slide and the car runs wide, so the peak is the grip; and
##     how far the wheels were turned at the peak beyond the arc's own
##     angle is the most steering worth asking for.
##
## A measurement, not training: nothing is fitted, the numbers are kept in
## memory for that race and never written down (invariant 6), and the same
## car measures the same numbers every time, as T50 measured the physics to
## replay. It takes about twenty seconds of the car's time. The kit's own
## choice, not a source's: Game AI Pro reads the grip from the physics
## (`docs/concepts/racing-ai.md`). Constant time a frame.
##
## When not to use it: a car whose grip changes during the race -- wear,
## rain, a heavier fuel load. One run at the start cannot see those.
class_name GripTest3D
extends RefCounted

const BRAKE_FROM: float = 25.0
const BRAKE_TO: float = 5.0
const HOLD_SPEED: float = 13.0
const FULL_LOCK: float = 0.4
## Seconds to settle at the steady speed, and to turn the wheels to lock.
const SETTLE_TIME: float = 1.5
const RAMP_TIME: float = 12.0
## Pedal per metre a second off the steady speed.
const PEDAL_GAIN: float = 0.5
## The share of each new reading the smoothed acceleration takes: about a
## third of a second's memory at 60 frames a second.
const SMOOTHING: float = 0.05

enum Phase { LAUNCH, BRAKE, SETTLE, RAMP, DONE }

var phase: Phase = Phase.LAUNCH
## What was measured, in metres a second squared; zero until it is.
var braking: float = 0.0
var grip: float = 0.0
## How much more the wheels were turned at the peak than the arc needed,
## in radians: what the tyres' slip asked for. Past it, turning further
## only slides the front.
var slip_steer: float = 0.0
## The smoothed sideways acceleration now, for the overlay.
var cornering: float = 0.0
var _clock: float = 0.0
var _brake_started: float = 0.0
var _brake_speed: float = 0.0


## True once both numbers are measured.
func done() -> bool:
	return phase == Phase.DONE


## One physics frame of the test: read the car, then set its controls.
func step(car: RaceCar3D, frame: float) -> void:
	_clock += frame
	var speed: float = car.forward_speed()
	match phase:
		Phase.LAUNCH:
			_launch(car, speed)
		Phase.BRAKE:
			_stop(car, speed)
		Phase.SETTLE, Phase.RAMP:
			_corner(car, speed)
		Phase.DONE:
			_drive(car, 0.0, 0.0, 1.0)


# Full throttle in a straight line, until fast enough to brake from.
func _launch(car: RaceCar3D, speed: float) -> void:
	_drive(car, 0.0, 1.0, 0.0)
	if speed >= BRAKE_FROM:
		phase = Phase.BRAKE
		_brake_started = _clock
		_brake_speed = speed


# The brakes on, until slow: the speed lost over the time it took.
func _stop(car: RaceCar3D, speed: float) -> void:
	_drive(car, 0.0, 0.0, 1.0)
	if speed <= BRAKE_TO:
		braking = (_brake_speed - speed) / (_clock - _brake_started)
		phase = Phase.SETTLE
		_clock = 0.0


# Hold the steady speed and turn the wheels slowly, watching how hard the
# car corners; done when the wheels reach full lock.
func _corner(car: RaceCar3D, speed: float) -> void:
	var pedal: float = PEDAL_GAIN * (HOLD_SPEED - speed)
	var turned: float = 0.0
	if phase == Phase.RAMP:
		turned = FULL_LOCK * minf(1.0, _clock / RAMP_TIME)
		cornering += (speed * car.angular_velocity.y - cornering) * SMOOTHING
		if cornering > grip:
			grip = cornering
			slip_steer = car.steer - atan(car.physics.wheelbase * grip / (speed * speed))
		if _clock >= RAMP_TIME:
			phase = Phase.DONE
	elif _clock >= SETTLE_TIME:
		phase = Phase.RAMP
		_clock = 0.0
	_drive(car, turned, clampf(pedal, 0.0, 1.0), clampf(-pedal, 0.0, 1.0))


func _drive(car: RaceCar3D, steering: float, pedal: float, stopping: float) -> void:
	car.steer_wanted = steering
	car.throttle = pedal
	car.brake = stopping
