## The words beside the fight: the frame, and for each fighter its move, the
## frame of it, its phase and the frame data behind it, its stun and what it
## has buffered -- and what happened on the frame.
##
## The frame data is written out next to the frame number on purpose: "jab,
## frame 7 of 20, active (startup 6, active 3, recovery 11)" is the sentence
## a person reads a fighting game's frame data in.
##
## When not to use it: during play at full speed. It is for a paused frame.
class_name FightingPanel
extends RefCounted


## The panel for `state`.
static func describe(state: FightState, data: FightData, paused: bool) -> String:
	var lines: PackedStringArray = ["frame %d%s" % [state.frame, "  ·  paused" if paused else ""], ""]
	for index: int in range(2):
		lines.append_array(_fighter_lines(index, state.fighters[index], data))
		lines.append("")
	lines.append("this frame: " + (", ".join(state.events) if not state.events.is_empty() else "nothing connected"))
	if state.winner != FightState.NOBODY:
		lines.append("DRAW" if state.winner == FightState.DRAW else "PLAYER %d WINS" % (state.winner + 1))
	return "\n".join(lines)


static func _fighter_lines(index: int, fighter: FighterState, data: FightData) -> PackedStringArray:
	var lines: PackedStringArray = ["player %d, the %s: %d health" % [index + 1, fighter.character, fighter.health]]
	if fighter.stun > 0:
		lines.append("  in %sstun, %d frame(s) left" % [fighter.stun_kind, fighter.stun])
	elif fighter.move == "":
		lines.append("  free to act")
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
		"  (startup %d, active %d, recovery %d)" % [frames["startup"], frames["active"], frames["recovery"]],
	])
