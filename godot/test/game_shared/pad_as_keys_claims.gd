# A controller presses the keys an example reads (wave 84).
#
# `PadAsKeys` turns a button into a key, the left stick into direction keys,
# the right trigger into the left mouse button and the right stick into the
# mouse moving. Every example reads one of those already, so the claims are
# about what the example would see -- `Input`'s own state -- after a pad
# event arrives the way a real pad's does, through `Input.parse_input_event`:
#
#   1. a mapped button holds its key down, as both `is_key_pressed` and
#      `is_physical_key_pressed` see it (the fighting game reads the second),
#      and lets go with the button;
#   2. the stick presses its direction past PRESS_AT, keeps it between
#      the two lines, and lets go under RELEASE_AT; up is the stick's
#      negative y;
#   3. the right trigger holds the left mouse button, and the right stick
#      moves the mouse;
#   4. a table swapped mid-press lets go of what the old one held;
#   5. without the mouse, the triggers hold their keys -- a racer's brake
#      and throttle;
#   6. a key pressed while Shift is held carries Shift, as a keyboard's
#      does: the stealth game reads its sprint from the arrow's own event --
#      even when both arrive in the same frame;
#   7. a key two inputs hold -- the racers' throttle, the stick's up and RT
#      -- stays down while either holds it: the stick wobbling near zero as
#      you steer does not lift the throttle RT still holds; and the
#      fighting game's walk, the stick's left and the D-pad's (wave 85);
#   8. the legend's line says the table in English, and in pt-BR keeps no
#      English word but the key names and the names printed on the pad; with
#      `PadAsKeys.planted`, it is written with no pad connected, broken
#      into lines that each fit the legend's width, and nothing dropped
#      (T103).
#
# Planted, and refused: each claim's numbers with that one claim broken, a
# pad that presses only the keycode -- the fighting game would not move --
# a pad where a key has one owner, wave 84's first version, and the English
# line, whose six English words must all be found.
#
#     ./scripts/godot --headless --path godot -s res://test/game_shared/pad_as_keys_claims.gd
#
# Exit codes: 0 every claim held; 1 one did not, or a planted case passed.
extends SceneTree

## A pad that sets the key's code and not its physical code: a keyboard
## reader of `keycode` would see it, `is_physical_key_pressed` would not.
class KeycodeOnlyPad extends PadAsKeys:
	func _send_key(key: Key, pressed: bool) -> void:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)


## A pad where a key has one owner, as wave 84 first wrote it: whichever
## input lets go, the key goes up -- and a racer steering lost its throttle.
class OneOwnerPad extends PadAsKeys:
	func _hold(_source: String, key: Key, pressed: bool) -> void:
		if pressed == _holders.has(key):
			return
		if pressed:
			_holders[key] = ["anyone"]
		else:
			_holders.erase(key)
		_send_key(key, pressed)

	func _hold_while(source: String, key: Key, amount: float) -> void:
		if not _holders.has(key) and amount >= PRESS_AT:
			_hold(source, key, true)
		elif _holders.has(key) and amount <= RELEASE_AT:
			_hold(source, key, false)


## Counts the mouse moving, as an example's `_unhandled_input` would see it.
class MotionCounter extends Node:
	var moves: int = 0

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			moves += 1


## Whether Up arrived with Shift held on the event itself.
class ShiftWatcher extends Node:
	var up_with_shift: bool = false

	func _unhandled_input(event: InputEvent) -> void:
		var key := event as InputEventKey
		if key != null and key.pressed and key.keycode == KEY_UP and key.shift_pressed:
			up_with_shift = true


const ALL_HELD: Dictionary = {"button_held": true, "button_physical": true, "button_released": true,
		"stick_pressed": true, "stick_kept": true, "stick_let_go": true, "stick_up": true,
		"click": true, "click_released": true, "looked": true, "swap_released": true,
		"trigger_held": true, "trigger_released": true, "shift_carried": true,
		"shift_same_frame": true, "shared_kept": true, "shared_released": true,
		"stick_and_dpad_kept": true, "stick_and_dpad_released": true,
		"legend_english": true, "legend_portuguese": true, "legend_planted": true,
		"legend_fits": true, "legend_whole": true}
## The narrowest legend with a pad's line, the stealth hall's.
const LEGEND_WIDTH: float = 290.0
## The line `_legend_words` expects in English, every kind of binding in it.
const LEGEND_IN_ENGLISH: String = ("pad: stick A/D/W/S, A Space, D-pad up Up, LT Down, RT Up, "
		+ "right stick looks, RT clicks")
