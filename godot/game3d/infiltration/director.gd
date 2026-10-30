## The infiltration level's director (T90): the player's intensity and the
## four phases of Booth's adaptive pacing, one step at a time.
##
## Left 4 Dead's director, as Booth's slides state it [Booth 2009]: estimate
## the player's "emotional intensity", raise it by what happens to them, let
## it decay "towards zero over time" -- not while they are engaged -- and
## read four phases from it: build up (full threats until the peak), sustain
## the peak (a few seconds more), fade (minimal threats until it falls out of
## the peak's range), relax (a while, or until the player has moved on).
## The events are dictionaries with a `kind`, as `DirectorEvents` makes them
## and the vectors write them. Every number is `director.json`'s, a copy of
## spec/director/director.json; `gameaikit.director.pacing` is the same
## machine, and spec/vectors/director holds the two to one answer. It fits
## nothing (invariant 6): it computes a number from what happened.
##
## A step is constant: the step's events, one subtraction, one comparison.
##
## When not to use it: as a difficulty setting. It paces a run; it does not
## make a guard better or worse at what it does.
class_name Director
extends RefCounted

const FILE: String = "res://game3d/infiltration/director.json"
const PHASES: Array[String] = ["build_up", "sustain_peak", "peak_fade", "relax"]  # not shown: identifiers, worded by InfiltrationWords

var spec: Dictionary = {}
var intensity: float = 0.0
var phase: String = PHASES[0]
var steps_in_phase: int = 0
var chased: bool = false
var exit_metres: float = INF
var relax_from: float = INF


func _init(numbers: Dictionary = {}) -> void:
	spec = numbers if not numbers.is_empty() else read_file()


## The director's numbers, from `director.json`.
static func read_file() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FILE))


## `seconds` as whole steps, so Godot and Python count a phase alike.
func steps_of(seconds: float) -> int:
	return roundi(seconds / float(spec["step_seconds"]))


## Apply one step's `events`, decay, and move the phase on. Returns the
## phase entered this step, or "" when it stayed: the change is what the
## game acts on and what the vectors record.
func step(events: Array) -> String:
	for event: Dictionary in events:
		intensity += raised_by(event)
	if not chased:
		intensity -= float(spec["decay_per_second"]) * float(spec["step_seconds"])
	intensity = clampf(intensity, 0.0, float(spec["most"]))
	steps_in_phase += 1
	var following: String = _next_phase()
	if following == phase:
		return ""
	phase = following
	steps_in_phase = 0
	if following == PHASES[3]:
		relax_from = exit_metres
	return following


## How much `event` adds to the intensity. A `chase` or an `exit` adds
## nothing and is remembered instead: the one stops the decay, the other
## is how far the relax has let the player move on.
func raised_by(event: Dictionary) -> float:
	var raises: Dictionary = spec["raise"]
	match str(event["kind"]):
		"chase":
			chased = bool(event["on"])
		"exit":
			exit_metres = float(event["metres"])
		"seen", "heard":
			return float(raises[event["kind"]])
		"hurt":
			return float(raises["hurt_per_point"]) * float(event["points"])
		"search_near":
			return float(raises["search_near"]) * float(spec["step_seconds"]) * nearness(float(event["distance"]))
	return 0.0


## Booth's "inversely proportional to distance": 1 within `full_within`,
## falling as 1/distance after it, 0 beyond `radius`.
func nearness(distance: float) -> float:
	var search: Dictionary = spec["search"]
	if distance > float(search["radius"]):
		return 0.0
	var full: float = float(search["full_within"])
	return minf(1.0, full / maxf(distance, full))


## True in the phases that want every reserve guard out: build up and the
## sustained peak. In the fade and the relax the director wants none.
func wants_threats() -> bool:
	return phase == PHASES[0] or phase == PHASES[1]


func _next_phase() -> String:
	if phase == PHASES[0] and intensity >= float(spec["peak"]):
		return PHASES[1]
	if phase == PHASES[1] and steps_in_phase >= steps_of(float(spec["sustain_seconds"])):
		return PHASES[2]
	if phase == PHASES[2] and intensity < float(spec["fade_below"]):
		return PHASES[3]
	if phase == PHASES[3] and _relaxed():
		return PHASES[0]
	return phase


func _relaxed() -> bool:
	var long_enough: bool = steps_in_phase >= steps_of(float(spec["relax_seconds"]))
	return long_enough or relax_from - exit_metres >= float(spec["relax_travel"])
