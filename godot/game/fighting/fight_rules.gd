## One frame of a fight: two inputs in, the next frame out.
##
## The order is the frame data's `resolution` list, and this file follows it
## step by step, top to bottom:
##
## 1. read each player's input into its buffer;
## 2. both fighters act at once, each from the frame as it began;
## 3. bodies are pushed apart and kept on the stage;
## 4. every hitbox is tested against the other's hurtbox, both before either
##    result is applied -- which is what makes a trade a trade;
## 5-8. each connection is a block or a hit, a counter-hit if it caught a
##    move starting up, and pushes the defender back;
## 9. a fighter at 0 health has lost.
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
	_separate(next, data)
	_face_each_other(next)
	var attackers: Array[int] = _connections(next, data)
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


# Step 2, for one fighter: count stun down, or carry on with the move, or
# start the buffered one, or walk.
static func _act(fighter: FighterState, held: int, data: FightData) -> void:
	if fighter.stun > 0:
		fighter.stun -= 1
		if fighter.stun == 0:
			fighter.stun_kind = ""
	elif fighter.move != "":
		_advance_move(fighter, data)
	elif not _start_buffered(fighter, data):
		var speed: int = int(data.character(fighter.character)["walk_speed"])
		fighter.x += FightInput.walk_direction(held) * speed


# One more frame of the move. Inside an open cancel window, a move that has
# connected may become the buffered one; a move that is over leaves the
# fighter free, and a buffered move starts on that same frame.
static func _advance_move(fighter: FighterState, data: FightData) -> void:
	fighter.move_frame += 1
	if _cancel_is_open(fighter, data) and _start_buffered(fighter, data, true):
		return
	if fighter.move_frame > data.length_of(fighter.character, fighter.move):
		fighter.move = ""
		fighter.move_frame = 0
		fighter.connected = false
		_start_buffered(fighter, data)


static func _cancel_is_open(fighter: FighterState, data: FightData) -> bool:
	var window: Array = data.move(fighter.character, fighter.move)["cancel_window"]
	return fighter.connected and fighter.move_frame >= int(window[0]) and fighter.move_frame <= int(window[1]) \
			and int(window[1]) > 0


# Start the move for the buffered button, if the character has one -- and, as
# a cancel, only if the current move lists it. True when a move started.
static func _start_buffered(fighter: FighterState, data: FightData, as_cancel: bool = false) -> bool:
	if fighter.buffered == "":
		return false
	var next_move: String = data.move_for_button(fighter.character, fighter.buffered)
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


# Step 3. Two bodies may not overlap: each gives way by half. Then both are
# kept on the stage, and one pinned to a wall leaves the other to give way.
static func _separate(state: FightState, data: FightData) -> void:
	var left: FighterState = state.fighters[0] if state.fighters[0].x <= state.fighters[1].x else state.fighters[1]
	var right: FighterState = state.fighters[1] if left == state.fighters[0] else state.fighters[0]
	var need: int = _body(left, data) + _body(right, data)
	var overlap: int = need - (right.x - left.x)
	if overlap > 0:
		left.x -= overlap / 2
		right.x += overlap - overlap / 2
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
# both before anything is applied.
static func _connections(state: FightState, data: FightData) -> Array[int]:
	var attackers: Array[int] = []
	for index: int in range(2):
		var hitbox: Array[int] = FightBoxes.hitbox(state.fighters[index], data)
		if FightBoxes.overlap(hitbox, FightBoxes.hurtbox(state.fighters[1 - index], data)):
			attackers.append(index)
	return attackers


# Steps 5 to 8. Every connection is judged on the fighters as step 4 found
# them, and only then applied: so in a trade, each defender's move is still
# the one it was hit out of.
static func _resolve(state: FightState, attackers: Array[int], inputs: Array[int], data: FightData) -> void:
	var outcomes: Array[String] = []
	var moves: Array[String] = []
	for attacker: int in attackers:
		outcomes.append(_judge(state, attacker, inputs[1 - attacker], data))
		moves.append(state.fighters[attacker].move)
	for index: int in range(attackers.size()):
		_apply(state, attackers[index], moves[index], outcomes[index], data)
	if attackers.size() == 2:
		state.events.append("trade")
	_keep_on_stage(state, data)


# "block", "counter-hit" or "hit", for the attacker's connection.
static func _judge(state: FightState, attacker: int, defender_held: int, data: FightData) -> String:
	var hitter: FighterState = state.fighters[attacker]
	var defender: FighterState = state.fighters[1 - attacker]
	var can_block: bool = defender.is_free() or defender.stun_kind == "block"
	if can_block and FightInput.holds_away(defender_held, defender.x, hitter.x):
		return "block"
	if FightBoxes.phase(defender, data) == "startup":
		return "counter-hit"
	return "hit"


# Apply one connection. `move` is the attacker's move as step 4 found it: in a
# trade the first hit applied has already knocked the other attacker out of
# its move, and its own hit still lands with the move it was made with.
static func _apply(state: FightState, attacker: int, move: String, outcome: String, data: FightData) -> void:
	var hitter: FighterState = state.fighters[attacker]
	var defender: FighterState = state.fighters[1 - attacker]
	var frames: Dictionary = data.move(hitter.character, move)
	hitter.connected = hitter.move != ""
	defender.x += hitter.facing * data.number("pushback")
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
		defender.move_frame = 0
		defender.connected = false
	state.events.append("p%d %s p%d with %s" % [attacker + 1, _verb(outcome), 2 - attacker, move])


static func _verb(outcome: String) -> String:
	return {"block": "is blocked by", "counter-hit": "counter-hits", "hit": "hits"}[outcome]


# Step 9.
static func _winner(state: FightState) -> int:
	var down: Array[bool] = [state.fighters[0].health <= 0, state.fighters[1].health <= 0]
	if down[0] and down[1]:
		return FightState.DRAW
	if down[0]:
		return 1
	if down[1]:
		return 0
	return FightState.NOBODY
