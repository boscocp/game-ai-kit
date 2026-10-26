## One fighter on one frame: where it stands, what it is doing, and what it
## is waiting to do.
##
## Every field is a whole number or a name, so a fighter's `digest` is the
## same text on every machine, and two replays can be compared frame by
## frame. `FightRules.step` never changes a fighter it is handed: it copies,
## and changes the copy.
##
## When not to use it: a fighter that needs physics -- juggles, a body that
## falls when hit, gravity that changes. A jump here is an arc written in the
## frame data and committed to at take-off, not a body under a force.
class_name FighterState
extends RefCounted

## Which character, by its name in the frame data.
var character: String
## Where its body's centre stands, in stage units.
var x: int = 0
## How high its feet are above the floor, in stage units: 0 on the ground.
var y: int = 0
## How many frames into its jump, from 1; 0 on the ground (T38).
var jump_frame: int = 0
## Which way the jump carries it along the stage, -1, 0 or +1, fixed at
## take-off: a jump is committed from the frame up is pressed.
var jump_direction: int = 0
## True once this jump has used its one air move, or been hit: no more
## attacks until it lands.
var air_spent: bool = false
## +1 when it faces right, -1 when it faces left.
var facing: int = 1
var health: int = 0
## The move it is doing, or "" when it is free to act.
var move: String = ""
## How many frames into `move`, from 1.
var move_frame: int = 0
## True while it crouches: holding down when not in a move, or in a
## crouching move. A crouching fighter guards low and does not walk.
var crouching: bool = false
## True once `move` has hit or been blocked: it connects at most once, and
## only a move that connected may be cancelled.
var connected: bool = false
## Frames of hitstun or blockstun left; it cannot act until they are gone.
var stun: int = 0
## "hit" or "block" while stunned, "takeoff" while it gathers to jump,
## "landing" while it lands from one, "" otherwise.
var stun_kind: String = ""
## The button pressed and not yet used, and the last frame it may still be.
var buffered: String = ""
var buffered_until: int = -1
## The input it held on the frame before, to tell a press from a hold.
var held_before: int = 0
## The move it cancelled out of this frame, for the frame's events only; the
## rules clear it as soon as they have said so, and it is never copied.
var cancelled_from: String = ""


func _init(character_name: String = "", standing_at: int = 0, starting_health: int = 0) -> void:
	character = character_name
	x = standing_at
	health = starting_health


## A fighter with the same fields, to change without changing this one.
func copy() -> FighterState:
	var twin := FighterState.new(character, x, health)
	twin.facing = facing
	twin.y = y
	twin.jump_frame = jump_frame
	twin.jump_direction = jump_direction
	twin.air_spent = air_spent
	twin.move = move
	twin.move_frame = move_frame
	twin.connected = connected
	twin.crouching = crouching
	twin.stun = stun
	twin.stun_kind = stun_kind
	twin.buffered = buffered
	twin.buffered_until = buffered_until
	twin.held_before = held_before
	return twin


## True when it can start a move, walk or jump: on the ground, not stunned,
## not in a move.
func is_free() -> bool:
	return stun == 0 and move == "" and jump_frame == 0


## True while it is in a jump: it cannot block, cannot be thrown, and goes
## where its arc takes it.
func is_airborne() -> bool:
	return jump_frame > 0


## Every field, as one line of text: two fighters with the same digest are
## the same fighter.
func digest() -> String:
	return "%s x%d y%d j%d:%d:%d f%d h%d %s:%d c%d k%d s%d%s b%s:%d i%d" % [character, x, y, jump_frame,  # not shown: the digest's notation
			jump_direction, int(air_spent), facing, health, move, move_frame, int(connected), int(crouching), stun,
			stun_kind, buffered, buffered_until, held_before]
