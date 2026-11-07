## The infiltration level you play (T70): sneak past guards who notice,
## doubt, search together and call for help -- or go in shooting. Third
## person; the same guards on every level.
##
## Keys: WASD walk (relative to the camera), the mouse turns the camera, C
## crouches, Z lies prone, Shift sprints, G throws a distraction where the
## crosshair points, E takes down a guard from behind, F opens or shuts
## the door within reach (T115), a click shoots. 1
## cycles the belief (off, grid, particles), 2-4 switch the coordinator,
## the arbiter and the accumulator; 5
## the off-screen halving; 6 the director (T90), which starts the level
## again with its reserve guards. Tab watches the next guard, H hides the AI's
## reasoning, L the next level (two hand-made, then generated ones), N
## starts again, P pauses, Space one decision while paused. K how a
## generated level is made (T95): drawn and tested, solved by the constraint
## solver, or solved with the solver's work replayed over the screen.
##
## The watched guard's intruder network (T115) is drawn under the radar:
## whether it believes anyone is there, which sign says so, and the last
## sign that changed its mind (`SuspicionView`).
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
var _stance: String = "standing"  # not shown: an identifier
## The one-shot wishes the input gathered since the last step.
var _pending := PlayerIntent.new()
var _pad := PadAsKeys.new()
## The director's strip, under the radar.
var _strip := DirectorStrip.new()
## The watched guard's intruder network, under the strip.
var _suspicion := SuspicionView.new()
## The solved level the generation view replays; null when it was drawn.
var solved: LevelConstraints
## The last level the solver made, kept by its seed so that N and a second
## K do not solve it again (120 ms a level on average, 2.2 s at worst).
var _last_solved: LevelConstraints
## The solve running off the main thread (T122); the old level plays on
## until it ends, and the panel says it is solving.
var _solving := LevelSolving.new()
## The seed of the solved level waited for to replace the one played, or
## -1: what the panel names, and what a finished solve rebuilds the world
## for. Not the pool's seed: L pressed mid-solve asks for the next one.
var _awaited: int = -1
## Whether a level is solved on `WorkerThreadPool`; headless, inline, so a
## seeded run never waits on a thread.
var solve_in_background: bool = DisplayServer.get_name() != "headless"
var _generation := GenerationView.new()

@onready var _drawing: InfiltrationDrawing = $Drawing
@onready var _camera: Camera3D = $Camera
@onready var _hud: InfiltrationHud = $Interface/Hud
@onready var _radar: InfiltrationRadar = $Interface/Radar
@onready var _panel: Label = $Interface/Panel
@onready var _legend: Legend = $Interface/Legend


func _ready() -> void:
	_pad.use(PAD_BUTTONS, [KEY_A, KEY_D, KEY_W, KEY_S], true)
	add_child(_pad)
	_strip.position = Vector2(964, 220)
	_strip.size = Vector2(300, 90)
	$Interface.add_child(_strip)
	_suspicion.position = Vector2(964, 318)
	_suspicion.size = Vector2(300, 112)
	$Interface.add_child(_suspicion)
	_generation.position = Vector2(300, 120)
	_generation.size = Vector2(660, 420)
	_generation.visible = false
	$Interface.add_child(_generation)
	_show_legend()
	_new_world()
	Language.apply_if_opened_alone(self)


# The legend is drawn, so it is rebuilt in the language just chosen (T80);
# the panel and the guards' labels are rebuilt every frame anyway.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_show_legend()


# The legend, then the pad's buttons under it when a pad is connected.
func _show_legend() -> void:
	_legend.set_entries([
		[InfiltrationDrawing.PHASES[0], tr("a guard's zones and bar: calm")],
		[InfiltrationDrawing.PHASES[1], tr("suspicious")],
		[InfiltrationDrawing.PHASES[2], tr("searching")],
		[InfiltrationDrawing.PHASES[3], tr("alert")],
		[InfiltrationDrawing.CLEAR, tr("a body point the guard sees; red: hidden by a box")],
		[InfiltrationDrawing.BELIEF, tr("where the watched guard believes you are")],
		[InfiltrationDrawing.PARTICLE, tr("particles (1): its guesses, bigger where more")],
		[InfiltrationDrawing.EMPTIED, tr("white square: guesses its sight just cleared")],
		[InfiltrationDrawing.SPOT, tr("the spot it was given to search; grey: searched")],
		[InfiltrationDrawing.SOUND, tr("a sound's reach along the level")],
	])
	_pad.add_to(_legend)


func _physics_process(delta: float) -> void:
	_collect_solved()
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
			"heard_help": world.time - guard.help_heard_at <= 15.0, "certainty": guard.percept.sight.certainty,
			"intruder": guard.suspicion.belief, "signs": guard.suspicion.asked,
			"lead": guard.suspicion.lead})
	return {"time": world.time, "guards": guards, "off_screen_halving": rules.off_screen_halving,
		"switches": {"belief": rules.use_belief, "particles": rules.use_particles, "coordinator": rules.use_coordinator,
			"arbiter": rules.use_arbiter, "accumulator": rules.use_accumulator, "director": rules.use_director},
		"director": director_overlay(), "generator": generator_overlay()}


