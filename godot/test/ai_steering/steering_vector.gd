# What a steering vector is, and the check of one against `ai_steering`.
#
# Kept apart from the runner, as `FuzzyVector` is, so the rules can be handed
# broken vectors by a test. A vector pins a trajectory: a vehicle's start,
# the behaviours it runs and their weights, and at each sampled step where it
# is, how it moves and the force it is about to be given. `derive.py`, beside
# the vectors, wrote the numbers, importing nothing from this repository.
#
# The tolerance is sized for single precision: a `Vector2` holds 32-bit
# floats (`docs/godot/vector2-is-single-precision.md`), and the file holds
# 64-bit answers.
class_name SteeringVector
extends RefCounted

## How far a number may stray, in the vector's own units. Shared with
## `python/tests/test_steering_vectors.py`.
const TOLERANCE: float = 1e-3
## Every key a behaviour of each kind may carry. A misspelt key is refused,
## or `"braking_raduis"` would quietly be no braking radius at all.
const BEHAVIOUR_KEYS: Dictionary = {
	"seek": ["kind", "weight", "target", "time_to_target"],
	"arrive": ["kind", "weight", "target", "braking_radius", "time_to_target"],
	"pursue": ["kind", "weight", "quarry", "max_prediction", "time_to_target"],
	"avoid": ["kind", "weight", "centres", "radii", "look_ahead"],
}


## Why `vector` is not a steering vector, or "" when it is one.
static func why_not_a_vector(vector: Dictionary) -> String:
	for key: String in ["name", "steps_per_second", "vehicle", "behaviours", "samples"]:
		if not vector.has(key):
			return "it has no %s" % key
	if (vector["samples"] as Array).is_empty():
		return "it samples no step"
	for spec: Dictionary in vector["behaviours"]:
		var wrong: String = _why_not_a_behaviour(spec)
		if wrong != "":
			return wrong
	return ""


# Why `spec` is not a behaviour this file format knows, or "".
static func _why_not_a_behaviour(spec: Dictionary) -> String:
	var kind: String = spec.get("kind", "")
	if not BEHAVIOUR_KEYS.has(kind):
		return "there is no behaviour called %s" % kind
	for key: String in spec:
		if not key in BEHAVIOUR_KEYS[kind]:
			return "a %s has no field %s" % [kind, key]
	return ""


## Every sample `vector` holds that `ai_steering` does not reach, as lines
## naming the file, the step and what differed.
static func check(file: String, vector: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var played: Dictionary = replay(vector)
	for sample: Dictionary in vector["samples"]:
		failures.append_array(_sample_failures(file, sample, played[int(sample["step"])]))
	return failures


# What of `sample` the replay's `found` [position, velocity, force] missed.
static func _sample_failures(file: String, sample: Dictionary, found: Array) -> Array[String]:
	var failures: Array[String] = []
	for index: int in range(3):
		var label: String = ["position", "velocity", "force"][index]
		var expected := Vector2(sample[label][0], sample[label][1])
		if not _close(found[index], expected):
			failures.append("%s step %d: %s is %s, the file says %s" % [file, sample["step"], label, found[index], expected])
	return failures


## Every sampled step's [position, velocity, force], as `ai_steering` plays it.
static func replay(vector: Dictionary) -> Dictionary:
	var start: Dictionary = vector["vehicle"]
	var car := SteeringVehicle.new(_vector(start["position"]), _vector(start["velocity"]),
		start["max_speed"], start["max_force"])
	var behaviours: Array[GakSteeringBehaviour] = []
	var weights := PackedFloat64Array()
	for spec: Dictionary in vector["behaviours"]:
		behaviours.append(_behaviour(spec))
		weights.append(spec.get("weight", 1.0))
	var dt: float = 1.0 / float(vector["steps_per_second"])
	var played: Dictionary = {}
	for step: int in range(_last_step(vector) + 1):
		var forces: Array[Vector2] = []
		for each: GakSteeringBehaviour in behaviours:
			forces.append(each.force(car))
		var force: Vector2 = Steering.combined(car, forces, weights)
		played[step] = [car.position, car.velocity, force]
		car.step(force, dt)
		_move_quarries(behaviours, dt)
	return played


static func _behaviour(spec: Dictionary) -> GakSteeringBehaviour:
	match spec["kind"]:
		"seek":
			return _seek(spec)
		"arrive":
			return _arrive(spec)
		"pursue":
			return _pursue(spec)
	var centres: Array[Vector2] = []
	for centre: Array in spec["centres"]:
		centres.append(_vector(centre))
	return AvoidBehaviour.new(centres, PackedFloat64Array(spec["radii"]), spec["look_ahead"])


# A field the file leaves out is left to the library's own default -- read
# from a behaviour built without it -- so the vectors pin the defaults too.
static func _seek(spec: Dictionary) -> SeekBehaviour:
	var target: Vector2 = _vector(spec["target"])
	var defaults := SeekBehaviour.new(target)
	return SeekBehaviour.new(target, spec.get("time_to_target", defaults.time_to_target))


static func _arrive(spec: Dictionary) -> ArriveBehaviour:
	if spec.has("time_to_target"):
		return ArriveBehaviour.new(_vector(spec["target"]), spec["braking_radius"], spec["time_to_target"])
	return ArriveBehaviour.new(_vector(spec["target"]), spec["braking_radius"])


static func _pursue(spec: Dictionary) -> PursueBehaviour:
	var quarry: Dictionary = spec["quarry"]
	var at: Vector2 = _vector(quarry["position"])
	var moving: Vector2 = _vector(quarry["velocity"])
	var defaults := PursueBehaviour.new(at, moving)
	var look_ahead: float = spec.get("max_prediction", defaults.max_prediction)
	return PursueBehaviour.new(at, moving, look_ahead, spec.get("time_to_target", defaults.time_to_target))


# A quarry moves on at its own velocity after every step, as the file's does.
static func _move_quarries(behaviours: Array[GakSteeringBehaviour], dt: float) -> void:
	for each: GakSteeringBehaviour in behaviours:
		if each is PursueBehaviour:
			var pursuit: PursueBehaviour = each
			pursuit.quarry_position += pursuit.quarry_velocity * dt


static func _last_step(vector: Dictionary) -> int:
	var last: int = 0
	for sample: Dictionary in vector["samples"]:
		last = maxi(last, int(sample["step"]))
	return last


static func _vector(pair: Array) -> Vector2:
	return Vector2(pair[0], pair[1])


static func _close(found: Vector2, expected: Vector2) -> bool:
	return absf(found.x - expected.x) <= TOLERANCE and absf(found.y - expected.y) <= TOLERANCE
