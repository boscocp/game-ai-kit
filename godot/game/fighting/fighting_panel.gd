## The words beside the fight: the frame, and for each fighter its move, the
## frame of it, its phase and the frame data behind it, its stun and what it
## has buffered -- and what happened on the frame, and, with an opponent in
## the dummy's place, what it saw and what it drew.
##
## The frame data is written out next to the frame number on purpose: "jab,
## frame 7 of 20, active (startup 6, active 3, recovery 11)" is the sentence
## a person reads a fighting game's frame data in.
##
## When not to use it: during play at full speed. It is for a paused frame.
class_name FightingPanel
extends RefCounted


## The panel for `state`.
## `seat` holds the opponent in the dummy's place, or is null for a scripted dummy.
static func describe(state: FightState, data: FightData, paused: bool, seat: FightDelay = null) -> String:
	var lines: PackedStringArray = ["frame %d%s" % [state.frame, "  ·  paused" if paused else ""], ""]
	for index: int in range(2):
		lines.append_array(_fighter_lines(index, state.fighters[index], data))
		lines.append("")
	lines.append("this frame: " + (", ".join(state.events) if not state.events.is_empty() else "nothing connected"))
	if seat != null:
		lines.append_array(_opponent_lines(state, seat))
	if state.winner != FightState.NOBODY:
		lines.append("DRAW" if state.winner == FightState.DRAW else "PLAYER %d WINS" % (state.winner + 1))
	return "\n".join(lines)


static func _fighter_lines(index: int, fighter: FighterState, data: FightData) -> PackedStringArray:
	var lines: PackedStringArray = ["player %d, the %s: %d health" % [index + 1, fighter.character, fighter.health]]
	if fighter.stun > 0:
		lines.append("  in %sstun, %d frame(s) left" % [fighter.stun_kind, fighter.stun])
	elif fighter.move == "":
		lines.append("  free to act, crouching" if fighter.crouching else "  free to act")
	else:
		lines.append_array(_move_lines(fighter, data))
	if fighter.buffered != "":
		lines.append("  buffered: %s, until frame %d" % [fighter.buffered, fighter.buffered_until])
	return lines


# The move, the frame of it, its phase, and the frame data it is read against.
static func _move_lines(fighter: FighterState, data: FightData) -> PackedStringArray:
	var frames: Dictionary = data.move(fighter.character, fighter.move)
	var length: int = data.length_of(fighter.character, fighter.move)
	var phase: String = FightBoxes.phase(fighter, data)
	return PackedStringArray([
		"  %s, frame %d of %d, %s" % [fighter.move, fighter.move_frame, length, phase],
		"  %s %s, hits %s" % [frames["stance"], frames["button"].replace("_", " "), frames["height"]],
		"  (startup %d, active %d, recovery %d)" % [frames["startup"], frames["active"], frames["recovery"]],
	])


# The opponent's last decision, with how old the fight it saw was: the
# number a person checks it against. The reaction is the seat's, which is
# the one enforced; a refused opponent says why.
static func _opponent_lines(state: FightState, seat: FightDelay) -> PackedStringArray:
	var opponent: FightOpponent = seat.opponent
	var lines: PackedStringArray = ["", "the opponent (%s), seeing %d frames late:" % [opponent.level, seat.reaction]]
	if seat.refusal != "":
		lines.append("  refused: " + seat.refusal)
		return lines
	if opponent.seen_frame < 0:
		lines.append("  has not seen the fight yet")
		return lines
	lines.append("  saw frame %d, %d frames ago: %s" % [opponent.seen_frame, state.frame - opponent.seen_frame,
			opponent.situation])
	lines.append("  drew: " + opponent.choice)
	return lines
