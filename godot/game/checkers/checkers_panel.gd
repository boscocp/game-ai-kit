## The words on the screen: the status line under the board, and the panel
## beside it that says what the computer considered and why it chose.
##
## The board draws the same numbers on the moves themselves. The panel is the
## same decision as a list, best first, with what a picture cannot say: what
## a number means, the line of play behind the chosen one, and what the search
## cost.
##
## Every sentence goes through TranslationServer.translate -- these are static
## functions, and `tr()` is a method of an object -- keyed by its English
## text in `godot/locale/checkers.csv` (T78). A sentence with a number in it
## is translated whole and its number put in by name, so a translator can
## move it. The scene builds these again when the language changes.
class_name CheckersPanel
extends RefCounted

## More moves than this and the panel would run off the window; the rest are
## counted instead. The list is sorted best first, so the cut ones are worse.
const MOST_MOVES_LISTED: int = 4



# Before white has thought: what the panel will show, and when.
static func _before_white_moves() -> PackedStringArray:
	return [TranslationServer.translate("white has not moved yet."), "",
		TranslationServer.translate("when it is white's turn, every move it considered"),
		TranslationServer.translate("appears here and on the board, with its value,"),
		TranslationServer.translate("before it plays one."), ""]


static func _what_a_value_means() -> String:
	return TranslationServer.translate("value: white's lead at the line's end, by these weights (E):")


## The line under the board: what is happening, the keys, and why the last
## click did nothing, if it did nothing.
static func status(board: CheckersBoard, pending: bool, holding: bool, depth: int, message: String) -> String:
	var keys: String = TranslationServer.translate(
			"1-6: how many plies white looks ahead (now {depth})  ·  E: hand or learned weights  ·  R: new game"
			).format({depth = depth})
	var lines: PackedStringArray = [_situation(board, pending, holding), keys]
	if message != "":
		# The message is a rule's reason, kept in English as the rules and
		# their vectors state it; it is translated here, where it is shown.
		lines.append(TranslationServer.translate(message))
	return "\n".join(lines)


## The panel for `decision`, with the line of play it expects. `pending` is
## true while the move is on show and not yet played; `evaluation` names the
## weights white searched with, and `why` is `CheckersExample.why()`.
static func describe(decision: AdversarialResult, expected: Array[CheckersMove], pending: bool,
		evaluation: String = "hand-written", why: Dictionary = {}) -> String:  # not shown
	if decision == null:
		var waiting: PackedStringArray = _before_white_moves()
		waiting.append(_what_a_value_means())
		var weights: String = TranslationServer.translate(evaluation)
		waiting.append(TranslationServer.translate("white searches with the {weights} weights").format({weights = weights}))
		return "\n".join(waiting)
	var lines: PackedStringArray = PackedStringArray()
	lines.append(_heading(decision.depth, pending))
	var cost: String = TranslationServer.translate("searched {positions} positions; skipped {pruned} replies, whole branches")
	lines.append(cost.format({positions = decision.positions, pruned = decision.pruned}))
	lines.append("")
	lines += _move_lines(decision, pending)
	lines.append("")
	lines += _expected_lines(expected)
	lines.append("")
	lines.append(_what_a_value_means())
	lines += why_lines(evaluation, why)
	lines += _footnotes(decision)
	return "\n".join(lines)


# The panel's first line: whether the move is still on show, and how deep.
static func _heading(depth: int, pending: bool) -> String:
	if depth == 1:
		if pending:
			return TranslationServer.translate("WHITE IS ABOUT TO MOVE  ·  alpha-beta, 1 ply ahead")
		return TranslationServer.translate("WHITE'S LAST MOVE  ·  alpha-beta, 1 ply ahead")
	if pending:
		return TranslationServer.translate("WHITE IS ABOUT TO MOVE  ·  alpha-beta, {depth} plies ahead").format({depth = depth})
	return TranslationServer.translate("WHITE'S LAST MOVE  ·  alpha-beta, {depth} plies ahead").format({depth = depth})


## The end of the expected line, count by count: how many of each white is
## ahead by, and what that adds to the score under each set of weights. The
## column white is searching with is marked, and it adds up to the chosen
## move's value. It is one position under two sets of weights: it says what
## the value is made of, not by itself why one move beat another -- that is
## the difference between the ends of different lines.
static func why_lines(evaluation: String, why: Dictionary) -> PackedStringArray:
	if why.is_empty():
		return PackedStringArray()
	var searching_with_hand: bool = evaluation == "hand-written"  # not shown
	var hand: String = TranslationServer.translate("hand")
	var learned_name: String = TranslationServer.translate("learned")
	if searching_with_hand:
		hand = "▶ " + hand
	else:
		learned_name = "▶ " + learned_name
	var count: String = TranslationServer.translate("count")
	# Each column as wide as its heading, whichever language that is in:
	# "▶ aprendidos" is twelve characters, and the numbers line up under it.
	var widths: Vector2i = Vector2i(maxi(6, count.length()), maxi(10, maxi(hand.length(), learned_name.length())))
	var lines: PackedStringArray = ["%-12s %s %s %s" % [TranslationServer.translate("white ahead"),
			count.lpad(widths.x), hand.lpad(widths.y), learned_name.lpad(widths.y)]]
	for index: int in range(CheckersEvaluation.FEATURES.size()):
		lines.append(_why_row(why, index, widths))
	return lines


