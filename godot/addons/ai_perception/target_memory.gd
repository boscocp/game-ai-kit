## What one guard remembers of its target: where, when and from what it last
## perceived it -- and nothing it did not perceive.
##
## When a guard loses sight it knows "the last position and direction"
## [Welsh 2015]. The cheap trick of going on "knowing" for 2-3 s is left out
## on purpose, as is any weight towards the target's real position: both
## read what the guard never perceived, and feel unfair [Welsh 2015;
## Couvidou 2021]. So the only way in is `remember`, called by whatever
## turned a look or a heard report into a place. Constant time.
##
## When not to use it: several targets. Keep one per target; this does not
## tell them apart.
class_name TargetMemory
extends RefCounted

## False until something has been perceived.
var known: bool = false
var place: Vector2 = Vector2.ZERO
## When, in seconds, and from what: an event kind, or "sight".
var at: float = -INF
var source: String = ""


## Keep `perceived_place`, perceived at `now` from `perceived_from`.
func remember(perceived_place: Vector2, now: float, perceived_from: String) -> void:
	known = true
	place = perceived_place
	at = now
	source = perceived_from


## Seconds since it was last perceived at `now`; INF when never.
func age(now: float) -> float:
	return now - at if known else INF
