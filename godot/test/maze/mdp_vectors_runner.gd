# Run the conformance vectors in spec/vectors/mdp against `MdpPacMan`.
#
# Each case is a maze state -- Pac-Man's cell, Blinky's cell and heading,
# the pellets left -- with its value, the four moves' Q-values and the best
# move, from `spec/vectors/mdp/derive.py`'s own value iteration. Set into a
# game in the MDP's regime, the state's published value, the published
# policy's move and the lookahead over the published values must agree with
# the case, within the file's tolerance. The Python half is
# `python/tests/test_mdp_vectors.py`.
#
#     ./scripts/godot --headless --path godot -s res://test/maze/mdp_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/mdp
#
# Exit codes: 0 every case matches, 1 one did not, 2 the vectors or the
# published tables could not be read -- which includes finding no case.
extends SceneTree

const VECTOR_FILE: String = "ten-states.json"
## Every field this runner reads and its type, checked before it reads any
## (T121): a cast that fails in a `-s` script is a SCRIPT ERROR the run
## survives.
const SHAPE: Dictionary = {
	"tolerance": VectorShape.NUMBER,
	"cases": [{"name": VectorShape.TEXT, "pacman": [VectorShape.NUMBER], "ghost": [VectorShape.NUMBER],
			"heading": VectorShape.TEXT, "pellets": [[VectorShape.NUMBER]], "value": VectorShape.NUMBER,
			"action": VectorShape.TEXT, "q": {"*": VectorShape.NUMBER}}],
}


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("mdp_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	quit(_run(arguments[0].path_join(VECTOR_FILE)))


func _run(path: String) -> int:
	var document: Dictionary = _read(path)
	var why: String = VectorShape.why_not(document, SHAPE, path)
	if why != "":
		printerr("mdp_vectors_runner: %s" % why)
		return 2
	var cases: Array = document["cases"]
	if cases.is_empty() or not MdpPacMan.is_published():
		printerr("mdp_vectors_runner: no cases in %s, or no published tables" % path)
		return 2
	var failures: Array[String] = []
	for one: Dictionary in cases:
		failures += check_case(one, float(document["tolerance"]))
	for failure: String in failures:
		print(failure)
	print("mdp vectors: %d case(s), %d failure(s)" % [cases.size(), failures.size()])
	return 1 if not failures.is_empty() else 0


## What differs between the published tables, read by `MdpPacMan`, and one case.
static func check_case(one: Dictionary, tolerance: float) -> Array[String]:
	var game: MazeGame = state_of(one)
	var failures: Array[String] = []
	var value: float = MdpPacMan.value_at(MdpPacMan.slot_of(game))
	if is_nan(value) or absf(value - float(one["value"])) > tolerance:
		failures.append("%s: value %s, the vector says %s" % [one["name"], value, one["value"]])
	var mdp := MdpPacMan.new()
	if mdp.move_for(game) != one["action"]:
		failures.append("%s: the policy moves %s, the vector says %s" % [one["name"], mdp.move_for(game), one["action"]])
	for move: Dictionary in mdp.lookahead(game):
		var wanted: float = float(one["q"][move["move"]])
		if is_nan(move["q"]) or absf(move["q"] - wanted) > tolerance:
			failures.append("%s: %s is worth %.4f, the vector says %.3f" % [one["name"], move["move"], move["q"], wanted])
	return failures


## A game in the MDP's regime, standing in the case's state.
static func state_of(one: Dictionary) -> MazeGame:
	var game := MazeGame.new(1, MdpPacMan.spec()["ghosts"], MdpPacMan.spec()["schedule"])
	game.pacman = MazeRules.cell_of(one["pacman"])
	var left: Array[Vector2i] = []
	for pair: Array in one["pellets"]:
		left.append(MazeRules.cell_of(pair))
	game.pellets = left
	game.ghosts[0].cell = MazeRules.cell_of(one["ghost"])
	game.ghosts[0].heading = one["heading"]
	return game


# `JSON.new().parse()` rather than `JSON.parse_string()`, which prints an
# engine error of its own on a malformed file; see docs/godot/.
func _read(path: String) -> Dictionary:
	var reader := JSON.new()
	if reader.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return reader.data if reader.data is Dictionary else {}