# One count's row: its name, white's lead in it, and what that adds to the
# score under each set of weights -- a dash when there is no learned set.
# `widths` are the count's column and each weight's, from the headings.
static func _why_row(why: Dictionary, index: int, widths: Vector2i) -> String:
	var learned: Array = why.get("learned", [])
	var learned_part: String = "%+.2f" % learned[index] if not learned.is_empty() else "-"
	var count: String = "%+d" % int(why["counts"][index])
	var hand: String = "%+.2f" % why["hand"][index]
	var feature: String = TranslationServer.translate(CheckersEvaluation.FEATURES[index])
	return "%-12s %s %s %s" % [feature, count.lpad(widths.x), hand.lpad(widths.y), learned_part.lpad(widths.y)]


static func _situation(board: CheckersBoard, pending: bool, holding: bool) -> String:
	if CheckersRules.is_draw(board):
		return TranslationServer.translate("drawn: forty moves each with no capture and no man moved")
	if CheckersRules.is_over(board):
		return _result(board)
	var line: String = TranslationServer.translate("your move: click a red piece, then a green square")
	if pending:
		line = TranslationServer.translate("white will play the pink arrow  ·  space plays it")
	elif holding:
		line = TranslationServer.translate("piece in hand: click a green square -- a jump goes one hop per click")
	elif CheckersRules.must_capture(board):
		line = TranslationServer.translate("you must capture: click a ringed piece")
	return line + _draw_countdown(board)


static func _result(board: CheckersBoard) -> String:
	var loser: int = board.to_move
	var wiped_out: bool = board.squares_of(loser).is_empty()
	if loser == CheckersBoard.WHITE:
		if wiped_out:
			return TranslationServer.translate("you win: white has no pieces left")
		return TranslationServer.translate("you win: white cannot move")
	if wiped_out:
		return TranslationServer.translate("white wins: you have no pieces left")
	return TranslationServer.translate("white wins: you cannot move")


# Once kings start shuffling, how long until the 40-move rule ends it.
static func _draw_countdown(board: CheckersBoard) -> String:
	if board.quiet_plies < 20:
		return ""
	var left: int = (CheckersBoard.QUIET_PLIES_TO_DRAW - board.quiet_plies + 1) / 2
	return "  ·  " + TranslationServer.translate("drawn in {moves} moves each unless a piece is taken or a man moves").format(
			{moves = left})


# Best first, the chosen one at the top of its value.
static func _move_lines(decision: AdversarialResult, pending: bool) -> PackedStringArray:
	var entries: Array = decision.considered.duplicate()
	entries.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return _rank(first, decision) > _rank(second, decision))
	var lines: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries.slice(0, MOST_MOVES_LISTED):
		lines.append(_line_for(entry, entry["action"] == decision.action, pending))
	if entries.size() > MOST_MOVES_LISTED:
		var more: String = TranslationServer.translate("and {count} more, none better")
		lines.append("   " + more.format({count = entries.size() - MOST_MOVES_LISTED}))
	return lines


# The chosen move sorts ahead of an equal value; a bound sorts as its bound.
static func _rank(entry: Dictionary, decision: AdversarialResult) -> float:
	return float(entry["value"]) + (0.001 if entry["action"] == decision.action else 0.0)


static func _line_for(entry: Dictionary, chosen: bool, pending: bool) -> String:
	var move: String = (entry["action"] as CheckersMove).notation()
	var value: String = CheckersView.value_words(entry["value"], entry["exact"])
	var played: String = ""
	if chosen:
		played = "   " + (TranslationServer.translate("will play") if pending else TranslationServer.translate("played"))
	return "%s %-12s %9s%s" % ["▶" if chosen else "   ", move, value, played]


# The chosen move and the replies it expects, by whose move each is.
static func _expected_lines(expected: Array[CheckersMove]) -> PackedStringArray:
	var words: PackedStringArray = PackedStringArray()
	for index: int in range(expected.size()):
		var side: String = TranslationServer.translate("white") if index % 2 == 0 else TranslationServer.translate("red")
		words.append("%s %s" % [side, expected[index].notation()])
	var lines: PackedStringArray = [TranslationServer.translate("the line it expects, which gives that value:")]
	for start: int in range(0, words.size(), 3):
		lines.append("   " + ", ".join(words.slice(start, start + 3)))
	return lines


static func _footnotes(decision: AdversarialResult) -> PackedStringArray:
	var notes: PackedStringArray = PackedStringArray()
	if decision.considered.any(func(entry: Dictionary) -> bool: return not entry["exact"]):
		notes.append(TranslationServer.translate("≤ x: cut short once proved worth at most x, so no better."))
	var tied: int = decision.considered.filter(func(entry: Dictionary) -> bool:
		return is_equal_approx(entry["value"], decision.value)).size()
	if tied > 1:
		notes.append(TranslationServer.translate("a tie goes to the move white lists first."))
	return notes
