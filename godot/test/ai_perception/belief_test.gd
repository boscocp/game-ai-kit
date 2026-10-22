# TargetMemory and BeliefMap, one claim per test. The claims over many
# generated graphs are in test/infiltration/awareness_properties.gd.
extends GdUnitTestSuite


# 0 - 1 - 2 - 3, a corridor.
func _corridor() -> Array[PackedInt32Array]:
	return [PackedInt32Array([1]), PackedInt32Array([0, 2]), PackedInt32Array([1, 3]), PackedInt32Array([2])]


func test_memory_knows_nothing_until_told() -> void:
	var memory := TargetMemory.new()
	assert_bool(memory.known).is_false()
	assert_float(memory.age(5.0)).is_equal(INF)
	memory.remember(Vector2(3, 4), 2.0, "footstep")
	assert_float(memory.age(5.0)).is_equal(3.0)
	assert_str(memory.source).is_equal("footstep")


func test_a_new_belief_is_even() -> void:
	assert_array(Array(BeliefMap.new(_corridor()).shares)).is_equal([0.25, 0.25, 0.25, 0.25])


func test_a_perceived_target_takes_all_the_belief() -> void:
	var belief := BeliefMap.new(_corridor())
	belief.collapse(2)
	assert_array(Array(belief.shares)).is_equal([0.0, 0.0, 1.0, 0.0])


func test_unseen_it_spreads_along_edges_and_seen_nodes_are_zeroed() -> void:
	var belief := BeliefMap.new(_corridor())
	belief.collapse(1)
	belief.step_unseen(PackedInt32Array([0]), 0.5)
	# 1 keeps a half and gives a quarter to each side; 0 is seen, so the
	# rest is renormalised over 1 and 2.
	assert_float(belief.shares[0]).is_equal(0.0)
	assert_float(belief.shares[1]).is_equal_approx(2.0 / 3.0, 1e-9)
	assert_float(belief.shares[2]).is_equal_approx(1.0 / 3.0, 1e-9)
	assert_float(belief.shares[3]).is_equal(0.0)


func test_a_step_that_would_clear_everything_reseeds_over_the_unseen() -> void:
	var belief := BeliefMap.new(_corridor())
	belief.collapse(0)
	belief.step_unseen(PackedInt32Array([0, 1]), 0.5)
	assert_bool(belief.reseeded).is_true()
	assert_array(Array(belief.shares)).is_equal([0.0, 0.0, 0.5, 0.5])


func test_diffusion_keeps_the_total() -> void:
	var spread: PackedFloat64Array = BeliefMap.spread_along_edges(PackedFloat64Array([0.1, 0.2, 0.3, 0.4]), _corridor(), 0.7)
	var total: float = 0.0
	for share: float in spread:
		total += share
	assert_float(total).is_equal_approx(1.0, 1e-12)
