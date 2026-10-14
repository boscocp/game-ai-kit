## Noughts and crosses against MENACE, Donald Michie's matchbox machine, with
## its beads on the squares before it draws one.
##
## MENACE plays crosses and moves first, as it did in 1961. On its turn each
## empty square shows how many beads its box holds for that move, as a number
## and as a bar, and the chance of that bead being drawn. Space shakes the box
## and draws. You play noughts: click a square.
##
## Keys 1 to 4 choose its age -- after 10, 100, 1,000 or 10,000 games of
## training, all done beforehand in Python -- so the same position can be
## seen through a young machine and an old one. M shows what perfect play
## (minimax) makes of each square, so you can see where MENACE agrees with it.
class_name TicTacToeExample
extends Node2D

const CELL: float = 150.0
const MENACE_SIDE: String = TicTacToeBoard.CROSS
const PERSON_SIDE: String = TicTacToeBoard.NOUGHT
const CROSS_COLOUR := Color(0.85, 0.20, 0.20)
const NOUGHT_COLOUR := Color(0.25, 0.55, 0.95)
const BEAD_COLOUR := Color(1.0, 0.80, 0.20)
const CHOSEN_COLOUR := Color(1.0, 0.30, 0.80)
const MINIMAX_COLOUR := Color(0.45, 0.90, 0.55)
const GRID_COLOUR := Color(0.85, 0.85, 0.85)

## Which snapshot plays, as an index into `MenacePlayer.ages`.
var age_index: int = 0
## True while M is on: each square says what perfect play makes of it.
var show_minimax: bool = false

var _menace: MenacePlayer
var _board: String = TicTacToeBoard.START
var _dice := RandomNumberGenerator.new()
# The last bead MENACE drew: the number, the square it played, its age.
var _last_draw: Dictionary = {}
var _message: String = ""

@onready var _status: Label = $Interface/Status
@onready var _panel: Label = $Interface/Decision
@onready var _legend: Legend = $Interface/Legend


func _ready() -> void:
	_legend.set_entries([
		[CROSS_COLOUR, "X: MENACE, the matchbox machine, first"],
		[NOUGHT_COLOUR, "O: you"],
		[BEAD_COLOUR, "number and bar: beads for that move"],
		[Color.TRANSPARENT, "   and the chance one of them is drawn"],
		[Color(0.7, 0.7, 0.7), "grey: the same move turned or mirrored,"],
		[Color.TRANSPARENT, "   so it shares one colour of bead"],
		[CHOSEN_COLOUR, "pink square: the move MENACE drew"],
		[MINIMAX_COLOUR, "green (M): what each square leads to with"],
		[Color.TRANSPARENT, "   perfect play, for whoever moves now"],
	] as Array[Array])
	_menace = MenacePlayer.load_published()
	# The youngest first: the manual check plays the 10-game machine, then the
	# 10,000-game one.
	age_index = 0
	_dice.seed = 1961
	new_game()


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		click_square(_square_at(get_local_mouse_position()))
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		_handle_key(key.keycode)


## Start again: an empty board, MENACE to move.
func new_game() -> void:
	_board = TicTacToeBoard.START
	_last_draw = {}
	_message = ""
	_refresh()


## Your move: a nought on `square`, if it is empty and it is your turn.
func click_square(square: int) -> void:
	_message = ""
	if square < 0 or TicTacToeBoard.winner(_board) != "":
		return
	if TicTacToeBoard.to_move(_board) != PERSON_SIDE:
		_message = "it is MENACE's turn: space draws its bead"
	elif _board[square] != TicTacToeBoard.EMPTY:
		_message = "that square is taken"
	else:
		_board = TicTacToeBoard.play(_board, square)
	_refresh()


## One decision. On MENACE's turn it draws a bead and plays it, as space does.
## On yours it plays your first empty square -- the stand-in for a person that
## lets a test, or somebody watching, step through a whole game.
func step_decision() -> void:
	if TicTacToeBoard.winner(_board) != "" or _menace_resigned():
		new_game()
	elif TicTacToeBoard.to_move(_board) == MENACE_SIDE:
		menace_moves(_dice.randf())
	else:
		click_square(TicTacToeBoard.moves(_board)[0])


## MENACE draws the bead `chance` lands on and plays it. With one square left
## the move is forced and Michie kept no box for it.
func menace_moves(chance: float) -> void:
	var moves: Array[int] = TicTacToeBoard.moves(_board)
	if moves.is_empty() or TicTacToeBoard.to_move(_board) != MENACE_SIDE:
		return
	var total: int = 0
	for beads_here: int in _menace.beads_for(age(), _board):
		total += beads_here
	var square: int = moves[0] if moves.size() == 1 else _menace.move_for(age(), _board, chance)
	_last_draw = {"chance": chance, "square": square, "board": _board, "age": age(),
			"forced": moves.size() == 1, "total": total, "bead": mini(floori(chance * total) + 1, total)}
	if square != -1:
		_board = TicTacToeBoard.play(_board, square)
	_refresh()