## The words of that line a person reads as English; key names (Up, Space)
## and the names printed on the pad (A, LT) stay in every language.
const ENGLISH_WORDS: Array[String] = ["pad", "stick", "up", "down", "left", "right", "looks", "clicks"]


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var failures: Array[String] = _planted()
	var seen: Dictionary = await _measure(PadAsKeys.new())
	failures.append_array(claims(seen))
	var keycode_only: Dictionary = await _measure(KeycodeOnlyPad.new())
	if claims(keycode_only).is_empty():
		failures.append("planted: a pad pressing only the keycode passed")
	var one_owner: Dictionary = await _measure(OneOwnerPad.new())
	for claim: String in ["shared_kept", "stick_and_dpad_kept"]:
		if not "%s did not hold" % claim in claims(one_owner):
			failures.append("planted: a pad where a key has one owner passed %s" % claim)
	print("pad_as_keys: measured %s" % seen)
	for failure: String in failures:
		print("FAIL ", failure)
	print("pad_as_keys: %d failure(s)" % failures.size())
	quit(1 if not failures.is_empty() else 0)


## The findings for what `Input` showed, one per claim that did not hold.
static func claims(seen: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	for name: String in ALL_HELD:
		if not seen.get(name, false):
			failures.append("%s did not hold" % name)
	return failures


# Each claim broken alone must be found, by name.
func _planted() -> Array[String]:
	var failures: Array[String] = []
	for name: String in ALL_HELD:
		var broken: Dictionary = ALL_HELD.duplicate()
		broken[name] = false
		if claims(broken).size() != 1:
			failures.append("planted: %s broken was not found alone" % name)
	if english_words(LEGEND_IN_ENGLISH).size() != 6:
		failures.append("planted: the English line's six English words were not all found: %s" % [english_words(LEGEND_IN_ENGLISH)])
	return failures


# Drive `pad` as a person would and record what `Input` showed after each.
func _measure(pad: PadAsKeys) -> Dictionary:
	var counter := MotionCounter.new()
	root.add_child(counter)
	root.add_child(pad)
	pad.use({JOY_BUTTON_A: KEY_SPACE}, [KEY_A, KEY_D, KEY_W, KEY_S], true)
	var seen: Dictionary = {}
	await _button(JOY_BUTTON_A, true)
	seen["button_held"] = Input.is_key_pressed(KEY_SPACE)
	seen["button_physical"] = Input.is_physical_key_pressed(KEY_SPACE)
	await _button(JOY_BUTTON_A, false)
	seen["button_released"] = not Input.is_key_pressed(KEY_SPACE)
	await _axis(JOY_AXIS_LEFT_X, 0.8)
	seen["stick_pressed"] = Input.is_physical_key_pressed(KEY_D)
	await _axis(JOY_AXIS_LEFT_X, 0.4)
	var kept: bool = Input.is_physical_key_pressed(KEY_D)
	await _axis(JOY_AXIS_LEFT_X, 0.2)
	seen["stick_kept"] = kept
	seen["stick_let_go"] = not Input.is_physical_key_pressed(KEY_D)
	await _axis(JOY_AXIS_LEFT_Y, -0.9)
	seen["stick_up"] = Input.is_physical_key_pressed(KEY_W) and not Input.is_physical_key_pressed(KEY_S)
	await _axis(JOY_AXIS_LEFT_Y, 0.0)
	seen.merge(await _mouse(counter))
	await _button(JOY_BUTTON_A, true)
	pad.use({})
	await _frames(2)
	seen["swap_released"] = not Input.is_physical_key_pressed(KEY_SPACE)
	await _button(JOY_BUTTON_A, false)
	seen.merge(await _triggers_and_shift(pad))
	seen.merge(await _shared_key(pad))
	seen.merge(_legend_words(pad))
	pad.queue_free()
	counter.queue_free()
	await _frames(2)
	return seen


# The trigger as the left mouse button, and the right stick as the mouse.
func _mouse(counter: MotionCounter) -> Dictionary:
	var seen: Dictionary = {}
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 0.9)
	seen["click"] = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 0.1)
	seen["click_released"] = not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await _axis(JOY_AXIS_RIGHT_X, 1.0)
	await _frames(5)
	await _axis(JOY_AXIS_RIGHT_X, 0.0)
	seen["looked"] = counter.moves > 0
	return seen


