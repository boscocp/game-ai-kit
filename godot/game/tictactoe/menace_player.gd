## MENACE playing by the beads Python gave it, and never adding or taking one.
##
## Donald Michie's machine learned by changing bead counts after every game
## (see `python/gameaikit/menace/matchbox.py`). Here it only draws: the beads
## come from `menace_beads.json`, written by `gameaikit.menace.report`, at four
## ages -- after 10, 100, 1,000 and 10,000 games. Invariant 6 says no training
## at game time, and `check_no_training.py` refuses a bead count written in
## GDScript (N5) and a bead file that a fresh run would not write (N6).
##
## The draw is handed in as a number in [0, 1) rather than drawn here, so the
## same number gives the same move in Python and in Godot; their random
## generators differ, and `spec/vectors/menace/` holds the two to that.
class_name MenacePlayer
extends RefCounted

const BEAD_FILE: String = "res://game/tictactoe/menace_beads.json"
const EMPTY_BOX: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0]

## The ages the file holds, in games played, youngest first.
var ages: Array[int] = []

# age -> box -> nine bead counts, one per square of the box. Every level is
# read-only: measured on the pinned engine, a write through any path -- an
# index, `+=`, a copy of the reference, replacing a box, `clear()` -- is
# refused with a script error and changes nothing. That is invariant 6 held
# by the engine; `check_no_training.py` N5 only catches the common spellings.
var _snapshots: Dictionary = {}


func _init(published: Dictionary = {}) -> void:
	_snapshots = published
	_snapshots.make_read_only()
	for age: int in _snapshots:
		ages.append(age)
	ages.sort()


## Read every snapshot from the published file. Empty `ages` when it is
## missing or unreadable, which the scene reports rather than crashing on.
static func load_published(path: String = BEAD_FILE) -> MenacePlayer:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		return MenacePlayer.new()
	var published: Dictionary = (parser.data as Dictionary).get("snapshots", {})
	var by_age: Dictionary = {}
	for age: String in published:
		by_age[int(age)] = _read_only_boxes(published[age]["boxes"])
	return MenacePlayer.new(by_age)


## A player holding one box, for a test or a vector that brings its own beads.
static func with_box(box: String, beads: Array) -> MenacePlayer:
	return MenacePlayer.new({0: _read_only_boxes({box: beads})})


## The square of the box whose bead `chance` lands on, or -1 for an empty box.
##
## The beads are laid out square by square, lowest first, each square's
## stretch closed at its start and open at its end, and `chance` is a point
## along them. The same rule, line for line, as `Menace.draw` in Python.
static func draw(beads: Array[int], chance: float) -> int:
	var total: int = 0
	for count: int in beads:
		total += count
	if total == 0:
		return -1
	var point: float = chance * total
	var last_drawable: int = -1
	for square: int in range(beads.size()):
		if point < beads[square]:
			return square
		point -= beads[square]
		if beads[square] > 0:
			last_drawable = square
	return last_drawable


## The bead counts in the box for `board`, at `age`.
func beads_for(age: int, board: String) -> Array[int]:
	var box: String = TicTacToeBoard.canonical(board)[0]
	return (_snapshots.get(age, {}) as Dictionary).get(box, EMPTY_BOX)


## The real square MENACE plays on `board` at `age` when it draws `chance`, or
## -1 when the box is empty and it resigns.
func move_for(age: int, board: String, chance: float) -> int:
	var box_square: int = draw(beads_for(age, board), chance)
	return -1 if box_square == -1 else TicTacToeBoard.real_square(board, box_square)


## What each empty square of the real board holds for MENACE at `age`: its
## beads, its chance of being drawn, and -- for a square that is the same move
## as another one turned -- which square plays that move instead.
func squares_for(age: int, board: String) -> Array[Dictionary]:
	var box_and_turn: Array = TicTacToeBoard.canonical(board)
	var beads: Array[int] = beads_for(age, board)
	var total: int = 0
	for count: int in beads:
		total += count
	var found: Array[Dictionary] = []
	for box_square: int in range(9):
		if box_and_turn[0][box_square] != TicTacToeBoard.EMPTY:
			continue
		found.append(_square_entry(box_and_turn, box_square, beads, total))
	return found


func _square_entry(box_and_turn: Array, box_square: int, beads: Array[int], total: int) -> Dictionary:
	var symmetry: Array = TicTacToeBoard.SYMMETRIES[box_and_turn[1]]
	var stands_for: int = TicTacToeBoard.representative(box_and_turn[0], box_square)
	var count: int = beads[box_square] if stands_for == box_square else 0
	var entry: Dictionary = {"square": symmetry[box_square], "beads": count,
			"probability": float(count) / total if total > 0 else 0.0}
	if stands_for != box_square:
		entry["same_move_as"] = symmetry[stands_for]
	return entry


# Each box as a read-only Array[int], in a read-only table. Not a packed
# array: packed arrays are passed by reference and cannot be made read-only,
# so a caller holding one could change the beads -- a review did exactly that.
static func _read_only_boxes(published: Dictionary) -> Dictionary:
	var table: Dictionary = {}
	for key: String in published:
		var row: Array[int] = []
		row.assign(published[key])
		row.make_read_only()
		table[key] = row
	table.make_read_only()
	return table
