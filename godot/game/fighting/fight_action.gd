## What a fighter is doing, as one word a person would use: the vocabulary
## the opponent model (T17) and behaviour cloning (T18) both read a fight in.
##
## Read off the fighter as it is drawn: the height of the move it started, a
## jump, a backdash (T40), a guard it was seen holding (blockstun shows it),
## a crouch, a step in or out. Nothing here counts or remembers: it is a
## reading of one frame, which is why it lives apart from the opponents that
## learn from it.
##
## When not to use it: telling two moves of one height apart. A jab and a
## straight are both "high" here, on purpose -- the answer to them is the same.
class_name FightAction
extends RefCounted

## Every action a fighter can be read as doing.
const ACTIONS: Array[String] = ["step in", "step out", "crouch", "jump", "high", "mid", "low", "overhead", "throw",
		"guard standing", "guard crouching", "evade"]


## What fighter `index` is doing in `state`, as one of `ACTIONS`, or "" when
## it is doing nothing to learn from -- standing, stunned by a hit, landing.
static func of(state: FightState, index: int, data: FightData) -> String:
	var fighter: FighterState = state.fighters[index]
	if fighter.is_airborne() or fighter.stun_kind == "takeoff":
		return "jump"
	if fighter.move != "":
		return data.move(fighter.character, fighter.move)["height"]
	if fighter.stun_kind == FightBackdash.KIND:
		return "evade"
	if fighter.stun_kind == "block":
		return "guard crouching" if fighter.crouching else "guard standing"
	if fighter.stun > 0:
		return ""
	if fighter.crouching:
		return "crouch"
	var walking: int = FightInput.walk_direction(fighter.held_before)
	if walking == 0:
		return ""
	var toward: int = signi(state.fighters[1 - index].x - fighter.x)
	return "step in" if walking == toward else "step out"
