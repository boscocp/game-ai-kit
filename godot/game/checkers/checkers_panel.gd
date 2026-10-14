## The words beside the board: what the computer considered, what each move is
## worth to it, and what it cost to find out.
##
## The board draws the same numbers on the moves themselves. The panel is the
## same decision as a list, with the two things a picture cannot say: what the
## number means, and how much searching it took.
class_name CheckersPanel
extends RefCounted

const WHAT_A_VALUE_MEANS: String = (
	"each number is white's lead at the end of the best\n"
	+ "line both sides can play from that move: a man is 1,\n"
	+ "a king 1.5, and a man earns 0.05 for each row it has\n"
	+ "advanced. Positive is good for white.")


## The panel for `decision`. `pending` is true while the move is still on show
## and not yet played.
static func describe(decision: AdversarialResult, pending: bool) -> String:
	if decision == null:
		return "white has not moved yet.\n\nwhen it is white's turn, every move it\nconsidered appears here and on the board,\nwith its value, before it plays one.\n\n" + WHAT_A_VALUE_MEANS
	var lines: PackedStringArray = PackedStringArray()
	var looked: String = "WHITE IS ABOUT TO MOVE" if pending else "WHITE'S LAST MOVE"
	lines.append("%s  ·  alpha-beta, %d plies ahead" % [looked, decision.depth])
	lines.append("searched %d positions; %d moves cut" % [decision.positions, decision.pruned])
	lines.append("without being looked at")
	lines.append("")
	for entry: Dictionary in decision.considered:
		lines.append(_line_for(entry, entry["action"] == decision.action))
	lines.append("")
	lines.append(WHAT_A_VALUE_MEANS)
	if decision.considered.any(func(entry: Dictionary) -> bool: return not entry["exact"]):
		lines.append("≤: alpha-beta stopped early, having proved\nthe move no better than one it already had.")
	return "\n".join(lines)


static func _line_for(entry: Dictionary, chosen: bool) -> String:
	var move: String = (entry["action"] as CheckersMove).notation()
	var value: String = CheckersView.value_words(entry["value"], entry["exact"])
	return "%s %-12s %8s%s" % ["▶" if chosen else " ", move, value, "   chosen" if chosen else ""]
