# The board's decision interface is only worth having if the engine enforces
# it. Split from test/ai_core/interfaces_test.gd when the board left ai_core
# (T61); that file holds the same cases for GakPathfinder, and says why they exist:
# a forgotten override must not load, rather than return a legitimate-looking
# "hold".
extends GdUnitTestSuite

const FORGETFUL_POLICY: String = "extends DecisionPolicy\n"

const DUTIFUL_POLICY: String = """
extends DecisionPolicy


func choose(state: BoardState, unit_id: int) -> Move:
	var unit: Unit = state.unit_by_id(unit_id)
	return Move.new(unit_id, [] as Array[Vector2i]) if unit != null else Move.new(unit_id, [])
"""


func test_a_policy_that_implements_choose_loads() -> void:
	# The pathfinder had a dutiful twin and the policy did not, so nothing
	# proved an implementable DecisionPolicy exists.
	var dutiful := GDScript.new()
	dutiful.source_code = DUTIFUL_POLICY

	assert_int(dutiful.reload()).is_equal(OK)


func test_a_policy_that_forgets_choose_does_not_load() -> void:
	assert_int(await _refused_status(FORGETFUL_POLICY)).is_not_equal(OK)


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
