## One arena of the steering demo: one vehicle, one behaviour, drawn deciding.
##
## Each arena is a world of its own, in world units (one unit is `SCALE`
## pixels), with its vehicle, what it steers at, and the behaviour that turns
## the one into a force. A step asks the behaviour for its force, keeps it
## for the drawing, and moves the vehicle under it. Drawn on top: the force
## as an orange arrow, the velocity as a blue one, and what each behaviour
## reasons with -- arrive's braking circle, pursue's guess, avoid's stretch
## ahead. An arrow pointing somewhere the vehicle does not go is what to look
## for: it is the decision before the outcome.
class_name SteeringLane
extends Node2D

const SCALE: float = 10.0
const SIZE := Vector2(44.0, 28.0)
const FORCE_COLOUR := Color(1.0, 0.55, 0.1)
const VELOCITY_COLOUR := Color(0.35, 0.65, 1.0)
const TARGET_COLOUR := Color(0.95, 0.95, 0.95)
const REASONING_COLOUR := Color(0.6, 1.0, 0.6, 0.8)
const OBSTACLE_COLOUR := Color(0.55, 0.5, 0.45)
## Seconds an arrow of length 1 stands for: the force is drawn as the change
## it makes in a quarter of a second, the velocity as the ground it covers in
## half of one, so both fit the arena at full size.
const FORCE_SECONDS: float = 0.25
const VELOCITY_SECONDS: float = 0.5
const DT: float = 1.0 / 60.0
const BRAKING_RADIUS: float = 8.0

## What this arena shows: "seek", "arrive", "pursue" or "seek + avoid".
var title: String
var vehicle: SteeringVehicle
var target: Vector2
## The quarry pursue chases: it runs round a circle at a steady speed.
var quarry_angle: float = 0.0
## The force asked for on the last step, as the arrow shows it.
var force: Vector2 = Vector2.ZERO
var obstacles: Array[Vector2] = [Vector2(16, 10), Vector2(26, 17), Vector2(20, 22)]
var radii := PackedFloat64Array([3.0, 3.5, 2.5])
# The title as drawn: looked up once per language, not on every frame.
var _shown_title: String


func _init(which: String) -> void:
	title = which
	_shown_title = which
	restart(Vector2(36, 14))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_shown_title = tr(title)
		queue_redraw()


## Back to the start: the vehicle at the left edge, going nowhere.
func restart(new_target: Vector2) -> void:
	vehicle = SteeringVehicle.new(Vector2(4, 14), Vector2.ZERO, 10.0, 20.0)
	target = new_target
	quarry_angle = 0.0
	force = Vector2.ZERO
	queue_redraw()


## One step: ask the behaviour, keep its answer, move under it.
func step() -> void:
	quarry_angle += 0.6 * DT
	force = behaviour().force(vehicle)
	vehicle.step(force, DT)
	queue_redraw()


## The behaviour this arena runs, built for this step's target.
func behaviour() -> GakSteeringBehaviour:
	match title:
		"seek":
			return SeekBehaviour.new(target)
		"arrive":
			return ArriveBehaviour.new(target, BRAKING_RADIUS)
		"pursue":
			return PursueBehaviour.new(quarry(), quarry_velocity(), 1.0)
	return CombinedSeekAvoid.new(target, obstacles, radii)


## Where pursue's quarry is: on a circle round the arena's middle.
func quarry() -> Vector2:
	return SIZE / 2.0 + Vector2(cos(quarry_angle), sin(quarry_angle)) * 10.0


## How the quarry moves: along its circle, six units a second.
func quarry_velocity() -> Vector2:
	return Vector2(-sin(quarry_angle), cos(quarry_angle)) * 6.0


## What this arena is deciding with, for the demo's overlay: the force it
## asked for (how hard, and which way), the point it is steering at -- for
## pursue, its guess, not the quarry -- and how far that is.
func overlay() -> Dictionary:
	var aim: Vector2 = aim_point()
	return {"behaviour": title, "force": force.length(), "push": [force.x, force.y],
		"aim": [aim.x, aim.y], "speed": vehicle.speed(), "distance": vehicle.position.distance_to(aim)}


