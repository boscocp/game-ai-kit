## The words beside and under the board: whose turn it is, how old MENACE is,
## the box it is drawing from with every bead numbered, the bead it drew, and
## what perfect play makes of the position.
##
## The beads are listed in the order the draw lays them out -- square by square
## of the box -- each move with its run of bead numbers, so "it drew bead 12 of
## 26" can be checked against the list by a person with nothing but the list.
##
## Every sentence is a key of `godot/locale/tictactoe.csv`, translated here
## with `TranslationServer.translate` -- these are static functions, and
## `tr()` is a method of an object (T79).
class_name TicTacToePanel
extends RefCounted

## How MENACE learnt, a line a key: a key is one line of text (T78's rule L4).
const HOW_IT_LEARNT: Array[String] = [  # shown through tr()
	"It learnt in Python, before the game: after each game every bead",
	"it drew went back with 3 more for a win, 1 for a draw, or stayed",
	"out for a loss. Draws earn beads too, so even an old box keeps",
	"some on lesser moves. Here it only draws -- it learns nothing from you.",
]

## How a game ended, by the winner `TicTacToeBoard.winner` names.
const OUTCOMES: Dictionary = {  # shown through tr()
	"X": "MENACE wins  ·  R plays again",
	"O": "you win  ·  R plays again",
	"draw": "a draw  ·  R plays again",
}

## What perfect play makes of the position, by the outcome the best move
## leads to: when every move is as good, and when one square or several are.
const EVERY_MOVE: Dictionary = {  # shown through tr()
	"wins": "perfect play: every move wins for {who} from here.",
	"draws": "perfect play: every move draws for {who} from here.",
	"loses": "perfect play: every move loses for {who} from here.",
}
const BEST_SQUARES: Dictionary = {  # shown through tr()
	"wins": "perfect play, for {who}, wins with",
	"draws": "perfect play, for {who}, draws with",
	"loses": "perfect play, for {who}, loses with",
}


## The line under the board.
static func status(board: String, overlay: Dictionary, playing_age: int, show_minimax: bool, message: String) -> String:
	var keys: String = TranslationServer.translate("1-4: MENACE after 10, 100, 1,000 or 10,000 games (now {games})  ·  M: perfect play on  ·  R: new game")
	if not show_minimax:
		keys = TranslationServer.translate("1-4: MENACE after 10, 100, 1,000 or 10,000 games (now {games})  ·  M: perfect play off  ·  R: new game")
	var lines: PackedStringArray = [_situation(board, overlay), keys.format({games = games(playing_age)})]
	if message != "":
		lines.append(TranslationServer.translate(message))
	return "\n".join(lines)


## The panel: the box, numbered bead by bead; the bead drawn; perfect play.
static func describe(overlay: Dictionary) -> String:
	var lines: PackedStringArray = [TranslationServer.translate("MENACE AFTER {games} GAMES").format({games = games(overlay["age"])})]
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
	for line: String in HOW_IT_LEARNT:
		lines.append(TranslationServer.translate(line))
	return "\n".join(lines)


## A number of games as the screen writes it: 10,000 rather than 10000 in
## English, 10.000 in Portuguese, where the comma marks decimals.
static func games(count: int) -> String:
	var separator: String = "." if Language.is_portuguese() else ","
	var digits: String = str(count)
	var grouped: String = ""
	for index: int in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			grouped += separator
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
		return [TranslationServer.translate("one square left: the move is forced, and there is no box for it.")]
	var total: int = 0
	for entry: Dictionary in squares:
		total += entry["beads"]
	if total == 0:
		return [TranslationServer.translate("its box for this position is empty: every move from here lost.")]
	var lines: PackedStringArray = [TranslationServer.translate("its box holds {beads} beads, counted out in this order:").format({beads = total})]
	var first: int = 1
	for entry: Dictionary in squares:
		if entry.has("same_move_as") or entry["beads"] == 0:
			continue
		var last: int = first + entry["beads"] - 1
		var run: String = TranslationServer.translate("bead {first}").format({first = first})
		if first != last:
			run = TranslationServer.translate("beads {first}-{last}").format({first = first, last = last})
		lines.append("   %-19s %-16s %s" % [TicTacToeView.square_name(entry["square"]), run, percent(entry["probability"])])
		first = last + 1
	return lines


static func _situation(board: String, overlay: Dictionary) -> String:
	var outcome: String = TicTacToeBoard.winner(board)
	if overlay.get("chosen", 0) == -1:
		return TranslationServer.translate("MENACE resigns: its box is empty -- every move from here lost before")
	if outcome != "":
		return TranslationServer.translate(OUTCOMES[outcome])
	if TicTacToeBoard.to_move(board) != TicTacToeExample.MENACE_SIDE:
		return TranslationServer.translate("your turn: click an empty square")
	if overlay["squares"].size() == 1:
		return TranslationServer.translate("MENACE's turn: one square left, so the move is forced  ·  space plays it")
	if _box_is_empty(overlay):
		return TranslationServer.translate("MENACE's turn: its box is empty  ·  space, and it resigns")
	return TranslationServer.translate("MENACE's turn: its beads are on the squares  ·  space shakes the box and draws one")


static func _box_is_empty(overlay: Dictionary) -> bool:
	for entry: Dictionary in overlay["squares"]:
		if entry["beads"] > 0:
			return false
	return true


static func _last_draw_line(overlay: Dictionary) -> String:
	var square: String = TicTacToeView.square_name(overlay["chosen"]) if overlay["chosen"] != -1 else ""
	var values: Dictionary = {games = games(overlay["drawn_at_age"]), square = square,
			bead = overlay["bead"], total = overlay["total"]}
	if overlay["chosen"] == -1:
		return TranslationServer.translate("its last move, at {games} games: it drew from an empty box, and resigned.").format(values)
	if overlay["forced"]:
		return TranslationServer.translate("its last move, at {games} games: forced, the {square}.").format(values)
	return "\n".join([TranslationServer.translate("its last move, at {games} games: it drew bead {bead} of {total},").format(values),
			TranslationServer.translate("which is the {square}.").format(values)])


# What perfect play makes of the position, without naming one move when
# several are as good -- or when every move is as bad.
static func _perfect_line(perfect: Dictionary) -> String:
	var values: Dictionary = perfect["values"]
	var who: String = "MENACE" if perfect["for"] == TicTacToeExample.MENACE_SIDE else TranslationServer.translate("you")
	var best: Array = perfect["best"]
	var outcome: String = TicTacToeSolver.words(values[best[0]])
	if best.size() == values.size():
		return TranslationServer.translate(EVERY_MOVE[outcome]).format({who = who})
	var names: PackedStringArray = PackedStringArray()
	for square: int in best:
		names.append(TicTacToeView.square_name(square))
	var listed: String = names[-1]
	if names.size() > 1:
		listed = TranslationServer.translate("{first} or {last}").format({first = ", ".join(names.slice(0, -1)), last = names[-1]})
	return "\n".join([TranslationServer.translate(BEST_SQUARES[outcome]).format({who = who}),
			TranslationServer.translate("the {squares},").format({squares = listed}),
			TranslationServer.translate("and the rest do worse.")])
