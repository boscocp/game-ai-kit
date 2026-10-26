# The learned-evaluation page's minimal example, given the weights the kit
# published for checkers: it must score a position exactly as the checkers
# game's own evaluation does with those weights, and refuse a file that is
# not one. The page shows the file's text, held equal by
# check_translations_docs.py.
extends GdUnitTestSuite

const EXAMPLE: Script = preload("res://test/checkers/evaluation_example.gd")


# The counts the checkers game takes of `board` for `player`, by name.
func _counts(board: CheckersBoard, player: int) -> Dictionary:
	var values: Array[float] = CheckersEvaluation.features(board, player)
	var by_name: Dictionary = {}
	for index: int in range(values.size()):
		by_name[CheckersEvaluation.FEATURES[index]] = values[index]
	return by_name


func test_the_example_scores_as_the_checkers_game_does() -> void:
	var evaluation: RefCounted = EXAMPLE.new(CheckersWeights.PATH)
	assert_bool(evaluation.is_ready()).is_true()
	var board: CheckersBoard = CheckersBoard.from_rows([
		". w . w . . . .",
		". . . . . . . .",
		". . . w . . . .",
		". . . . . . . .",
		". . . . . r . .",
		". . . . . . . .",
		". . . R . r . r",
		". . . . . . . .",
	] as Array[String], CheckersBoard.WHITE)
	for player: int in [CheckersBoard.RED, CheckersBoard.WHITE]:
		var theirs: float = CheckersEvaluation.weighted(board, player, CheckersWeights.learned())
		assert_float(evaluation.score(_counts(board, player))).is_equal_approx(theirs, 0.000001)


func test_the_example_refuses_a_file_that_is_not_weights() -> void:
	var evaluation: RefCounted = EXAMPLE.new("res://test/checkers/no_such_file.json")
	assert_bool(evaluation.is_ready()).is_false()
