## The fighting scenario in training mode: you against a dummy, with every
## box and every frame on show.
##
## You are player one: A and D walk, J is light, K heavy, L special, and
## holding away from the dummy blocks. C swaps which character you play. The
## dummy, player two, does what its mode says -- stand, block, or jab every
## second -- and M cycles the mode. P pauses, and space then plays one frame:
## the step every example offers (T21), here one frame of the resolution
## order, which is what a person learning frame data needs to see.
##
## There is no AI here yet (T16). T17 puts an opponent model in the dummy's
## place, and reads the same input log this scene keeps.
##
## When not to use it: as a game. It is a frame-data bench.
class_name FightingExample
extends Node2D

const MODES: Array[String] = ["stand", "block", "jab"]
const KEYS: Dictionary = {KEY_A: FightInput.LEFT, KEY_D: FightInput.RIGHT, KEY_J: FightInput.LIGHT,
		KEY_K: FightInput.HEAVY, KEY_L: FightInput.SPECIAL}
## How often the dummy jabs in its "jab" mode, in frames.
const JAB_EVERY: int = 60

var data: FightData = FightData.read()
var state: FightState
## What the dummy does: an entry of `MODES`. It starts jabbing, so a fight
## opens with something to look at.
var dummy_mode: String = "jab"
var paused: bool = false
## Every frame's inputs since the fight began, as `FightReplay` reads them.
var input_log: Array = []
var _characters: Array[String] = ["lancer", "dancer"]

@onready var _view: FightView = $FightView
@onready var _status: Label = $Interface/Status
@onready var _panel: Label = $Interface/Decision
@onready var _legend: Legend = $Interface/Legend


func _ready() -> void:
	_legend.set_entries([
		[FightView.SIDES[0], "you (player one)"],
		[FightView.SIDES[1], "the dummy (player two)"],
		[FightView.HURTBOX, "outline: hurtbox, where it can be hit"],
		[FightView.HITBOX, "red bar: hitbox, out on active frames"],
		[FightView.STUNNED, "pale: in hitstun or blockstun"],
	] as Array[Array])
	restart()


func _physics_process(_delta: float) -> void:
	if not paused:
		step_decision()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_P:
			paused = not paused
		KEY_SPACE:
			paused = true
			step_decision()
		KEY_M:
			dummy_mode = MODES[(MODES.find(dummy_mode) + 1) % MODES.size()]
		KEY_C:
			_characters.reverse()
			restart()
		KEY_R:
			restart()
	_refresh()


## The opening frame, the log emptied.
func restart() -> void:
	if data.refusal != "":
		_refresh()
		return
	state = FightState.starting(data, _characters[0], _characters[1])
	input_log.clear()
	_refresh()


## One frame: read both inputs, resolve, and keep them in the log.
func step_decision() -> void:
	if data.refusal != "":
		return
	var inputs: Array[int] = [_held_keys(), _dummy_input()]
	input_log.append([inputs[0], inputs[1]])
	state = FightRules.step(state, inputs, data)
	_refresh()


## What the frame is resolving with: each fighter's move, the frame of it and
## its phase, its boxes, its stun and its buffer, and what happened. Nothing
## is left blank: "free", "none" and "nothing connected" say so in words, as
## the panel does.
func decision_overlay() -> Dictionary:
	var fighters: Array[Dictionary] = []
	for fighter: FighterState in state.fighters:
		fighters.append(_fighter_overlay(fighter))
	var happened: String = ", ".join(state.events) if not state.events.is_empty() else "nothing connected"
	return {"frame": state.frame, "fighters": fighters, "events": happened, "dummy": dummy_mode}


func _fighter_overlay(fighter: FighterState) -> Dictionary:
	var hitbox: Array[int] = FightBoxes.hitbox(fighter, data)
	return {"character": fighter.character, "move": fighter.move if fighter.move != "" else "free",
			"move_frame": fighter.move_frame, "phase": FightBoxes.phase(fighter, data) if fighter.move != "" else "free",
			"hitbox": str(hitbox) if not hitbox.is_empty() else "none", "hurtbox": str(FightBoxes.hurtbox(fighter, data)),
			"stun": fighter.stun, "buffered": fighter.buffered if fighter.buffered != "" else "nothing",
			"health": fighter.health}


func _held_keys() -> int:
	var held: int = 0
	for keycode: Key in KEYS:
		if Input.is_physical_key_pressed(keycode):
			held |= KEYS[keycode]
	return held


# The dummy holds away to block, or presses light once every `JAB_EVERY`
# frames, or stands.
func _dummy_input() -> int:
	var dummy: FighterState = state.fighters[1]
	match dummy_mode:
		"block":
			return FightInput.RIGHT if state.fighters[0].x < dummy.x else FightInput.LEFT
		"jab":
			return FightInput.LIGHT if state.frame % JAB_EVERY == 0 else 0
	return 0


func _refresh() -> void:
	if not is_node_ready():
		return
	if data.refusal != "":
		_status.text = "the frame data was refused: " + data.refusal
		return
	_view.show_fight(state, data)
	_status.text = ("A/D walk, J light, K heavy, L special, hold away to block  ·  C swap characters  ·  "
			+ "M dummy: %s  ·  P pause, space one frame  ·  R restart" % dummy_mode)
	_panel.text = FightingPanel.describe(state, data, paused)
