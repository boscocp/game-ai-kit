## A PID controller: how hard to push, from how far off you are.
##
## The output is three terms added up. The **proportional** term pushes in
## proportion to the error now. The **integral** pushes in proportion to the
## error summed over time, so an error that sits there -- a car whose tyres
## need some steering just to hold a bend -- builds a push until it is gone.
## The **derivative** pushes against the error's rate of change, which damps
## the overshoot. Melder & Tomlinson's racing chapter (Game AI Pro, 2013)
## steers on the distance from the line this way, and says what each term
## is for: a proportional term alone leaves the car short of the line, the
## integral removes that offset, the derivative stops it swinging past; and
## in practice "Kd and Ki are approximately half of Kp". Constant time.
##
## `proportional_only` drops the other two terms, which is the toggle that
## shows the offset. The integral is held to `integral_limit`, so a long
## error cannot wind it up past what the output could ever use.
##
## When not to use it: a system that changes faster than it is sampled, or
## one whose push and response are not roughly in proportion. Then the
## gains that work at one speed do not at another.
class_name PidController
extends RefCounted

var proportional: float
var integral: float
var derivative: float
## The most the integral term may contribute, either way.
var integral_limit: float
var proportional_only: bool = false

## The three terms of the last update, for drawing.
var proportional_term: float = 0.0
var integral_term: float = 0.0
var derivative_term: float = 0.0

var _summed: float = 0.0
var _last_error: float = 0.0
var _started: bool = false


func _init(kp: float, ki: float, kd: float, most_integral: float) -> void:
	proportional = kp
	integral = ki
	derivative = kd
	integral_limit = most_integral


## The push for `error`, `step` seconds after the last update. The first
## update has no rate of change to damp, so its derivative term is zero.
func update(error: float, step: float) -> float:
	proportional_term = proportional * error
	integral_term = 0.0
	derivative_term = 0.0
	if not proportional_only:
		_summed += error * step
		if integral != 0.0:
			_summed = clampf(_summed, -integral_limit / absf(integral), integral_limit / absf(integral))
		integral_term = integral * _summed
		var rate: float = (error - _last_error) / step if _started and step > 0.0 else 0.0
		derivative_term = derivative * rate
	_last_error = error
	_started = true
	return proportional_term + integral_term + derivative_term


## Forget the past: no summed error, no last error.
func reset() -> void:
	_summed = 0.0
	_last_error = 0.0
	_started = false
