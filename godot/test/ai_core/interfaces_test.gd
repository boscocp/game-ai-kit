# The interface in ai_core is only worth having if the engine enforces it.
# DecisionPolicy, the board's, has the same cases in test/board/.
#
# These tests exist because the first version of those files did not enforce
# anything: they called push_error and returned a default, and the default each
# one returned was a value its own contract defines as a legitimate answer --
# an empty path means "no route" for a pathfinder and "hold" for a policy. A
# forgotten override was indistinguishable from an implementation that had
# thought about it and decided to do nothing.
#
# A subclass that forgets an @abstract method cannot be written in this file,
# because the file would then not parse. So the subclass is built at run time
# and the engine is asked what it makes of it. `assert_error` is how gdUnit4
# lets a test expect an engine error instead of being failed by one.
extends GdUnitTestSuite

const FORGETFUL_PATHFINDER: String = "extends Pathfinder\n"

const DUTIFUL_PATHFINDER: String = """
extends Pathfinder


func find_path(graph: GridGraph, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	return [to] if graph.contains(to) and from != to else []
"""

const INSTANTIATES_THE_INTERFACE: String = """
extends RefCounted


static func build() -> Pathfinder:
	return Pathfinder.new()
"""


func test_a_pathfinder_that_forgets_find_path_does_not_load() -> void:
	assert_int(await _refused_status(FORGETFUL_PATHFINDER)).is_not_equal(OK)


func test_a_pathfinder_that_implements_find_path_loads() -> void:
	var dutiful := GDScript.new()
	dutiful.source_code = DUTIFUL_PATHFINDER

	assert_int(dutiful.reload()).is_equal(OK)


func test_an_interface_cannot_be_instantiated_on_its_own() -> void:
	# An abstract class with no implementation is not a usable default, which
	# is the whole point: there is no "it sort of works" state to ship.
	assert_int(await _refused_status(INSTANTIATES_THE_INTERFACE)).is_not_equal(OK)


# Compile `source` at run time, expecting the engine to refuse it, and return
# the status it refused with.
#
# The status travels in an array because a GDScript lambda captures a local by
# *value*: assigning to a plain `var` inside the closure leaves the outer one
# at whatever it was, and the first version of this asserted on a variable that
# could never change. It read as a passing test of a working rule. An array is
# a reference, so appending to it reaches out of the closure.
func _refused_status(source: String) -> int:
	var captured: Array[int] = []
	await assert_error(func() -> void:
		var built := GDScript.new()
		built.source_code = source
		captured.append(built.reload())
	).is_runtime_error(any_string())
	return captured[0] if not captured.is_empty() else OK
