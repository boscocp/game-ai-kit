# EngagementRings' promises over random scenes with cover, and the planted
# generators each check must reject: one that ignores the claims, one that
# ignores the view and one that ignores the line of sight. The Python twin
# holds the same promises in `python/tests/test_teamwork_rings.py`.
extends GdUnitTestSuite

const TRIALS: int = 40
const STEPS: int = 30
const MELEE: int = 6
const RANGED: int = 2
const PILLARS: int = 4
const SPACING: float = 2.5


# A generator that never says a point is taken or crowded.
class IgnoresClaims:
	extends EngagementRings

	func _init(rings_config: EngagementRings.Config) -> void:
		super(rings_config)

	func _crowding(_enemy_id: int, _point: EngagementRings.Point) -> int:
		return -1


# A generator that calls every point in front of the camera.
class IgnoresView:
	extends EngagementRings

	func _init(rings_config: EngagementRings.Config) -> void:
		super(rings_config)

	func _faces(_position: Vector2, _view_from: Vector2, _view_forward: Vector2) -> bool:
		return true


# A generator that says every point sees the target.
class IgnoresSight:
	extends EngagementRings

	func _init(rings_config: EngagementRings.Config) -> void:
		super(rings_config)

	func _sight(_point: EngagementRings.Point) -> bool:
		return true


# A pillar of the scene: it blocks every line through it.
class Pillar:
	extends RefCounted
	var centre: Vector2
	var radius: float


func _ring(name: String, radius: float, count: int, phase: float = 0.0) -> EngagementRings.Ring:
	var ring := EngagementRings.Ring.new()
	ring.name = name
	ring.radius = radius
	ring.count = count
	ring.phase = phase
	return ring


# Inner and waiting rings close enough that a claim on one crowds the other.
func _config() -> EngagementRings.Config:
	var config := EngagementRings.Config.new()
	config.rings = [_ring(EngagementRings.INNER, 2.0, 4), _ring(EngagementRings.WAITING, 4.0, 10, PI / 10.0),
			_ring(EngagementRings.RANGED, 9.0, 10)]
	config.spacing = SPACING
	config.weights.max_travel = 40.0
	return config


func _make(kind: String) -> EngagementRings:
	match kind:
		"claims":
			return IgnoresClaims.new(_config())
		"view":
			return IgnoresView.new(_config())
		"sight":
			return IgnoresSight.new(_config())
	return EngagementRings.new(_config())


# Whether the segment from `start` to `end` passes through a pillar.
func _blocked(start: Vector2, end: Vector2, pillars: Array[Pillar]) -> bool:
	for pillar: Pillar in pillars:
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(pillar.centre, start, end)
		if nearest.distance_to(pillar.centre) < pillar.radius:
			return true
	return false


func _in_front(position: Vector2, view_from: Vector2, forward: Vector2) -> bool:
	return (position - view_from).dot(forward) > 0.0


# Whether a point of `ring` is in front, seen and uncrowded -- worked out
# here, from the scene, not by the rings.
func _free_in_front(field: EngagementRings, enemy: int, ring: String, view_from: Vector2, forward: Vector2,
		pillars: Array[Pillar]) -> bool:
	for point: EngagementRings.Point in field.points:
		if point.ring != ring or not _in_front(point.position, view_from, forward):
			continue
		if not _blocked(point.position, field.target, pillars) and not _crowded(field, enemy, point.position):
			return true
	return false


func _crowded(field: EngagementRings, enemy: int, position: Vector2) -> bool:
	for other: EngagementRings.Point in field.points:
		if other.claimed_by != -1 and other.claimed_by != enemy and other.position.distance_to(position) < SPACING:
			return true
	return false


# Two claims closer than the spacing, named, or "".
func _too_close(field: EngagementRings) -> String:
	var claimed: Array[EngagementRings.Point] = []
	for point: EngagementRings.Point in field.points:
		if point.claimed_by != -1:
			claimed.append(point)
	for index: int in range(claimed.size()):
		for other: int in range(index + 1, claimed.size()):
			if claimed[index].position.distance_to(claimed[other].position) < SPACING:
				return "%s and %s closer than the spacing" % [claimed[index].id, claimed[other].id]
	return ""


func _pillars(random: RandomNumberGenerator, at: Vector2) -> Array[Pillar]:
	var pillars: Array[Pillar] = []
	for each: int in range(PILLARS):
		var pillar := Pillar.new()
		pillar.centre = at + Vector2.from_angle(random.randf_range(0.0, TAU)) * random.randf_range(3.0, 8.0)
		pillar.radius = random.randf_range(0.5, 1.0)
		pillars.append(pillar)
	return pillars


# A random fight round one moving target; the first broken promise, or "".
func _fight(field: EngagementRings, seed_value: int) -> String:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var offsets: Array[Pillar] = _pillars(random, Vector2.ZERO)
	var standing: Array[Vector2] = []
	for enemy: int in range(MELEE + RANGED):
		standing.append(Vector2(random.randf_range(-12.0, 12.0), random.randf_range(-12.0, 12.0)))
	var heading: float = random.randf_range(0.0, TAU)
	for step: int in range(STEPS):
		heading += random.randf_range(-0.6, 0.6)
		field.place(Vector2(random.randf_range(-0.5, 0.5), random.randf_range(-0.5, 0.5)))
		var pillars: Array[Pillar] = _moved(offsets, field.target)
		for point: EngagementRings.Point in field.points:
			point.line_of_sight = not _blocked(point.position, field.target, pillars)
		var why: String = _one_step(field, random, standing, Vector2.from_angle(heading), pillars)
		if why != "":
			return "seed %d step %d: %s" % [seed_value, step, why]
	return ""


