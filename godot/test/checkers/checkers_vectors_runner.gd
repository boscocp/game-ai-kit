# Run the conformance vectors in spec/vectors/checkers against the GDScript
# checkers: `rules.json` against `CheckersRules`, `evaluation.json` against
# `CheckersEvaluation`. Python reads the same two files in `make test-python`,
# so the language that self-plays and the one the game is played in cannot
# disagree about a legal move or a score without one of them going red.
#
#     ./scripts/godot --headless --path godot -s res://test/checkers/checkers_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/checkers
#
# Exit codes: 0 every case passes, 1 a case failed, 2 the vectors could not
# be read -- which includes either file missing or holding no cases, because
# a conformance run that inspects nothing and reports success is the failure
# this repository is arranged against.
extends SceneTree

## The two files' cases, every field and its type, checked before anything
## reads them (T121): a cast that fails in a `-s` script is a SCRIPT ERROR
## the run survives, printing "0 failure(s)".
const RULES_SHAPE: Dictionary = {"cases": [{
	"name": VectorShape.TEXT, "rows": [VectorShape.TEXT], "to_move": VectorShape.TEXT, "moves": [VectorShape.TEXT],
	"crowns": [VectorShape.TEXT], "taken": [[VectorShape.TEXT]], "drawn": VectorShape.FLAG,
	"quiet_plies?": VectorShape.NUMBER,
}]}
const SCORES_SHAPE: Dictionary = {"cases": [{
	"name": VectorShape.TEXT, "rows": [VectorShape.TEXT], "player": VectorShape.TEXT,
	"weights": [VectorShape.NUMBER], "features": [VectorShape.NUMBER], "score": VectorShape.NUMBER,
}]}
## How far two floating-point scores may differ and still agree: the two
## languages add the same products in different orders.
const TOLERANCE: float = 1e-9
const SIDES: Dictionary = {"red": CheckersBoard.RED, "white": CheckersBoard.WHITE}


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		printerr("checkers_vectors_runner: give me the vectors directory after `--`")
		quit(2)
		return
	quit(_run(arguments[0]))


func _run(directory: String) -> int:
	var rule_cases: Array = _cases_in(_read_vector(directory + "/rules.json"), RULES_SHAPE, "rules.json")
	var score_cases: Array = _cases_in(_read_vector(directory + "/evaluation.json"), SCORES_SHAPE, "evaluation.json")
	if rule_cases.is_empty() or score_cases.is_empty():
		printerr("checkers_vectors_runner: rules.json and evaluation.json under %s must each have cases" % directory)
		return 2
	var failures: Array[String] = []
	for case: Dictionary in rule_cases:
		failures += check_rules(case)
	for case: Dictionary in score_cases:
		failures += check_score(case)
	for failure: String in failures:
		print(failure)
	print("checkers vectors: %d rule case(s), %d score case(s), %d failure(s)" % [
			rule_cases.size(), score_cases.size(), failures.size()])
	return 1 if not failures.is_empty() else 0


## What is wrong with one rules case: the legal moves in order, which of them
## crown, what each takes, and whether the position is drawn. Notation alone
## would pass a jump that forgot to crown.
static func check_rules(case: Dictionary) -> Array[String]:
	var board: CheckersBoard = _board_of(case["rows"], SIDES.get(case["to_move"], -1))
	board.quiet_plies = int(case.get("quiet_plies", 0))
	var legal: Array = CheckersRules.legal_moves(board)
	var crowning: Array = legal.filter(func(move: CheckersMove) -> bool: return move.crowns)
	var found: Dictionary = {"moves": legal.map(_notation_of), "crowns": crowning.map(_notation_of),
			"taken": legal.map(_taken_by), "drawn": CheckersRules.is_draw(board)}
	var failures: Array[String] = []
	for field: String in found:
		if found[field] != case[field]:
			failures.append("rules.json: %s -- %s %s, the vector says %s" % [case["name"], field, found[field], case[field]])
	return failures


## What is wrong with one evaluation case: the three counts, and the score.
static func check_score(case: Dictionary) -> Array[String]:
	var board: CheckersBoard = _board_of(case["rows"], CheckersBoard.RED)
	var player: int = SIDES.get(case["player"], -1)
	var weights: Array[float] = []
	weights.assign(case["weights"])
	var counts: Array[float] = CheckersEvaluation.features(board, player)
	var score: float = CheckersEvaluation.weighted(board, player, weights)
	var label: String = "evaluation.json: %s" % case["name"]
	if counts != Array(case["features"]).map(func(count: Variant) -> float: return float(count)):
		return ["%s -- counts %s, the vector says %s" % [label, counts, case["features"]]]
	if absf(score - float(case["score"])) > TOLERANCE:
		return ["%s -- scores %f, the vector says %f" % [label, score, case["score"]]]
	return []


static func _notation_of(move: CheckersMove) -> String:
	return move.notation()


static func _taken_by(move: CheckersMove) -> Array:
	return move.captured.map(CheckersMove.square_name)


static func _board_of(rows: Array, side: int) -> CheckersBoard:
	var lines: Array[String] = []
	lines.assign(rows)
	return CheckersBoard.from_rows(lines, side)


# The vector's cases, or [] when it has none or is not `shape`, said why.
func _cases_in(vector: Dictionary, shape: Dictionary, name: String) -> Array:
	var why: String = VectorShape.why_not(vector, shape, name)
	if why != "":
		printerr("checkers_vectors_runner: %s" % why)
		return []
	return vector["cases"]


# `JSON.new().parse()` rather than `JSON.parse_string()`, which prints an
# engine error of its own on a malformed file; see docs/godot/.
func _read_vector(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var reader := JSON.new()
	if reader.parse(file.get_as_text()) != OK:
		return {}
	return reader.data if reader.data is Dictionary else {}
