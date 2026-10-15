## Where a fighter can hit, and where it can be hit, on the frame it is on.
##
## A box is a rectangle, kept as two intervals so each reads as the frame
## data writes it: along the stage, `[left, right]`, and up from the floor,
## `[bottom, top]`, in stage units, both ends included (T38). A hit needs
## both to meet: a high meets a crouch along the stage and passes over it. A **hitbox** exists only on a move's active
## frames, reaches from `hitbox[0]` to `hitbox[1]` in front of the fighter,
## and is gone once the move has connected. A **hurtbox** is the body, and
## from a move's first active frame to its last recovery frame it also
## reaches `hurtbox_reach` in front: a limb that is out can be hit. That is
## what makes a long whiffed move punishable, and it is in the data, not here.
##
## When not to use it: fighters with limbs that need several boxes a frame,
## drawn rather than written. Here a fighter has one of each.
class_name FightBoxes
extends RefCounted

## The empty box: no hitbox this frame.
const NONE: Array[int] = []


## The fighter's hitbox this frame, or `NONE` outside its move's active frames
## or once the move has connected.
static func hitbox(fighter: FighterState, data: FightData) -> Array[int]:
	if fighter.move == "" or fighter.connected:
		return NONE
	var frames: Dictionary = data.move(fighter.character, fighter.move)
	var startup: int = int(frames["startup"])
	if fighter.move_frame <= startup or fighter.move_frame > startup + int(frames["active"]):
		return NONE
	var near: int = int(frames["hitbox"][0])
	var far: int = int(frames["hitbox"][1])
	if fighter.facing > 0:
		return [fighter.x + near, fighter.x + far]
	return [fighter.x - far, fighter.x - near]


## The fighter's hurtbox this frame: its body, and the move's reach once the
## move is past its startup.
static func hurtbox(fighter: FighterState, data: FightData) -> Array[int]:
	var body: int = int(data.character(fighter.character)["body"])
	var box: Array[int] = [fighter.x - body, fighter.x + body]
	if fighter.move == "":
		return box
	var frames: Dictionary = data.move(fighter.character, fighter.move)
	if fighter.move_frame <= int(frames["startup"]):
		return box
	var reach: int = int(frames["hurtbox_reach"])
	if fighter.facing > 0:
		box[1] = maxi(box[1], fighter.x + reach)
	else:
		box[0] = mini(box[0], fighter.x - reach)
	return box


## The fighter's hitbox, up from the floor: its move's `rise`, from where its
## feet are. Only meaningful while `hitbox` is out.
static func hit_rise(fighter: FighterState, data: FightData) -> Array[int]:
	var rise: Array = data.move(fighter.character, fighter.move)["rise"]
	return [fighter.y + int(rise[0]), fighter.y + int(rise[1])]


## The fighter's hurtbox, up from the floor: from its feet to the top of its
## head, lower while it crouches.
static func hurt_rise(fighter: FighterState, data: FightData) -> Array[int]:
	var numbers: Dictionary = data.character(fighter.character)
	var tall: int = int(numbers["crouching_tall"] if fighter.crouching else numbers["tall"])
	return [fighter.y, fighter.y + tall]


## How a hitbox that meets the hurtbox along the stage misses it up from the
## floor, in words with a `%d` for the defender, or "" when it does not miss.
## The words name the move's own height: a mid under a jump is not a low.
static func misses_vertically(attacker: FighterState, defender: FighterState, data: FightData) -> String:
	var hit: Array[int] = FightBoxes.hit_rise(attacker, data)
	var hurt: Array[int] = FightBoxes.hurt_rise(defender, data)
	if FightBoxes.overlap(hit, hurt):
		return ""
	var height: String = data.move(attacker.character, attacker.move)["height"]
	var why: String = {"high": " (a high misses a crouch)", "low": " (a low misses a fighter in the air)"}.get(height, "")
	if hit[0] > hurt[1]:
		return "passes over p%d" + (why if height == "high" and defender.crouching else "")
	return "passes under p%d" + (why if height == "low" and defender.is_airborne() else " (it is in the air)")


## True when two intervals share at least one unit. An empty box overlaps nothing.
static func overlap(first: Array[int], second: Array[int]) -> bool:
	if first.is_empty() or second.is_empty():
		return false
	return first[0] <= second[1] and second[0] <= first[1]


## Which part of its move a fighter is in: "startup", "active", "recovery",
## or "" when it is in none.
static func phase(fighter: FighterState, data: FightData) -> String:
	if fighter.move == "":
		return ""
	var frames: Dictionary = data.move(fighter.character, fighter.move)
	var startup: int = int(frames["startup"])
	if fighter.move_frame <= startup:
		return "startup"
	if fighter.move_frame <= startup + int(frames["active"]):
		return "active"
	return "recovery"