func _moved(offsets: Array[Pillar], at: Vector2) -> Array[Pillar]:
	var pillars: Array[Pillar] = []
	for offset: Pillar in offsets:
		var pillar := Pillar.new()
		pillar.centre = offset.centre + at
		pillar.radius = offset.radius
		pillars.append(pillar)
	return pillars


# Every enemy chooses once, two random melee holding a token; the first
# promise a choice broke, or "".
func _one_step(field: EngagementRings, random: RandomNumberGenerator, standing: Array[Vector2], forward: Vector2,
		pillars: Array[Pillar]) -> String:
	var view_from: Vector2 = field.target - forward * 3.0
	var first: int = random.randi_range(0, MELEE - 1)
	var holders: Array[int] = [first, (first + random.randi_range(1, MELEE - 1)) % MELEE]
	for enemy: int in range(MELEE + RANGED):
		var ring: String = EngagementRings.ring_for(enemy in holders, enemy >= MELEE)
		field.release(enemy)
		var had_free_front: bool = _free_in_front(field, enemy, ring, view_from, forward, pillars)
		var chosen: int = field.choose(enemy, ring, standing[enemy], view_from, forward)
		var why: String = _too_close(field)
		if why == "" and chosen != -1:
			why = _wrong_place(field.points[chosen], field.target, view_from, forward, pillars, had_free_front)
			standing[enemy] = field.points[chosen].position
		if why != "":
			return "enemy %d: %s" % [enemy, why]
	return ""


func _wrong_place(point: EngagementRings.Point, target: Vector2, view_from: Vector2, forward: Vector2,
		pillars: Array[Pillar], had_free_front: bool) -> String:
	if point.ring == EngagementRings.RANGED and _blocked(point.position, target, pillars):
		return "ranged at %s, which cannot see the target" % point.id
	if point.ring == EngagementRings.WAITING and not _in_front(point.position, view_from, forward) and had_free_front:
		return "waiting behind the camera at %s with a free point in front" % point.id
	return ""


func _first_broken(kind: String) -> String:
	for trial: int in range(TRIALS):
		var why: String = _fight(_make(kind), trial)
		if why != "":
			return why
	return ""


func test_every_promise_holds_over_random_scenes() -> void:
	assert_str(_first_broken("")).is_equal("")


func test_a_generator_that_ignores_the_claims_is_caught() -> void:
	assert_str(_first_broken("claims")).contains("closer than the spacing")


func test_a_generator_that_ignores_the_view_is_caught() -> void:
	assert_str(_first_broken("view")).contains("behind the camera")


func test_a_generator_that_ignores_the_sight_is_caught() -> void:
	assert_str(_first_broken("sight")).contains("cannot see the target")


func test_a_token_sends_a_melee_enemy_in_and_back_out() -> void:
	assert_str(EngagementRings.ring_for(true, false)).is_equal(EngagementRings.INNER)
	assert_str(EngagementRings.ring_for(false, false)).is_equal(EngagementRings.WAITING)
	assert_str(EngagementRings.ring_for(true, true)).is_equal(EngagementRings.RANGED)
	assert_str(EngagementRings.ring_for(false, true)).is_equal(EngagementRings.RANGED)


func test_the_points_lie_on_their_rings_and_follow_the_target() -> void:
	var field := EngagementRings.new(_config(), Vector2(3.0, -1.0))
	field.choose(1, EngagementRings.WAITING, Vector2(3.0, 6.0), Vector2(3.0, -4.0), Vector2(0.0, 1.0))
	var claim: int = field.claim_of(1)
	field.place(Vector2(5.0, 2.0))
	var radius: Dictionary = {}
	for ring: EngagementRings.Ring in _config().rings:
		radius[ring.name] = ring.radius
	for point: EngagementRings.Point in field.points:
		assert_float(point.position.distance_to(Vector2(5.0, 2.0))).is_equal_approx(radius[point.ring], 1e-4)
	assert_int(field.claim_of(1)).is_equal(claim)
	assert_bool(field.release(1)).is_true()
	assert_bool(field.release(1)).is_false()
	assert_int(field.claim_of(1)).is_equal(-1)


func test_no_point_left_is_minus_one() -> void:
	var field := EngagementRings.new(_config())
	var taken: Array[int] = []
	for enemy: int in range(5):
		taken.append(field.choose(enemy, EngagementRings.INNER, Vector2(0.0, 5.0), Vector2(0.0, -3.0), Vector2(0.0, 1.0)))
	assert_int(taken[4]).is_equal(-1)
	var first_four: Array[int] = taken.slice(0, 4)
	first_four.sort()
	assert_array(first_four).is_equal([0, 1, 2, 3])
