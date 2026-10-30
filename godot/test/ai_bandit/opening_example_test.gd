# The ai_bandit page's minimal example, loaded into an empty scene and played
# against a player who beats the rush and loses to the expansion: it must try
# every opening, settle on the one that wins, and start every match empty.
# The page shows the file's text, held equal by check_translations_docs.py.
extends GdUnitTestSuite

const EXAMPLE: Script = preload("res://test/ai_bandit/opening_example.gd")
## What each opening scores against this player.
const AGAINST_THIS_PLAYER: Dictionary = {"rush": 0.0, "turtle": 0.5, "expand": 1.0}


func _opponent() -> Node:
	var scene: Node = auto_free(Node.new())
	add_child(scene)
	var example: Node = EXAMPLE.new()
	scene.add_child(example)
	return example


func test_the_example_tries_every_opening_first() -> void:
	var opponent: Node = _opponent()
	var tried: Array[String] = []
	for round_number: int in range(3):
		var opening: String = opponent.next_opening()
		tried.append(opening)
		opponent.round_ended(AGAINST_THIS_PLAYER[opening])
	assert_array(tried).is_equal(["rush", "turtle", "expand"])


func test_the_example_settles_on_what_wins() -> void:
	var opponent: Node = _opponent()
	var played: Dictionary = {"rush": 0, "turtle": 0, "expand": 0}
	for round_number: int in range(60):
		var opening: String = opponent.next_opening()
		played[opening] += 1
		opponent.round_ended(AGAINST_THIS_PLAYER[opening])
	assert_int(played["expand"]).is_greater(played["turtle"] + played["rush"])
	var rows: Array[Dictionary] = opponent.worth()
	assert_float(rows[2]["mean"]).is_equal(1.0)


func test_the_example_starts_empty_in_every_match() -> void:
	var first: Node = _opponent()
	for round_number: int in range(5):
		first.round_ended(1.0)
	var second: Node = _opponent()
	for row: Dictionary in second.worth():
		assert_int(row["pulls"]).is_equal(0)
