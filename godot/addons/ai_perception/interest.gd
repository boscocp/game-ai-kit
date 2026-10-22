## The one thing a guard is attending to: which event, where, and since when.
##
## A guard holds one interest at a time, and a higher priority replaces it;
## events of the same priority replace each other too, so "the last thing
## you notice is probably the most important thing" [Miles 2013]. An
## interest past its row's lifetime is forgotten. The kinds and their
## priorities are a `StimulusTable`'s rows. Constant time.
##
## When not to use it: a guard that must weigh several things at once --
## the shot and the body. Keep a list and let the selector score each.
class_name Interest
extends RefCounted

## The event attended to, or "" when none.
var kind: String = ""
var place: Vector2 = Vector2.ZERO
## When it was noticed, in seconds.
var noticed_at: float = 0.0


## Attend to an event of `kind` at `place`, noticed at `now`, if it matters
## at least as much as what is held or what is held is stale. True when it
## was taken.
func offer(table: StimulusTable, offered_kind: String, offered_place: Vector2, now: float) -> bool:
	if not table.has(offered_kind):
		return false
	if held(table, now) and table.priority(offered_kind) < table.priority(kind):
		return false
	kind = offered_kind
	place = offered_place
	noticed_at = now
	return true


## True when something is held and still news at `now`.
func held(table: StimulusTable, now: float) -> bool:
	return kind != "" and table.has(kind) and table.fresh(kind, now - noticed_at)
