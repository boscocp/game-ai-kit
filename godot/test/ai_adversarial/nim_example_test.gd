# The ai_adversarial page's minimal example, asked for a move from several
# piles: it must leave its opponent a multiple of four, which is the known
# winning play of this Nim, and agree with plain minimax. The page shows the
# file's text, held equal by check_translations_docs.py.
extends GdUnitTestSuite

const EXAMPLE: Script = preload("res://test/ai_adversarial/nim_example.gd")


func test_the_example_leaves_a_multiple_of_four() -> void:
	var game: AdversarialGame = EXAMPLE.new()
	for sticks: int in [5, 6, 7, 9, 10, 11, 13]:
		var take: int = game.best_take(sticks)
		assert_int((sticks - take) % 4).override_failure_message(
			"from %d it took %d" % [sticks, take]).is_equal(0)


func test_the_example_takes_the_last_sticks_when_it_can() -> void:
	var game: AdversarialGame = EXAMPLE.new()
	assert_int(game.best_take(3)).is_equal(3)
	assert_int(game.best_take(1)).is_equal(1)


func test_alpha_beta_agrees_with_minimax_on_the_example() -> void:
	var game: AdversarialGame = EXAMPLE.new()
	var pile: RefCounted = EXAMPLE.Pile.new(10, 0)
	var pruned: AdversarialResult = AlphaBetaSearch.new().search(game, pile, 10)
	var plain: AdversarialResult = MinimaxSearch.new().search(game, pile, 10)
	assert_that(pruned.action).is_equal(plain.action)
	assert_float(pruned.value).is_equal(plain.value)
	assert_int(pruned.positions).is_less(plain.positions)
