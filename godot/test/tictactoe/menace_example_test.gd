# The MENACE page's minimal example, loaded into an empty scene with the
# published beads: every move it makes must be an empty square, its chances
# must sum to one, and an older machine must be surer of its opening than a
# young one. The page shows the file's text, held equal by
# check_translations_docs.py.
extends GdUnitTestSuite

const EXAMPLE: Script = preload("res://test/tictactoe/menace_example.gd")


func _player() -> Node:
	var scene: Node = auto_free(Node.new())
	add_child(scene)
	var example: Node = EXAMPLE.new()
	scene.add_child(example)
	return example


func test_the_example_only_plays_empty_squares() -> void:
	var player: Node = _player()
	for board: String in [".........", "X...O....", "XO..O...X"]:
		for square: int in _fifty_moves(player, board):
			assert_bool(square == -1 or board[square] == ".").is_true()


# Fifty moves drawn on `board`, each with a fresh chance.
func _fifty_moves(player: Node, board: String) -> Array[int]:
	var squares: Array[int] = []
	for _draw: int in range(50):
		squares.append(player.move_for(board))
	return squares


func test_the_example_chances_sum_to_one() -> void:
	var player: Node = _player()
	var total: float = 0.0
	for chance: float in player.chances(".........").values():
		total += chance
	assert_float(total).is_equal_approx(1.0, 0.0001)


func test_an_older_machine_is_surer_of_its_opening() -> void:
	var player: Node = _player()
	player.age = 10
	var young: float = player.chances(".........").values().max()
	player.age = 10000
	var old: float = player.chances(".........").values().max()
	assert_float(old).is_greater(young)


func test_the_example_says_when_its_beads_are_missing() -> void:
	var player: Node = _player()
	assert_bool(player.has_beads()).is_true()
	assert_bool(MenacePlayer.load_published("res://no/such/beads.json").ages.is_empty()).is_true()
