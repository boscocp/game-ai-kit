# The ai_constraints page's minimal example, loaded into an empty scene: every
# placement it returns keeps every rule, a seed is one placement, and the
# seeds between them use more than one. The page shows the file's text, held
# equal by check_translations_docs.py.
extends GdUnitTestSuite

const EXAMPLE: Script = preload("res://test/ai_constraints/rooms_example.gd")


func _dungeon() -> Node:
	var scene: Node = auto_free(Node.new())
	add_child(scene)
	var example: Node = EXAMPLE.new()
	scene.add_child(example)
	return example


func test_every_placement_keeps_every_rule() -> void:
	var dungeon: Node = _dungeon()
	for seed_value: int in range(1, 30):
		var placed: Dictionary = dungeon.place(seed_value)
		var key: int = EXAMPLE.ROOMS.find(placed["key"])
		var chest: int = EXAMPLE.ROOMS.find(placed["chest"])
		var guard: int = EXAMPLE.ROOMS.find(placed["guard"])
		assert_bool(key < chest and absi(guard - chest) <= 1 and guard != key).is_true()
		assert_bool([key, chest, guard].has(3)).is_true()


func test_a_seed_is_one_placement_and_seeds_differ() -> void:
	var dungeon: Node = _dungeon()
	assert_dict(dungeon.place(4)).is_equal(dungeon.place(4))
	var seen: Dictionary = {}
	for seed_value: int in range(1, 30):
		seen[str(dungeon.place(seed_value))] = true
	assert_int(seen.size()).is_greater(1)
