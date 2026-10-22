## What one guard makes of its percepts: how aware it is of what it saw and
## of what it heard, and what it remembers of where the target was.
##
## One `Awareness` per stimulus, as Crysis keeps an envelope per stimulus
## and target [Welsh 2013]: sight rises by the guard type's fuzzy rate,
## sound by the loudness times the type's `heard_rate`. The phase the guard
## is in is the higher of the two readings. Its `TargetMemory` is written
## from a look or from a sound and from nothing else. What the guard then
## does is T70's selector, which reads these numbers; nothing here decides.
## Constant time a step, but for the fuzzy controller.
##
## When not to use it: a guard that must tell two targets apart. Keep a
## mind per target, or key the awareness by target as well as stimulus.
class_name GuardMind
extends RefCounted

const STIMULI: Array[String] = ["sight", "sound"]

var type: GuardType
var awareness: Dictionary[String, Awareness] = {}
var memory := TargetMemory.new()


func _init(guard_type: GuardType) -> void:
	type = guard_type
	for stimulus: String in STIMULI:
		awareness[stimulus] = Awareness.new()


## One step of `seconds`, ending at `now`, from `percept` alone; both
## rates scaled by `rate_scale`, the difficulty's awareness knob.
func step(percept: GuardPercept, now: float, seconds: float, rate_scale: float = 1.0) -> void:
	var seeing: bool = percept.sight.perceived()
	var sight_rate: float = 0.0
	if seeing:
		sight_rate = type.rate(percept.sight.certainty, percept.light, percept.motion, percept.distance) * rate_scale
	awareness["sight"].step(type.awareness, seeing, sight_rate, seconds, now)
	var hearing: bool = percept.loudness > 0.0
	var sound_rate: float = percept.loudness * float(type.hearing["heard_rate"]) * rate_scale
	awareness["sound"].step(type.awareness, hearing, sound_rate, seconds, now)
	if seeing:
		memory.remember(percept.seen_place, now, "sight")
	elif hearing:
		memory.remember(percept.heard_place, now, percept.heard_kind)


## The phase the guard is in: the higher of its stimuli's readings.
func phase() -> int:
	var highest: int = 0
	for stimulus: String in STIMULI:
		highest = maxi(highest, Awareness.phase(awareness[stimulus].value, type.awareness))
	return highest


## The name of `phase()`, from the guard type's row.
func phase_name() -> String:
	return str(type.awareness["phases"][phase()]["name"])
