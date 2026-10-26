# The racer's human seat, through the scene a person opens: the keys reach
# your car, and the screen shows that car.
#
# The owner played `make demo-racing3d` (2026-10-22) and could not drive.
# The keys did drive: measured, the red car went 21 m in three seconds of
# a held Up. But the camera started on the first AI car, so the car on the
# screen ignored the keys, and the twenty seconds of measuring before the
# grid looked the same. Three claims hold the fix:
#
#   1. **the camera starts on your car**: once the scene is loaded, the
#      watched car is the human driver's -- and again after watching an AI
#      car and starting the race again (R or T);
#   2. **the wait is said**: while the cars are measured, the status panel
#      says the keys drive once every car is on the grid; racing, while an
#      AI car is watched, it says how to watch yours;
#   3. **the keys drive it**: once racing, your car stays put for
#      IDLE_FRAMES with no key held, then moves at least MIN_MOVED metres
#      in HELD_FRAMES with Up held -- pressed as a person's keyboard
#      would, through `Input.parse_input_event`.
#
# Each claim is first shown planted numbers it must refuse: the first AI's
# car watched, at the start or after a restart, a panel that says nothing
# of the keys or of Tab, a car the key does not move, and a car that moves
# with no key held.
#
#     ./scripts/godot --headless --fixed-fps 60 --path godot -s res://test/racing3d/racing3d_you_drive.gd
#
# Exit codes: 0 every claim held; 1 one did not, or a planted case passed.
extends SceneTree

const SCENE: String = "res://game3d/racing/racing3d.tscn"
## Physics frames the measuring may take before the run is given up on;
## measured on 4.7.2 (2026-10-22) at 1307.
const GIVE_UP: int = 3000
const IDLE_FRAMES: int = 60
const HELD_FRAMES: int = 120
## Metres a held Up must move the car in HELD_FRAMES; measured 9.3 m in
## two seconds from rest, so a fifth of that is still unmistakably driving.
const MIN_MOVED: float = 2.0
## Metres the car may creep with no key held, settling on its springs.
const STILL: float = 0.2
## Words the panel must show while measuring, and racing while an AI car
## is watched.
const WAIT_WORDS: String = "the keys drive yours"
const TAB_WORDS: String = "Tab until"

var _errors := Racing3DErrors.new()
## The counter's own planted case, run first: "" when it counted it.
var _counter_works: String = ""


func _initialize() -> void:
	# The panel's English words are what it looks for, and the engine starts
	# in the machine's locale (T80): English, whatever the machine speaks.
	TranslationServer.set_locale("en")
	OS.add_logger(_errors)
	_counter_works = _errors.self_check()
	_run()


func _run() -> void:
	await process_frame
	var failures: Array[String] = _planted()
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var you: int = scene.race.drivers.find(scene.human)
	var seen: Dictionary = {"watched": scene.watched, "you": you, "panel": scene._status.text}
	var frames: int = 0
	while not scene.race.racing and frames < GIVE_UP:
		await physics_frame
		frames += 1
	if not scene.race.racing:
		failures.append("the race never started: still measuring after %d frames" % GIVE_UP)
	else:
		seen.merge(await _drive(scene.race.cars[you]))
		seen.merge(await _watch_another(scene))
		print("racing after %d frames; your car moved %.2f m idle, %.2f m with Up held" % [frames, seen["idle"], seen["held"]])
	failures.append_array(claims(seen))
	if _counter_works != "":
		failures.append(_counter_works)
	var engine: String = _errors.finding("the scene")
	if engine != "":
		failures.append(engine)
	for failure: String in failures:
		print(failure)
	print("racing3d you drive: %d failure(s)" % failures.size())
	quit(1 if not failures.is_empty() else 0)


# How far `car` moves with no key held, then with Up held as a keyboard
# would press it; Up is let go after.
func _drive(car: RaceCar3D) -> Dictionary:
	var start: Vector3 = car.global_position
	for frame: int in range(IDLE_FRAMES):
		await physics_frame
	var idle: float = start.distance_to(car.global_position)
	start = car.global_position
	_press(KEY_UP, true)
	for frame: int in range(HELD_FRAMES):
		await physics_frame
	_press(KEY_UP, false)
	return {"idle": idle, "held": start.distance_to(car.global_position)}


# Racing, an AI car watched: what the panel says; then the race started
# again, as R does, and which car the camera is on.
func _watch_another(scene: Node) -> Dictionary:
	scene.watched = 0
	# `process_frame` is emitted before the scene's `_process`: two frames,
	# so the panel has been drawn once since.
	await process_frame
	await process_frame
	var hint: String = scene._status.text
	scene.restart()
	return {"racing_panel": hint, "after_restart": scene.watched}


func _press(key: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = down
	Input.parse_input_event(event)


## The findings for what the scene showed: `seen` holds the watched car,
## yours, the panel's text while measuring, and -- absent when the race
## never started -- the metres your car moved idle and with Up held, the
## panel racing with an AI car watched, and the car watched after a restart.
static func claims(seen: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	if seen["watched"] != seen["you"]:
		failures.append("the camera starts on car %d, yours is car %d" % [seen["watched"], seen["you"]])
	if not WAIT_WORDS in String(seen["panel"]):
		failures.append("while measuring, the panel does not say when the keys drive")
	if seen.has("racing_panel") and not TAB_WORDS in String(seen["racing_panel"]):
		failures.append("racing, with an AI car watched, the panel does not say how to watch yours")
	if seen.has("after_restart") and seen["after_restart"] != seen["you"]:
		failures.append("after a restart the camera is on car %d, yours is car %d" % [seen["after_restart"], seen["you"]])
	if seen.has("held") and float(seen["held"]) < MIN_MOVED:
		failures.append("Up held moved your car %.2f m, under %.1f" % [seen["held"], MIN_MOVED])
	if seen.has("idle") and float(seen["idle"]) > STILL:
		failures.append("with no key held your car moved %.2f m, over %.1f" % [seen["idle"], STILL])
	return failures


# Every claim is shown one planted case it must refuse, and an honest one
# it must pass (invariant 4).
func _planted() -> Array[String]:
	var honest: Dictionary = {"watched": 3, "you": 3, "panel": WAIT_WORDS, "idle": 0.0, "held": 9.3,
		"racing_panel": TAB_WORDS, "after_restart": 3}
	var failures: Array[String] = []
	if not claims(honest).is_empty():
		failures.append("planted: an honest scene was refused: %s" % "; ".join(claims(honest)))
	var planted: Dictionary = {
		"the first AI's car watched": {"watched": 0},
		"a panel silent about the keys": {"panel": "Measuring each car on the test pad."},
		"a car the key does not move": {"held": 0.0},
		"a car that moves with no key": {"idle": 9.3},
		"a racing panel silent about Tab": {"racing_panel": "easy: 80 km/h"},
		"the first AI's car after a restart": {"after_restart": 0},
	}
	for name: String in planted:
		var case: Dictionary = honest.duplicate()
		case.merge(planted[name], true)
		if claims(case).size() != 1:
			failures.append("planted: %s gave %d finding(s), not 1" % [name, claims(case).size()])
	return failures
