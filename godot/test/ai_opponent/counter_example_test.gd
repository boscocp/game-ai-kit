# The ai_opponent page's minimal example, loaded into an empty scene and
# shown a player with a habit: it must learn the habit within the match,
# play what beats it, and know nothing before the player has moved. The
# page shows the file's text, held equal by check_translations_docs.py.
extends GdUnitTestSuite

const EXAMPLE: Script = preload("res://test/ai_opponent/counter_example.gd")


func _opponent() -> Node:
	var scene: Node = auto_free(Node.new())
	add_child(scene)
	var example: Node = EXAMPLE.new()
	scene.add_child(example)
	return example


func test_the_example_knows_nothing_before_the_player_moves() -> void:
	var opponent: Node = _opponent()
	for chance: float in opponent.expectation().values():
		assert_float(chance).is_equal_approx(1.0 / 3.0, 0.0001)


func test_the_example_beats_a_player_who_repeats_a_pattern() -> void:
	var opponent: Node = _opponent()
	for _repeat: int in range(6):
		for move: String in ["rock", "rock", "paper"]:
			opponent.player_played(move)
	# After "rock, paper" this player always plays rock: answer with paper.
	assert_str(opponent.counter()).is_equal("paper")
	opponent.player_played("rock")
	# After "paper, rock" comes rock again: still paper.
	assert_str(opponent.counter()).is_equal("paper")
	opponent.player_played("rock")
	# After "rock, rock" comes paper: answer with scissors.
	assert_str(opponent.counter()).is_equal("scissors")


func test_the_example_starts_empty_in_every_match() -> void:
	var first: Node = _opponent()
	for move: String in ["rock", "rock", "rock", "rock"]:
		first.player_played(move)
	var second: Node = _opponent()
	assert_float(second.expectation()["rock"]).is_equal_approx(1.0 / 3.0, 0.0001)
