## One frame of a fight: two inputs in, the next frame out.
##
## The order is the frame data's `resolution` list, and this file follows it
## step by step, top to bottom:
##
## 1. read each player's input into its buffer;
## 2. both fighters act at once, each from the frame as it began -- one in
##    the air goes on along its arc, whatever else it does;
## 3. bodies are pushed apart and kept on the stage;
## 4. every hitbox is tested against the other's hurtbox, along the stage and
##    up from the floor, both before either result is applied -- which is
##    what makes a trade a trade;
## 5. two throws break each other, and a strike beats a throw;
## 6-9. each connection is a block or a hit -- a block only with the guard
##    its height asks for -- a counter-hit if it caught a move starting up,
##    and pushes the defender back;
## 10. a fighter at 0 health has lost.
##
## Guard, strike and throw are a triangle: guarding stops a strike, a strike
## beats a throw, a throw beats guarding. Heights split guarding in two, so
## the defender has to guess low or high as well -- and a crouch ducks a
## high, standing punch altogether. The jump is a fourth corner (T38): it
## goes over a low and out of a throw, cannot guard, and loses to a strike
## aimed up.
##
## Everything is whole numbers and nothing is random, so the same inputs from
## the same frame always give the same next frame (`FightReplay`).
##
## Complexity: constant per frame -- two fighters, a handful of boxes.
##
## When not to use it: more than two fighters, or projectiles. Each is
## another thing with boxes, and the pairwise tests in step 4 grow with them.
class_name FightRules
extends RefCounted


## The frame after `state`, given each player's input bits for it (player one
## first). `state` is not changed. A finished fight stays as it is.
static func step(state: FightState, inputs: Array[int], data: FightData) -> FightState:
	var next: FightState = state.copy()
	next.frame = state.frame + 1
	if state.winner != FightState.NOBODY:
		return next
	for index: int in range(2):
		_read_input(next.fighters[index], inputs[index], next.frame, data)
	for index: int in range(2):
		_act(next.fighters[index], inputs[index], data)
		if next.fighters[index].cancelled_from != "":
			next.events.append("p%d cancels %s into %s" % [index + 1, next.fighters[index].cancelled_from, next.fighters[index].move])
			next.fighters[index].cancelled_from = ""
	_separate(next, data)
	_face_each_other(next)
	var attackers: Array[int] = _settle_throws(next, _connections(next, data), data)
	_resolve(next, attackers, inputs, data)
	next.winner = _winner(next)
	return next


# Step 1. A button newly pressed is remembered for `buffer_frames` frames,
# replacing any older one; a remembered button whose time is up is forgotten.
static func _read_input(fighter: FighterState, held: int, frame: int, data: FightData) -> void:
	var pressed: String = FightInput.pressed(held, fighter.held_before)
	fighter.held_before = held
	if pressed != "":
		fighter.buffered = pressed
		fighter.buffered_until = frame + data.number("buffer_frames") - 1
	elif frame > fighter.buffered_until:
		fighter.buffered = ""


# Step 2, for one fighter: in the air, fly; on the ground, count stun down,
# or carry on with the move, or start the buffered one, or jump, or crouch,
# or walk. Then it is crouching if its move is a crouching one, or, out of a
# move, if it holds down -- except in hitstun, which it takes standing: a
# fighter reeling from a hit cannot duck the next one, or a combo would end
# whenever its victim held down.
static func _act(fighter: FighterState, held: int, data: FightData) -> void:
	if fighter.is_airborne():
		_fly(fighter, held, data)
		return
	if fighter.stun > 0:
		_count_stun_down(fighter)
	elif fighter.move != "":
		_advance_move(fighter, held, data)
	elif _start_buffered(fighter, held, data):
		pass
	elif FightInput.holds_up(held):
		_take_off(fighter, held)
	elif not FightInput.holds_down(held):
		var speed: int = int(data.character(fighter.character)["walk_speed"])
		fighter.x += FightInput.walk_direction(held) * speed
	if fighter.is_airborne():
		fighter.crouching = false
	elif fighter.move != "":
		fighter.crouching = data.move(fighter.character, fighter.move)["stance"] == "crouching"
	else:
		fighter.crouching = FightInput.holds_down(held) and fighter.stun_kind != "hit"


static func _count_stun_down(fighter: FighterState) -> void:
	fighter.stun -= 1
	if fighter.stun == 0:
		fighter.stun_kind = ""


