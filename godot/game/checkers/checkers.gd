## Checkers against the computer, which plays white with minimax and
## alpha-beta, and shows what it is about to play and why before it plays it.
##
## You are red and move first. Click one of your pieces and the squares it can
## reach light up; click one and the piece goes there -- a multi-jump one hop
## per click, or straight to its last square. When a capture is compulsory the
## pieces that can take are ringed.
##
## Then the computer searches, and the board shows every move it considered
## with the value it worked out for it: white's lead at the end of the line it
## expects, looking that many moves ahead. The pink arrow is what it will play,
## and the panel spells out the line it expects to follow. Space plays it.
## Keys 1 to 6 set how far it looks, and the panel says what that cost.
##
## E switches white between two evaluations (T32): the hand-written weights,
## and weights Python fitted to self-play results. The panel shows, for the
## position at the end of the expected line, what each count adds to the
## score under both -- what the chosen move's value is made of, and how the
## learned weights would count the same position.
class_name CheckersExample
extends Node2D

const COMPUTER: int = CheckersBoard.WHITE
const PERSON: int = CheckersBoard.RED
const MAX_DEPTH: int = 6

## How many plies the computer looks ahead. At 4 it answers in about 50 ms at
## worst and already sees an exchange coming. At 6 it was measured at 360 ms
## in a game of men and 730 ms with four kings in the open, and the search
## runs in the frame, so the window stalls for that long on white's turn.
var depth: int = 4

var _board: CheckersBoard
var _game := CheckersGame.new()
var _search := AlphaBetaSearch.new()
var _decision: AdversarialResult = null
var _expected: Array[CheckersMove] = []
var _pending: bool = false
var _hand := CheckersHand.new()
var _last: CheckersMove = null
var _message: String = ""
var _learned: bool = false
# The position white decided on, which the expected line starts from.
var _board_before_decision: CheckersBoard

@onready var _view: CheckersView = $CheckersView
@onready var _status: Label = $Interface/Status
@onready var _panel: Label = $Interface/Decision
@onready var _legend: Legend = $Interface/Legend


func _ready() -> void:
	_legend.set_entries([
		[Art.texture(Art.RED_MAN), "red: you, moving up the board, first"],
		[Art.texture(Art.WHITE_MAN), "white: the computer, moving down"],
		[Art.texture(Art.CROWN), "crown: a king, moves both ways", CheckersView.CROWN],
		[CheckersView.SELECTED, "yellow ring: the piece in your hand"],
		[CheckersView.MUST_CAPTURE, "orange ring: must capture; cross: taken"],
		[CheckersView.TARGET, "green: where the piece in hand can go"],
		[CheckersView.LAST_MOVE, "grey squares: the last move played"],
		[CheckersView.CONSIDERED, "blue arrow: a move white considered"],
		[CheckersView.CHOSEN, "pink arrow: the move white will play"],
	] as Array[Array])
	new_game()


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		click_square(_view.square_at(_view.get_local_mouse_position()))
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		_handle_key(key.keycode)


## Start again from the opening, red to move.
func new_game() -> void:
	_board = CheckersBoard.starting()
	_decision = null
	_expected = []
	_pending = false
	_hand.drop()
	_last = null
	_message = ""
	_refresh()


## What a click on `square` means: pick up one of your pieces, or move the one
## in hand there. A click that does nothing says why.
func click_square(square: Vector2i) -> void:
	if CheckersRules.is_over(_board) or not CheckersBoard.is_inside(square):
		return
	_message = ""
	var owner: int = CheckersBoard.owner_of(_board.piece_at(square))
	if _board.to_move != PERSON:
		_message = "it is white's turn: space plays the pink move"
	elif _hand.is_holding() and _hand.targets(_board).has(square):
		# Before "pick up your own piece": a king's capture can end on the
		# square it started from, which holds the king itself.
		_move_hand_to(square)
	elif owner == PERSON:
		_hand.pick_up(_board, square)
		_message = _hand.refusal
	elif _hand.is_holding():
		_move_hand_to(square)
	elif owner == COMPUTER:
		_message = "that is one of white's pieces: yours are red"
	else:
		_message = "click one of your red pieces first"
	_refresh()


## One decision. On the computer's turn it plays the move on show, as space
## does. On yours it plays your first legal move for you -- the stand-in for a
## person that lets a test, or somebody watching, step through a whole game.
func step_decision() -> void:
	if CheckersRules.is_over(_board):
		new_game()
	elif _pending:
		_play_the_decision()
	else:
		_play(CheckersRules.legal_moves(_board)[0])


## What the computer is reasoning with: every move it considered, with its
## value and whether that value is exact or only a bound, the move it chose,
## the line it expects to follow, and what the search cost.
func decision_overlay() -> Dictionary:
	if _decision == null:
		return {}
	var overlay: Dictionary = {"depth": _decision.depth, "moves": _root_moves(),
			"positions": _decision.positions, "pruned": _decision.pruned, "pending": _pending,
			"evaluation": evaluation_name(), "why": why()}
	if _decision.action != null:
		overlay["chosen"] = (_decision.action as CheckersMove).notation()
		overlay["value"] = _decision.value
		overlay["expects"] = _expected.map(_notation_of)
	return overlay


