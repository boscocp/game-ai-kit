# What the engine actually loaded, asserted from inside the engine.
#
# This was `smoke_test.gd`, whose job was to prove the runner could go red
# before any real code existed. T2 is that code and the canary is retired: the
# board now has suites of its own that fail when it is wrong. (An earlier
# version of this comment put a number on that, counting every test in the
# repository including the two below, which pass whatever the board does. A
# number in a comment is a number that goes stale on the next commit.)
#
# What survives here is the one assertion a test can make and an external gate
# cannot: what the *running* engine believes, after every command-line flag has
# had its say.
extends GdUnitTestSuite


func test_project_uses_the_compatibility_renderer() -> void:
	# Tier 2 of this project must run on integrated graphics. The gate
	# check_renderer.py asserts the same thing from outside, by reading
	# project.godot; this asserts it from inside, where an override would show.
	var method: String = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	assert_str(method).is_equal("gl_compatibility")


func test_the_main_scene_is_the_board() -> void:
	# A main scene that points at nothing is how `make test-godot` popped a
	# desktop dialog under --headless in wave 2. It is set now, and this is the
	# assertion that keeps it set.
	var scene: String = ProjectSettings.get_setting("application/run/main_scene")
	assert_str(scene).is_equal("res://game/main.tscn")