# Leaving the ground: the direction held now is the direction of the whole
# jump. Its first frame of flight is the next one.
static func _take_off(fighter: FighterState, held: int) -> void:
	fighter.jump_direction = FightInput.walk_direction(held)
	fighter.jump_frame = 1
	fighter.crouching = false


# One frame along the arc -- up, along, and down, as the frame data has it --
# and, at the same time, the stun counting down, or the air move going on,
# or one starting for a buffered button. The arc goes on whatever happens: a
# fighter hit in the air still comes down where its jump was taking it.
static func _fly(fighter: FighterState, held: int, data: FightData) -> void:
	fighter.y = data.height_at(fighter.character, fighter.jump_frame)
	fighter.x += fighter.jump_direction * int(data.character(fighter.character)["jump"]["speed"])
	if fighter.stun > 0:
		_count_stun_down(fighter)
	elif fighter.move != "":
		_advance_move(fighter, held, data)
	else:
		_start_buffered(fighter, held, data)
	fighter.jump_frame += 1
	if fighter.jump_frame > data.jump_length(fighter.character):
		_land(fighter, data)


# Back on the floor: an air move ends with the jump, and a fighter not
# already stunned takes the jump's landing frames, when it can do nothing.
static func _land(fighter: FighterState, data: FightData) -> void:
	fighter.y = 0
	fighter.jump_frame = 0
	fighter.jump_direction = 0
	if fighter.move != "":
		fighter.move = ""
		fighter.move_frame = 0
		fighter.connected = false
	var landing: int = int(data.character(fighter.character)["jump"]["landing"])
	if fighter.stun == 0 and landing > 0:
		fighter.stun = landing
		fighter.stun_kind = "landing"


# One more frame of the move. Inside an open cancel window, a move that has
# connected may become the buffered one; a move that is over leaves the
# fighter free, and a buffered move starts on that same frame.
static func _advance_move(fighter: FighterState, held: int, data: FightData) -> void:
	fighter.move_frame += 1
	var cancelled_from: String = fighter.move
	if _cancel_is_open(fighter, data) and _start_buffered(fighter, held, data, true):
		fighter.cancelled_from = cancelled_from
		return
	if fighter.move_frame > data.length_of(fighter.character, fighter.move):
		fighter.move = ""
		fighter.move_frame = 0
		fighter.connected = false
		_start_buffered(fighter, held, data)


static func _cancel_is_open(fighter: FighterState, data: FightData) -> bool:
	var window: Array = data.move(fighter.character, fighter.move)["cancel_window"]
	return fighter.connected and fighter.move_frame >= int(window[0]) and fighter.move_frame <= int(window[1]) \
			and int(window[1]) > 0


# Start the move for the buffered button, if the character has one -- the
# crouching one while holding down -- and, as a cancel, only if the current
# move lists it. True when a move started.
static func _start_buffered(fighter: FighterState, held: int, data: FightData, as_cancel: bool = false) -> bool:
	if fighter.buffered == "":
		return false
	var next_move: String = data.move_for_button(fighter.character, fighter.buffered, FightInput.holds_down(held),
			fighter.is_airborne())
	if next_move == "":
		fighter.buffered = ""
		return false
	if as_cancel and not next_move in data.move(fighter.character, fighter.move)["cancels_into"]:
		return false
	fighter.move = next_move
	fighter.move_frame = 1
	fighter.connected = false
	fighter.buffered = ""
	return true


# Step 3. Two bodies may not overlap: each gives way by half, rounded up, so
# an odd overlap leaves a one-unit gap rather than favouring a side -- the
# mirror image of any push is the same push. Then both are kept on the stage,
# and one pinned to a wall leaves the other to give way.
static func _separate(state: FightState, data: FightData) -> void:
	var left: FighterState = state.fighters[0] if state.fighters[0].x <= state.fighters[1].x else state.fighters[1]
	var right: FighterState = state.fighters[1] if left == state.fighters[0] else state.fighters[0]
	var need: int = _body(left, data) + _body(right, data)
	var overlap: int = need - (right.x - left.x)
	if overlap > 0:
		left.x -= (overlap + 1) / 2
		right.x += (overlap + 1) / 2
	_keep_on_stage(state, data)
	overlap = need - (right.x - left.x)
	if overlap > 0 and left.x == _body(left, data):
		right.x += overlap
	elif overlap > 0:
		left.x -= overlap


static func _keep_on_stage(state: FightState, data: FightData) -> void:
	var width: int = int(data.table["stage"]["width"])
	for fighter: FighterState in state.fighters:
		fighter.x = clampi(fighter.x, _body(fighter, data), width - _body(fighter, data))


