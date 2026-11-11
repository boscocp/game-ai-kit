# EngagementRings' promises over random scenes with cover, and the planted
# generators each check must reject: one that ignores the claims, the view
# or the line of sight; one where nothing gives way to a token holder; one
# that drops a point for being far. The Python twin holds the same promises
# in `python/tests/test_teamwork_rings.py`.
extends GdUnitTestSuite

const TRIALS: int = 40
const STEPS: int = 30
const MELEE: int = 6
const RANGED: int = 2
const PILLARS: int = 4
const SPACING: float = 2.5
## Where the enemies start: far enough that the default 20 m `max_travel`
## would drop the front points of a ring.
const SPAWN: float = 30.0


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


# A generator where a waiting claim keeps a token holder out of the inner ring.
class NothingGivesWay:
	extends EngagementRings

	func _init(rings_config: EngagementRings.Config) -> void:
		super(rings_config)

	func _gives_way(_claim: EngagementRings.Point, _point: EngagementRings.Point) -> bool:
		return false


# A generator that keeps the config's `max_travel`, so a far front point is dropped.
class DropsFarPoints:
	extends EngagementRings

	func _init(rings_config: EngagementRings.Config) -> void:
		super(rings_config)

	func _weights_reaching(_from: Vector2) -> TacticalPositions.Weights:
		return config.weights


# A pillar of the scene: it blocks every line through it.
class Pillar:
	extends RefCounted
	var centre: Vector2
	var radius: float


# What one step's choice needs to be judged: the scene and what was free.
class Judged:
	extends RefCounted
	var ring: String
	var view_from: Vector2
	var forward: Vector2
	var pillars: Array[Pillar]
	var free: Array[String]
	var free_front: Array[String]


var _choices: int = 0
var _none: int = 0


func _ring(name: String, radius: float, count: int, phase: float = 0.0) -> EngagementRings.Ring:
	var ring := EngagementRings.Ring.new()
	ring.name = name
	ring.radius = radius
	ring.count = count
	ring.phase = phase
	return ring


# Inner and waiting rings close enough that a claim on one crowds the other;
# the default weights.
func _config() -> EngagementRings.Config:
	var config := EngagementRings.Config.new()
	config.rings = [_ring(EngagementRings.INNER, 2.0, 4), _ring(EngagementRings.WAITING, 4.0, 10, PI / 10.0),
			_ring(EngagementRings.RANGED, 9.0, 10)]
	config.spacing = SPACING
	return config


func _make(kind: String) -> EngagementRings:
	match kind:
		"claims":
			return IgnoresClaims.new(_config())
		"view":
			return IgnoresView.new(_config())
		"sight":
			return IgnoresSight.new(_config())
		"way":
			return NothingGivesWay.new(_config())
		"far":
			return DropsFarPoints.new(_config())
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


# The points of `ring` in sight and uncrowded -- and in front, when
# `front_only` -- worked out here, from the scene, not by the rings.
func _free_points(field: EngagementRings, enemy: int, judged: Judged, front_only: bool) -> Array[String]:
	var free: Array[String] = []
	for point: EngagementRings.Point in field.points:
		if point.ring != judged.ring or _blocked(point.position, field.target, judged.pillars):
			continue
		if front_only and not _in_front(point.position, judged.view_from, judged.forward):
			continue
		if not _crowded(field, enemy, point):
			free.append(point.id)
	return free


# Whether another's claim is within the spacing of `point`; only inner
# claims keep an enemy out of the inner ring -- a token holder's right of way.
func _crowded(field: EngagementRings, enemy: int, point: EngagementRings.Point) -> bool:
	for other: EngagementRings.Point in field.points:
		if other.claimed_by == -1 or other.claimed_by == enemy:
			continue
		if point.ring == EngagementRings.INNER and other.ring != EngagementRings.INNER:
			continue
		if other.position.distance_to(point.position) < SPACING:
			return true
	return false


# Two claims closer than the spacing, named, or "".
func _too_close(field: EngagementRings) -> String:
	var claimed: Array[EngagementRings.Point] = []
	for point: EngagementRings.Point in field.points:
		if point.claimed_by != -1:
			claimed.append(point)
	for index: int in range(claimed.size()):
		var why: String = _too_close_to(claimed[index], claimed.slice(index + 1))
		if why != "":
			return why
	return ""


func _too_close_to(point: EngagementRings.Point, others: Array[EngagementRings.Point]) -> String:
	for other: EngagementRings.Point in others:
		if point.position.distance_to(other.position) < SPACING:
			return "%s and %s closer than the spacing" % [point.id, other.id]
	return ""


# Why `chosen` breaks a promise, or "": a -1 must have had nothing free.
func _wrong_place(field: EngagementRings, chosen: int, judged: Judged) -> String:
	if chosen == -1 and judged.free.is_empty():
		return ""
	if chosen == -1:
		return "got no %s point while %s is free" % [judged.ring, judged.free[0]]
	var point: EngagementRings.Point = field.points[chosen]
	if point.ring == EngagementRings.RANGED and _blocked(point.position, field.target, judged.pillars):
		return "ranged at %s, which cannot see the target" % point.id
	if not _in_front(point.position, judged.view_from, judged.forward) and not judged.free_front.is_empty():
		return "%s behind the camera at %s with %s free in front" % [judged.ring, point.id, judged.free_front[0]]
	return ""


func _pillars(random: RandomNumberGenerator) -> Array[Pillar]:
	var pillars: Array[Pillar] = []
	for each: int in range(PILLARS):
		var pillar := Pillar.new()
		pillar.centre = Vector2.from_angle(random.randf_range(0.0, TAU)) * random.randf_range(3.0, 8.0)
		pillar.radius = random.randf_range(0.5, 1.0)
		pillars.append(pillar)
	return pillars


