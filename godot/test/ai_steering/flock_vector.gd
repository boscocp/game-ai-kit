# What a flock vector is, and the check of one against `ai_steering`.
#
# Kept apart from its runner, as `SteeringVector` is, so `flock_test.gd` can
# hand it broken vectors and watch it object. Two shapes, both written by
# `spec/vectors/steering/flock/derive.py`, which imports nothing from this
# repository:
#
#   * "forces": one boid, the neighbours it was handed, and the three rules'
#     forces and the flock's sum, written out;
#   * "steps": a small flock flying, every boid handed the whole flock --
#     itself included, which each rule must skip -- every force worked out
#     from one snapshot before any boid moves; at each sampled step, where
#     each boid is and how it moves. This pins alignment's self-skip; the
#     self-only flock in `flock_test.gd` pins separation's and cohesion's.
#
# The tolerance is `SteeringVector.TOLERANCE`, sized for 32-bit floats.
class_name FlockVector
extends RefCounted

## Every key each shape may carry. A misspelt one is refused, or
## "separation_raduis" would quietly be no radius at all.
const SHAPE_KEYS: Dictionary = {
	"forces": ["name", "shape", "why", "boid", "neighbours", "separation_radius", "time_to_target", "weights",
		"expected"],
	"steps": ["name", "shape", "why", "boids", "max_speed", "max_force", "separation_radius", "time_to_target",
		"weights", "steps_per_second", "samples"],
}
const RULES: Array[String] = ["separation", "alignment", "cohesion", "flock"]
## The types each shape reads, checked before anything reads them (T121):
## a cast that fails in a `-s` script is a SCRIPT ERROR the run survives.
const SHAPES: Dictionary = {
	"forces": {
		"boid": {"position": [VectorShape.NUMBER], "velocity": [VectorShape.NUMBER],
				"max_speed": VectorShape.NUMBER, "max_force": VectorShape.NUMBER},
		"neighbours": [{"position": [VectorShape.NUMBER], "velocity": [VectorShape.NUMBER]}],
		"separation_radius": VectorShape.NUMBER, "time_to_target?": VectorShape.NUMBER,
		"weights?": [VectorShape.NUMBER],
		"expected": {"separation": [VectorShape.NUMBER], "alignment": [VectorShape.NUMBER],
				"cohesion": [VectorShape.NUMBER], "flock": [VectorShape.NUMBER]},
	},
	"steps": {
		"boids": [{"position": [VectorShape.NUMBER], "velocity": [VectorShape.NUMBER]}],
		"max_speed": VectorShape.NUMBER, "max_force": VectorShape.NUMBER, "separation_radius": VectorShape.NUMBER,
		"time_to_target?": VectorShape.NUMBER, "weights?": [VectorShape.NUMBER],
		"steps_per_second": VectorShape.NUMBER,
		"samples": [{"step": VectorShape.NUMBER, "positions": [[VectorShape.NUMBER]],
				"velocities": [[VectorShape.NUMBER]]}],
	},
}


## Why `vector` is not a flock vector, or "" when it is one.
static func why_not_a_vector(vector: Dictionary) -> String:
	var shape: String = vector.get("shape", "")
	if not SHAPE_KEYS.has(shape):
		return "there is no shape called %s" % shape
	for key: String in vector:
		if not key in SHAPE_KEYS[shape]:
			return "a %s vector has no field %s" % [shape, key]
	for key: String in SHAPE_KEYS[shape]:
		if not key in ["why", "time_to_target", "weights"] and not vector.has(key):
			return "it has no %s" % key
	var types: String = VectorShape.why_not(vector, SHAPES[shape])
	if types != "":
		return types
	if shape == "steps" and (vector["samples"] as Array).is_empty():
		return "it samples no step"
	return ""


## Every number `vector` holds that `ai_steering` does not reach, as lines
## naming the file and what differed.
static func check(file: String, vector: Dictionary) -> Array[String]:
	if vector["shape"] == "forces":
		return _check_forces(file, vector)
	return _check_steps(file, vector)


