# The ai_planning page's minimal example, asked for the open door from two
# starts: it must find the four steps from the door, the three from the
# table, nothing to do when the door is already open, and say plainly when
# there is no key. The page shows the file's text, held equal by
# check_translations_docs.py.
extends GdUnitTestSuite

const EXAMPLE: Script = preload("res://test/ai_planning/door_example.gd")
var open_door := PackedStringArray(["door_open"])


func _character() -> Node:
	var scene: Node = auto_free(Node.new())
	add_child(scene)
	var example: Node = EXAMPLE.new()
	scene.add_child(example)
	return example


func test_the_example_fetches_the_key_before_the_door() -> void:
	var character: Node = _character()
	assert_array(Array(character.steps(PackedStringArray(["at_door", "key_on_table"]), open_door))).is_equal([
		"walk to the table", "take the key", "walk to the door", "unlock the door",
	])
	assert_array(Array(character.steps(PackedStringArray(["at_table", "key_on_table"]), open_door))).is_equal([
		"take the key", "walk to the door", "unlock the door",
	])


func test_the_example_tells_done_from_impossible() -> void:
	var character: Node = _character()
	var done: PlanResult = character.plan_for(PackedStringArray(["door_open"]), open_door)
	var stuck: PlanResult = character.plan_for(PackedStringArray(["at_door"]), open_door)
	assert_bool(done.solved).is_true()
	assert_array(done.steps).is_empty()
	assert_bool(stuck.solved).is_false()
	assert_bool(stuck.gave_up).is_false()
