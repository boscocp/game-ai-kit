# The first test in the repository. It exists to prove the runner can go red,
# not because `2 + 2` is in doubt: a test runner that finds nothing also exits
# zero, and that is the kind of green this project does not accept.
#
# Replaced by real tests in T2. Until then, plant a failure here and watch
# `make test-godot` fail before trusting any other green.
extends GdUnitTestSuite


func test_runner_actually_runs_something() -> void:
	assert_int(2 + 2).is_equal(4)


func test_project_uses_the_compatibility_renderer() -> void:
	# Tier 2 of this project must run on integrated graphics. The gate
	# check_renderer.py asserts the same thing from outside; this asserts it
	# from inside a running engine, where a command-line override would show.
	var method: String = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	assert_str(method).is_equal("gl_compatibility")
