## The infiltration level you play (T70): sneak past guards who notice,
## doubt, search together and call for help -- or go in shooting. Third
## person; the same guards on every level.
##
## Keys: WASD walk (relative to the camera), the mouse turns the camera, C
## crouches, Z lies prone, Shift sprints, G throws a distraction where the
## crosshair points, E takes down a guard from behind, a click shoots. 1-4
## switch the belief, the coordinator, the arbiter and the accumulator; 5
## the off-screen halving. Tab watches the next guard, H hides the AI's
## reasoning, L the next level (two hand-made, then generated ones), N
## starts again, P pauses, Space one decision while paused.
##
## The camera's frustum says which guards are on screen, for the halving.
extends Node3D

const MOUSE_TURN: float = 0.0025
const CAMERA_BACK: float = 4.5
const CAMERA_UP: float = 2.2
## Levels L cycles: the hand-made ones, then this many generated.
const GENERATED: int = 3

## The controller, as the keys (wave 84): the left stick walks, the right
## looks, RT shoots (the first pull takes the camera, as a click does), A a
## takedown, B crouch, X prone, RB throws, LB held sprints, Y the next guard.
const PAD_BUTTONS: Dictionary = {JOY_BUTTON_A: KEY_E, JOY_BUTTON_B: KEY_C, JOY_BUTTON_X: KEY_Z,
		JOY_BUTTON_RIGHT_SHOULDER: KEY_G, JOY_BUTTON_LEFT_SHOULDER: KEY_SHIFT, JOY_BUTTON_Y: KEY_TAB}

var world: InfiltrationWorld
var rules: InfiltrationRules = InfiltrationRules.read()
var _level_index: int = 0
var _seed: int = 1
var _watched: int = 0
var _paused: bool = false
var _thinking: bool = true
var _carried: float = 0.0
var _yaw: float = 0.0
var _pitch: float = -0.3
var _stance: String = "standing"
## The one-shot wishes the input gathered since the last step.
var _pending := PlayerIntent.new()

@onready var _drawing: InfiltrationDrawing = $Drawing
@onready var _camera: Camera3D = $Camera
@onready var _hud: InfiltrationHud = $Interface/Hud
@onready var _radar: InfiltrationRadar = $Interface/Radar
@onready var _panel: Label = $Interface/Panel
@onready var _legend: Legend = $Interface/Legend


func _ready() -> void:
	_legend.set_entries([
		[InfiltrationDrawing.PHASES[0], "a guard's zones and bar: calm"],
		[InfiltrationDrawing.PHASES[1], "suspicious"],
		[InfiltrationDrawing.PHASES[2], "searching"],
		[InfiltrationDrawing.PHASES[3], "alert"],
		[InfiltrationDrawing.CLEAR, "a body point the guard sees; red: hidden by a box"],
		[InfiltrationDrawing.BELIEF, "where the watched guard believes you are"],
		[InfiltrationDrawing.SPOT, "the spot it was given to search; grey: searched"],
		[InfiltrationDrawing.SOUND, "a sound's reach along the level"],
	])
	var pad := PadAsKeys.new()
	pad.use(PAD_BUTTONS, [KEY_A, KEY_D, KEY_W, KEY_S], true)
	add_child(pad)
	pad.add_to(_legend)
	_new_world()


func _physics_process(delta: float) -> void:
	if not _paused and world.outcome == "":
		_carried += delta
		while _carried >= rules.step_seconds:
			_carried -= rules.step_seconds
			world.step(_intent())
	_show()


## One decision: the world stepped, the player standing still, until every
## guard has weighed its actions once more.
func step_decision() -> void:
	var due: float = world.next_decision
	while world.time < due + rules.step_seconds and world.outcome == "":
		world.step(PlayerIntent.new())
	_show()


## What each guard is deciding with: its phase and awareness, the action it
## chose and every action's score, its role and whether it heard a call --
## and which switches are on.
func decision_overlay() -> Dictionary:
	var guards: Array = []
	for guard: InfiltrationGuard in world.guards:
		var record: Dictionary = world.decisions.get(guard.id, {})
		guards.append({"phase": guard.mind.phase_name(), "awareness": guard.aware(), "action": guard.action,
			"scores": record.get("scores", []), "role": guard.role, "spot": guard.spot,
			"heard_help": world.time - guard.help_heard_at <= 15.0, "certainty": guard.percept.sight.certainty})
	return {"time": world.time, "guards": guards, "off_screen_halving": rules.off_screen_halving,
		"switches": {"belief": rules.use_belief, "coordinator": rules.use_coordinator,
			"arbiter": rules.use_arbiter, "accumulator": rules.use_accumulator}}


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw += event.relative.x * MOUSE_TURN
		_pitch = clampf(_pitch - event.relative.y * MOUSE_TURN, -1.2, 0.4)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_pending.shoot = _aim_direction()
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event.keycode)


