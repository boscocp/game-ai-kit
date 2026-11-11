## Where the enemies stand while one of them attacks: rings round the
## target, and a point on the right ring for each enemy.
##
## Attack tokens say who strikes (T154); they do not say where the others
## stand, and without that the waiting ones bunch up, stand behind the
## player where they cannot be seen, or block the ranged attacker's line.
## Reckoning split the circle round the player into an inner attack circle
## and an outer approach circle, so the player can tell the immediate
## threats [Dawe 2013, 28.3.1]; this adds a third, a band for the ranged.
## The rings only place candidate points. Which point an enemy takes is the
## tactical position query [Jack 2013], asked of `TacticalPositions`: a
## point on another ring is outside the area, a point within `spacing` of
## another enemy's claim is claimed, a point with no line of sight is
## exposed, and nearness ranks the rest. A point behind the player's view
## is taken only when no point in front is free, and a token holder has the
## right of way into the inner ring.
## O(points^2) per choice: each point is checked against every claim.
##
## It casts no rays. The caller fills in each point's line of sight, as it
## fills in `TacticalPositions`' facts, so the Python twin needs no physics.
##
## When not to use it: one enemy, which needs no turns; or a squad that
## fights from cover -- that is `TacticalPositions` on cover points, not a
## circle in the open.
class_name EngagementRings
extends RefCounted

## The rings an enemy is sent to: a melee token holder strikes from INNER,
## the rest of the melee wait on WAITING, the ranged keep to RANGED.
const INNER: String = "inner"
const WAITING: String = "waiting"
const RANGED: String = "ranged"


## One ring: its name, how far from the target in metres, how many points
## it has, and the angle of its first point in radians -- half a step
## between two rings keeps their points from lining up.
class Ring:
	extends RefCounted
	var name: String = ""
	var radius: float = 0.0
	var count: int = 0
	var phase: float = 0.0


## The rings, the spacing, and the weights the query scores with.
class Config:
	extends RefCounted
	var rings: Array[Ring] = []
	## No two claims closer than this, in metres, on any ring.
	var spacing: float = 1.5
	## `TacticalPositions`' weights; nearness ranks the points of a ring.
	## `max_travel` never drops a ring point: each query raises it to the
	## farthest point, so an enemy far off still goes to the front.
	var weights: TacticalPositions.Weights = TacticalPositions.Weights.new()


## One point on a ring. `line_of_sight` is the caller's to fill in --
## standing there, can the enemy see the target -- cast with physics; it is
## true until the caller says otherwise.
class Point:
	extends RefCounted
	var id: String = ""
	var ring: String = ""
	var position: Vector2 = Vector2.ZERO
	var line_of_sight: bool = true
	## The enemy that claimed it, or -1.
	var claimed_by: int = -1


var config: Config
## Every ring's points, ring by ring in the config's order.
var points: Array[Point] = []
## Where the target is: the centre of every ring.
var target: Vector2 = Vector2.ZERO
## The last query's answer -- every point's status and score -- for a view
## to draw why each point was not taken.
var last_choice: TacticalPositions.Choice = TacticalPositions.Choice.new()
## Per point, whether it was behind the view at the last choice: the camera
## rule's half of an OUTSIDE_AREA, which a point on another ring also is.
var last_behind: Array[bool] = []
## The enemies whose claims the last choice gave up, for a token holder
## stepping in beside them: each must choose again.
var last_bumped: Array[int] = []


func _init(rings_config: Config, at: Vector2 = Vector2.ZERO) -> void:
	config = rings_config
	for ring: Ring in config.rings:
		for index: int in range(ring.count):
			var point := Point.new()
			point.id = "%s-%d" % [ring.name, index]
			point.ring = ring.name
			points.append(point)
	place(at)


## Move the rings to `at`, where the target now is. Each point keeps its id
## and its claim, so the enemies follow the target round rather than
## choosing again from nothing; Reckoning's slots moved with the player too
## [Dawe 2013, 28.6.1].
func place(at: Vector2) -> void:
	target = at
	var index: int = 0
	for ring: Ring in config.rings:
		for step: int in range(ring.count):
			var angle: float = ring.phase + TAU * step / ring.count
			points[index].position = at + Vector2(cos(angle), sin(angle)) * ring.radius
			index += 1


## The ring an enemy belongs on. Holding a melee token sends it in, and
## giving the token back sends it out again; a ranged enemy keeps to its
## band either way, for it strikes from there. The rings never grant an
## attack: `AttackTokens` does.
static func ring_for(holds_token: bool, ranged: bool) -> String:
	if ranged:
		return RANGED
	return INNER if holds_token else WAITING


