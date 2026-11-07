## A hundred boids and three rules, each one switchable, one boid watched.
##
## T150's demo. No boid knows about the flock: each looks at the neighbours
## inside its sight and adds three forces -- away from the too close, towards
## their heading, towards their middle (`Flock`). 1, 2 and 3 switch
## separation, alignment and cohesion off and on again, so a person sees what
## each was doing by its absence. A click drops an obstacle, which
## `AvoidBehaviour` already knows how to go round. Tab watches the next boid,
## space pauses, the full stop steps one sixtieth of a second, R starts again.
##
## What is drawn is the watched boid's decision, as invariant 13 asks: its
## sight and its too-close circle, a line to each neighbour it counted, and
## its three forces in three colours -- avoid's in a fourth when something is
## ahead -- drawn from where everyone was when it decided, the step that
## decision has just moved it by being one sixtieth of a second's flight.
class_name FlockingDemo
extends Node2D

const MARGIN := Vector2(24.0, 24.0)
const BACKGROUND := Color(0.1, 0.11, 0.13)
const BORDER := Color(0.4, 0.4, 0.45)
const BOID_COLOUR := Color(0.62, 0.64, 0.7)
const WATCHED_COLOUR := Color(1.0, 1.0, 1.0)
const NEIGHBOUR_COLOUR := Color(1.0, 0.85, 0.3)
const SIGHT_COLOUR := Color(1.0, 0.85, 0.3, 0.45)
## One colour a rule, in `Flock.Rule` order, then avoid's.
const FORCE_COLOURS: Array[Color] = [Color(1.0, 0.35, 0.35), Color(0.35, 0.65, 1.0), Color(0.4, 0.95, 0.45),
	Color(1.0, 0.55, 0.1)]
const OBSTACLE_COLOUR := Color(0.55, 0.5, 0.45)
## A force of `MAX_FORCE` is drawn this many pixels long.
const ARROW_PIXELS: float = 48.0

@onready var _status: Label = $Interface/Status
@onready var _legend: Legend = $Interface/Legend

var world := FlockWorld.new()
var paused: bool = false


func _ready() -> void:
	_legend.set_entries(_legend_entries())
	_refresh()
	Language.apply_if_opened_alone(self)


# Rebuilt in the language just chosen (T80): the status is set from code and
# keeps the words it was given, and the legend is drawn.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_legend.set_entries(_legend_entries())
		_refresh()


func _legend_entries() -> Array[Array]:
	return [
		[FORCE_COLOURS[Flock.Rule.SEPARATION], tr("separation: away from the too close")],
		[FORCE_COLOURS[Flock.Rule.ALIGNMENT], tr("alignment: towards their heading")],
		[FORCE_COLOURS[Flock.Rule.COHESION], tr("cohesion: towards their middle")],
		[FORCE_COLOURS[3], tr("avoid: the obstacle ahead")],
		[NEIGHBOUR_COLOUR, tr("the neighbours it counted, its sight")],
		[WATCHED_COLOUR, tr("the watched boid")],
		[OBSTACLE_COLOUR, tr("an obstacle")],
	] as Array[Array]


func _physics_process(_delta: float) -> void:
	if not paused:
		step_decision()


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		if Rect2(MARGIN, FlockWorld.SIZE).has_point(click.position):
			world.place_obstacle(click.position - MARGIN)
			queue_redraw()
		return
	var key := event as InputEventKey
	if key == null or not key.is_pressed() or key.echo:
		return
	_on_key(key.keycode)
	_refresh()
	queue_redraw()


func _on_key(keycode: Key) -> void:
	match keycode:
		KEY_1, KEY_2, KEY_3:
			world.toggle(keycode - KEY_1)
		KEY_TAB:
			world.watch_next()
		KEY_SPACE:
			paused = not paused
		KEY_PERIOD:
			paused = true
			step_decision()
		KEY_R:
			world.restart()


## Every boid decides its force once, from where everyone is, then moves.
func step_decision() -> void:
	world.step()
	if world.steps % 10 == 0:
		_refresh()
	queue_redraw()


