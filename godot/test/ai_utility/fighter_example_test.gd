# The ai_utility page's minimal example, loaded into an empty scene and
# asked in four situations: it must shoot, reload, take cover and patrol
# each when its percepts favour that most. The page shows the file's text,
# held equal by check_translations_docs.py.
extends GdUnitTestSuite

const EXAMPLE: Script = preload("res://test/ai_utility/fighter_example.gd")


func _fighter() -> Node:
	var scene: Node = auto_free(Node.new())
	add_child(scene)
	var example: Node = EXAMPLE.new()
	scene.add_child(example)
	return example


func test_the_example_does_what_its_percepts_favour_most() -> void:
	var fighter: Node = _fighter()
	assert_str(fighter.decide({"enemy_visible": 1, "ammo": 10, "health": 100})).is_equal("shoot")
	assert_str(fighter.decide({"enemy_visible": 1, "ammo": 0, "health": 100})).is_equal("reload")
	assert_str(fighter.decide({"enemy_visible": 1, "ammo": 10, "health": 20})).is_equal("take cover")
	assert_str(fighter.decide({"enemy_visible": 0, "ammo": 10, "health": 20})).is_equal("patrol")


func test_the_example_shows_every_score() -> void:
	var fighter: Node = _fighter()
	var scores: Dictionary = fighter.scores({"enemy_visible": 1, "ammo": 10, "health": 20})
	assert_float(scores["shoot"]).is_equal_approx(0.7, 0.0001)
	assert_float(scores["take cover"]).is_equal_approx(0.72, 0.0001)
	assert_float(scores["reload"]).is_equal(0.0)
	assert_float(scores["patrol"]).is_equal_approx(0.1, 0.0001)
