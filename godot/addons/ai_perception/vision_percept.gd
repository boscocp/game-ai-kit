## What one look gave: how certain the eye is, through which zone, which
## body points it saw, and why the certainty is what it is.
##
## A record, not a decision. `VisionShape.percept` fills it and an overlay
## draws it -- the points seen and unseen are the readable part of a guard's
## sight [Walsh 2015], and `why` says in words what the number means.
##
## When not to use it: as the guard's memory. A look is one moment; what a
## guard keeps of it is `TargetMemory`.
class_name VisionPercept
extends RefCounted

## From 0, nothing, to 1, "that is the player" [Rabin 2015].
var certainty: float = 0.0
## The zone it was seen through, or -1.
var zone: int = -1
## One entry per body point, as the caller gave them: true when clear.
var points: Array[bool] = []
## Why: the zone it was in, or what stopped it.
var why: String = ""


## True when the eye has anything at all to go on.
func perceived() -> bool:
	return certainty > 0.0