func _key(keycode: Key) -> void:
	match keycode:
		KEY_C:
			_stance = "standing" if _stance == "crouched" else "crouched"
		KEY_Z:
			_stance = "standing" if _stance == "prone" else "prone"
		KEY_G:
			_pending.throw_at = _aim_point()
		KEY_E:
			_pending.takedown = true
		KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_:
			InfiltrationKeys.switch(self, keycode)


## Build the world again on the current level and seed, the switches kept.
func new_world() -> void:
	_new_world()


## Cycle to the next level.
func next_level() -> void:
	_level_index = (_level_index + 1) % (InfiltrationLevel.HAND_MADE.size() + GENERATED)
	_new_world()


## Watch the next guard.
func watch_next() -> void:
	_watched = (_watched + 1) % world.guards.size()


## Pause, or go on.
func toggle_pause() -> void:
	_paused = not _paused


## Show the AI's reasoning, or only what a player sees.
func toggle_thinking() -> void:
	_thinking = not _thinking


func _new_world() -> void:
	var level: InfiltrationLevel
	if _level_index < InfiltrationLevel.HAND_MADE.size():
		level = InfiltrationLevel.read(InfiltrationLevel.HAND_MADE[_level_index])
	else:
		var generated: int = _seed + _level_index
		level = InfiltrationLevel.read(LevelGenerator.make(generated), "generated %d" % generated)
	world = InfiltrationWorld.make(level, rules, _seed)
	world.sounds.on_screen = _on_screen
	_watched = mini(_watched, world.guards.size() - 1)
	_yaw = 0.0
	_drawing.build(world)
	_hud.world = world
	_hud.camera = _camera
	_radar.world = world


func _intent() -> PlayerIntent:
	var made := _pending
	_pending = PlayerIntent.new()
	var ahead: float = float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
	var aside: float = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	var forward: Vector2 = Vector2.from_angle(_yaw)
	made.direction = (forward * ahead + forward.orthogonal() * -aside).limit_length(1.0)
	made.stance = _stance
	made.sprint = Input.is_key_pressed(KEY_SHIFT)
	return made


func _on_screen(guard: InfiltrationGuard) -> bool:
	return _camera.is_position_in_frustum(world.level.arena.above(guard.position, 1.2))


func _show() -> void:
	_place_camera()
	_drawing.refresh(world, _watched, _thinking)
	_hud.watched = _watched
	_radar.watched = _watched
	_hud.queue_redraw()
	_radar.queue_redraw()
	_panel.text = InfiltrationText.panel(world, _watched) if _thinking else world.level.name


# Behind the player and above, looking the way the mouse turned it: `_yaw`
# is the floor angle the camera faces, `_pitch` how far it looks down.
func _place_camera() -> void:
	var head: Vector3 = world.level.arena.above(world.player.position, 1.6)
	var forward: Vector2 = Vector2.from_angle(_yaw)
	var behind: Vector3 = -Vector3(forward.x, 0.0, forward.y) * CAMERA_BACK * cos(_pitch)
	_camera.position = head + behind + Vector3.UP * (CAMERA_UP - sin(_pitch) * CAMERA_BACK * 0.5)
	_camera.look_at(head + Vector3(forward.x, 0.0, forward.y) * 2.0, Vector3.UP)


func _aim_direction() -> Vector3:
	return (_aim_point_3d() - world.level.arena.above(world.player.position, rules.points_of(world.player.stance)[0])).normalized()


func _aim_point_3d() -> Vector3:
	var middle: Vector2 = get_viewport().get_visible_rect().size / 2.0
	var from: Vector3 = _camera.project_ray_origin(middle)
	var normal: Vector3 = _camera.project_ray_normal(middle)
	var reach: float = 60.0
	if normal.y < -0.01:
		reach = minf(reach, from.y / -normal.y)
	var toward: Vector3 = from + normal * reach
	return from.lerp(toward, world.level.arena.first_block(from, toward))


func _aim_point() -> Vector2:
	var point: Vector3 = _aim_point_3d()
	return Vector2(point.x, point.z)
