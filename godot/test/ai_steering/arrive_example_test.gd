# The ai_steering page's minimal example, loaded into an empty scene and
# stepped through ten seconds of physics frames by hand: it must come to
# rest on its target, from wherever it was placed. The page shows the
# file's text, held equal by check_translations_docs.py.
extends GdUnitTestSuite

const EXAMPLE: Script = preload("res://test/ai_steering/arrive_example.gd")
const FRAME: float = 1.0 / 60.0
const FRAMES: int = 600


# The example placed at `start`, in an empty scene, run for FRAMES frames.
func _driven_from(start: Vector2) -> Node2D:
	var scene: Node = auto_free(Node.new())
	add_child(scene)
	var example: Node2D = EXAMPLE.new()
	example.position = start
	scene.add_child(example)
	# Stepped here, not by the engine, so the run takes no wall-clock time
	# and every frame is exactly one sixtieth of a second.
	example.set_physics_process(false)
	for frame: int in range(FRAMES):
		example._physics_process(FRAME)
	return example


func test_the_example_drives_to_its_target_and_stops() -> void:
	var example: Node2D = _driven_from(Vector2.ZERO)
	var target: Vector2 = example.get("target")
	var vehicle: SteeringVehicle = example.get("vehicle")
	assert_float(example.position.distance_to(target)).is_less(1.0)
	assert_float(vehicle.speed()).is_less(1.0)


func test_the_example_starts_where_it_was_placed() -> void:
	var example: Node2D = auto_free(EXAMPLE.new())
	example.position = Vector2(500, 40)
	add_child(example)
	# Before any frame: the vehicle stands where the node does, not at the
	# origin, so the first frame does not teleport it.
	var vehicle: SteeringVehicle = example.get("vehicle")
	assert_vector(vehicle.position).is_equal(Vector2(500, 40))


func test_the_example_arrives_from_away_from_the_origin() -> void:
	var example: Node2D = _driven_from(Vector2(500, 40))
	var target: Vector2 = example.get("target")
	assert_float(example.position.distance_to(target)).is_less(1.0)
