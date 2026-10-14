# Run the conformance vectors in spec/vectors/checkers against the GDScript
# checkers: `rules.json` against `CheckersRules`, `evaluation.json` against
# `CheckersEvaluation`. Python reads the same two files in `make test-python`,
# so the language that self-plays and the one the game is played in cannot
# disagree about a legal move or a score without one of them going red.
#
#     ./scripts/godot --headless --path godot -s res://test/checkers_vectors_runner.gd \
#         -- /absolute/path/to/spec/vectors/checkers
#
# Exit codes: 0 every case passes, 1 a case failed, 2 the vectors could not
# be read -- which includes either file missing or holding no cases, because
# a conformance run that inspects nothing and reports success is the failure
# this repository is arranged against.
extends SceneTree

const RULE_FIELDS: Array[String] = ["name", "rows", "to_move", "moves"]
const SCORE_FIELDS: Array[String] = ["name", "rows", "player", "weights", "features", "score"]
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
	var rule_cases: Array = _cases_in(_read_vector(directory + "/rules.json"), RULE_FIELDS)
	var score_cases: Array = _cases_in(_read_vector(directory + "/evaluation.json"), SCORE_FIELDS)
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


## What is wrong with one rules case: the legal moves, in order, as notation.
static func check_rules(case: Dictionary) -> Array[String]:
	var board: CheckersBoard = _board_of(case["rows"], SIDES.get(case["to_move"], -1))
	var moves: Array = CheckersRules.legal_moves(board).map(func(move: CheckersMove) -> String: return move.notation())
	if moves != case["moves"]:
		return ["rules.json: %s -- moves %s, the vector says %s" % [case["name"], moves, case["moves"]]]
	return []


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


static func _board_of(rows: Array, side: int) -> CheckersBoard:
	var lines: Array[String] = []
	lines.assign(rows)
	return CheckersBoard.from_rows(lines, side)


# The vector's cases, or [] when it has none or one is missing a field.
func _cases_in(vector: Dictionary, fields: Array[String]) -> Array:
	var cases: Variant = vector.get("cases")
	if not cases is Array:
		return []
	for case: Variant in cases:
		if not case is Dictionary or not (case as Dictionary).has_all(fields):
			return []
	return cases


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
