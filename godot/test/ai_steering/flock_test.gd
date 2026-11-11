# The flock's three rules one at a time, and the flock vector checker's
# refusals. The worked numbers are the vectors'; these name the rule when
# one breaks.
extends GdUnitTestSuite


func _boid() -> SteeringVehicle:
	return SteeringVehicle.new(Vector2.ZERO, Vector2(5, 0), 10.0, 20.0)


func _other(at: Vector2, moving: Vector2) -> SteeringVehicle:
	return SteeringVehicle.new(at, moving, 0.0, 0.0)


func test_the_case_on_the_page_gives_the_page_s_numbers() -> void:
	var flock := Flock.new(4.0)
	flock.see([_other(Vector2(2, 0), Vector2(0, 8)), _other(Vector2(0, 6), Vector2(6, 0))] as Array[SteeringVehicle])
	var forces: Array[Vector2] = flock.forces(_boid())
	var near := Vector2(1e-3, 1e-3)
	assert_vector(forces[Flock.Rule.SEPARATION]).is_equal_approx(Vector2(-10, 0), near)
	assert_vector(forces[Flock.Rule.ALIGNMENT]).is_equal_approx(Vector2(2.071, 7.071), near)
	assert_vector(forces[Flock.Rule.COHESION]).is_equal_approx(Vector2(-1.838, 9.487), near)
	assert_vector(flock.force(_boid())).is_equal_approx(Vector2(-13.312, 14.926), near)


func test_a_boid_listed_among_its_own_neighbours_is_skipped() -> void:
	var boid: SteeringVehicle = _boid()
	var flock := Flock.new(4.0)
	flock.see([boid] as Array[SteeringVehicle])
	for force: Vector2 in flock.forces(boid):
		assert_vector(force).is_equal(Vector2.ZERO)


func test_separation_pushes_nothing_from_its_radius_and_beyond() -> void:
	var separation := SeparationBehaviour.new(4.0)
	separation.neighbours = [_other(Vector2(4, 0), Vector2.ZERO), _other(Vector2(0, 9), Vector2.ZERO)] as Array[SteeringVehicle]
	assert_vector(separation.force(_boid())).is_equal(Vector2.ZERO)


func test_alignment_counts_a_slow_neighbour_as_much_as_a_fast_one() -> void:
	var slow := AlignmentBehaviour.new()
	slow.neighbours = [_other(Vector2(9, 9), Vector2(0, 0.1))] as Array[SteeringVehicle]
	var fast := AlignmentBehaviour.new()
	fast.neighbours = [_other(Vector2(9, 9), Vector2(0, 90))] as Array[SteeringVehicle]
	assert_vector(slow.force(_boid())).is_equal_approx(fast.force(_boid()), Vector2(1e-5, 1e-5))


func test_cohesion_with_nobody_asks_for_nothing_rather_than_braking() -> void:
	# A centre of nobody taken as the boid's own place would ask it to stop.
	assert_vector(CohesionBehaviour.new().force(_boid())).is_equal(Vector2.ZERO)


func test_a_weight_of_zero_switches_a_rule_off() -> void:
	var flock := Flock.new(4.0, 1.0, PackedFloat64Array([0.0, 0.0, 1.0]))
	flock.see([_other(Vector2(2, 0), Vector2(0, 8))] as Array[SteeringVehicle])
	assert_vector(flock.force(_boid())).is_equal(flock.cohesion.force(_boid()))


func test_a_flock_vector_with_a_misspelt_field_or_an_unknown_shape_is_refused() -> void:
	var good: Dictionary = {"name": "x", "shape": "forces", "neighbours": [], "separation_radius": 4.0,
		"boid": {"position": [0, 0], "velocity": [0, 0], "max_speed": 10.0, "max_force": 20.0},
		"expected": {"separation": [0, 0], "alignment": [0, 0], "cohesion": [0, 0], "flock": [0, 0]}}
	assert_str(FlockVector.why_not_a_vector(good)).is_empty()
	var misspelt: Dictionary = good.duplicate(true)
	misspelt["separation_raduis"] = 4.0
	assert_str(FlockVector.why_not_a_vector(misspelt)).contains("separation_raduis")
	var unknown: Dictionary = good.duplicate(true)
	unknown["shape"] = "swarm"
	assert_str(FlockVector.why_not_a_vector(unknown)).contains("swarm")
	var missing: Dictionary = good.duplicate(true)
	missing.erase("expected")
	assert_str(FlockVector.why_not_a_vector(missing)).contains("expected")


func test_a_planted_wrong_force_is_caught() -> void:
	var vector: Dictionary = {"name": "x", "shape": "forces", "separation_radius": 4.0,
		"boid": {"position": [0, 0], "velocity": [5, 0], "max_speed": 10.0, "max_force": 20.0},
		"neighbours": [{"position": [2, 0], "velocity": [0, 8]}, {"position": [0, 6], "velocity": [6, 0]}],
		"expected": {"separation": [-10, 0], "alignment": [2.0711, 7.0711], "cohesion": [-1.8377, 9.4868],
			"flock": [-13.3117, 14.9264]}}
	assert_array(FlockVector.check("by hand", vector)).is_empty()
	vector["expected"]["alignment"][1] += 10 * SteeringVector.TOLERANCE
	assert_array(FlockVector.check("by hand", vector)).has_size(1)


# T121: a vector of the wrong types is refused before it is read. Each of
# these, a list given as text in a copy of a real file, was a SCRIPT ERROR
# that skipped the check and let the runner exit 0.
func test_a_flock_vector_of_the_wrong_types_is_refused() -> void:
	var vector: Dictionary = VectorShape.read_spec("vectors/steering/flock/far-neighbours-only-pull.json")
	assert_str(FlockVector.why_not_a_vector(vector)).is_empty()
	var paths: Array = [["boid", "position"], ["neighbours"], ["neighbours", 0, "velocity"], ["expected", "flock"]]
	for path: Array in paths:
		var why: String = FlockVector.why_not_a_vector(VectorShape.planted(vector, path, "x"))
		assert_str(why).override_failure_message(str(path)).contains(" is not ")