## The words on the screen: the status line under the board, and the panel
## beside it that says what the computer considered and why it chose.
##
## The board draws the same numbers on the moves themselves. The panel is the
## same decision as a list, best first, with what a picture cannot say: what
## a number means, the line of play behind the chosen one, and what the search
## cost.
class_name CheckersPanel
extends RefCounted

## More moves than this and the panel would run off the window; the rest are
## counted instead. The list is sorted best first, so the cut ones are worse.
const MOST_MOVES_LISTED: int = 5

const WHAT_A_VALUE_MEANS: String = (
	"value: white's lead at the end of that line, positive good\n"
	+ "for white -- a man 1, a king 1.5, +0.05 a row a man advanced")


const BEFORE_WHITE_MOVES: String = (
	"white has not moved yet.\n\nwhen it is white's turn, every move it considered\n"
	+ "appears here and on the board, with its value,\n"
	+ "before it plays one.\n\n")


## The line under the board: what is happening, the keys, and why the last
## click did nothing, if it did nothing.
static func status(board: CheckersBoard, pending: bool, holding: bool, depth: int, message: String) -> String:
	var keys: String = "1-6: how many plies white looks ahead (now %d)  ·  R: new game" % depth
	var lines: PackedStringArray = [_situation(board, pending, holding), keys]
	if message != "":
		lines.append(message)
	return "\n".join(lines)


## The panel for `decision`, with the line of play it expects. `pending` is
## true while the move is on show and not yet played.
static func describe(decision: AdversarialResult, expected: Array[CheckersMove], pending: bool) -> String:
	if decision == null:
		return BEFORE_WHITE_MOVES + WHAT_A_VALUE_MEANS
	var lines: PackedStringArray = PackedStringArray()
	var plies: String = "1 ply" if decision.depth == 1 else "%d plies" % decision.depth
	lines.append("%s  ·  alpha-beta, %s ahead" % ["WHITE IS ABOUT TO MOVE" if pending else "WHITE'S LAST MOVE", plies])
	lines.append("searched %d positions; skipped %d replies, whole branches" % [decision.positions, decision.pruned])
	lines.append("")
	lines += _move_lines(decision, pending)
	lines.append("")
	lines += _expected_lines(expected)
	lines.append("")
	lines.append(WHAT_A_VALUE_MEANS)
	lines += _footnotes(decision)
	return "\n".join(lines)


static func _situation(board: CheckersBoard, pending: bool, holding: bool) -> String:
	if CheckersRules.is_draw(board):
		return "drawn: forty moves each with no capture and no man moved"
	if CheckersRules.is_over(board):
		return _result(board)
	var line: String = "your move: click a red piece, then a green square"
	if pending:
		line = "white will play the pink arrow  ·  space plays it"
	elif holding:
		line = "piece in hand: click a green square -- a jump goes one hop per click"
	elif CheckersRules.must_capture(board):
		line = "you must capture: click a ringed piece"
	return line + _draw_countdown(board)


static func _result(board: CheckersBoard) -> String:
	var loser: int = board.to_move
	var why: String = "has no pieces left" if board.squares_of(loser).is_empty() else "cannot move"
	if loser == CheckersBoard.WHITE:
		return "you win: white %s" % why
	return "white wins: you %s" % why.replace("has", "have")


# Once kings start shuffling, how long until the 40-move rule ends it.
static func _draw_countdown(board: CheckersBoard) -> String:
	if board.quiet_plies < 20:
		return ""
	var left: int = (CheckersBoard.QUIET_PLIES_TO_DRAW - board.quiet_plies + 1) / 2
	return "  ·  drawn in %d moves each unless a piece is taken or a man moves" % left


# Best first, the chosen one at the top of its value.
static func _move_lines(decision: AdversarialResult, pending: bool) -> PackedStringArray:
	var entries: Array = decision.considered.duplicate()
	entries.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return _rank(first, decision) > _rank(second, decision))
	var lines: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries.slice(0, MOST_MOVES_LISTED):
		lines.append(_line_for(entry, entry["action"] == decision.action, pending))
	if entries.size() > MOST_MOVES_LISTED:
		lines.append("   and %d more, none better" % (entries.size() - MOST_MOVES_LISTED))
	return lines


# The chosen move sorts ahead of an equal value; a bound sorts as its bound.
static func _rank(entry: Dictionary, decision: AdversarialResult) -> float:
	return float(entry["value"]) + (0.001 if entry["action"] == decision.action else 0.0)


static func _line_for(entry: Dictionary, chosen: bool, pending: bool) -> String:
	var move: String = (entry["action"] as CheckersMove).notation()
	var value: String = CheckersView.value_words(entry["value"], entry["exact"])
	return "%s %-12s %9s%s" % ["▶" if chosen else "   ", move, value, ("   will play" if pending else "   played") if chosen else ""]


# The chosen move and the replies it expects, by whose move each is.
static func _expected_lines(expected: Array[CheckersMove]) -> PackedStringArray:
	var words: PackedStringArray = PackedStringArray()
	for index: int in range(expected.size()):
		words.append("%s %s" % ["white" if index % 2 == 0 else "red", expected[index].notation()])
	var lines: PackedStringArray = ["the line it expects, which gives that value:"]
	for start: int in range(0, words.size(), 3):
		lines.append("   " + ", ".join(words.slice(start, start + 3)))
	return lines


static func _footnotes(decision: AdversarialResult) -> PackedStringArray:
	var notes: PackedStringArray = PackedStringArray()
	if decision.considered.any(func(entry: Dictionary) -> bool: return not entry["exact"]):
		notes.append("≤ x: cut short once proved worth at most x, so no better.")
	var tied: int = decision.considered.filter(func(entry: Dictionary) -> bool:
		return is_equal_approx(entry["value"], decision.value)).size()
	if tied > 1:
		notes.append("a tie goes to the move white lists first.")
	return notes
