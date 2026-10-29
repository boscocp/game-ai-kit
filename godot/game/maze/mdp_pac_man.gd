## Pac-Man played by a policy that value iteration computed in Python: a
## controller that looks its move up, and never learns anything.
##
## `gameaikit.mdp` (T98) solved the maze as a Markov decision process -- a
## state is Pac-Man's cell, Blinky's cell and heading, and the pellets left;
## Blinky's next move is the chance -- and wrote two tables to `data/maze/`:
## each state's value and its best move. This reads both and does
## arithmetic on the index (`mdp.json`'s "about" gives the layout). It is
## the shape of every learned thing in the kit (invariant 6): Python solves
## and publishes, GDScript reads; `check_no_training.py`'s N15 holds that
## nothing here writes the tables, and that they are what Python makes.
##
## What the demo draws is read from the same tables: the value of every cell
## for Pac-Man with Blinky and the pellets as they are, the policy's arrow on
## each, and the one-step lookahead behind the move he takes -- each move's
## Q-value, the reward plus the discounted value of where it leads, weighted
## by Blinky's chances (`MazeGhost.chances`). That lookahead is a reading of
## the published values, not an update of them.
##
## Complexity: a lookup is constant; the lookahead, four moves by at most
## three of Blinky's ways.
##
## When not to use it: outside the regime it was solved for -- Blinky alone,
## chasing for ever. With Pinky, or the arcade's schedule, the state no
## longer says what happens next, and the table answers a different game.
class_name MdpPacMan
extends RefCounted

const MDP_FILE: String = "res://game/maze/mdp.json"
## Where Python publishes, beside the project: `res://../data/maze`.
const PUBLISHED_FOLDER: String = "../data/maze"
const VALUES_FILE: String = "values.json"
const POLICY_FILE: String = "policy.json"
## The policy's letters, as the published file writes a move.
const LETTERS: Dictionary = {"u": "up", "l": "left", "d": "down", "r": "right"}  # not shown: identifiers

static var _spec: Dictionary = {}
static var _cells: Array[Vector2i] = []
static var _values := PackedFloat64Array()
static var _letters: String = ""


## The MDP's numbers: the schedule it was solved for, its ghosts, rewards
## and discount -- `mdp.json`, a copy of `spec/maze/mdp.json`.
static func spec() -> Dictionary:
	if _spec.is_empty():
		_spec = _read(MDP_FILE)
	return _spec


## Whether the published tables were found and read.
static func is_published() -> bool:
	_load_tables()
	return not _letters.is_empty()


## Pac-Man's move in `game`: the published policy's, for the state as it is.
func move_for(game: MazeGame) -> String:
	var letter: String = policy_letter(slot_of(game))
	if not LETTERS.has(letter):
		push_error("MdpPacMan: no published move for this state")  # not shown: for the log
		return game.facing
	return LETTERS[letter]


## The published letter at `slot`, "." where no state is.
static func policy_letter(slot: int) -> String:
	_load_tables()
	if slot < 0 or slot >= _letters.length():
		return "."
	return _letters[slot]


## The published value at `slot`, NAN where no state is.
static func value_at(slot: int) -> float:
	_load_tables()
	if slot < 0 or slot >= _values.size():
		return NAN
	return _values[slot]


## The slot of `game`'s state in the published tables.
static func slot_of(game: MazeGame) -> int:
	var blinky: MazeGhost = game.ghosts[0]
	return slot(game.pacman, blinky.cell, blinky.heading, pellet_bits(game.pellets))


## A state's slot: ((pacman x cells + ghost) x 4 + heading) x 16 + pellets.
static func slot(pacman: Vector2i, ghost: Vector2i, heading: String, pellets: int) -> int:
	if _cells.is_empty():
		_cells = MazeRules.floor_cells()
	var cells: Array[Vector2i] = _cells
	var headings: Array = MazeRules.rules()["tie_order"]
	var row: int = (cells.find(pacman) * cells.size() + cells.find(ghost)) * headings.size() + headings.find(heading)
	return row * (1 << MazeRules.maze()["pellets"].size()) + pellets


