## The valley as it stands on one day (T164, ADR 0025), rebuilt from the
## record of deeds by `ValleyRules` and never saved.
##
## A fact is `place.fact`, true or false: `barn.standing`, `market.bread`.
## Beside each fact that has changed since the first day the world keeps
## why -- the deed or the rule that last wrote it -- so a screen can say
## what happened to the market and what the player did that led there.
##
## When not to use it: as something to keep. It is cheap to rebuild and
## always agrees with the record it was rebuilt from; a stored copy would
## agree only until the rules changed.
class_name ValleyWorld
extends RefCounted

## The day this world is the end of; 0 is the valley before any deed.
var day: int = 0
## Every fact of the valley, by name.
var facts: Dictionary = {}
## For each fact that has changed since the first day, the reason written
## beside the deed or the rule that last changed it.
var because: Dictionary = {}


func _init(start: Dictionary = {}, on_day: int = 0) -> void:
	facts = start.duplicate()
	day = on_day


## Whether `name` is true on this day. An unknown fact is a mistake in
## the caller: it is reported, then read as false.
func fact(name: String) -> bool:
	if not facts.has(name):
		push_error("the valley has no fact %s" % name)
	return bool(facts.get(name, false))


## The next day's world, before its deeds: the same facts and reasons,
## to be written into.
func next_day() -> ValleyWorld:
	var following := ValleyWorld.new(facts, day + 1)
	following.because = because.duplicate()
	return following


## Write `value` into the fact `name`, with the reason `why`. The reason is
## kept only when the value changes, so it always names the cause of what
## the fact is now.
func write(name: String, value: bool, why: String) -> void:
	if bool(facts[name]) != value:
		because[name] = why
	facts[name] = value
