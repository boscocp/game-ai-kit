## Everything one guard perceived in one step, and nothing else: what its
## eye made of the target, and the loudest event it heard.
##
## AIMA's agent is a function from percepts to actions [Russell and Norvig,
## ch. 2]; T67's bot reads one record, and so does a guard. `GuardMind`
## reads this and nothing else, so a guard on another level, or in a test
## with no level at all, knows exactly what this says -- which is how the
## honesty claim in `awareness_properties.gd` can hold it.
##
## When not to use it: as the world. Where the target really is belongs to
## the level; a guard that reads it is cheating, and the properties plant
## exactly that to show they would catch it.
class_name GuardPercept
extends RefCounted

## The eye's look at the target; `VisionPercept.new()` when it had none.
var sight: VisionPercept = VisionPercept.new()
## Where the eye put the target, how far off, the light at its feet, and
## how fast it moved, from 0 still to 1 running. Read only when seen.
var seen_place: Vector2 = Vector2.ZERO
var distance: float = 0.0
var light: float = 0.0
var motion: float = 0.0
## The loudest event heard this step, from 0 to 1, where and what it was.
var loudness: float = 0.0
var heard_place: Vector2 = Vector2.ZERO
var heard_kind: String = ""
## On a crowded level (T152), when the eye picked the player out of a
## group: whether it blends in or stands out, and why; "" otherwise.
var figure: String = ""
var crowd_reason: String = ""
