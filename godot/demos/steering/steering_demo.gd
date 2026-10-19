## Four vehicles, four steering behaviours, each with its force drawn.
##
## T22's demo. The same start in four arenas: seek, arrive, pursue and seek
## with avoid. Click in an arena to move its target -- every arena's but
## pursue's, whose quarry runs its own circle. Space pauses, the full stop
## steps one sixtieth of a second, R starts again.
##
## What to watch is the difference T22 is about: seek reaches the cross at
## full speed, overshoots and swings back through it forever; arrive starts
## braking as it enters its circle and stops on the cross. The orange arrow
## is what the behaviour asks for, the blue one where the vehicle is going:
## when they disagree, the vehicle is about to turn.
class_name SteeringDemo
extends Node2D

const MARGIN := Vector2(24.0, 24.0)
const GAP: float = 24.0
const TITLES: Array[String] = ["seek", "arrive", "pursue", "seek + avoid"]

@onready var _status: Label = $Interface/Status
@onready var _legend: Legend = $Interface/Legend

var lanes: Array[SteeringLane] = []
var paused: bool = false
var steps: int = 0


func _ready() -> void:
	var size: Vector2 = SteeringLane.SIZE * SteeringLane.SCALE
	for index: int in range(TITLES.size()):
		var lane := SteeringLane.new(TITLES[index])
		lane.position = MARGIN + Vector2(index % 2 * (size.x + GAP), index / 2 * (size.y + GAP))
		add_child(lane)
		lanes.append(lane)
	_legend.set_entries([
		[SteeringLane.FORCE_COLOUR, "the force it asks for"],
		[SteeringLane.VELOCITY_COLOUR, "where it is going"],
		[SteeringLane.TARGET_COLOUR, "cross: target; dot: quarry"],
		[SteeringLane.REASONING_COLOUR, "braking circle, guess, look"],
		[SteeringLane.OBSTACLE_COLOUR, "an obstacle"],
	] as Array[Array])
	_refresh()


func _physics_process(_delta: float) -> void:
	if not paused:
		step_decision()


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_place_target(click.position)
		return
	var key := event as InputEventKey
	if key == null or not key.is_pressed() or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			paused = not paused
		KEY_PERIOD:
			paused = true
			step_decision()
		KEY_R:
			restart()
	_refresh()


## Every vehicle takes one step: each behaviour decides its force once.
func step_decision() -> void:
	for lane: SteeringLane in lanes:
		lane.step()
	steps += 1
	if steps % 10 == 0:
		_refresh()


## What each behaviour is deciding with: its force, its speed and how far it
## has to go, for `test/demo_overlays.gd`.
func decision_overlay() -> Dictionary:
	var shown: Array[Dictionary] = []
	for lane: SteeringLane in lanes:
		shown.append(lane.overlay())
	return {"step": steps, "lanes": shown}


## Every arena back to its start, the targets where they began.
func restart() -> void:
	for lane: SteeringLane in lanes:
		lane.restart(Vector2(36, 14))
	steps = 0


func _place_target(at: Vector2) -> void:
	for lane: SteeringLane in lanes:
		var inside: Vector2 = (at - lane.position) / SteeringLane.SCALE
		if Rect2(Vector2.ZERO, SteeringLane.SIZE).has_point(inside):
			lane.target = inside
			lane.queue_redraw()


func _refresh() -> void:
	var lines: Array[String] = ["%.1f s%s  ·  click: target  ·  space: pause  ·  .: one step  ·  R: again" % [
		steps / 60.0, "  (paused)" if paused else ""]]
	for lane: SteeringLane in lanes:
		var seen: Dictionary = lane.overlay()
		lines.append("%s: speed %.1f, force %.1f, %.1f to go" % [seen["behaviour"], seen["speed"], seen["force"], seen["distance"]])
	_status.text = "\n".join(lines)