## Choose a point on `ring` for `enemy_id`, standing at `from`, and claim
## it: its index, or -1 when no point is left. The enemy's old claim is
## given up first, so asking again at each decision is how an enemy keeps
## up with the target, its token and the view. `view_from` and
## `view_forward` are the player's camera on the ground plane: a point
## behind it is taken only when no point in front is free. A token holder
## has the right of way: a claim on another ring does not crowd it out of
## the inner ring, and is given up instead (`last_bumped`).
func choose(enemy_id: int, ring: String, from: Vector2, view_from: Vector2, view_forward: Vector2) -> int:
	release(enemy_id)
	last_bumped = []
	last_behind = []
	for point: Point in points:
		last_behind.append(not _faces(point.position, view_from, view_forward))
	var weights: TacticalPositions.Weights = _weights_reaching(from)
	last_choice = TacticalPositions.choose(enemy_id, _candidates(enemy_id, ring, from, true), weights, true, true)
	if last_choice.chosen == -1:
		last_choice = TacticalPositions.choose(enemy_id, _candidates(enemy_id, ring, from, false), weights, true, true)
	if last_choice.chosen != -1:
		points[last_choice.chosen].claimed_by = enemy_id
		_bump_beside(points[last_choice.chosen])
	return last_choice.chosen


## Give up `enemy_id`'s claim; true when it had one. An enemy that dies or
## leaves the fight calls it, so its point is free for the next.
func release(enemy_id: int) -> bool:
	for point: Point in points:
		if point.claimed_by == enemy_id:
			point.claimed_by = -1
			return true
	return false


## The index of the point `enemy_id` claims, or -1.
func claim_of(enemy_id: int) -> int:
	for index: int in range(points.size()):
		if points[index].claimed_by == enemy_id:
			return index
	return -1


# Every point as the facts `TacticalPositions` weighs for `enemy_id`. A
# point on another ring -- or, with `front_only`, behind the view at the
# last choice -- is outside the area; a point another's claim crowds reads
# as claimed by that one; the line of sight is the line of fire, and a
# ring point is open ground, never covered, so a point with no sight is
# exposed.
func _candidates(enemy_id: int, ring: String, from: Vector2, front_only: bool) -> Array[TacticalPositions.Candidate]:
	var found: Array[TacticalPositions.Candidate] = []
	for index: int in range(points.size()):
		var point: Point = points[index]
		var candidate := TacticalPositions.Candidate.new()
		candidate.id = point.id
		candidate.travel = from.distance_to(point.position)
		candidate.threat_distance = target.distance_to(point.position)
		candidate.in_area = point.ring == ring and not (front_only and last_behind[index])
		candidate.claimed_by = _crowding(enemy_id, point)
		candidate.fires_on_main = _sight(point)
		candidate.covered_from_main = false
		found.append(candidate)
	return found


# The config's weights, with `max_travel` raised to reach the farthest
# point from `from`: walking far is ranked by nearness, never dropped, so
# the camera rule cannot be broken by a front point being too far.
func _weights_reaching(from: Vector2) -> TacticalPositions.Weights:
	var weights := TacticalPositions.Weights.new()
	for property: Dictionary in weights.get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			weights.set(property["name"], config.weights.get(property["name"]))
	for point: Point in points:
		weights.max_travel = maxf(weights.max_travel, from.distance_to(point.position))
	return weights


# The enemy whose claim leaves `point` too close for `enemy_id`, or -1: the
# point itself claimed by another, or another's claim nearer than
# `spacing`, on any ring -- except a claim that gives way to it. The
# suite's planted generator overrides it to see no one.
func _crowding(enemy_id: int, point: Point) -> int:
	for other: Point in points:
		if other.claimed_by == -1 or other.claimed_by == enemy_id or _gives_way(other, point):
			continue
		if other == point or other.position.distance_to(point.position) < config.spacing:
			return other.claimed_by
	return -1


# Whether `claim` steps aside for whoever asks for `point`: a claim off the
# inner ring never keeps a token holder out of it. The suite plants a
# generator where nothing gives way.
func _gives_way(claim: Point, point: Point) -> bool:
	return point.ring == INNER and claim.ring != INNER


# Give up every claim within the spacing that gave way to the new claim on
# `taken`, and note whose.
func _bump_beside(taken: Point) -> void:
	for other: Point in points:
		if other == taken or other.claimed_by == -1 or not _gives_way(other, taken):
			continue
		if other.position.distance_to(taken.position) < config.spacing:
			last_bumped.append(other.claimed_by)
			other.claimed_by = -1


# Whether `position` is in front of the view: strictly, so a point level
# with the camera counts as behind.
func _faces(position: Vector2, view_from: Vector2, view_forward: Vector2) -> bool:
	return (position - view_from).dot(view_forward) > 0.0


# The caller's line-of-sight fact. A hook, so the suite can plant a
# generator that ignores it.
func _sight(point: Point) -> bool:
	return point.line_of_sight
