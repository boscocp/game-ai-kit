## Race the AI: your car against one AI driver, in the same car.
##
## T23's demo, made a game by T59. You drive the red car with the arrows or
## WASD; the AI drives the other, at the level 1-3 chose, for `LAPS` laps
## from a three-second count. Your car is a plain `RacingCar` on the race's
## one `RacingPhysics` -- the same engine, brakes and grip -- so who is faster
## is who drives better. The camera follows you; the minimap shows the rest.
##
## What the AI is deciding stays on screen while you race it: the white dot
## it steers at, down the line; the line coloured by the speed it allows
## itself, red where it must be slow; the white bar where it must already be
## braking. Follow it into a corner and you see where to brake. Tab switches
## to T23's view, the three levels racing each other on the whole track, 1-3
## following one and A showing it alone. P pauses, the full stop steps one
## sixtieth of a second while paused, R starts again.
class_name RacingDemo
extends Node2D

const LAPS: int = 3
const COUNTDOWN: float = 3.0
## Pixels a metre while racing, and while watching the whole track.
const RACE_ZOOM: float = 7.0
const WATCH_ZOOM: float = 1.95
## The middle of the screen left of the panel, in pixels: where the camera
## puts what it looks at.
const VIEW_MIDDLE: float = 472.0
const SCREEN_MIDDLE: float = 640.0
## Each car's picture and its dot on the minimap, in this order: yours, then
## easy, normal and hard.
const YOURS: int = 0
const DOTS: Array[Color] = [Color(0.95, 0.3, 0.1), Color(0.2, 0.55, 1.0), Color(1.0, 0.85, 0.1), Color(0.1, 0.1, 0.1)]
## Each car's wander follows the same seed, so a restart races the same race.
const SEED: int = 23
## Between the legend's last line and the status under it. The legend grows
## by the pad's lines, two or three of them, and the status follows it down;
## the minimap sits in the view's corner to leave the status the room (T108).
const BELOW_LEGEND: float = 12.0

## The controller, as the keys (wave 84): the stick steers, the triggers
## brake and drive, the D-pad chooses the AI, Y watches, X starts again,
## B one step while paused, Menu pauses. Arrows, not WASD: A is a key here.
const PAD_BUTTONS: Dictionary = {JOY_BUTTON_DPAD_LEFT: KEY_1, JOY_BUTTON_DPAD_UP: KEY_2,
		JOY_BUTTON_DPAD_RIGHT: KEY_3, JOY_BUTTON_Y: KEY_TAB, JOY_BUTTON_X: KEY_R,
		JOY_BUTTON_B: KEY_PERIOD, JOY_BUTTON_START: KEY_P}

@onready var _status: Label = $Interface/Status
@onready var _legend: Legend = $Interface/Legend
@onready var _banner: Label = $Interface/Banner
@onready var _minimap: RacingMinimap = $Interface/Minimap
@onready var _speedo: Label = $Interface/Speedo

var levels: Array[RacingLevel] = RacingLevel.ladder()
var race: RacingRace
var human: RacingHumanDriver
## Your car's number in the race, and the AI's when you race it; -1 watching.
var you: int = -1
var ai: int = -1
var track_view: RacingTrackView
var race_view: RacingRaceView
var camera := Camera2D.new()
## "race", you against one AI; or "watch", T23's three levels.
var mode: String = "race"
## The AI's level when racing, and the level followed when watching.
var chosen: int = 1
var alone: bool = false
var paused: bool = false
## Seconds left before the start; the race does not move until it is 0.
var countdown: float = 0.0
var _pad := PadAsKeys.new()


func _ready() -> void:
	add_child(camera)
	restart()
	_pad.use(PAD_BUTTONS, [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN], false, [KEY_DOWN, KEY_UP])
	add_child(_pad)
	_show_legend()
	Language.apply_if_opened_alone(self)


# Rebuilt in the language just chosen (T80): the panel and the banner are set
# from code and keep the words they were given, and the legend is drawn.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_show_legend()
		_refresh()


# The legend, then the pad's buttons under it when a pad is connected, and
# the status moved to just below its last line.
func _show_legend() -> void:
	_legend.set_entries([
		[Art.texture(Art.RACING_CARS[0]), tr("you")],
		[Art.texture(Art.RACING_CARS[1]), tr("easy AI")],
		[Art.texture(Art.RACING_CARS[2]), tr("normal AI")],
		[Art.texture(Art.RACING_CARS[3]), tr("hard AI")],
		[RacingRaceView.MARK, tr("dot: where the AI steers")],
		[RacingRaceView.MARK, tr("bar: where it must be braking")],
		[RacingRaceView.YOURS, tr("yellow bar: brake here, you")],
		[RacingTrackView.SLOW, tr("line: it must be slow here")],
		[RacingTrackView.FAST, tr("line: only top speed limits it")],
	] as Array[Array])
	_pad.add_to(_legend)
	_status.position.y = _legend.position.y + _legend.drawn_height() + BELOW_LEGEND


func _physics_process(delta: float) -> void:
	if paused:
		return
	if countdown > 0.0:
		countdown = maxf(countdown - delta, 0.0)
		_banner.text = "%d" % ceili(countdown) if countdown > 0.0 else ""
		return
	if human != null:
		_read_keys()
	step_decision()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.is_pressed() or key.echo:
		return
	match key.keycode:
		KEY_1, KEY_2, KEY_3:
			_choose(key.keycode - KEY_1)
		KEY_TAB:
			mode = "watch" if mode == "race" else "race"
			restart()
		KEY_A:
			alone = mode == "watch" and not alone
		KEY_P:
			paused = not paused
		KEY_PERIOD:
			_step_while_paused()
		KEY_R:
			restart()
	_show_alone()
	_refresh()