## Search with the learned weights, or with the hand-written ones. With a
## move on show, white thinks again, so the two choices can be compared on
## the same position. Without a usable weights file it stays on the hand.
func use_learned(learned: bool) -> void:
	_learned = learned and not CheckersWeights.learned().is_empty()
	_game = CheckersGame.new(CheckersWeights.learned() if _learned else CheckersEvaluation.HAND_WEIGHTS)
	if _pending:
		_think()
	_refresh()


## Which evaluation white is searching with, as the panel names it.
func evaluation_name() -> String:
	return "learned" if _learned else "hand-written"


## Why the chosen move scores as it does: the position at the end of the line
## white expects, and what each count there adds to the score under each set
## of weights, white's way round. Empty before white has thought.
func why() -> Dictionary:
	if _decision == null or _expected.is_empty():
		return {}
	var board: CheckersBoard = _board_before_decision
	for move: CheckersMove in _expected:
		board = CheckersRules.play(board, move)
	var parts: Dictionary = {"counts": CheckersEvaluation.features(board, COMPUTER),
			"hand": CheckersEvaluation.contributions(board, COMPUTER, CheckersEvaluation.HAND_WEIGHTS)}
	if not CheckersWeights.learned().is_empty():
		parts["learned"] = CheckersEvaluation.contributions(board, COMPUTER, CheckersWeights.learned())
	return parts


## Set how far the computer looks. When it has a move on show, it thinks again
## at the new depth, so the two answers can be compared on the same position.
func set_depth(plies: int) -> void:
	depth = clampi(plies, 1, MAX_DEPTH)
	if _pending:
		_think()
	_refresh()


func _root_moves() -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	for entry: Dictionary in _decision.considered:
		var move: CheckersMove = entry["action"]
		moves.append({"move": move.notation(), "value": entry["value"], "exact": entry["exact"]})
	return moves


func _notation_of(move: CheckersMove) -> String:
	return move.notation()


func _handle_key(keycode: Key) -> void:
	if keycode >= KEY_1 and keycode <= KEY_6:
		set_depth(keycode - KEY_0)
	elif keycode == KEY_SPACE and _pending:
		_play_the_decision()
	elif keycode == KEY_R:
		new_game()
	elif keycode == KEY_E:
		use_learned(not _learned)


func _move_hand_to(square: Vector2i) -> void:
	var move: CheckersMove = _hand.click(_board, square)
	_message = _hand.refusal
	if move != null:
		_play(move)


func _play(move: CheckersMove) -> void:
	_board = CheckersRules.play(_board, move)
	_last = move
	_hand.drop()
	_pending = false
	if _board.to_move == COMPUTER and not CheckersRules.is_over(_board):
		_think()
	_refresh()


func _play_the_decision() -> void:
	_play(_decision.action as CheckersMove)


func _think() -> void:
	_board_before_decision = _board
	_decision = _search.search(_game, _board, depth)
	_expected = _expected_line()
	_pending = true


# The line of play behind the chosen move's value: the chosen move, then the
# reply each side would pick at the depth that is left. Searching again costs
# less than the first search -- each is a ply shallower -- and it turns one
# number into the moves that produce it.
func _expected_line() -> Array[CheckersMove]:
	var line: Array[CheckersMove] = []
	var board: CheckersBoard = _board
	var move: CheckersMove = _decision.action
	for plies_left: int in range(depth, 0, -1):
		if move == null:
			break
		line.append(move)
		board = CheckersRules.play(board, move)
		if plies_left == 1 or CheckersRules.is_over(board):
			break
		move = _search.search(_game, board, plies_left - 1).action
	return line


func _refresh() -> void:
	if not is_node_ready():
		return
	_view.show_position(_board, _marks())
	_status.text = CheckersPanel.status(_board, _pending, _hand.is_holding(), depth, _message)
	_panel.text = CheckersPanel.describe(_decision, _expected, _pending, evaluation_name(), why())


func _marks() -> Dictionary:
	var marks: Dictionary = {"last": _last}
	if _board.to_move == PERSON and CheckersRules.must_capture(_board) and not _hand.is_holding():
		marks["must_capture"] = _pieces_that_can_capture()
	if _hand.is_holding():
		marks["selected"] = _hand.route[0]
		marks["route"] = _hand.route
		marks["targets"] = _hand.targets(_board)
		marks["paths"] = _hand.candidates(_board)
	if _pending:
		marks["considered"] = _decision.considered.map(_considered_mark)
	return marks


func _pieces_that_can_capture() -> Array[Vector2i]:
	var takers: Array[Vector2i] = []
	for move: CheckersMove in CheckersRules.legal_moves(_board):
		if not takers.has(move.from()):
			takers.append(move.from())
	return takers


func _considered_mark(entry: Dictionary) -> Dictionary:
	var chosen: bool = entry["action"] == _decision.action
	return {"move": entry["action"], "value": entry["value"], "exact": entry["exact"], "chosen": chosen}