# The triggers as keys, and Shift carried on the key pressed after it.
func _triggers_and_shift(pad: PadAsKeys) -> Dictionary:
	var seen: Dictionary = {}
	var shift_seen := ShiftWatcher.new()
	root.add_child(shift_seen)
	pad.use({JOY_BUTTON_LEFT_SHOULDER: KEY_SHIFT, JOY_BUTTON_DPAD_UP: KEY_UP}, [], false, [KEY_DOWN, KEY_UP])
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 0.9)
	seen["trigger_held"] = Input.is_physical_key_pressed(KEY_UP)
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	seen["trigger_released"] = not Input.is_physical_key_pressed(KEY_UP)
	await _button(JOY_BUTTON_LEFT_SHOULDER, true)
	await _button(JOY_BUTTON_DPAD_UP, true)
	seen["shift_carried"] = shift_seen.up_with_shift
	await _button(JOY_BUTTON_DPAD_UP, false)
	await _button(JOY_BUTTON_LEFT_SHOULDER, false)
	# Both in one frame: LB's Shift is still queued when the D-pad's Up goes.
	shift_seen.up_with_shift = false
	_send_now(_joy_button(JOY_BUTTON_LEFT_SHOULDER, true))
	_send_now(_joy_button(JOY_BUTTON_DPAD_UP, true))
	await _frames(3)
	seen["shift_same_frame"] = shift_seen.up_with_shift
	await _button(JOY_BUTTON_DPAD_UP, false)
	await _button(JOY_BUTTON_LEFT_SHOULDER, false)
	shift_seen.queue_free()
	return seen


# The racers' throttle: the stick's up and RT both press Up. RT held, the
# stick goes up and comes back near zero, as steering wobbles it.
func _shared_key(pad: PadAsKeys) -> Dictionary:
	var seen: Dictionary = {}
	pad.use({}, [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN], false, [KEY_DOWN, KEY_UP])
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _axis(JOY_AXIS_LEFT_Y, -0.8)
	await _axis(JOY_AXIS_LEFT_Y, -0.1)
	seen["shared_kept"] = Input.is_physical_key_pressed(KEY_UP)
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	seen["shared_released"] = not Input.is_physical_key_pressed(KEY_UP)
	# The fighting game: the stick held left, the D-pad's left pressed too,
	# then the stick let go -- the D-pad still walks.
	pad.use({JOY_BUTTON_DPAD_LEFT: KEY_A}, [KEY_A, KEY_D, KEY_W, KEY_S])
	await _axis(JOY_AXIS_LEFT_X, -0.9)
	await _button(JOY_BUTTON_DPAD_LEFT, true)
	await _axis(JOY_AXIS_LEFT_X, 0.0)
	seen["stick_and_dpad_kept"] = Input.is_physical_key_pressed(KEY_A)
	await _button(JOY_BUTTON_DPAD_LEFT, false)
	seen["stick_and_dpad_released"] = not Input.is_physical_key_pressed(KEY_A)
	return seen


# The legend's line, in English and in pt-BR, with every kind of binding in
# it; and the line written with no pad connected, once one is planted.
func _legend_words(pad: PadAsKeys) -> Dictionary:
	var seen: Dictionary = {}
	pad.use({JOY_BUTTON_A: KEY_SPACE, JOY_BUTTON_DPAD_UP: KEY_UP}, [KEY_A, KEY_D, KEY_W, KEY_S], true,
			[KEY_DOWN, KEY_UP])
	TranslationServer.set_locale("en")
	seen["legend_english"] = pad.describe() == LEGEND_IN_ENGLISH
	TranslationServer.set_locale("pt_BR")
	var portuguese: String = pad.describe()
	seen["legend_portuguese"] = english_words(portuguese).is_empty() and portuguese.begins_with("controle: ")
	print("pad_as_keys: in pt-BR, %s" % portuguese)
	PadAsKeys.planted = true
	var legend := Legend.new()
	legend.size = Vector2(LEGEND_WIDTH, 200.0)
	pad.add_to(legend)
	PadAsKeys.planted = false
	var written: Array[String] = []
	for entry: Array in legend.entries:
		written.append(str(entry[1]))
	seen["legend_planted"] = written == pad.legend_lines(legend) and written.size() > 1
	seen["legend_fits"] = written.all(func(line: String) -> bool:
		return Legend.width_of(line) <= legend.words_width())
	seen["legend_whole"] = ", ".join(written.map(func(line: String) -> String:
		return line.strip_edges())) == portuguese
	legend.free()
	TranslationServer.set_locale("en")
	pad.use({})
	return seen


## The English words of the pad's line found in `line`, whole words only:
## none may be left in pt-BR. Key and button names are not among them, and
## "D-pad", which the menu's Portuguese keeps too, is not "pad".
static func english_words(line: String) -> Array[String]:
	var found: Array[String] = []
	for word: String in ENGLISH_WORDS:
		if RegEx.create_from_string("(?<![\\w-])%s(?![\\w-])" % word).search(line) != null:
			found.append(word)
	return found


# A pad event goes in buffered; the pad node answers it in the next frame
# with a key event, buffered in turn. Three frames see both through.
func _button(button: JoyButton, pressed: bool) -> void:
	_send_now(_joy_button(button, pressed))
	await _frames(3)


func _joy_button(button: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func _send_now(event: InputEvent) -> void:
	Input.parse_input_event(event)


func _axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	await _frames(3)


func _frames(count: int) -> void:
	for frame: int in range(count):
		await process_frame