## What MENACE is reasoning with: the box, every empty square's beads and
## chance in the order they are laid out for the draw, the bead it last drew,
## and what perfect play makes of each square.
func decision_overlay() -> Dictionary:
	var looking_at: String = _deciding_board()
	var overlay: Dictionary = {"age": _deciding_age(), "box": TicTacToeBoard.canonical(looking_at)[0],
			"squares": squares_for(looking_at, _deciding_age()), "over": _is_over(),
			"pending": not _is_over() and TicTacToeBoard.to_move(_board) == MENACE_SIDE}
	if not _is_over():
		overlay["perfect"] = _perfect_play()
	if not _last_draw.is_empty():
		for key: String in ["chance", "bead", "total", "forced"]:
			overlay[key] = _last_draw[key]
		overlay["chosen"] = _last_draw["square"]
		overlay["drawn_at_age"] = _last_draw["age"]
	return overlay


# What perfect play makes of the board in front of the player to move.
func _perfect_play() -> Dictionary:
	var values: Dictionary = TicTacToeSolver.square_values(_board)
	return {"values": values, "best": TicTacToeSolver.best_squares(_board), "for": TicTacToeBoard.to_move(_board)}


## What each empty square holds for MENACE on `board`. With one square left
## there is no box: the move is forced, and the square says so.
func squares_for(board: String, at_age: int) -> Array[Dictionary]:
	var moves: Array[int] = TicTacToeBoard.moves(board)
	if moves.size() == 1:
		return [{"square": moves[0], "beads": 0, "probability": 1.0, "forced": true}] as Array[Dictionary]
	return _menace.squares_for(at_age, board)


## The games MENACE had played before the snapshot now playing.
func age() -> int:
	return _menace.ages[age_index] if not _menace.ages.is_empty() else 0


func _handle_key(keycode: Key) -> void:
	if keycode >= KEY_1 and keycode <= KEY_4:
		age_index = clampi(keycode - KEY_1, 0, maxi(0, _menace.ages.size() - 1))
	elif keycode == KEY_M:
		show_minimax = not show_minimax
	elif keycode == KEY_SPACE:
		menace_moves(_dice.randf())
	elif keycode == KEY_R:
		new_game()
	_refresh()


# The position MENACE's beads are about: the one in front of it on its turn,
# and the one it last drew from on yours or once the game is over, so its
# reasoning stays on show and a finished board never shows an empty box.
func _deciding_board() -> String:
	var menace_to_move: bool = TicTacToeBoard.to_move(_board) == MENACE_SIDE
	if _last_draw.is_empty() or (menace_to_move and not _is_over()):
		return _board
	return _last_draw["board"]


# The age whose beads are on show: the one playing now on MENACE's turn, and
# the one that drew the last move otherwise -- a draw made at 10 games shown
# beside the 10,000-game box used to name a square that box would not give.
func _deciding_age() -> int:
	return age() if _deciding_board() == _board or _last_draw.is_empty() else _last_draw["age"]


func _is_over() -> bool:
	return TicTacToeBoard.winner(_board) != "" or _menace_resigned()


func _menace_resigned() -> bool:
	return not _last_draw.is_empty() and _last_draw["square"] == -1


func _square_at(point: Vector2) -> int:
	var cell := Vector2i(floori(point.x / CELL), floori(point.y / CELL))
	if cell.x < 0 or cell.x > 2 or cell.y < 0 or cell.y > 2:
		return -1
	return cell.y * 3 + cell.x


func _refresh() -> void:
	if not is_node_ready():
		return
	queue_redraw()
	var overlay: Dictionary = decision_overlay()
	_status.text = TicTacToePanel.status(_board, overlay, age(), show_minimax, _message)
	_panel.text = TicTacToePanel.describe(overlay)


func _draw() -> void:
	TicTacToeView.draw_board(self, _board)
	var overlay: Dictionary = decision_overlay()
	if overlay["pending"]:
		TicTacToeView.draw_beads(self, overlay["squares"])
	if not _last_draw.is_empty() and _last_draw["square"] != -1:
		TicTacToeView.draw_chosen(self, _last_draw["square"])
	if show_minimax and overlay.has("perfect"):
		TicTacToeView.draw_perfect(self, overlay["perfect"])
	TicTacToeView.draw_winning_line(self, _board)