func _moved(offsets: Array[Pillar], at: Vector2) -> Array[Pillar]:
	var pillars: Array[Pillar] = []
	for offset: Pillar in offsets:
		var pillar := Pillar.new()
		pillar.centre = offset.centre + at
		pillar.radius = offset.radius
		pillars.append(pillar)
	return pillars


# A random fight round one moving target; the first broken promise, or "".
func _fight(field: EngagementRings, seed_value: int) -> String:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var offsets: Array[Pillar] = _pillars(random)
	var standing: Array[Vector2] = []
	for enemy: int in range(MELEE + RANGED):
		standing.append(Vector2(random.randf_range(-SPAWN, SPAWN), random.randf_range(-SPAWN, SPAWN)))
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


# Every enemy chooses once, two random melee holding a token; the first
# promise a choice broke, or "".
func _one_step(field: EngagementRings, random: RandomNumberGenerator, standing: Array[Vector2], forward: Vector2,
		pillars: Array[Pillar]) -> String:
	var first: int = random.randi_range(0, MELEE - 1)
	var holders: Array[int] = [first, (first + random.randi_range(1, MELEE - 1)) % MELEE]
	for enemy: int in range(MELEE + RANGED):
		var judged := Judged.new()
		judged.ring = EngagementRings.ring_for(enemy in holders, enemy >= MELEE)
		judged.view_from = field.target - forward * 3.0
		judged.forward = forward
		judged.pillars = pillars
		field.release(enemy)
		judged.free = _free_points(field, enemy, judged, false)
		judged.free_front = _free_points(field, enemy, judged, true)
		var chosen: int = field.choose(enemy, judged.ring, standing[enemy], judged.view_from, forward)
		_choices += 1
		_none += 1 if chosen == -1 else 0
		var why: String = _too_close(field)
		if why == "":
			why = _wrong_place(field, chosen, judged)
		if why != "":
			return "enemy %d: %s" % [enemy, why]
		if chosen != -1:
			standing[enemy] = field.points[chosen].position
	return ""


func _first_broken(kind: String) -> String:
	for trial: int in range(TRIALS):
		var why: String = _fight(_make(kind), trial)
		if why != "":
			return why
	return ""


func test_every_promise_holds_over_random_scenes() -> void:
	_choices = 0
	_none = 0
	assert_str(_first_broken("")).is_equal("")
	# The promises were asked of every choice, and most found a point.
	assert_int(_choices).is_equal(TRIALS * STEPS * (MELEE + RANGED))
	assert_int(_none).is_less(_choices / 10)


func test_a_generator_that_ignores_the_claims_is_caught() -> void:
	assert_str(_first_broken("claims")).contains("closer than the spacing")


func test_a_generator_that_ignores_the_view_is_caught() -> void:
	assert_str(_first_broken("view")).contains("behind the camera")


func test_a_generator_that_ignores_the_sight_is_caught() -> void:
	assert_str(_first_broken("sight")).contains("cannot see the target")


func test_a_token_holder_kept_out_by_a_waiter_is_caught() -> void:
	assert_str(_first_broken("way")).contains("got no inner point")


func test_a_generator_that_drops_far_points_is_caught() -> void:
	var why: String = _first_broken("far")
	assert_bool(why.contains("behind the camera") or why.contains("got no")).override_failure_message(
			"dropping far points went unseen: %s" % why).is_true()


func test_a_token_sends_a_melee_enemy_in_and_back_out() -> void:
	assert_str(EngagementRings.ring_for(true, false)).is_equal(EngagementRings.INNER)
	assert_str(EngagementRings.ring_for(false, false)).is_equal(EngagementRings.WAITING)
	assert_str(EngagementRings.ring_for(true, true)).is_equal(EngagementRings.RANGED)
	assert_str(EngagementRings.ring_for(false, true)).is_equal(EngagementRings.RANGED)


func test_the_points_lie_on_their_rings_and_follow_the_target() -> void:
	var field := EngagementRings.new(_config(), Vector2(3.0, -1.0))
	assert_int(field.choose(1, EngagementRings.WAITING, Vector2(3.0, 6.0), Vector2(3.0, -4.0), Vector2(0.0, 1.0))).is_not_equal(-1)
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


func test_a_holder_bumps_the_waiter_beside_its_point() -> void:
	var field := EngagementRings.new(_config())
	var waiting: int = field.choose(1, EngagementRings.WAITING, Vector2(4.0, 1.0), Vector2(0.0, -3.0), Vector2(0.0, 1.0))
	assert_str(field.points[waiting].id).is_equal("waiting-0")
	var inner: int = field.choose(2, EngagementRings.INNER, Vector2(4.0, 1.0), Vector2(0.0, -3.0), Vector2(0.0, 1.0))
	assert_str(field.points[inner].id).is_equal("inner-0")
	assert_array(field.last_bumped).is_equal([1])
	assert_int(field.claim_of(1)).is_equal(-1)


func test_the_view_is_told_apart_from_the_ring() -> void:
	var field := EngagementRings.new(_config())
	field.choose(1, EngagementRings.WAITING, Vector2(0.0, 6.0), Vector2(0.0, -3.0), Vector2(0.0, 1.0))
	var behind: Array[String] = []
	for index: int in range(field.points.size()):
		if field.last_behind[index]:
			behind.append(field.points[index].id)
	assert_array(behind).is_equal(["waiting-6", "waiting-7", "waiting-8", "ranged-6", "ranged-7", "ranged-8", "ranged-9"])