static func _body(fighter: FighterState, data: FightData) -> int:
	return int(data.character(fighter.character)["body"])


# A fighter that is free turns to face the other; one in a move or stunned
# keeps the way it was facing, as it would in any fighting game.
static func _face_each_other(state: FightState) -> void:
	for index: int in range(2):
		var fighter: FighterState = state.fighters[index]
		var other: FighterState = state.fighters[1 - index]
		if fighter.is_free() and other.x != fighter.x:
			fighter.facing = signi(other.x - fighter.x)


# Step 4. Every fighter whose hitbox overlaps the other's hurtbox, found for
# both before anything is applied. Boxes that meet along the stage and not
# up from the floor do not connect: a high passes over a crouching fighter,
# a low under one in the air, neither blocked nor hit, and the events say so.
# A throw does not find a fighter in hitstun or blockstun -- a hit could
# otherwise be followed by a throw the victim had no frame to answer -- nor
# one in the air, which is what a jump out of a throw is.
# (Within a blockstring it is frame advantage, in the data, that keeps a
# throw answerable: every move here is minus on block.)
static func _connections(state: FightState, data: FightData) -> Array[int]:
	var attackers: Array[int] = []
	for index: int in range(2):
		var attacker: FighterState = state.fighters[index]
		var defender: FighterState = state.fighters[1 - index]
		if _throwing(index, state, data) and (defender.stun > 0 or defender.is_airborne()):
			continue
		if not FightBoxes.overlap(FightBoxes.hitbox(attacker, data), FightBoxes.hurtbox(defender, data)):
			continue
		var missed: String = _misses_vertically(attacker, defender, data)
		if missed != "":
			state.events.append("p%d's %s %s" % [index + 1, attacker.move, missed % (2 - index)])
		else:
			attackers.append(index)
	return attackers


# How a hitbox that meets the hurtbox along the stage misses it up from the
# floor, in words with a `%d` for the defender, or "" when it does not miss.
static func _misses_vertically(attacker: FighterState, defender: FighterState, data: FightData) -> String:
	var hit: Array[int] = FightBoxes.hit_rise(attacker, data)
	var hurt: Array[int] = FightBoxes.hurt_rise(defender, data)
	if FightBoxes.overlap(hit, hurt):
		return ""
	if hit[0] > hurt[1]:
		return "passes over p%d (a high misses a crouch)" if defender.crouching else "passes over p%d"
	return "passes under p%d (a low misses a fighter in the air)"


# Step 5. Two throws found on one frame break each other: both moves end and
# the two are pushed apart, and neither lands. A throw found with a strike
# loses to it. The attackers left are the ones whose connection is judged.
static func _settle_throws(state: FightState, attackers: Array[int], data: FightData) -> Array[int]:
	if attackers.size() < 2:
		return attackers
	var throwers: Array[int] = []
	throwers.assign(attackers.filter(_throwing.bind(state, data)))
	if throwers.size() == 2:
		_break_both_throws(state, data)
		return []
	if throwers.size() == 1:
		var striker: int = 1 - throwers[0]
		var strike: String = state.fighters[striker].move
		state.events.append("p%d's throw is beaten by p%d's %s (strike beats throw)" % [2 - striker, striker + 1, strike])
		return [striker] as Array[int]
	return attackers


# True when the fighter at `index` is in a throw.
static func _throwing(index: int, state: FightState, data: FightData) -> bool:
	var fighter: FighterState = state.fighters[index]
	return fighter.move != "" and data.is_throw(fighter.character, fighter.move)


# Two throws meeting: each pushes the other away, and both end with nothing landed.
static func _break_both_throws(state: FightState, data: FightData) -> void:
	for index: int in range(2):
		_push_back(state, state.fighters[index], state.fighters[1 - index], data)
		state.fighters[index].move = ""
		state.fighters[index].move_frame = 0
	state.events.append("the throws clash and both break")


# Steps 6 to 9. Every connection is judged on the fighters as step 4 found
# them, and only then applied: so in a trade, each defender's move is still
# the one it was hit out of.
static func _resolve(state: FightState, attackers: Array[int], inputs: Array[int], data: FightData) -> void:
	var verdicts: Array[Array] = []
	var moves: Array[String] = []
	for attacker: int in attackers:
		verdicts.append(_judge(state, attacker, inputs[1 - attacker], data))
		moves.append(state.fighters[attacker].move)
	for index: int in range(attackers.size()):
		_apply(state, attackers[index], moves[index], verdicts[index], data)
	if attackers.size() == 2:
		state.events.append("trade")
	_keep_on_stage(state, data)


