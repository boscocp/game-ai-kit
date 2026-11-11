## The boss fight you play (T157): one boss, a few melee minions and one or
## two ranged, round you in a small arena -- a group, but one strikes at a
## time, and the ranged one shoots from the edge only while no melee one is
## on you, as a request described Insomniac's Spider-Man (`BossFight` says
## how). Third person.
##
## Keys: WASD walk (relative to the camera), the mouse turns the camera, a
## click or J a light attack, Shift dodges (nothing hurts you mid-dodge), Q
## locks on to the nearest enemy in view and again lets go. H hides the AI's
## reasoning, N fights again, P pauses, Space one decision while paused.
## The controller: the left stick walks, the right looks, RT attacks, A
## dodges, RB locks on, Y hides the reasoning.
##
## The camera and the walking are the infiltration level's, copied rather
## than shared: an example depends on no other example (`modules/`).
extends Node3D

const MOUSE_TURN: float = 0.0025
const CAMERA_BACK: float = 6.0
const CAMERA_UP: float = 3.0
## The controller, as the keys.
const PAD_BUTTONS: Dictionary = {JOY_BUTTON_A: KEY_SHIFT, JOY_BUTTON_RIGHT_SHOULDER: KEY_Q, JOY_BUTTON_Y: KEY_H,
		JOY_BUTTON_X: KEY_J}

var fight: BossFight
var _seed: int = 1
var _paused: bool = false
var _thinking: bool = true
var _carried: float = 0.0
var _yaw: float = -PI / 2.0
var _pitch: float = -0.35
var _pending := BossFightIntent.new()
var _pad := PadAsKeys.new()
var _boss_panel := BossPanel.new()

@onready var _drawing: BossfightDrawing = $Drawing
@onready var _camera: Camera3D = $Camera
@onready var _panel: Label = $Interface/Panel
@onready var _legend: Legend = $Interface/Legend


func _ready() -> void:
	_pad.use(PAD_BUTTONS, [KEY_A, KEY_D, KEY_W, KEY_S], true)
	add_child(_pad)
	_boss_panel.name = "BossPanel"  # not shown: a node's name
	_boss_panel.position = Vector2(880, 12)
	_boss_panel.size = Vector2(384, 160)
	_boss_panel.reasons.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_boss_panel.reasons.custom_minimum_size = Vector2(384, 0)
	_boss_panel.add_theme_constant_override("separation", 4)
	for label: Label in [_boss_panel.heading, _boss_panel.reasons]:
		label.add_theme_font_size_override("font_size", 13)
	$Interface.add_child(_boss_panel)
	_show_legend()
	_new_fight()
	Language.apply_if_opened_alone(self)


# The legend is drawn, so it is rebuilt in the language just chosen.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_show_legend()


func _show_legend() -> void:
	_legend.set_entries([
		[BossfightDrawing.MELEE_TOKEN, tr("a melee token: this one may strike you now")],
		[BossfightDrawing.RANGED_TOKEN, tr("a ranged token, and a ranged minion's aim")],
		[BossfightDrawing.RING, tr("the rings: inner to strike, waiting, the ranged band")],
		[BossfightDrawing.CLAIM, tr("the ring point each minion claimed")],
		[BossfightDrawing.TELEGRAPH, tr("the boss's reach, filling as it winds up")],
		[BossfightDrawing.ACTIVE, tr("the blow lands now: dodge")],
		[BossfightDrawing.LOCK, tr("cross: your lock-on")],
	])
	_pad.add_to(_legend)


func _physics_process(delta: float) -> void:
	if not _paused and fight.outcome == "":
		_carried += delta
		while _carried >= fight.rules.step_seconds:
			_carried -= fight.rules.step_seconds
			fight.step(_intent())
	_show()


## One decision: the fight stepped, you standing still, until the minions
## have asked for tokens and points once more.
func step_decision() -> void:
	var due: float = fight.next_decision()
	while fight.time < due + fight.rules.step_seconds and fight.outcome == "":
		fight.step(_still())
	_show()


## What the group is deciding with: each kind's tokens, holders, queue and
## timer; the rings and their claims; each minion; the boss's phase, attack
## and telegraph (`BossFightShown`).
func decision_overlay() -> Dictionary:
	return BossFightShown.overlay(fight)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw += event.relative.x * MOUSE_TURN
		_pitch = clampf(_pitch - event.relative.y * MOUSE_TURN, -1.2, 0.2)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_pending.attack = true
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event.keycode)


func _key(keycode: Key) -> void:
	match keycode:
		KEY_J:
			_pending.attack = true
		KEY_SHIFT:
			_pending.dodge = true
		KEY_Q:
			_pending.toggle_lock = true
		KEY_H:
			_thinking = not _thinking
		KEY_N:
			_seed += 1
			_new_fight()
		KEY_P:
			_paused = not _paused
		KEY_SPACE:
			_step_while_paused()
		KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _step_while_paused() -> void:
	if _paused:
		step_decision()


func _new_fight() -> void:
	fight = BossFight.shipped(_seed)
	_drawing.build(fight)


# The keys held and the wishes gathered since the last step, walking
# relative to the camera.
func _intent() -> BossFightIntent:
	var made := _pending
	_pending = BossFightIntent.new()
	var ahead: float = float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
	var aside: float = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	var forward: Vector2 = Vector2.from_angle(_yaw)
	made.direction = (forward * ahead + forward.orthogonal() * -aside).limit_length(1.0)
	_view(made)
	return made


func _still() -> BossFightIntent:
	var still := BossFightIntent.new()
	_view(still)
	return still


# The camera on the ground: where it stands and which way it looks.
func _view(intent: BossFightIntent) -> void:
	intent.view_forward = Vector2.from_angle(_yaw)
	intent.view_from = fight.player.position - intent.view_forward * CAMERA_BACK


func _show() -> void:
	if fight.player.locked != "":
		var toward: Vector2 = fight.position_of(fight.player.locked) - fight.player.position
		if toward.length() > 0.5:
			_yaw = lerp_angle(_yaw, toward.angle(), 0.15)
	_place_camera()
	_drawing.refresh(fight, _thinking)
	_panel.text = BossfightText.panel(fight, _thinking)
	_boss_panel.visible = _thinking
	_boss_panel.show_boss(fight.boss.shown(fight.time))


# Behind the player and above, looking the way the mouse turned it.
func _place_camera() -> void:
	var head := Vector3(fight.player.position.x, 1.5, fight.player.position.y)
	var forward: Vector2 = Vector2.from_angle(_yaw)
	var behind: Vector3 = -Vector3(forward.x, 0.0, forward.y) * CAMERA_BACK * cos(_pitch)
	_camera.position = head + behind + Vector3.UP * (CAMERA_UP - sin(_pitch) * CAMERA_BACK * 0.5)
	_camera.look_at(head + Vector3(forward.x, 0.0, forward.y) * 2.0, Vector3.UP)