## What the watched boid is deciding with, for `test/menu/demo_overlays.gd`:
## how many neighbours it counted and which, how hard each rule pushes it,
## which rules are on, and how many obstacles there are.
func decision_overlay() -> Dictionary:
	var lengths: Array[float] = []
	for force: Vector2 in world.forces:
		lengths.append(force.length())
	return {"step": world.steps, "watched": world.watched, "neighbours": world.counted.size(),
		"counted": _counted_words(), "separation": lengths[0], "alignment": lengths[1],
		"cohesion": lengths[2], "avoid": lengths[3], "rules": _rules_words(),
		"obstacles": world.obstacles.size()}


func _counted_words() -> String:
	if world.counted.is_empty():
		return "none"  # not shown
	return ", ".join(Array(world.counted).map(func(index: int) -> String: return str(index)))


func _rules_words() -> String:
	var on: Array[String] = []
	for rule: int in range(FlockWorld.RULES.size()):
		if world.rules_on[rule]:
			on.append(FlockWorld.RULES[rule])
	return " ".join(on) if not on.is_empty() else "none"  # not shown


func _draw() -> void:
	draw_rect(Rect2(MARGIN, FlockWorld.SIZE), BACKGROUND)
	draw_rect(Rect2(MARGIN, FlockWorld.SIZE), BORDER, false, 1.0)
	for centre: Vector2 in world.obstacles:
		draw_circle(MARGIN + centre, FlockWorld.OBSTACLE_RADIUS, OBSTACLE_COLOUR)
	for boid: SteeringVehicle in world.boids:
		_draw_boid(boid, BOID_COLOUR, 1.0)
	_draw_what_the_watched_one_sees()


# Its sight and too-close circles, a line to each neighbour it counted, the
# point cohesion steers at, and its forces as arrows -- all where everyone
# was when it decided (`FlockWorld.decided_at`), the snapshot the forces
# came from, not where that decision has since moved them.
func _draw_what_the_watched_one_sees() -> void:
	var watched: SteeringVehicle = world.boids[world.watched]
	var at: Vector2 = MARGIN + world.decided_at[world.watched]
	draw_arc(at, FlockWorld.SIGHT, 0.0, TAU, 48, SIGHT_COLOUR, 1.0)
	draw_arc(at, FlockWorld.TOO_CLOSE, 0.0, TAU, 32, FORCE_COLOURS[Flock.Rule.SEPARATION] * Color(1, 1, 1, 0.5), 1.0)
	for index: int in world.counted:
		draw_line(at, MARGIN + world.decided_at[index], SIGHT_COLOUR, 1.0)
		_draw_boid(world.boids[index], NEIGHBOUR_COLOUR, 1.0)
	if not world.counted.is_empty():
		draw_circle(MARGIN + world.centre_seen(), 3.0, FORCE_COLOURS[Flock.Rule.COHESION])
	for rule: int in range(world.forces.size()):
		var arrow: Vector2 = world.forces[rule] / FlockWorld.MAX_FORCE * ARROW_PIXELS
		draw_line(at, at + arrow, FORCE_COLOURS[rule], 3.0)
	_draw_boid(watched, WATCHED_COLOUR, 1.6)


func _draw_boid(boid: SteeringVehicle, colour: Color, size: float) -> void:
	var at: Vector2 = MARGIN + boid.position
	var heading: Vector2 = boid.velocity.normalized()
	if heading == Vector2.ZERO:
		heading = Vector2.RIGHT
	var side := Vector2(-heading.y, heading.x)
	draw_colored_polygon(PackedVector2Array([at + heading * 7.0 * size, at - heading * 4.0 * size + side * 3.5 * size,
		at - heading * 4.0 * size - side * 3.5 * size]), colour)


func _refresh() -> void:
	var clock: String = tr("{seconds} s  (paused)") if paused else tr("{seconds} s")
	var lines: Array[String] = [clock.format({seconds = "%.1f" % (world.steps / 60.0)}),
		tr("1 separation, 2 alignment, 3 cohesion: on or off"),
		tr("click: an obstacle  ·  Tab: the next boid"),
		tr("space: pause  ·  .: one step  ·  R: again"), ""]
	for rule: int in range(FlockWorld.RULES.size()):
		var state: String = tr("switched on") if world.rules_on[rule] else tr("switched off")
		lines.append(tr("{rule} ({state}): pushes {force}").format({rule = tr(FlockWorld.RULES[rule]), state = state,
			force = "%.0f" % world.forces[rule].length()}))
	lines.append(tr("boid {boid} counts {count} neighbours").format({boid = world.watched,
		count = world.counted.size()}))
	_status.text = "\n".join(lines)
