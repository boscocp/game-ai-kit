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
## The Xbox names for the buttons a table may use, as printed on the pad, and
## shown as printed in every language.
const BUTTON_NAMES: Dictionary = {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu",
	JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
}
## The D-pad's four directions, which no pad prints: words, so translated.
const DPAD_NAMES: Dictionary = {  # shown through tr()
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
}
## The D-pad's buttons, and the arrow keys, left, right, up and down: the
## order of `stick_keys`, so four of them read as one binding.
const DPAD: Array[JoyButton] = [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP,
		JOY_BUTTON_DPAD_DOWN]
const ARROWS: Array[Key] = [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]
## Keys whose name `OS.get_keycode_string` writes as an English word, or as
## a word the key does not print: a space bar prints none, an arrow key an
## arrow the legend's font cannot draw. The kit's tables say "espaço" and
## "setas" (the glossary: a key's name is what the key shows).
const KEY_WORDS: Dictionary = {  # shown through tr()
	KEY_SPACE: "Space", KEY_PERIOD: ".",
	KEY_LEFT: "Left", KEY_RIGHT: "Right", KEY_UP: "Up", KEY_DOWN: "Down",
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
## Whether `add_to` writes the table with no controller connected. A check
## run headless cannot connect one, and must still read the line an example
## shows somebody holding one (T103). Nothing in a game sets it.
static var planted: bool = false

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


## Add the table to `legend` when a controller is connected: somebody on the
## keyboard has no use for it, and the legend's first job is the AI's
## colours. Each example calls it again whenever it rebuilds its legend, a
## change of language included.
func add_to(legend: Legend) -> void:
	if Input.get_connected_joypads().is_empty() and not planted:
		return
	for line: String in legend_lines(legend):
		legend.entries.append([Color.TRANSPARENT, line])
	legend.queue_redraw()


## The lines `add_to` writes into `legend`, in the language chosen now:
## "pad: " before the first, and as many bindings a line as fit the legend's
## width. A count of bindings a line did not: three ran off the window in
## English, in the racers and the stealth hall, and Portuguese is longer.
func legend_lines(legend: Legend) -> Array[String]:
	var room: float = legend.words_width()
	var lines: Array[String] = []
	var line: String = tr("pad: {bindings}").format({bindings = ""})
	var bindings_on_line: int = 0
	for binding: String in _bindings():
		var longer: String = line + (", " if bindings_on_line > 0 else "") + binding
		if bindings_on_line > 0 and Legend.width_of(longer) > room:
			lines.append(line)
			longer = "  " + binding
			bindings_on_line = 0
		line = longer
		bindings_on_line += 1
	if bindings_on_line > 0:
		lines.append(line)
	return lines


## The table in words, on one line: "pad: A Space, B C".
func describe() -> String:
	return tr("pad: {bindings}").format({bindings = ", ".join(_bindings())})


# Each binding in words: "stick A/D/W/S", "D-pad arrows", "A Space". The
# words are translated; key names and the names printed on the pad stay as
# written. The stick is the left one where the right one looks too.
func _bindings() -> Array[String]:
	var parts: Array[String] = []
	if not stick_keys.is_empty() and looks_with_mouse:
		parts.append(tr("left stick {keys}").format({keys = _keys_named(stick_keys)}))
	elif not stick_keys.is_empty():
		parts.append(tr("stick {keys}").format({keys = _keys_named(stick_keys)}))
	var dpad_keys: Array[Key] = _dpad_keys()
	if not dpad_keys.is_empty():
		parts.append(tr("D-pad {keys}").format({keys = _keys_named(dpad_keys)}))
	for button: JoyButton in buttons:
		if dpad_keys.is_empty() or not button in DPAD:
			parts.append("%s %s" % [_name_of(button), _key_named(buttons[button])])
	# "LT" as a value, not "LT %s": a literal with a word and a space would
	# read to check_translations_game.py as prose, and a pad's name is not.
	if trigger_keys.size() == 2:
		parts.append("%s %s" % ["LT", _key_named(trigger_keys[0])])
		parts.append("%s %s" % ["RT", _key_named(trigger_keys[1])])
	if looks_with_mouse:
		parts.append(tr("right stick looks"))
		parts.append(tr("RT clicks"))
	return parts


# A button as the legend names it: a D-pad direction in the language chosen,
# any other as printed on the pad.
func _name_of(button: JoyButton) -> String:
	if DPAD_NAMES.has(button):
		return tr(DPAD_NAMES[button])
	return BUTTON_NAMES.get(button, str(button))


# The keys the D-pad's four directions press, in the order of DPAD, when
# the table binds all four: they read as one binding. Empty otherwise.
func _dpad_keys() -> Array[Key]:
	var keys: Array[Key] = []
	for button: JoyButton in DPAD:
		if not buttons.has(button):
			return []
		keys.append(buttons[button])
	return keys


# Four direction keys as one name: "arrows", or "A/D/W/S".
func _keys_named(keys: Array[Key]) -> String:
	if keys == ARROWS:
		return tr("arrows")
	return "/".join(keys.map(_key_named))


# A key's name as the key shows it, in the language chosen.
func _key_named(key: Key) -> String:
	if KEY_WORDS.has(key):
		return tr(KEY_WORDS[key])
	return OS.get_keycode_string(key)


func _init() -> void:
	# The pause key has to reach an example that is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	release_all()


func _input(event: InputEvent) -> void:
	var button := event as InputEventJoypadButton
	if button != null and buttons.has(button.button_index):
		_hold("button %d" % button.button_index, buttons[button.button_index], button.pressed)  # not shown
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
			_hold_while("stick left", stick_keys[0], -value)  # not shown
			_hold_while("stick right", stick_keys[1], value)  # not shown
		JOY_AXIS_LEFT_Y when stick_used:
			_hold_while("stick up", stick_keys[2], -value)  # not shown
			_hold_while("stick down", stick_keys[3], value)  # not shown
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