## How the level was made, for the overlay: the mode, and for a solved one
## the solver's counts and how far the view has replayed them.
func generator_overlay() -> Dictionary:
	var found: Dictionary = {"mode": rules.level_generator, "shown": rules.show_generation, "solved": solved != null}
	if solved != null:
		found.merge({"assignments": solved.solver.assignments, "backtracks": solved.solver.backtracks,
			"pruned": solved.solver.pruned, "steps": solved.solver.trace.size(), "replayed": _generation.progress().x})
	return found


## The next way of making a generated level, in the cycle K turns: drawn,
## solved, solved and shown. On a generated level the world starts again;
## on a hand-made one only the mode changes, for the next generated level.
func next_generator() -> void:
	if rules.level_generator == LevelGenerator.DRAW:
		rules.level_generator = LevelGenerator.CONSTRAINTS
	elif not rules.show_generation:
		rules.show_generation = true
	else:
		rules.level_generator = LevelGenerator.DRAW
		rules.show_generation = false
	if _level_index >= InfiltrationLevel.HAND_MADE.size():
		_new_world()


## The director's side of the overlay: its phase, the intensity it was
## taken on, and how many orders it gave; only `on`, false, with it off.
func director_overlay() -> Dictionary:
	if world.director == null:
		return {"on": false}
	return {"on": true, "phase": world.director.pacing.phase, "intensity": world.director.pacing.intensity,
		"orders": world.director.orders.size(), "on_patrol": world.director.on_patrol(world).x}


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
			_stance = "standing" if _stance == "crouched" else "crouched"  # not shown: an identifier
		KEY_Z:
			_stance = "standing" if _stance == "prone" else "prone"  # not shown: an identifier
		KEY_G:
			_pending.throw_at = _aim_point()
		KEY_E:
			_pending.takedown = true
		KEY_F:
			_pending.use_door = true
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
	var level: InfiltrationLevel = _level()
	if level == null:
		return  # being solved off the main thread: the old level plays on
	_awaited = -1
	world = InfiltrationWorld.make(level, rules, _seed)
	world.sounds.on_screen = _on_screen
	_watched = mini(_watched, world.guards.size() - 1)
	_yaw = 0.0
	_drawing.build(world)
	_hud.world = world
	_hud.camera = _camera
	_strip.world = world
	_suspicion.world = world
	_radar.world = world


# The level to play: a hand-made one, or one generated the way the rules'
# `level_generator` says. A solved level falls back to the drawn one when the
# solver gave up, and the generation view, when shown, says so. Null while
# the level is being solved off the main thread.
func _level() -> InfiltrationLevel:
	if _level_index < InfiltrationLevel.HAND_MADE.size():
		_show_made(null)
		return InfiltrationLevel.read(InfiltrationLevel.HAND_MADE[_level_index])
	var generated: int = _seed + _level_index
	if rules.level_generator != LevelGenerator.CONSTRAINTS:
		_show_made(null)
	else:
		var found: LevelConstraints = _solved_for(generated)
		if found == null:
			return null
		_show_made(found)
		if not found.data.is_empty():
			return InfiltrationLevel.read(found.data, "solved %d" % generated)  # not shown as written: InfiltrationWords.level words it
	return InfiltrationLevel.read(LevelGenerator.make(generated), "generated %d" % generated)  # not shown as written: InfiltrationWords.level words it


# What the generation view and the overlay show for the level about to be
# played: `found`, the solver's level, or null for a drawn or hand-made one.
func _show_made(found: LevelConstraints) -> void:
	solved = found if found != null and not found.data.is_empty() else null
	_generation.show_solving(solved)
	_generation.visible = found != null and rules.show_generation
	if found != null and found.data.is_empty():
		_generation.show_gave_up(found.seed_value)


# The level the solver makes from `generated`, solved once and kept; null
# while it is being solved on the pool. Inline when there is no world yet
# to play meanwhile, or when `solve_in_background` is off.
func _solved_for(generated: int) -> LevelConstraints:
	if _last_solved != null and _last_solved.seed_value == generated:
		return _last_solved
	if world == null or not solve_in_background:
		_last_solved = LevelConstraints.solve(generated, true)
		return _last_solved
	_solving.start(generated)
	_awaited = generated
	return null


# A solve the pool finished becomes the kept level, and the world is built
# again if a solved level is still awaited: L pressed while it ran may await
# another seed, solved next; K to drawn or L to a hand-made level, none.
func _collect_solved() -> void:
	var found: LevelConstraints = _solving.poll()
	if found == null:
		return
	_last_solved = found
	if _awaited != -1:
		_new_world()


# A task still running when the scene leaves is waited for: the pool frees
# a task only once it is waited for. Until it ends the window is frozen (up
# to about 2.5 s on seed 144). Its level is dropped: nothing adds this scene
# back to the tree, and one that did would have to ask again.
func _exit_tree() -> void:
	_solving.wait()


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
	_strip.thinking = _thinking
	_strip.queue_redraw()
	_suspicion.watched = _watched
	_suspicion.thinking = _thinking
	_suspicion.queue_redraw()
	_panel.text = InfiltrationText.panel(world, _watched) if _thinking else InfiltrationWords.level(world.level.name)
	if _awaited != -1:
		_panel.text = tr("solving level {seed}: this one plays until it is ready").format({seed = _awaited}) + "\n" + _panel.text


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