## The point the behaviour steers at: the target, or pursue's guess.
func aim_point() -> Vector2:
	if title == "pursue":
		return PursueBehaviour.new(quarry(), quarry_velocity(), 1.0).predicted(vehicle)
	return target


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE * SCALE), Color(0.12, 0.13, 0.15))
	draw_rect(Rect2(Vector2.ZERO, SIZE * SCALE), Color(0.4, 0.4, 0.45), false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(8, 18), _shown_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	_draw_reasoning()
	var at: Vector2 = vehicle.position * SCALE
	draw_line(at, at + vehicle.velocity * VELOCITY_SECONDS * SCALE, VELOCITY_COLOUR, 3.0)
	draw_line(at, at + force * FORCE_SECONDS * SCALE, FORCE_COLOUR, 3.0)
	_draw_vehicle(at)


func _draw_reasoning() -> void:
	match title:
		"arrive":
			draw_arc(target * SCALE, BRAKING_RADIUS * SCALE, 0.0, TAU, 48, REASONING_COLOUR, 1.0)
		"pursue":
			draw_circle(quarry() * SCALE, 5.0, TARGET_COLOUR)
			draw_arc(aim_point() * SCALE, 6.0, 0.0, TAU, 16, REASONING_COLOUR, 2.0)
			return
		"seek + avoid":
			_draw_what_avoid_sees()
	draw_line((target + Vector2(-0.8, 0)) * SCALE, (target + Vector2(0.8, 0)) * SCALE, TARGET_COLOUR, 2.0)
	draw_line((target + Vector2(0, -0.8)) * SCALE, (target + Vector2(0, 0.8)) * SCALE, TARGET_COLOUR, 2.0)


# The obstacles, and the stretch ahead avoid asks about: as long as
# `AvoidBehaviour` makes it, shorter as the vehicle slows.
func _draw_what_avoid_sees() -> void:
	for index: int in range(obstacles.size()):
		draw_circle(obstacles[index] * SCALE, radii[index] * SCALE, OBSTACLE_COLOUR)
	var reach: float = CombinedSeekAvoid.LOOK_AHEAD * minf(vehicle.speed() / vehicle.max_speed, 1.0)
	var ahead: Vector2 = vehicle.position + vehicle.velocity.normalized() * reach
	draw_line(vehicle.position * SCALE, ahead * SCALE, REASONING_COLOUR, 1.0)


func _draw_vehicle(at: Vector2) -> void:
	var heading: Vector2 = vehicle.velocity.normalized()
	if heading == Vector2.ZERO:
		heading = Vector2.RIGHT
	var side := Vector2(-heading.y, heading.x)
	draw_colored_polygon(PackedVector2Array([at + heading * 9.0, at - heading * 6.0 + side * 5.0,
		at - heading * 6.0 - side * 5.0]), Color.WHITE)


## Seek and avoid together, as `Steering.combined` adds them: avoid weighs
## twice what seek does, so a swerve wins over the pull while there is
## something ahead.
class CombinedSeekAvoid extends GakSteeringBehaviour:
	const LOOK_AHEAD: float = 7.0
	var seek: SeekBehaviour
	var avoid: AvoidBehaviour

	func _init(where: Vector2, centres: Array[Vector2], radii: PackedFloat64Array) -> void:
		seek = SeekBehaviour.new(where)
		avoid = AvoidBehaviour.new(centres, radii, LOOK_AHEAD)

	## The two forces, weighted 1 and 2, added and clamped once.
	func force(vehicle: SteeringVehicle) -> Vector2:
		var forces: Array[Vector2] = [seek.force(vehicle), avoid.force(vehicle)]
		return Steering.combined(vehicle, forces, PackedFloat64Array([1.0, 2.0]))
