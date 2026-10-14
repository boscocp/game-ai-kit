## The words beside and under the board: whose turn it is, how old MENACE is,
## the box it is drawing from with every bead numbered, the bead it drew, and
## what perfect play makes of the position.
##
## The beads are listed in the order the draw lays them out -- square by square
## of the box -- each move with its run of bead numbers, so "it drew bead 12 of
## 26" can be checked against the list by a person with nothing but the list.
class_name TicTacToePanel
extends RefCounted

const HOW_IT_LEARNT: String = (
	"It learnt in Python, before the game: after each game every bead\n"
	+ "it drew went back with 3 more for a win, 1 for a draw, or stayed\n"
	+ "out for a loss. Draws earn beads too, so even an old box keeps\n"
	+ "some on lesser moves. Here it only draws -- it learns nothing from you.")


const OUTCOMES: Dictionary = {"X": "MENACE wins", "O": "you win", "draw": "a draw"}


## The line under the board.
static func status(board: String, overlay: Dictionary, playing_age: int, show_minimax: bool, message: String) -> String:
	var keys: String = "1-4: MENACE after 10, 100, 1,000 or 10,000 games (now %s)  ·  M: perfect play %s  ·  R: new game" % [
			games(playing_age), "on" if show_minimax else "off"]
	var lines: PackedStringArray = [_situation(board, overlay), keys]
	if message != "":
		lines.append(message)
	return "\n".join(lines)


## The panel: the box, numbered bead by bead; the bead drawn; perfect play.
static func describe(overlay: Dictionary) -> String:
	var lines: PackedStringArray = ["MENACE AFTER %s GAMES" % games(overlay["age"]).to_upper()]
	lines += _box_lines(overlay)
	lines.append("")
	# Only beside the box it was drawn from. On MENACE's turn the box on show is
	# the next one, and a draw from the last box next to it reads as a draw
	# from this one.
	if overlay.has("chance") and not overlay["pending"]:
		lines.append(_last_draw_line(overlay))
		lines.append("")
	if overlay.has("perfect"):
		lines.append(_perfect_line(overlay["perfect"]))
		lines.append("")
	lines.append(HOW_IT_LEARNT)
	return "\n".join(lines)


## A number of games as the screen writes it: 10,000 rather than 10000.
static func games(count: int) -> String:
	var digits: String = str(count)
	var grouped: String = ""
	for index: int in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			grouped += ","
		grouped += digits[index]
	return grouped


## A chance as a percentage, and "<1%" rather than "0%" for beads that exist.
static func percent(probability: float) -> String:
	if probability > 0.0 and probability < 0.005:
		return "<1%"
	return "%d%%" % roundi(probability * 100.0)


static func _box_lines(overlay: Dictionary) -> PackedStringArray:
	var squares: Array = overlay["squares"]
	if squares.size() == 1 and squares[0].get("forced", false):
		return ["one square left: the move is forced, and there is no box for it."]
	var total: int = 0
	for entry: Dictionary in squares:
		total += entry["beads"]
	if total == 0:
		return ["its box for this position is empty: every move from here lost."]
	var lines: PackedStringArray = ["its box holds %d beads, counted out in this order:" % total]
	var first: int = 1
	for entry: Dictionary in squares:
		if entry.has("same_move_as") or entry["beads"] == 0:
			continue
		var last: int = first + entry["beads"] - 1
		var run: String = "bead %d" % first if first == last else "beads %d-%d" % [first, last]
		lines.append("   %-14s %-16s %s" % [TicTacToeView.square_name(entry["square"]), run, percent(entry["probability"])])
		first = last + 1
	return lines


static func _situation(board: String, overlay: Dictionary) -> String:
	var outcome: String = TicTacToeBoard.winner(board)
	if overlay.get("chosen", 0) == -1:
		return "MENACE resigns: its box is empty -- every move from here lost before"
	if outcome != "":
		return OUTCOMES[outcome] + "  ·  R plays again"
	if TicTacToeBoard.to_move(board) != TicTacToeExample.MENACE_SIDE:
		return "your turn: click an empty square"
	if overlay["squares"].size() == 1:
		return "MENACE's turn: one square left, so the move is forced  ·  space plays it"
	if _box_is_empty(overlay):
		return "MENACE's turn: its box is empty  ·  space, and it resigns"
	return "MENACE's turn: its beads are on the squares  ·  space shakes the box and draws one"


static func _box_is_empty(overlay: Dictionary) -> bool:
	for entry: Dictionary in overlay["squares"]:
		if entry["beads"] > 0:
			return false
	return true


static func _last_draw_line(overlay: Dictionary) -> String:
	var when: String = "its last move, at %s games" % games(overlay["drawn_at_age"])
	if overlay["chosen"] == -1:
		return when + ": it drew from an empty box, and resigned."
	if overlay["forced"]:
		return when + ": forced, the %s." % TicTacToeView.square_name(overlay["chosen"])
	return when + ": it drew bead %d of %d,\nwhich is the %s." % [
			overlay["bead"], overlay["total"], TicTacToeView.square_name(overlay["chosen"])]


# What perfect play makes of the position, without naming one move when
# several are as good -- or when every move is as bad.
static func _perfect_line(perfect: Dictionary) -> String:
	var values: Dictionary = perfect["values"]
	var who: String = "MENACE" if perfect["for"] == TicTacToeExample.MENACE_SIDE else "you"
	var best: Array = perfect["best"]
	var outcome: String = TicTacToeSolver.words(values[best[0]])
	if best.size() == values.size():
		return "perfect play: every move %s for %s from here." % [outcome, who]
	var names: PackedStringArray = PackedStringArray()
	for square: int in best:
		names.append(TicTacToeView.square_name(square))
	var listed: String = names[-1] if names.size() == 1 else ", ".join(names.slice(0, -1)) + " or " + names[-1]
	var verb: String = outcome if best.size() == 1 else outcome.trim_suffix("s")
	return "perfect play, for %s: the %s %s,\nand the rest do worse." % [who, listed, verb]
