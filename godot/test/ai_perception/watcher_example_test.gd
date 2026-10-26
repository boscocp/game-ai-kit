# The ai_perception page's minimal example, placed away from the origin in
# an empty scene and stepped by hand: it must grow alert at what stands in
# front of it, ignore what stands behind it, and calm down through every
# phase once the target is gone. The page shows the file's text, held equal
# by check_translations_docs.py.
extends GdUnitTestSuite

const EXAMPLE: Script = preload("res://test/ai_perception/watcher_example.gd")
const FRAME: float = 1.0 / 60.0
const GUARD_AT: Vector2 = Vector2(400, -200)


# The guard at GUARD_AT facing along +x, and a target at `target_at`.
func _guard_watching(target_at: Vector2) -> Node2D:
	var scene: Node = auto_free(Node.new())
	add_child(scene)
	var guard: Node2D = EXAMPLE.new()
	guard.position = GUARD_AT
	var target := Node2D.new()
	target.position = target_at
	scene.add_child(guard)
	scene.add_child(target)
	guard.target = target
	guard.set_physics_process(false)
	return guard


func _run(guard: Node2D, seconds: float) -> void:
	for frame: int in range(roundi(seconds / FRAME)):
		guard._physics_process(FRAME)


func test_the_example_grows_alert_at_what_is_in_front() -> void:
	var guard: Node2D = _guard_watching(GUARD_AT + Vector2(200, 50))
	_run(guard, 1.0)
	assert_str(guard.phase()).is_equal("suspicious")
	_run(guard, 1.0)
	assert_str(guard.phase()).is_equal("alert")


func test_the_example_ignores_what_is_behind_or_out_of_reach() -> void:
	var behind: Node2D = _guard_watching(GUARD_AT + Vector2(-100, 0))
	var far: Node2D = _guard_watching(GUARD_AT + Vector2(400, 0))
	_run(behind, 3.0)
	_run(far, 3.0)
	assert_str(behind.phase()).is_equal("calm")
	assert_str(far.phase()).is_equal("calm")


func test_the_example_turns_with_its_node() -> void:
	var guard: Node2D = _guard_watching(GUARD_AT + Vector2(-100, 0))
	guard.rotation = PI
	assert_bool(guard.sees_target()).is_true()


func test_the_example_calms_down_through_every_phase() -> void:
	var guard: Node2D = _guard_watching(GUARD_AT + Vector2(100, 0))
	_run(guard, 3.0)
	guard.target.position = GUARD_AT + Vector2(-100, 0)
	_run(guard, 2.0)
	# Out of sight, the caution floor keeps it suspicious for five seconds...
	assert_str(guard.phase()).is_equal("suspicious")
	_run(guard, 3.0)
	assert_str(guard.phase()).is_equal("suspicious")
	# ...and then it falls to calm.
	_run(guard, 5.0)
	assert_str(guard.phase()).is_equal("calm")
