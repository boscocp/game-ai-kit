## The stealth properties about what a guard senses: awareness follows
## exposure, sound goes round walls, and the off-screen halving only lowers.
##
## Each claim takes the technique as a Callable, so `awareness_properties.gd`
## can hand it the real one, which must pass, and a planted one, which must
## not (invariant 4). Each returns its findings, one line each.
##
## When not to use it: as a guard's senses. These only test them.
class_name SensesClaims
extends RefCounted

## How long a body is watched before its awareness is read: short enough
## that the fast cases have not all reached the peak.
const WATCHED_SECONDS: float = 1.0
const STEP_SECONDS: float = 0.1
const TOLERANCE: float = 1e-9


## The sight awareness a guard of `type` reaches after WATCHED_SECONDS of a
## body `distance` metres straight ahead, in `light`, `moving` or not, with
## `clear` of its three points showing, in `stance`, `angle` degrees off the
## facing. `light_seen` turns the light at its feet into what the guard is
## told -- the honest one passes it through.
static func reached(type: GuardType, distance: float, light: float, moving: bool, clear: int,
		light_seen: Callable, stance: String = "standing", angle: float = 0.0) -> float:
	var told: float = float(light_seen.call(light))
	var points: Array[bool] = [clear > 0, clear > 1, clear > 2]
	var mind := GuardMind.new(type)
	for step: int in range(roundi(WATCHED_SECONDS / STEP_SECONDS)):
		var percept := GuardPercept.new()
		percept.sight = type.vision.percept(distance, angle, points, type.needed_for(stance), told, moving, 0.0)
		percept.distance = distance
		percept.light = told
		percept.motion = 1.0 if moving else 0.0
		mind.step(percept, step * STEP_SECONDS, STEP_SECONDS)
	return mind.awareness["sight"].value


## Awareness follows exposure: nearer along the facing, into light, or
## starting to move never lowers what is reached; outside every zone -- too
## far, or inside the distance but off to the side -- or with fewer points
## showing than the stance needs, nothing is.
static func follows_exposure(type: GuardType, light_seen: Callable) -> Array[String]:
	var reach: float = _furthest(type)
	var found: Array[String] = []
	for tenth: int in range(1, 11):
		var nearer: String = _nearer_never_lowers(type, reach, tenth / 10.0, light_seen)
		if nearer != "":
			return [nearer]
	found.append_array(_more_light_and_movement(type, reach, light_seen))
	found.append_array(_unseen_rises_nothing(type, reach, light_seen))
	return found


# Too far; inside the middle zone's distance but behind its opening; no
# point showing standing; one point showing crouched, which needs more.
static func _unseen_rises_nothing(type: GuardType, reach: float, light_seen: Callable) -> Array[String]:
	var middle: Dictionary = type.vision.zones[1]
	var inside: float = (float(middle["near"]) + float(middle["far"])) / 2.0
	var cases: Dictionary = {
		"beyond every zone": reached(type, reach + 1.0, 1.0, true, 3, light_seen),
		"off the side of the middle zone": reached(type, inside, 1.0, true, 3, light_seen, "standing", 179.0),
		"no point showing": reached(type, 1.0, 1.0, true, 0, light_seen),
		"one point showing, crouched": reached(type, inside, 1.0, true, 1, light_seen, "crouched"),
	}
	var found: Array[String] = []
	for case: String in cases:
		if float(cases[case]) > 0.0:
			found.append("awareness rose with the body %s" % case)
	return found


# Walking in along the facing, a quarter metre at a time, in `light`.
static func _nearer_never_lowers(type: GuardType, reach: float, light: float, light_seen: Callable) -> String:
	for step: int in range(roundi(reach * 4.0)):
		var far: float = reach - step / 4.0
		if reached(type, far - 0.25, light, false, 3, light_seen) < reached(type, far, light, false, 3, light_seen) - TOLERANCE:
			return "nearer than %.2f m lowered the awareness, in light %.1f" % [far, light]
	return ""


# Turning the light up a tenth at a time, at `distance`.
static func _more_light_never_lowers(type: GuardType, distance: float, light_seen: Callable) -> String:
	for tenth: int in range(10):
		var darker: float = reached(type, distance, tenth / 10.0, false, 3, light_seen)
		if reached(type, distance, (tenth + 1) / 10.0, false, 3, light_seen) < darker - TOLERANCE:
			return "more light at %.1f m lowered the awareness, from light %.1f" % [distance, tenth / 10.0]
	return ""


static func _more_light_and_movement(type: GuardType, reach: float, light_seen: Callable) -> Array[String]:
	for step: int in range(roundi(reach)):
		var distance: float = step + 0.5
		var lighter: String = _more_light_never_lowers(type, distance, light_seen)
		if lighter != "":
			return [lighter]
		if reached(type, distance, 0.5, true, 3, light_seen) < reached(type, distance, 0.5, false, 3, light_seen) - TOLERANCE:
			return ["starting to move at %.1f m lowered the awareness" % distance]
	return []


## The rate's rule base leaves no hole: over a grid of its four inputs it
## always answers a number, never NaN.
static func rate_has_no_hole(type: GuardType) -> Array[String]:
	for corner: int in range(625):
		var values: Dictionary = {"certainty": _fifth(corner, 1), "light": _fifth(corner, 5),
			"motion": _fifth(corner, 25), "distance": _fifth(corner, 125) * _furthest(type)}
		if is_nan(type.rate_controller.evaluate(values)["rate"]):
			return ["the rate's rules leave a hole at %s" % values]
	return []


# One of five even steps from 0 to 1, read off `corner` as a digit in base 5.
static func _fifth(corner: int, place: int) -> float:
	return (floori(float(corner) / place) % 5) / 4.0


static func _furthest(type: GuardType) -> float:
	var furthest: float = 0.0
	for zone: Dictionary in type.vision.zones:
		furthest = maxf(furthest, float(zone["far"]))
	return furthest
