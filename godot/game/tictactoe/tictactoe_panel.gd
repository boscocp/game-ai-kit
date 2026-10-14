## The words beside the board: whose turn it is, how old MENACE is, what is in
## the box it is drawing from, and what it drew.
class_name TicTacToePanel
extends RefCounted

const HOW_IT_LEARNT: String = (
	"It learnt in Python, before the game: after each game every bead\n"
	+ "it drew went back with 3 more for a win, 1 for a draw, or stayed\n"
	+ "out for a loss. Here it only draws -- it learns nothing from you.")


## The line under the board.
static func status(board: String, age: int, show_minimax: bool, resigned: bool, message: String) -> String:
	var keys: String = "1-4: MENACE after 10, 100, 1,000 or 10,000 games (now %d)  ·  M: perfect play %s  ·  R: new game" % [
			age, "on" if show_minimax else "off"]
	var lines: PackedStringArray = [_situation(board, resigned), keys]
	if message != "":
		lines.append(message)
	return "\n".join(lines)


## The panel: the box MENACE is drawing from, each move's beads best first,
## and the bead it drew last.
static func describe(overlay: Dictionary, board: String) -> String:
	var total: int = 0
	for entry: Dictionary in overlay["squares"]:
		total += entry["beads"]
	var lines: PackedStringArray = ["MENACE AFTER %d GAMES  ·  this box holds %d beads:" % [overlay["age"], total]]
	var playable: Array = (overlay["squares"] as Array).filter(func(entry: Dictionary) -> bool: return not entry.has("same_move_as"))
	playable.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return first["beads"] > second["beads"])
	for entry: Dictionary in playable:
		lines.append("   %-14s %5d beads   %3d%%" % [TicTacToeView.square_name(entry["square"]), entry["beads"], roundi(entry["probability"] * 100.0)])
	lines.append("")
	if overlay.has("chance"):
		lines.append(_last_draw_line(overlay))
		lines.append("")
	if overlay.has("minimax_square"):
		lines.append("perfect play would take the %s." % TicTacToeView.square_name(overlay["minimax_square"]))
		lines.append("")
	lines.append(HOW_IT_LEARNT)
	return "\n".join(lines)


static func _situation(board: String, resigned: bool) -> String:
	var outcome: String = TicTacToeBoard.winner(board)
	if resigned:
		return "MENACE resigns: its box is empty -- every move from here lost before"
	if outcome == TicTacToeBoard.CROSS:
		return "MENACE wins"
	if outcome == TicTacToeBoard.NOUGHT:
		return "you win"
	if outcome == TicTacToeBoard.DRAW:
		return "a draw"
	if TicTacToeBoard.to_move(board) == TicTacToeExample.MENACE_SIDE:
		return "MENACE's turn: its beads are on the squares  ·  space shakes the box and draws one"
	return "your turn: click an empty square"


static func _last_draw_line(overlay: Dictionary) -> String:
	if overlay["chosen"] == -1:
		return "it drew from an empty box, and resigned."
	return "its last move: it drew %.2f of the way along its beads,\nwhich landed on the %s." % [overlay["chance"], TicTacToeView.square_name(overlay["chosen"])]
