## One conformance vector of `spec/vectors/racing3d/`, decided by
## `RaceDriver3D`.
##
## A vector is a driver and the snapshots it is shown in turn, each with the
## decision it must make. This builds the driver from the file, shows it
## every snapshot, and compares each number with the file. The rules for what
## a vector is live here, so `racing3d_vector_test.gd` can hand it broken
## vectors and watch it object.
class_name Racing3DVector
extends RefCounted

## Shared with `python/tests/test_racing3d_vectors.py`. Both sides compute
## in 64-bit floats.
const TOLERANCE: float = 1e-9
const DECIDED: Array[String] = [
	"steer", "throttle", "brake", "target_speed", "braking_in", "aim_forward", "aim_left", "wanted_left",
]


## Why `vector` is not a racing vector, or "" when it is one.
static func why_not_a_vector(vector: Dictionary) -> String:
	for key: String in ["name", "why", "driver", "frames"]:
		if not vector.has(key):
			return "it has no %s" % key
	if not (vector["frames"] is Array) or (vector["frames"] as Array).is_empty():
		return "it shows the driver nothing"
	for frame: Variant in vector["frames"]:
		if not (frame is Dictionary) or not frame.has("view") or not frame.has("expect"):
			return "a frame has no view or no expect"
	return ""


## Every way this side's decisions differ from the file's, one line each.
static func check(label: String, vector: Dictionary) -> Array[String]:
	var found: Array[String] = []
	var decided: Array[Dictionary] = decisions(vector)
	for index: int in range(decided.size()):
		found.append_array(_misses("%s frame %d" % [label, index], decided[index], vector["frames"][index]["expect"]))
	return found


static func _misses(label: String, decided: Dictionary, expected: Dictionary) -> Array[String]:
	var found: Array[String] = []
	for key: String in DECIDED:
		if absf(float(decided[key]) - float(expected[key])) > TOLERANCE:
			found.append("%s %s: %.12f, the file says %.12f" % [label, key, decided[key], expected[key]])
	return found


## What `RaceDriver3D` decides on each of the vector's frames, in turn.
static func decisions(vector: Dictionary) -> Array[Dictionary]:
	var spec: Dictionary = vector["driver"]
	var knobs: Dictionary = spec["level"]
	var level := RaceLevel3D.new(str(knobs["title"]), float(knobs["lookahead"]),
		float(knobs["grip_margin"]), float(knobs["wander"]))
	var driver := RaceDriver3D.new(level, spec["known"])
	driver.drift_phases = PackedFloat64Array(spec["drift_phases"])
	var switches: Dictionary = spec.get("switches", {})
	driver.full_pid = bool(switches.get("full_pid", true))
	driver.traffic.heat_vision = bool(switches.get("heat_vision", true))
	var decided: Array[Dictionary] = []
	for frame: Dictionary in vector["frames"]:
		driver.decide(RaceView3D.from_dictionary(frame["view"]))
		var answer: Dictionary = {}
		for key: String in DECIDED:
			answer[key] = driver.get(key)
		decided.append(answer)
	return decided
