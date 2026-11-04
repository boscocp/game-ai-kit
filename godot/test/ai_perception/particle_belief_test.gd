# ParticleBelief, one claim per test. The exact clouds are
# the vectors' (spec/vectors/perception/particles-*.json); these hold the
# collapse, the reseed, and the sensor on graphs the vectors do not cover.
extends GdUnitTestSuite


# 0 - 1 - 2 - 3, a corridor.
func _corridor() -> Array[PackedInt32Array]:
	return [PackedInt32Array([1]), PackedInt32Array([0, 2]), PackedInt32Array([1, 3]), PackedInt32Array([2])]


# Eight nodes in a ring: every node alike, so only the sensor tells two apart.
func _ring() -> Array[PackedInt32Array]:
	var ring: Array[PackedInt32Array] = []
	for node: int in range(8):
		ring.append(PackedInt32Array([(node + 7) % 8, (node + 1) % 8]))
	return ring


func test_a_new_cloud_is_even() -> void:
	assert_array(Array(ParticleBelief.new(_corridor(), 8).shares)).is_equal([0.25, 0.25, 0.25, 0.25])


func test_a_perceived_target_takes_every_particle() -> void:
	var cloud := ParticleBelief.new(_corridor(), 8)
	cloud.collapse(2)
	assert_array(Array(cloud.nodes)).is_equal([2, 2, 2, 2, 2, 2, 2, 2])
	assert_array(Array(cloud.shares)).is_equal([0.0, 0.0, 1.0, 0.0])
	assert_bool(cloud.reseeded).is_false()


func test_a_seen_node_keeps_no_particle() -> void:
	var cloud := ParticleBelief.new(_corridor(), 64, 5)
	cloud.collapse(1)
	cloud.step_unseen(PackedInt32Array([0]), PackedInt32Array())
	assert_float(cloud.shares[0]).is_equal(0.0)
	assert_bool(cloud.reseeded).is_false()


func test_every_particle_seen_reseeds_over_the_unseen() -> void:
	var cloud := ParticleBelief.new(_corridor(), 8, 2)
	cloud.collapse(0)
	cloud.step_unseen(PackedInt32Array([0, 1]), PackedInt32Array())
	assert_bool(cloud.reseeded).is_true()
	assert_array(Array(cloud.shares)).is_equal([0.0, 0.0, 0.5, 0.5])
	assert_bool(Array(cloud.emptied).has(0) or Array(cloud.emptied).has(1)).is_true()


func test_a_node_that_would_have_been_heard_keeps_fewer() -> void:
	var heard: float = 0.0
	var not_heard: float = 0.0
	for seed_value: int in range(1, 21):
		var cloud := ParticleBelief.new(_ring(), 400, seed_value)
		cloud.step_unseen(PackedInt32Array(), PackedInt32Array([0]))
		heard += cloud.shares[0]
		not_heard += cloud.shares[4]
	assert_float(heard).is_less(0.6 * not_heard)


func test_the_same_seed_gives_the_same_cloud() -> void:
	var one := ParticleBelief.new(_ring(), 32, 9)
	var other := ParticleBelief.new(_ring(), 32, 9)
	for cloud: ParticleBelief in [one, other]:
		cloud.collapse(3)
		for step: int in range(4):
			cloud.step_unseen(PackedInt32Array([0]), PackedInt32Array([6]))
	assert_array(Array(one.nodes)).is_equal(Array(other.nodes))
