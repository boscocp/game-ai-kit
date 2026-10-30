# The ai_rts_core page's minimal example, given a wall with one gap and
# units scattered over the map: the field must take several frames to
# build, and then every unit that follows its arrows must reach the goal,
# through the gap. The page shows the file's text, held equal by
# check_translations_docs.py.
extends GdUnitTestSuite

const EXAMPLE: Script = preload("res://test/ai_rts_core/flow_example.gd")
const GOAL: Vector2i = Vector2i(20, 8)
const GAP: Vector2i = Vector2i(12, 2)


# The example in an empty scene, with a wall down column 12 but for GAP.
func _map_with_a_wall() -> Node:
	var scene: Node = auto_free(Node.new())
	add_child(scene)
	var example: Node = EXAMPLE.new()
	scene.add_child(example)
	example.set_physics_process(false)
	var map: GakGridGraph = example.map
	for row: int in range(map.height):
		if Vector2i(GAP.x, row) != GAP:
			map.block(Vector2i(GAP.x, row))
	return example


func _frames_until_built(example: Node) -> int:
	var frames: int = 0
	while example.step_from(Vector2i(0, 0)) == Vector2i.ZERO and frames < 1000:
		example._physics_process(1.0 / 60.0)
		frames += 1
	return frames


func test_the_example_builds_its_field_over_several_frames() -> void:
	var example: Node = _map_with_a_wall()
	example.send_everyone_to(GOAL)
	assert_vector(example.step_from(Vector2i(0, 0))).is_equal(Vector2i.ZERO)
	assert_int(_frames_until_built(example)).is_between(2, 999)


func test_every_unit_reaches_the_goal_through_the_gap() -> void:
	var example: Node = _map_with_a_wall()
	example.send_everyone_to(GOAL)
	_frames_until_built(example)
	for start: Vector2i in [Vector2i(0, 0), Vector2i(3, 15), Vector2i(11, 9), Vector2i(23, 0)]:
		var cell: Vector2i = start
		var passed_the_gap: bool = start.x > GAP.x
		for _step: int in range(200):
			passed_the_gap = passed_the_gap or cell == GAP
			cell += example.step_from(cell)
		assert_vector(cell).override_failure_message("from %s" % start).is_equal(GOAL)
		assert_bool(passed_the_gap).is_true()