## The flock a vector describes: its radius, and its time and weights or the
## library's own defaults, so the vectors pin the defaults too.
static func flock_of(vector: Dictionary) -> Flock:
	var defaults := Flock.new(vector["separation_radius"])
	return Flock.new(vector["separation_radius"], vector.get("time_to_target", defaults.alignment.time_to_target),
		PackedFloat64Array(vector.get("weights", defaults.weights)))


static func _check_forces(file: String, vector: Dictionary) -> Array[String]:
	var spec: Dictionary = vector["boid"]
	var boid := SteeringVehicle.new(_vector(spec["position"]), _vector(spec["velocity"]),
		spec["max_speed"], spec["max_force"])
	var neighbours: Array[SteeringVehicle] = []
	for other: Dictionary in vector["neighbours"]:
		neighbours.append(SteeringVehicle.new(_vector(other["position"]), _vector(other["velocity"]), 0.0, 0.0))
	var flock: Flock = flock_of(vector)
	flock.see(neighbours)
	var found: Array[Vector2] = flock.forces(boid)
	found.append(flock.force(boid))
	var failures: Array[String] = []
	for index: int in range(RULES.size()):
		var expected: Vector2 = _vector(vector["expected"][RULES[index]])
		if not _close(found[index], expected):
			failures.append("%s: %s is %s, the file says %s" % [file, RULES[index], found[index], expected])
	return failures


static func _check_steps(file: String, vector: Dictionary) -> Array[String]:
	var played: Dictionary = replay(vector)
	var failures: Array[String] = []
	for sample: Dictionary in vector["samples"]:
		var boids: Array[SteeringVehicle] = played[int(sample["step"])]
		for index: int in range(boids.size()):
			var where: String = "%s step %d boid %d" % [file, sample["step"], index]
			failures.append_array(_boid_failures(where, boids[index], sample, index))
	return failures


# What of boid `index` in `sample` the replayed `boid` missed.
static func _boid_failures(where: String, boid: SteeringVehicle, sample: Dictionary, index: int) -> Array[String]:
	var failures: Array[String] = []
	var expected_position: Vector2 = _vector(sample["positions"][index])
	var expected_velocity: Vector2 = _vector(sample["velocities"][index])
	if not _close(boid.position, expected_position):
		failures.append("%s: position is %s, the file says %s" % [where, boid.position, expected_position])
	if not _close(boid.velocity, expected_velocity):
		failures.append("%s: velocity is %s, the file says %s" % [where, boid.velocity, expected_velocity])
	return failures


## Every sampled step's boids, copied, as `ai_steering` flies them.
static func replay(vector: Dictionary) -> Dictionary:
	var boids: Array[SteeringVehicle] = []
	for spec: Dictionary in vector["boids"]:
		boids.append(SteeringVehicle.new(_vector(spec["position"]), _vector(spec["velocity"]),
			vector["max_speed"], vector["max_force"]))
	var flock: Flock = flock_of(vector)
	flock.see(boids)
	var dt: float = 1.0 / float(vector["steps_per_second"])
	var played: Dictionary = {}
	for step: int in range(_last_step(vector) + 1):
		played[step] = _copies(boids)
		var forces: Array[Vector2] = []
		for boid: SteeringVehicle in boids:
			forces.append(flock.force(boid))
		for index: int in range(boids.size()):
			boids[index].step(forces[index], dt)
	return played


# Each boid as it is now, so the next steps do not move the sample.
static func _copies(boids: Array[SteeringVehicle]) -> Array[SteeringVehicle]:
	var copied: Array[SteeringVehicle] = []
	for boid: SteeringVehicle in boids:
		copied.append(SteeringVehicle.new(boid.position, boid.velocity, boid.max_speed, boid.max_force))
	return copied


static func _last_step(vector: Dictionary) -> int:
	var last: int = 0
	for sample: Dictionary in vector["samples"]:
		last = maxi(last, int(sample["step"]))
	return last


static func _vector(pair: Array) -> Vector2:
	return Vector2(pair[0], pair[1])


static func _close(found: Vector2, expected: Vector2) -> bool:
	var tolerance: float = SteeringVector.TOLERANCE
	return absf(found.x - expected.x) <= tolerance and absf(found.y - expected.y) <= tolerance
