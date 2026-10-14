## Where a fighter can hit, and where it can be hit, on the frame it is on.
##
## The stage is a line, so a box is an interval: `[left, right]` in stage
## units, both ends included. A **hitbox** exists only on a move's active
## frames, reaches from `hitbox[0]` to `hitbox[1]` in front of the fighter,
## and is gone once the move has connected. A **hurtbox** is the body, and
## from a move's first active frame to its last recovery frame it also
## reaches `hurtbox_reach` in front: a limb that is out can be hit. That is
## what makes a long whiffed move punishable, and it is in the data, not here.
##
## When not to use it: two dimensions. Boxes there are rectangles, several to
## a frame, and drawn rather than written.
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


## True when two boxes share at least one unit. An empty box overlaps nothing.
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
