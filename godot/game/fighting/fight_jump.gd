## A jump, from the frame up is pressed to the frame its fighter can act
## again (T38): take-off, flight along an arc, landing.
##
## Each part is frame data, in the character's `jump`. **Take-off** is
## `takeoff` frames still on the ground, committed: the fighter cannot guard
## and can still be thrown, which is why a throw cannot be escaped on the
## frame it arrives. **Flight** is `rise` frames up to `height`, `hang` there
## and `fall` down, `speed` units a frame along the stage the way it held at
## take-off; it goes on whatever happens, so a fighter hit in the air still
## comes down where its jump was taking it. **Landing** is `landing` frames
## on the floor when it can do nothing -- and can be thrown.
##
## A fighter has one air move a jump, and none once it has been hit in the
## air: being knocked out of the air is the end of that jump's threat.
##
## `FightRules.step` calls these at step 2; nothing else moves a fighter up.
##
## When not to use it: a jump the player steers, or one with gravity that
## changes. This arc is a table of heights, the same every time.
class_name FightJump
extends RefCounted


## Start a jump from the ground, the way `held` points: the take-off frames,
## or straight into the air when the character has none.
static func take_off(fighter: FighterState, held: int, data: FightData) -> void:
	fighter.jump_direction = FightInput.walk_direction(held)
	fighter.crouching = false
	var takeoff: int = int(data.character(fighter.character)["jump"]["takeoff"])
	if takeoff == 0:
		leave_the_ground(fighter, data)
		return
	fighter.stun = takeoff
	fighter.stun_kind = "takeoff"


## The take-off is over: the fighter's first frame in the air, with its one
## air move still to spend.
static func leave_the_ground(fighter: FighterState, data: FightData) -> void:
	fighter.jump_frame = 0
	fighter.air_spent = false
	carry(fighter, data)


## One frame further along the arc: up or down, and along the stage. True when
## the arc is over and the fighter has landed instead.
static func carry(fighter: FighterState, data: FightData) -> bool:
	fighter.jump_frame += 1
	fighter.crouching = false
	if fighter.jump_frame > data.jump_length(fighter.character):
		land(fighter, data)
		return true
	fighter.y = data.height_at(fighter.character, fighter.jump_frame)
	fighter.x += fighter.jump_direction * int(data.character(fighter.character)["jump"]["speed"])
	return false


## Back on the floor: an air move ends with the jump, and a fighter not
## already stunned takes the jump's landing frames.
static func land(fighter: FighterState, data: FightData) -> void:
	fighter.y = 0
	fighter.jump_frame = 0
	fighter.jump_direction = 0
	fighter.air_spent = false
	if fighter.move != "":
		fighter.move = ""
		fighter.move_frame = 0
		fighter.connected = false
	var landing: int = int(data.character(fighter.character)["jump"]["landing"])
	if fighter.stun == 0 and landing > 0:
		fighter.stun = landing
		fighter.stun_kind = "landing"
