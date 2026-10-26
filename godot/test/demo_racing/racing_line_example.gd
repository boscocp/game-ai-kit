# The minimal example on docs/techniques/racing_driver.md, run by
# racing_line_example_test.gd. A car of your own that drives round a racing
# line: it steers at a point ahead on the line, and is never faster than the
# line's speed profile says it can be and still take what is coming.
extends Node2D

## The racing line: a closed loop of points a few units apart, in the same
## space as `position` -- a baked Path2D, say. Set it before the node enters
## the tree.
var line := PackedVector2Array()
## How many points ahead it steers at. More cuts corners and steadies the
## car; fewer follows the line tightly and weaves.
var lookahead: int = 8
## The difficulty: the share of the grip it dares to use. 1 is on the limit;
## below it brakes earlier and corners slower. No rubber band.
var grip_margin: float = 1.0

## How hard it can turn and brake, units a second squared: a corner of
## radius r is taken at most at sqrt(GRIP * r).
const GRIP: float = 300.0
const BRAKING: float = 400.0
## How quickly it closes on the velocity it wants: a tenth of a second.
const RESPONSE: float = 10.0

## Top speed 400 a second; it may change its velocity by 600 a second.
var vehicle := SteeringVehicle.new(Vector2.ZERO, Vector2.ZERO, 400.0, 600.0)
## The fastest it will be at each point of the line.
var speed_limits := PackedFloat64Array()

var _at: int = 0


func _ready() -> void:
	vehicle.position = position
	speed_limits = speed_profile(line, GRIP * grip_margin, BRAKING * grip_margin, vehicle.max_speed)
	_at = _nearest(0, line.size())


func _physics_process(delta: float) -> void:
	_at = _nearest(_at, 2 * lookahead)
	var aim: Vector2 = line[(_at + lookahead) % line.size()]
	# Seek, with the profile's speed in place of top speed: the force is
	# the velocity it wants minus the one it has, closed at RESPONSE.
	var wanted: Vector2 = vehicle.position.direction_to(aim) * speed_limits[_at]
	vehicle.step((wanted - vehicle.velocity) * RESPONSE, delta)
	position = vehicle.position


## Each point's speed limit: the corner there, sqrt(grip / curvature), then
## carried backwards, so the car is slow enough to brake for every corner
## ahead in time. Twice round the loop, so the last corner reaches the first.
static func speed_profile(points: PackedVector2Array, grip: float, braking: float, top: float) -> PackedFloat64Array:
	var count: int = points.size()
	var limits := PackedFloat64Array()
	for index: int in range(count):
		var bend: float = _curvature(points[index - 1], points[index], points[(index + 1) % count])
		limits.append(top if bend == 0.0 else minf(top, sqrt(grip / bend)))
	for step: int in range(2 * count, 0, -1):
		var here: int = (step - 1) % count
		var next: int = step % count
		var room: float = points[here].distance_to(points[next])
		limits[here] = minf(limits[here], sqrt(limits[next] * limits[next] + 2.0 * braking * room))
	return limits


# The point of the line nearest the car among the `span` from `from` on.
func _nearest(from: int, span: int) -> int:
	var best: int = from
	for ahead: int in range(span):
		var index: int = (from + ahead) % line.size()
		if vehicle.position.distance_to(line[index]) < vehicle.position.distance_to(line[best]):
			best = index
	return best


# One over the radius of the circle through three points; 0 on a straight.
static func _curvature(before: Vector2, here: Vector2, after: Vector2) -> float:
	var twice_area: float = absf((here - before).cross(after - before))
	var sides: float = before.distance_to(here) * here.distance_to(after) * after.distance_to(before)
	return 0.0 if sides == 0.0 else 2.0 * twice_area / sides
