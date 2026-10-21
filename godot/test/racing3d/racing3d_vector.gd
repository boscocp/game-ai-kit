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


## Every field a frame's view must carry, and the ones that are lists of
## points, all as long as each other.
const VIEW_FIELDS: Array[String] = [
	"time", "step", "speed", "cross_track", "line_forward", "line_left", "room_left", "room_right", "rivals",
]
const POINT_FIELDS: Array[String] = ["line_forward", "line_left", "room_left", "room_right"]
## The fewest points a view may show: the bend at a point is measured over
## RaceDriver3D.BEND_REACH points either side.
const FEWEST_POINTS: int = 2 * RaceDriver3D.BEND_REACH + 1


## Why `vector` is not a racing vector, or "" when it is one.
static func why_not_a_vector(vector: Dictionary) -> String:
	for key: String in ["name", "why", "driver", "frames"]:
		if not vector.has(key):
			return "it has no %s" % key
	if not (vector["frames"] is Array) or (vector["frames"] as Array).is_empty():
		return "it shows the driver nothing"
	for frame: Variant in vector["frames"]:
		var wrong: String = why_not_a_frame(frame)
		if wrong != "":
			return wrong
	return ""


## Why `frame` is not a frame of a vector -- a view missing a field, lists of
## points of different lengths or too short, an expect missing a decision --
## or "" when it is one. Checked before anything is decided, so a missing
## key is a refusal and not a SCRIPT ERROR the run walks past.
static func why_not_a_frame(frame: Variant) -> String:
	if not (frame is Dictionary) or not frame.has("view") or not frame.has("expect"):
		return "a frame has no view or no expect"
	for key: String in VIEW_FIELDS:
		if not frame["view"].has(key):
			return "a view has no %s" % key
	for key: String in DECIDED:
		if not frame["expect"].has(key):
			return "an expect has no %s" % key
	var points: int = (frame["view"]["line_forward"] as Array).size()
	for key: String in POINT_FIELDS:
		if (frame["view"][key] as Array).size() != points:
			return "a view's %s is not as long as its line_forward" % key
	if points < FEWEST_POINTS:
		return "a view shows %d points, under %d" % [points, FEWEST_POINTS]
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
		# Written so that a NaN on either side is a miss: NaN <= x is false.
		if not (absf(float(decided[key]) - float(expected[key])) <= TOLERANCE):
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
