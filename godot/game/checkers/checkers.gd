## Checkers against the computer, which plays white with minimax and
## alpha-beta, and shows what it is about to play and why before it plays it.
##
## You are red and move first. Click one of your pieces and the squares it can
## reach light up; click one of those and the move is made, a multi-jump all
## at once. When a capture is compulsory the pieces that can take are ringed.
##
## Then the computer searches, and the board shows every move it considered
## with the value it worked out for it -- white's material minus red's, after
## looking that many moves ahead. The gold one is what it will play. Space
## plays it. Keys 1 to 6 set how far it looks, and the panel says how many
## positions that cost and how many moves alpha-beta never had to look at.
class_name CheckersExample
extends Node2D

const COMPUTER: int = CheckersBoard.WHITE
const PERSON: int = CheckersBoard.RED
const NOWHERE := Vector2i(-1, -1)
const MAX_DEPTH: int = 6

## How many plies the computer looks ahead. 4 answers in well under a second
## on the opening and already sees an exchange coming.
var depth: int = 4

var _board: CheckersBoard
var _game := CheckersGame.new()
var _search := AlphaBetaSearch.new()
var _decision: AdversarialResult = null
var _pending: bool = false
var _selected: Vector2i = NOWHERE
var _last: CheckersMove = null
var _message: String = ""

@onready var _view: CheckersView = $CheckersView
@onready var _status: Label = $Interface/Status
@onready var _panel: Label = $Interface/Decision
@onready var _legend: Legend = $Interface/Legend


func _ready() -> void:
	_legend.set_entries([
		[CheckersView.RED_PIECE, "red: you, moving up the board, first"],
		[CheckersView.WHITE_PIECE, "white: the computer, moving down"],
		[CheckersView.CROWN, "gold centre: a king, moves both ways"],
		[CheckersView.MUST_CAPTURE, "orange ring: must capture, and can"],
		[CheckersView.TARGET, "green: where the piece in hand can go"],
		[CheckersView.CONSIDERED, "blue line: a move white considered"],
		[CheckersView.CHOSEN, "gold line: the move white will play"],
		[Color.TRANSPARENT, "number: white's lead after that move,"],
		[Color.TRANSPARENT, "   looking ahead; ≤ means at most"],
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
	_pending = false
	_selected = NOWHERE
	_last = null
	_message = ""
	_refresh()


## What a click on `square` means: pick up one of your pieces, or move the one
## in hand there. A move that is not allowed is refused with the reason.
func click_square(square: Vector2i) -> void:
	if _board.to_move != PERSON or CheckersRules.is_over(_board):
		return
	_message = ""
	if CheckersBoard.owner_of(_board.piece_at(square)) == PERSON:
		_pick_up(square)
	elif _selected != NOWHERE:
		_try_move(_selected, square)
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
## and what the search cost.
func decision_overlay() -> Dictionary:
	if _decision == null:
		return {}
	var overlay: Dictionary = {"depth": _decision.depth, "moves": _root_moves(),
			"positions": _decision.positions, "pruned": _decision.pruned, "pending": _pending}
	if _decision.action != null:
		overlay["chosen"] = (_decision.action as CheckersMove).notation()
		overlay["value"] = _decision.value
	return overlay


func _root_moves() -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	for entry: Dictionary in _decision.considered:
		var move: CheckersMove = entry["action"]
		moves.append({"move": move.notation(), "value": entry["value"], "exact": entry["exact"]})
	return moves


## Set how far the computer looks. When it has a move on show, it thinks again
## at the new depth, so the two answers can be compared on the same position.
func set_depth(plies: int) -> void:
	depth = clampi(plies, 1, MAX_DEPTH)
	if _pending:
		_think()
	_refresh()


func _handle_key(keycode: Key) -> void:
	if keycode >= KEY_1 and keycode <= KEY_6:
		set_depth(keycode - KEY_0)
	elif keycode == KEY_SPACE and _pending:
		_play_the_decision()
	elif keycode == KEY_R:
		new_game()


func _pick_up(square: Vector2i) -> void:
	_selected = square
	if CheckersRules.moves_of(_board, square).is_empty():
		_message = CheckersRules.why_refused(_board, square, NOWHERE)
		if _message.begins_with("pieces move only"):
			_message = "that piece has no move from here"


func _try_move(from: Vector2i, to: Vector2i) -> void:
	# Two capture sequences can end on the same square by different routes.
	# A click names only the end, so the first such sequence is played.
	for move: CheckersMove in CheckersRules.moves_of(_board, from):
		if move.to() == to:
			_play(move)
			return
	_message = CheckersRules.why_refused(_board, from, to)


func _play(move: CheckersMove) -> void:
	_board = CheckersRules.play(_board, move)
	_last = move
	_selected = NOWHERE
	_pending = false
	if _board.to_move == COMPUTER and not CheckersRules.is_over(_board):
		_think()
	_refresh()


func _play_the_decision() -> void:
	_play(_decision.action as CheckersMove)


func _think() -> void:
	_decision = _search.search(_game, _board, depth)
	_pending = true


func _refresh() -> void:
	if not is_node_ready():
		return
	_view.show_position(_board, _marks())
	_status.text = _status_line()
	_panel.text = CheckersPanel.describe(_decision, _pending)


func _marks() -> Dictionary:
	var marks: Dictionary = {"selected": _selected, "last": _last}
	if _board.to_move == PERSON and CheckersRules.must_capture(_board):
		marks["must_capture"] = _pieces_that_can_capture()
	if _selected != NOWHERE:
		marks["targets"] = CheckersRules.moves_of(_board, _selected).map(_end_of)
	if _pending:
		marks["considered"] = _decision.considered.map(_considered_mark)
	return marks


func _pieces_that_can_capture() -> Array[Vector2i]:
	var takers: Array[Vector2i] = []
	for move: CheckersMove in CheckersRules.legal_moves(_board):
		if not takers.has(move.from()):
			takers.append(move.from())
	return takers


func _end_of(move: CheckersMove) -> Vector2i:
	return move.to()


func _considered_mark(entry: Dictionary) -> Dictionary:
	var chosen: bool = entry["action"] == _decision.action
	return {"move": entry["action"], "value": entry["value"], "exact": entry["exact"], "chosen": chosen}


func _status_line() -> String:
	var keys: String = "1-6 how far white looks (now %d)  ·  R new game" % depth
	if CheckersRules.is_draw(_board):
		return "drawn: forty moves each with no capture and no man moved  ·  " + keys
	if CheckersRules.is_over(_board):
		var won: bool = CheckersRules.winner(_board) == PERSON
		return ("you win: white cannot move" if won else "white wins: you cannot move") + "  ·  " + keys
	if _pending:
		return "white will play the gold move  ·  space plays it  ·  " + keys
	var line: String = "your move: click a red piece, then a green square  ·  " + keys
	if CheckersRules.must_capture(_board):
		line = "you must capture: click a ringed piece  ·  " + keys
	return line + ("\n" + _message if _message != "" else "")
