## A game controller that presses the keys an example already reads.
##
## Every example here reads the keyboard and the mouse, each in its own way --
## a key's event, a key held, a physical key held, the mouse moving. Teaching
## each one a second way in, for the controller, would double every input path
## a reader has to follow. So the controller is translated instead: each
## example declares a table, this button presses that key, and the example
## never learns a controller exists. The table is what the legend shows.
##
## Buttons become keys, the left stick becomes four direction keys, the right
## stick moves the mouse (for the examples that look around with it), and the
## right trigger is the left mouse button. A key is pressed through
## `Input.parse_input_event`, so `Input.is_key_pressed` and
## `is_physical_key_pressed` see it held until it is let go.
##
## When not to use it: a game designed for a controller should read analogue
## values through the InputMap. A stick pushed halfway is a key held here.
class_name PadAsKeys
extends Node

## How far a stick or a trigger must go before it counts as pressed, and how
## far back before it lets go: the gap stops a stick resting near the line
## from pressing and releasing every frame.
const PRESS_AT: float = 0.5
const RELEASE_AT: float = 0.35
## The right stick, fully pushed, moves the mouse this many pixels a second.
const LOOK_SPEED: float = 900.0
## Below this the right stick is resting, not looking: sticks rarely centre.
const LOOK_DEADZONE: float = 0.2
## How many bindings the legend puts on one line, so the table stays narrow.
const BINDINGS_A_LINE: int = 3
## The Xbox names for the buttons a table may use, as printed on the pad.
const BUTTON_NAMES: Dictionary = {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu",
	JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
}

## Which key each button presses: `{JOY_BUTTON_A: KEY_SPACE}`.
var buttons: Dictionary = {}
## The left stick's four directions as keys, left, right, up and down; empty
## leaves the stick unused.
var stick_keys: Array[Key] = []
## The left and right triggers as keys -- a racer's brake and throttle; empty
## leaves them unused. With `looks_with_mouse`, the right trigger clicks
## instead.
var trigger_keys: Array[Key] = []
## Whether the right stick moves the mouse and the right trigger clicks it.
var looks_with_mouse: bool = false

# Who holds each key down right now: a key to the pad inputs holding it --
# "button 0", "stick up", "RT". A key can be reached from two (a racer's
# throttle is the stick's up and RT), and it goes up only when the last of
# them lets go: steering wobbles the stick's y near zero, and a key with one
# owner dropped the throttle RT was still holding (wave 84's review).
var _holders: Dictionary = {}
var _holding_click: bool = false
var _right_stick: Vector2 = Vector2.ZERO


## Replace the table, letting go of every key the old one held. The menu swaps
## tables as an example starts and ends, and a key left held would drive the
## next example on its own.
func use(new_buttons: Dictionary, new_stick_keys: Array[Key] = [], mouse: bool = false,
		new_trigger_keys: Array[Key] = []) -> void:
	release_all()
	buttons = new_buttons
	stick_keys = new_stick_keys
	looks_with_mouse = mouse
	trigger_keys = new_trigger_keys


## Let go of everything held. Called when the table changes and on leaving.
func release_all() -> void:
	for key: Key in _holders.keys():
		_send_key(key, false)
	_holders.clear()
	if _holding_click:
		_set_click(false)
	_right_stick = Vector2.ZERO


## Add the table to `legend`, a few bindings a line, when a controller is
## connected: somebody on the keyboard has no use for it, and the legend's
## first job is the AI's colours.
func add_to(legend: Legend) -> void:
	if Input.get_connected_joypads().is_empty():
		return
	var parts: PackedStringArray = describe().trim_prefix("pad: ").split(", ")
	for first: int in range(0, parts.size(), BINDINGS_A_LINE):
		var line: String = ", ".join(parts.slice(first, first + BINDINGS_A_LINE))
		legend.entries.append([Color.TRANSPARENT, ("pad: " if first == 0 else "  ") + line])
	legend.queue_redraw()