# The attacker's connection judged: `[outcome, why]`, the outcome "throw",
# "block", "counter-hit" or "hit", and why in words for the events. A
# defender who could block and holds away still takes a strike when its
# guard is the wrong height: a low through a standing guard, an overhead
# through a crouching one.
static func _judge(state: FightState, attacker: int, defender_held: int, data: FightData) -> Array[String]:
	var hitter: FighterState = state.fighters[attacker]
	var defender: FighterState = state.fighters[1 - attacker]
	var height: String = data.move(hitter.character, hitter.move)["height"]
	if height == "throw":
		return ["throw", " (a throw cannot be blocked)"]
	var can_block: bool = defender.is_free() or defender.stun_kind == "block"
	if defender.is_airborne():
		var starting: bool = FightBoxes.phase(defender, data) == "startup"
		return ["counter-hit", " (caught in the air, starting up)"] if starting else ["hit", " (in the air, which cannot guard)"]
	var crouched: bool = FightInput.holds_down(defender_held)
	var guard: String = "crouching" if crouched else "standing"
	if can_block and FightInput.holds_away(defender_held, defender.x, hitter.x):
		if _guard_stops(height, crouched):
			return ["block", " (holding away, %s)" % guard]
		return ["hit", " (%s through a %s guard)" % [_a_height(height), guard]]
	if FightBoxes.phase(defender, data) == "startup":
		return ["counter-hit", " (caught starting up)"]
	return ["hit", ""]


# True when a guard -- crouching or not -- stops a strike of `height`.
static func _guard_stops(height: String, crouched: bool) -> bool:
	return height == "mid" or (height == "low" and crouched) or (height in ["overhead", "high"] and not crouched)


# A height in words. "high" is here for completeness: a high never meets a
# crouching guard, since every high's rise is above every crouch.
static func _a_height(height: String) -> String:
	return {"low": "a low", "overhead": "an overhead", "high": "a high"}[height]


# Apply one connection. `move` is the attacker's move as step 4 found it: in a
# trade the first hit applied has already knocked the other attacker out of
# its move, and its own hit still lands with the move it was made with.
static func _apply(state: FightState, attacker: int, move: String, verdict: Array, data: FightData) -> void:
	var outcome: String = verdict[0]
	var hitter: FighterState = state.fighters[attacker]
	var defender: FighterState = state.fighters[1 - attacker]
	var frames: Dictionary = data.move(hitter.character, move)
	hitter.connected = hitter.move != ""
	_push_back(state, hitter, defender, data)
	if outcome == "block":
		defender.stun = int(frames["blockstun"])
		defender.stun_kind = "block"
	else:
		var counter: bool = outcome == "counter-hit"
		var bonus: Dictionary = data.table["counter_hit"]
		var damage: int = int(frames["damage"]) * (int(bonus["damage_percent"]) if counter else 100) / 100
		defender.health = maxi(0, defender.health - damage)
		defender.stun = int(frames["hitstun"]) + (int(bonus["extra_hitstun"]) if counter else 0)
		defender.stun_kind = "hit"
		defender.move = ""
		defender.crouching = false
		defender.move_frame = 0
		defender.connected = false
	state.events.append("p%d %s p%d with %s%s" % [attacker + 1, _verb(outcome), 2 - attacker, move, verdict[1]])


static func _verb(outcome: String) -> String:
	return {"block": "is blocked by", "counter-hit": "counter-hits", "hit": "hits", "throw": "throws"}[outcome]


# Step 9's pushback. The defender is pushed away; what a wall stops it from
# taking, the attacker takes instead, backwards -- so a fighter in the corner
# is not a free place to keep hitting from, as in most fighting games.
static func _push_back(state: FightState, hitter: FighterState, defender: FighterState, data: FightData) -> void:
	var push: int = data.number("pushback")
	var width: int = int(data.table["stage"]["width"])
	var wanted: int = defender.x + hitter.facing * push
	var allowed: int = clampi(wanted, _body(defender, data), width - _body(defender, data))
	defender.x = allowed
	hitter.x -= hitter.facing * absi(wanted - allowed)


# Step 10.
static func _winner(state: FightState) -> int:
	var down: Array[bool] = [state.fighters[0].health <= 0, state.fighters[1].health <= 0]
	if down[0] and down[1]:
		return FightState.DRAW
	if down[0]:
		return 1
	if down[1]:
		return 0
	return FightState.NOBODY