## The pellets left, as bits: pellet i of `maze.json` is bit i.
static func pellet_bits(pellets: Array[Vector2i]) -> int:
	var bits: int = 0
	var laid: Array = MazeRules.maze()["pellets"]
	for index: int in range(laid.size()):
		if MazeRules.cell_of(laid[index]) in pellets:
			bits |= 1 << index
	return bits


## Each of Pac-Man's four moves in `game`, in tie order, with its Q-value
## over the published values: {move, q, chosen}. The chosen one is the
## policy's.
func lookahead(game: MazeGame) -> Array[Dictionary]:
	var blinky: MazeGhost = game.ghosts[0]
	var ways: Array[Dictionary] = blinky.ways(blinky.target(MazeRules.CHASE, game.pacman, game.facing))
	var chances: Dictionary = MazeGhost.chances(ways, MazeRules.CHASE)
	var chosen: String = move_for(game)
	var found: Array[Dictionary] = []
	for move: String in MazeRules.rules()["tie_order"]:
		found.append({"move": move, "q": q_value(game, move, chances), "chosen": move == chosen})
	return found


## What `move` is worth in `game`: over Blinky's ways, the chance of each
## times the reward of the step plus the discounted value of where it leads.
static func q_value(game: MazeGame, move: String, chances: Dictionary) -> float:
	var rewards: Dictionary = spec()["rewards"]
	var blinky: MazeGhost = game.ghosts[0]
	var after: Vector2i = game.pacman
	if MazeRules.is_open(MazeRules.moved(game.pacman, move)):
		after = MazeRules.moved(game.pacman, move)
	if after == blinky.cell:
		return float(rewards["step"]) + float(rewards["caught"])
	var reward: float = float(rewards["step"])
	var left: int = pellet_bits(game.pellets)
	var eaten: int = pellet_bits([after] as Array[Vector2i])
	if (left & eaten) != 0:
		reward += float(rewards["pellet"])
		left &= ~eaten
		if left == 0:
			return reward + float(rewards["cleared"])
	var worth: float = 0.0
	for way: String in chances:
		var ghost_after: Vector2i = MazeRules.moved(blinky.cell, way)
		var future: float = 0.0
		var paid: float = reward + float(rewards["caught"])
		if ghost_after != after:
			future = value_at(slot(after, ghost_after, way, left))
			paid = reward
		worth += float(chances[way]) * (paid + float(spec()["discount"]) * future)
	return worth


## For every floor cell, its value with Pac-Man standing there and Blinky
## and the pellets as in `game`: the heat map. A cell no state has (Blinky's,
## a pellet's) is left out.
static func value_map(game: MazeGame) -> Dictionary:
	var blinky: MazeGhost = game.ghosts[0]
	var bits: int = pellet_bits(game.pellets)
	var found: Dictionary = {}
	for cell: Vector2i in MazeRules.floor_cells():
		var slot_here: int = slot(cell, blinky.cell, blinky.heading, bits)
		if not is_nan(value_at(slot_here)):
			found[cell] = {"value": value_at(slot_here), "move": LETTERS.get(policy_letter(slot_here), "")}
	return found


static func _load_tables() -> void:
	if not _letters.is_empty():
		return
	var folder: String = ProjectSettings.globalize_path("res://").path_join(PUBLISHED_FOLDER).simplify_path()
	var values: Dictionary = _read(folder.path_join(VALUES_FILE))
	var policy: Dictionary = _read(folder.path_join(POLICY_FILE))
	if values.is_empty() or policy.is_empty():
		return
	var scale: float = float(values["scale"])
	for row: Array in values["values"]:
		for value: Variant in row:
			_values.append(NAN if value == null else float(value) / scale)
	_letters = "".join(PackedStringArray(policy["actions"]))


# `JSON.new().parse()`, not `parse_string()`, which prints an engine error of
# its own on a bad file (docs/godot/reading-json-in-godot.md).
static func _read(path: String) -> Dictionary:
	var reader := JSON.new()
	if reader.parse(FileAccess.get_file_as_string(path)) != OK or not reader.data is Dictionary:
		push_error("MdpPacMan: %s could not be read" % path)  # not shown: for the log
		return {}
	return reader.data