## The table in words: "pad: A Space, B C".
func describe() -> String:
	var parts: Array[String] = []
	if not stick_keys.is_empty():
		parts.append("stick " + "/".join(stick_keys.map(OS.get_keycode_string)))
	for button: JoyButton in buttons:
		parts.append("%s %s" % [BUTTON_NAMES.get(button, str(button)), OS.get_keycode_string(buttons[button])])
	if trigger_keys.size() == 2:
		parts.append("LT %s, RT %s" % [OS.get_keycode_string(trigger_keys[0]), OS.get_keycode_string(trigger_keys[1])])
	if looks_with_mouse:
		parts.append("right stick looks, RT clicks")
	return "pad: " + ", ".join(parts)


func _init() -> void:
	# The pause key has to reach an example that is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	release_all()


func _input(event: InputEvent) -> void:
	var button := event as InputEventJoypadButton
	if button != null and buttons.has(button.button_index):
		_hold("button %d" % button.button_index, buttons[button.button_index], button.pressed)
		return
	var motion := event as InputEventJoypadMotion
	if motion != null:
		_move_axis(motion.axis, motion.axis_value)


func _process(delta: float) -> void:
	if not looks_with_mouse or _right_stick.length() < LOOK_DEADZONE:
		return
	var look := InputEventMouseMotion.new()
	look.relative = _right_stick * LOOK_SPEED * delta
	Input.parse_input_event(look)


# One axis moved: the left stick's directions, the right stick's look, or
# the right trigger's click.
func _move_axis(axis: JoyAxis, value: float) -> void:
	var stick_used: bool = stick_keys.size() == 4
	var triggers_used: bool = trigger_keys.size() == 2
	match axis:
		# A stick's y grows downwards, so up is its negative side.
		JOY_AXIS_LEFT_X when stick_used:
			_hold_while("stick left", stick_keys[0], -value)
			_hold_while("stick right", stick_keys[1], value)
		JOY_AXIS_LEFT_Y when stick_used:
			_hold_while("stick up", stick_keys[2], -value)
			_hold_while("stick down", stick_keys[3], value)
		JOY_AXIS_RIGHT_X:
			_right_stick.x = value
		JOY_AXIS_RIGHT_Y:
			_right_stick.y = value
		JOY_AXIS_TRIGGER_RIGHT when looks_with_mouse:
			_click_while(value)
		JOY_AXIS_TRIGGER_LEFT when triggers_used:
			_hold_while("LT", trigger_keys[0], value)
		JOY_AXIS_TRIGGER_RIGHT when triggers_used:
			_hold_while("RT", trigger_keys[1], value)


# `source` presses `key` once `amount` passes PRESS_AT and lets go once it
# falls under RELEASE_AT; between the two, it holds as it was.
func _hold_while(source: String, key: Key, amount: float) -> void:
	var held: bool = source in _holders.get(key, [])
	if not held and amount >= PRESS_AT:
		_hold(source, key, true)
	elif held and amount <= RELEASE_AT:
		_hold(source, key, false)


# The left mouse button, held as `_hold_while` holds a key.
func _click_while(amount: float) -> void:
	if not _holding_click and amount >= PRESS_AT:
		_set_click(true)
	elif _holding_click and amount <= RELEASE_AT:
		_set_click(false)


# `source` takes hold of `key` or lets go of it. The key goes down with its
# first holder and up with its last; in between, nothing is sent.
func _hold(source: String, key: Key, pressed: bool) -> void:
	var holders: Array = _holders.get(key, [])
	if pressed == (source in holders):
		return
	if pressed:
		holders.append(source)
	else:
		holders.erase(source)
	if holders.is_empty():
		_holders.erase(key)
		_send_key(key, false)
	elif holders.size() == 1 and pressed:
		_holders[key] = holders
		_send_key(key, true)


func _send_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	# A keyboard's arrow carries the Shift held with it, and an example may
	# read it there (the stealth game's sprint) rather than ask `Input`.
	# This node's own Shift counts at once: pressed in the same frame, its
	# event is still queued, and `Input` does not know it yet.
	event.shift_pressed = _holders.has(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_SHIFT)
	event.ctrl_pressed = _holders.has(KEY_CTRL) or Input.is_physical_key_pressed(KEY_CTRL)
	Input.parse_input_event(event)


func _set_click(pressed: bool) -> void:
	_holding_click = pressed
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
