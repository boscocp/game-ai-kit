# The squad's positions for MCTS (T87), spec/squad/positions.json, against
# `SquadSearchGame` and `MonteCarloSearch`: on each position, after its
# iterations from its seed, the root's visits must be the file's, answer for
# answer. The Python half is `python/tests/test_squad_search.py`, on the
# same file; both run in `make test-squad-search-vectors`. The positions are
# the squad's, not the addon's: `ai_adversarial` never sees a squad.
#
# The file's map must also be the tactical map, so the two languages cannot
# agree with each other on a board the game no longer plays.
#
#     ./scripts/godot --headless --path godot -s res://test/squad/squad_search_vectors_runner.gd \
#         -- /absolute/path/to/spec/squad/positions.json
#
# Exit codes: 0 every position's visits match, 1 one did not, 2 the file
# could not be read -- which includes one with no positions in it.
extends SceneTree

## Every field this runner reads and its type, checked before it reads any
## (T121): a cast that fails in a `-s` script is a SCRIPT ERROR the run
## survives, printing "0 failure(s)". A piece, and an answer with its visits,
## mix numbers and names.
const SHAPE: Dictionary = {
	"about": [VectorShape.TEXT], "map": [VectorShape.TEXT],
	"positions": [{"name": VectorShape.TEXT, "turn": VectorShape.NUMBER, "to_move": VectorShape.NUMBER,
			"acting": VectorShape.NUMBER, "phase": VectorShape.TEXT, "waiting": [VectorShape.NUMBER],
			"pieces": [[VectorShape.ANY]], "seed": VectorShape.NUMBER, "iterations": VectorShape.NUMBER,
			"visits": [[VectorShape.ANY]], "decision": VectorShape.TEXT}],
}


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("squad_search_vectors_runner: give me the path of positions.json after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(path: String) -> int:
	var written: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var why: String = VectorShape.why_not(written, SHAPE, path)
	if why != "" or (written["positions"] as Array).is_empty():
		printerr("squad_search_vectors_runner: %s" % (why if why != "" else path + " holds no positions"))
		return 2
	var failures: Array[String] = map_drifted(written["map"])
	for position: Dictionary in written["positions"]:
		failures += check_position(position)
	for failure: String in failures:
		print(failure)
	print("squad search vectors: %d position(s), %d failure(s)" % [written["positions"].size(), failures.size()])
	return 1 if not failures.is_empty() else 0


## Nothing when `rows` is the tactical map; otherwise what is wrong.
static func map_drifted(rows: Array) -> Array[String]:
	if JSON.stringify(rows) != JSON.stringify(SquadScenario.rows()):
		return ["positions.json's map is not the tactical map"]
	return []


## Nothing when the search's root on `position` is the file's; otherwise the
## first answer whose visits differ, or the decision when only that does.
static func check_position(position: Dictionary) -> Array[String]:
	var found: Array = root_visits(position)
	var wanted: Array = position["visits"]
	if found.size() != wanted.size():
		return ["%s: %d answers at the root, the file has %d" % [position["name"], found.size(), wanted.size()]]
	for index: int in range(found.size()):
		if found[index][0] != wanted[index][0] or found[index][1] != int(wanted[index][1]):
			return ["%s: answer %d is %s, the file has %s" % [position["name"], index, found[index], wanted[index]]]
	var decision: String = SquadSearchGame.described(_searched(position).action)
	if decision != position["decision"]:
		return ["%s: decided %s, the file has %s" % [position["name"], decision, position["decision"]]]
	return []


## `[answer, visits]` for every answer at the root, in the game's order.
static func root_visits(position: Dictionary) -> Array:
	var found: Array = []
	for entry: Dictionary in _searched(position).considered:
		found.append([SquadSearchGame.described(entry["action"]), entry["visits"]])
	return found


## The root question `position` writes, on a board built from its pieces.
static func root(position: Dictionary) -> SquadSearchGame.Position:
	var types: Dictionary = SquadTable.unit_types()
	var graphs: Dictionary = TacticalRules.graphs_from(SquadScenario.rows())
	var units: Array[Unit] = []
	for piece: Array in position["pieces"]:
		units.append(Unit.new(int(piece[0]), int(piece[1]), Vector2i(int(piece[3]), int(piece[4])), int(piece[5]),
			int(piece[6]), types[piece[2]]))
	var board := BoardState.new(graphs[UnitType.GROUND], units, int(position["to_move"]), int(position["turn"]))
	board.movement_graphs = {TacticalRules.WATER_MOVER: graphs[TacticalRules.WATER_MOVER]}
	var waiting: Array[int] = []
	for unit_id: Variant in position["waiting"]:
		waiting.append(int(unit_id))
	var phase: int = SquadSearchGame.WALK if position["phase"] == "walk" else SquadSearchGame.SHOOT
	return SquadSearchGame.question(board, int(position["acting"]), phase, waiting)


static func _searched(position: Dictionary) -> MctsResult:
	var search := MonteCarloSearch.new(SquadSearchGame.new(), root(position), int(position["seed"]),
		MctsSquad.exploration(), MctsSquad.playout_limit())
	return search.step(int(position["iterations"]))