## Every driver decides once -- yours from the keys -- and every car moves
## one sixtieth of a second.
func step_decision() -> void:
	race.step()
	race_view.remember_marks()
	_follow_with_camera()
	race_view.queue_redraw()
	_speedo.text = RacingDemoText.speedo(race, you) if you >= 0 else ""
	_minimap.queue_redraw()
	if race.steps % 10 == 0:
		_refresh()


## What each AI driver is deciding with, for `test/menu/demo_overlays.gd`:
## the point it steers at, the speed it chose and the one it is doing, how
## far ahead it must be braking, and the knobs it used. And, when you race,
## your speed and lap.
func decision_overlay() -> Dictionary:
	var shown: Array[Dictionary] = []
	for number: int in range(race.cars.size()):
		if race.drivers[number] != human:
			shown.append(_ai_overlay(number))
	var overlay: Dictionary = {"step": race.steps, "mode": mode, "cars": shown}
	if human != null:
		overlay["you"] = {"speed": race.cars[you].speed, "lap": race.laps(you)}
	return overlay


## The race from its start: the cars at rest on the grid, the count running
## when you race. Racing, the AI takes the left of the front row, the inside
## of the first corner, and you the right. Alone, the right slot costs
## nothing, measured; what costs is being the one behind into the corner,
## which you then have to pass. Watching, easy starts in front, so the
## harder levels must pass it.
func restart() -> void:
	race = RacingRace.new(RacingPhysics.new())
	var pictures: Array[String] = []
	var dots: Array[Color] = []
	human = null
	you = -1
	ai = -1
	alone = false
	if mode == "race":
		human = RacingHumanDriver.new()
		ai = race.enter(RacingDriver.new(levels[chosen], SEED))
		you = race.enter(human)
		pictures.assign([Art.RACING_CARS[chosen + 1], Art.RACING_CARS[YOURS]])
		dots.assign([DOTS[chosen + 1], DOTS[YOURS]])
	else:
		for number: int in range(levels.size()):
			race.enter(RacingDriver.new(levels[number], SEED))
			pictures.append(Art.RACING_CARS[number + 1])
			dots.append(DOTS[number + 1])
	race.plan()
	_build_views(pictures)
	_minimap.show_race(race, dots)
	countdown = COUNTDOWN if mode == "race" else 0.0
	_banner.text = "%d" % ceili(countdown) if countdown > 0.0 else ""
	_follow_with_camera()
	_refresh()


# One sixtieth of a second, but only while paused -- running, the frames do
# it -- and not before the count is out. Your keys are read as on any step.
func _step_while_paused() -> void:
	if not paused or countdown > 0.0:
		return
	if human != null:
		_read_keys()
	step_decision()


# Racing, 1-3 choose the AI and start again; watching, they choose whom to
# follow, and the race goes on.
func _choose(level: int) -> void:
	chosen = level
	if mode == "race":
		restart()
		return
	track_view.show_level(levels[chosen])
	race_view.followed = chosen


# One AI driver's decision, as the overlay carries it.
func _ai_overlay(number: int) -> Dictionary:
	var driver: RacingDriver = race.drivers[number]
	return {"level": driver.level.title, "aim": [driver.aim.x, driver.aim.y],
		"target_speed": driver.target_speed, "speed": race.cars[number].speed,
		"braking_in": _braking_distance(number), "lap": race.laps(number), "used": driver.used}


func _build_views(pictures: Array[String]) -> void:
	if track_view != null:
		track_view.queue_free()
		race_view.queue_free()
	track_view = RacingTrackView.new(race, levels[chosen])
	race_view = RacingRaceView.new(race, pictures)
	race_view.followed = ai if mode == "race" else chosen
	race_view.you = you
	add_child(track_view)
	add_child(race_view)
	_show_alone()


func _show_alone() -> void:
	for number: int in range(race.cars.size()):
		race_view.shown[number] = not alone or number == race_view.followed
	race_view.queue_redraw()


# Racing, the camera sits on your car, close; watching, on the whole track.
# Either way what it looks at is put in the middle of the screen left of
# the panel.
func _follow_with_camera() -> void:
	var zoom: float = RACE_ZOOM if mode == "race" else WATCH_ZOOM
	var looked_at: Vector2 = race.cars[you].position if mode == "race" else _track_middle()
	camera.zoom = Vector2(zoom, zoom)
	camera.position = looked_at + Vector2((SCREEN_MIDDLE - VIEW_MIDDLE) / zoom, 0.0)


func _read_keys() -> void:
	human.throttle = Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W)
	human.brake = Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S)
	var left: bool = Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A)
	var right: bool = Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)
	human.steer = (1.0 if right else 0.0) - (1.0 if left else 0.0)


# Metres along the line to where car `number` must already be braking; the
# whole reach when nothing ahead is slower than it is.
func _braking_distance(number: int) -> float:
	var driver: RacingDriver = race.drivers[number]
	if driver.braking_point < 0:
		return RacingDriver.BRAKING_REACH * RacingTrack.SPACING
	var samples: int = posmod(driver.braking_point - driver.decided_at, race.track.line.size())
	return samples * RacingTrack.SPACING


func _refresh() -> void:
	if mode == "race":
		_status.text = RacingDemoText.racing(race, you, ai, LAPS, paused)
		var result: String = RacingDemoText.result(race, you, ai, LAPS)
		if result != "":
			_banner.text = result
	else:
		_status.text = RacingDemoText.watching(race, chosen, paused)


# The middle of the track's centre line, in metres: what the camera looks at
# when watching the whole of it.
func _track_middle() -> Vector2:
	var bounds := Rect2(race.track.centre[0], Vector2.ZERO)
	for point: Vector2 in race.track.centre:
		bounds = bounds.expand(point)
	return bounds.get_center()
