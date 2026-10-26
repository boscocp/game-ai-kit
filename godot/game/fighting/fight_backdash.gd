## The evade: a backdash, from the frame it starts to the frame its fighter
## can act again (T40).
##
## Each part is frame data, in the character's `backdash`, after how shipped
## games build one -- a quick hop backwards, invulnerable from its first
## frame for about a quarter of its length, then committed. The fighter goes
## `speed` units a frame away from the way it faces for `travel` frames, and
## the whole thing lasts `frames`. On its first `invulnerable` frames nothing
## finds it, strike or throw: a jab already on its way passes through. After
## them, until it is over, it cannot guard and can be thrown. That is the
## price: a backdash read is a backdash punished, by a long strike that
## arrives as it stops.
##
## It is kept as a stun -- `stun_kind` "evade", `stun` counting down -- like
## a jump's take-off, so a fighter needs no new field, and a log recorded
## before the backdash existed still replays to the same digests. A hit ends
## it, as a hit ends any stun.
##
## `FightRules.step` calls these at step 2, and asks `invulnerable` at step 4.
##
## When not to use it: a dodge that turns -- a sidestep -- or one that
## leaves the floor. This backdash stays on the ground, on a line.
class_name FightBackdash
extends RefCounted

## What `stun_kind` says while a fighter is evading.
const KIND: String = "evade"  # not shown: an identifier


## Start a backdash: its frame 1 is this one, already a step away, and the
## fighter is committed to it for `frames` frames, standing.
static func start(fighter: FighterState, data: FightData) -> void:
	fighter.stun = int(data.character(fighter.character)["backdash"]["frames"])
	fighter.stun_kind = KIND
	fighter.crouching = false
	_travel(fighter, data)


## One frame further into the backdash. True while it goes on; false on the
## frame it is over, when the fighter is free and acts on that same frame --
## so a backdash of `frames` frames costs exactly that many, as a move does.
static func carry(fighter: FighterState, data: FightData) -> bool:
	fighter.stun -= 1
	if fighter.stun == 0:
		fighter.stun_kind = ""
		return false
	_travel(fighter, data)
	return true


## Which frame of its backdash the fighter is on, from 1, or 0 when it is not
## evading. The stun is what is left, so the frame is what has gone.
static func frame_of(fighter: FighterState, data: FightData) -> int:
	if fighter.stun_kind != KIND:
		return 0
	return int(data.character(fighter.character)["backdash"]["frames"]) - fighter.stun + 1


## True while nothing can find the fighter: the first `invulnerable` frames
## of its backdash.
static func invulnerable(fighter: FighterState, data: FightData) -> bool:
	var frame: int = frame_of(fighter, data)
	return frame > 0 and frame <= int(data.character(fighter.character)["backdash"]["invulnerable"])


# A step away from the way it faces, while the backdash's `travel` lasts.
static func _travel(fighter: FighterState, data: FightData) -> void:
	var backdash: Dictionary = data.character(fighter.character)["backdash"]
	if frame_of(fighter, data) <= int(backdash["travel"]):
		fighter.x -= fighter.facing * int(backdash["speed"])
