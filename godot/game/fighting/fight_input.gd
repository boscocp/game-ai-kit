## One frame of a player's input, as a number: one bit per thing held down.
##
## A frame's input is a whole number so an input log is a list of whole
## numbers, which replays bit for bit -- T17 and T18 learn from a person's
## logged inputs, and a log that replayed differently would teach nothing.
##
## Directions are held. Buttons are *pressed*: a button counts on the frame
## it goes down, not on every frame it stays down, so holding a button does
## not repeat a move.
##
## When not to use it: analogue input. A stick's angle is not a bit.
class_name FightInput
extends RefCounted

const LEFT: int = 1
const RIGHT: int = 2
## Held to crouch, and with a button to pick its crouching move.
const DOWN: int = 4
const LIGHT_PUNCH: int = 8
const HEAVY_PUNCH: int = 16
const LIGHT_KICK: int = 32
const HEAVY_KICK: int = 64
const THROW: int = 128
## Held to jump, with left or right to jump that way (T38).
const UP: int = 256
## Pressed to evade: a backdash, away from the way the fighter faces (T40).
## A button of its own, so a log recorded before it existed never holds
## this bit and replays exactly as it did. A person may also tap back twice:
## `FightDoubleTap` turns that into this bit before the frame is logged.
const EVADE: int = 512
## The name a pressed evade is buffered under, beside the buttons' names.
const EVADE_NAME: String = "evade"  # not shown: an identifier

## The buttons, by the name the frame data's moves use, in the order they are
## looked at when two are pressed on one frame: the last one wins.
const BUTTONS: Dictionary = {"light_punch": LIGHT_PUNCH, "heavy_punch": HEAVY_PUNCH, "light_kick": LIGHT_KICK,
		"heavy_kick": HEAVY_KICK, "throw": THROW}


## The button newly pressed this frame -- down now and not on the frame before
## -- or "" when none is. Of two pressed together, the later in `BUTTONS`,
## and an evade over any of them: a fighter that asks to get out gets out.
static func pressed(now: int, before: int) -> String:
	if now & EVADE and not before & EVADE:
		return EVADE_NAME
	var found: String = ""
	for name: String in BUTTONS:
		var bit: int = BUTTONS[name]
		if now & bit and not before & bit:
			found = name
	return found


## Which way the input walks: -1 left, +1 right, 0 for neither or both.
static func walk_direction(held: int) -> int:
	return (1 if held & RIGHT else 0) - (1 if held & LEFT else 0)


## True when the input holds up: a jump, once the fighter is free.
static func holds_up(held: int) -> bool:
	return held & UP != 0


## True when the input holds down: a crouch, and a crouching guard.
static func holds_down(held: int) -> bool:
	return held & DOWN != 0


## True when the input holds back from a strike travelling `strike_direction`
## (+1 rightwards, -1 leftwards): that is how a fighter blocks. Read off the
## strike, not off where the two stand, so it is the same before and after
## the defender's own step back, and a cross-up -- a strike that arrives
## from the other side -- is guarded the other way (T38). Facing each other,
## it is holding away.
static func holds_back_from(held: int, strike_direction: int) -> bool:
	return strike_direction != 0 and walk_direction(held) == strike_direction
