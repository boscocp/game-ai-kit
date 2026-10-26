# The ai_steering page's minimal example, loaded into an empty scene and
# stepped through ten seconds of physics frames by hand: it must come to
# rest on its target. The page shows the file's text, held equal by
# check_translations_docs.py.
extends GdUnitTestSuite

const EXAMPLE: Script = preload("res://test/ai_steering/arrive_example.gd")
const FRAME: float = 1.0 / 60.0
const FRAMES: int = 600


func test_the_example_drives_to_its_target_and_stops() -> void:
	var scene: Node = auto_free(Node.new())
	add_child(scene)
	var example: Node2D = EXAMPLE.new()
	scene.add_child(example)
	# Stepped here, not by the engine, so the run takes no wall-clock time
	# and every frame is exactly one sixtieth of a second.
	example.set_physics_process(false)
	for frame: int in range(FRAMES):
		example._physics_process(FRAME)
	var target: Vector2 = example.get("target")
	var vehicle: SteeringVehicle = example.get("vehicle")
	assert_float(example.position.distance_to(target)).is_less(1.0)
	assert_float(vehicle.speed()).is_less(1.0)
