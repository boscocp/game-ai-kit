## One kind of guard, read from a row of `guard_types.json`: what it sees,
## how many body points each stance must show, how its awareness rises and
## falls, and how it hears.
##
## This is where the example wires the techniques together, as T14's
## stealth demo does: `ai_perception`'s shape, events and accumulator, and
## the rate the accumulator rises by from an `ai_fuzzy` rule base of
## certainty, light, motion and distance -- its sets and rules in the same
## row. No number in this file tunes a guard and none names a level; a new
## guard type is a new row.
##
## Light and motion are read twice, on purpose. The vision shape's
## certainty is how sure the eye is that something is there, and light and
## movement make it surer [Rabin 2015]; the rate's light and motion are how
## alarming that something is -- a lit, moving body is a threat sooner than
## a still one in the dark, even seen as clearly. Crysis keeps the two
## apart the same way: a stimulus's strength and the envelope it drives
## [Welsh 2013].
##
## When not to use it: a guard whose numbers change during play -- tired at
## night, wary after a body. Then the row is a starting point and a copy
## per guard is what changes.
class_name GuardType
extends RefCounted

const FILE: String = "res://game3d/infiltration/guard_types.json"

var name: String = ""
var vision: VisionShape
## Stance -> how many body points must be clear before the eye has anything.
var stances: Dictionary = {}
var body_points: Array[String] = []
## The accumulator's row (`Awareness`).
var awareness: Dictionary = {}
var hearing: Dictionary = {}
var rate_controller: FuzzyRuleBase


## Every guard type in `data` (the file's shape), by name. The events every
## guard notices are the file's `events`, a `StimulusTable`'s rows.
static func all_in(data: Dictionary) -> Dictionary[String, GuardType]:
	var types: Dictionary[String, GuardType] = {}
	for type_name: String in data["guards"]:
		types[type_name] = GuardType.from_row(type_name, data["guards"][type_name])
	return types


## The file's contents, or an empty dictionary when it cannot be read.
static func read_file(path: String = FILE) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## The guard type a row describes.
static func from_row(type_name: String, row: Dictionary) -> GuardType:
	var made := GuardType.new()
	made.name = type_name
	made.vision = VisionShape.from_row(row["vision"])
	made.stances = row["stances"]
	for point: String in row["body_points"]:
		made.body_points.append(point)
	made.awareness = row["awareness"]
	made.hearing = row["hearing"]
	made.rate_controller = FuzzyFromData.rule_base(row["rate"])
	return made


## How fast awareness rises, in shares of the peak a second, for a body seen
## at `certainty`, standing in `light`, `motion` 0 still to 1 moving, and
## `distance` metres off. The fuzzy controller's answer; 0 where its rules
## leave a hole, which `awareness_properties.gd` looks for.
func rate(certainty: float, light: float, motion: float, distance: float) -> float:
	var values: Dictionary = {"certainty": certainty, "light": light, "motion": motion, "distance": distance}
	var answer: float = rate_controller.evaluate(values)["rate"]
	return 0.0 if is_nan(answer) else answer


## How many body points must be clear for `stance`; every point when the
## stance is unknown, so a stance the data forgot hides the body rather than
## giving it away.
func needed_for(stance: String) -> int:
	return int(stances.get(stance, body_points.size()))
