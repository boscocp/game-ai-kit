## What a guard sees of a body, as a certainty from 0 to 1 rather than a yes.
##
## A cone has one edge, and the game is played on it: seen at 10 m, unseen at
## 10.001 m [Rabin 2015], a player beside the guard unseen and one far off
## noticed [McIntosh 2015]. So the shape is a few **zones**, each a band of
## distance with an opening of its own -- wide near the eye, narrow far off,
## which together widen and then narrow as Blacklist's and Mirage's coffins
## do [Walsh 2015; Reparaz 2024] -- and each zone a certainty: from "I see
## something" to "that is the player" [Rabin 2015]. Where zones overlap, the
## most certain one counts, as the most inclusive shape sets Blacklist's
## timer [Walsh 2015]. Light and hiding take from it and movement adds to it
## [Rabin 2015].
##
## The body is a few points -- head, chest, feet, say -- and the caller says
## which have a clear line from the eye; how many must be clear is the
## stance's rule [Walsh 2015], given here as a number. What it returns,
## `VisionPercept`, keeps the points and the reason the certainty is what it
## is, which is what an overlay draws.
##
## Nothing here knows a level: distance and angle in, numbers from a data row.
## Constant time per zone and point.
##
## When not to use it: a target that is never half-seen -- a pickup, a door.
## A plain `VisionCone` answers yes or no, which is all those need.
class_name VisionShape
extends RefCounted

## Each zone: `name`, `near` and `far` (metres, near inclusive, far
## exclusive), `half_angle` (degrees either side of the facing) and
## `certainty` (0 to 1), in the order the data gives them.
var zones: Array[Dictionary] = []
## How much of a zone's certainty is left in total darkness: 1 and light
## does not matter, 0 and the dark hides a body completely.
var dark_share: float = 1.0
## What a moving body adds to the certainty.
var motion_bonus: float = 0.0


func _init(shape_zones: Array[Dictionary], shape_dark_share: float, shape_motion_bonus: float) -> void:
	zones = shape_zones
	dark_share = clampf(shape_dark_share, 0.0, 1.0)
	motion_bonus = maxf(shape_motion_bonus, 0.0)


## The shape a data row describes: `{"zones": [...], "dark_share": d,
## "motion_bonus": m}`. A guard type is a JSON row, so the shape is one too.
static func from_row(row: Dictionary) -> VisionShape:
	var typed: Array[Dictionary] = []
	for zone: Dictionary in row["zones"]:
		typed.append(zone)
	# `new()`, not its own class name: naming it would make the script hold itself (T162, docs/godot/exit-leaks.md).
	return new(typed, float(row["dark_share"]), float(row["motion_bonus"]))


## The index of the most certain zone that holds a body `distance` metres
## away at `angle_degrees` off the facing, or -1 when none does. The earlier
## zone wins a tie, so the answer never depends on anything but the data.
func zone_at(distance: float, angle_degrees: float) -> int:
	var best: int = -1
	for index: int in range(zones.size()):
		if not _holds(zones[index], distance, absf(angle_degrees)):
			continue
		if best == -1 or float(zones[index]["certainty"]) > float(zones[best]["certainty"]):
			best = index
	return best


## What the eye makes of a body: `distance` and `angle_degrees` from the eye
## and its facing, `points_clear` one entry per body point (true when the
## line to it is clear), `needed` the stance's count of clear points, `light`
## at the body's feet (0 dark, 1 lit), whether it is `moving`, and `hidden`,
## the share a hiding spot covers (0 none, 1 all).
func percept(distance: float, angle_degrees: float, points_clear: Array[bool], needed: int,
		light: float, moving: bool, hidden: float) -> VisionPercept:
	var seen := VisionPercept.new()
	seen.points = points_clear.duplicate()
	seen.zone = zone_at(distance, angle_degrees)
	var clear: int = points_clear.count(true)
	if seen.zone == -1:
		seen.why = "outside every zone"
		return seen
	if clear < needed:
		seen.why = "%d of %d points clear; the stance needs %d" % [clear, points_clear.size(), needed]
		return seen
	seen.certainty = certainty_in(seen.zone, light, moving, hidden)
	seen.why = "in %s" % zones[seen.zone]["name"]
	return seen


## The certainty zone `index` gives a body that enough points of are seen:
## the zone's own, kept down to `dark_share` of it in darkness, plus
## `motion_bonus` when moving, all times what a hiding spot leaves.
func certainty_in(index: int, light: float, moving: bool, hidden: float) -> float:
	var lit: float = lerpf(dark_share, 1.0, clampf(light, 0.0, 1.0))
	var shown: float = float(zones[index]["certainty"]) * lit + (motion_bonus if moving else 0.0)
	return clampf(shown * (1.0 - clampf(hidden, 0.0, 1.0)), 0.0, 1.0)


# Inside the zone's band of distance and its opening; an angle exactly on
# the edge is inside, as `VisionCone`'s is.
static func _holds(zone: Dictionary, distance: float, angle_degrees: float) -> bool:
	var in_band: bool = distance >= float(zone["near"]) and distance < float(zone["far"])
	return in_band and angle_degrees <= float(zone["half_angle"])
