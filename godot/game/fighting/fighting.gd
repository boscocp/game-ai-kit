## The fighting scenario in training mode: you against a dummy, with every
## box and every frame on show.
##
## You are player one: A and D walk, W jumps -- with A or D, that way -- S
## crouches, U and I punch light and heavy, J and K kick light and heavy --
## in the air, each is a jump-in attack, one a jump -- S with I is the
## anti-air uppercut, L throws; jump forwards from close and you cross over
## to the dummy's other side; holding away from the dummy guards, standing or -- with S --
## crouching. C swaps which character you play. The dummy, player two, does
## what its mode says -- stand, guard standing, guard crouching, jab, throw or
## low kick every second, uppercut you out of the air, or fight back as the
## fixed opponent at one of its three levels -- and M cycles the mode: each
## guard has a height that gets through it. P pauses, and space then plays
## one frame: the step every example offers (T21), here one frame of the
## resolution order, which is what a person learning frame data needs to see.
##
## The opponent (T37) sees the fight a quarter of a second late or more, and
## the panel says what it saw, on which frame, and what it drew. T17 puts an
## opponent model in the same place, and reads the same input log this scene
## keeps.
##
## When not to use it: as a game. It is a frame-data bench.
class_name FightingExample
extends Node2D

const MODES: Array[String] = ["stand", "guard standing", "guard crouching", "jab", "throw", "low kick",
		"anti-air (sees you now)", "opponent: easy", "opponent: medium", "opponent: hard"]
const OPPONENT_MODE: String = "opponent: "
## Punches on the top row and kicks below them, as an arcade panel has them.
const KEYS: Dictionary = {KEY_A: FightInput.LEFT, KEY_D: FightInput.RIGHT, KEY_S: FightInput.DOWN, KEY_W: FightInput.UP,
		KEY_U: FightInput.LIGHT_PUNCH, KEY_I: FightInput.HEAVY_PUNCH, KEY_J: FightInput.LIGHT_KICK,
		KEY_K: FightInput.HEAVY_KICK, KEY_L: FightInput.THROW}
## How often the dummy presses in its "jab", "throw" and "low kick" modes,
## in frames.
const JAB_EVERY: int = 60
## How near you must be, in the air, for the anti-air dummy to answer, in
## stage units: about where its uppercut comes out in time to meet you.
const ANTI_AIR_RANGE: int = 110

var data: FightData = FightData.read()
var state: FightState
## What the dummy does: an entry of `MODES`. It starts as the medium
## opponent, so a fight opens with something deciding. Setting it seats the
## opponent its mode names, or none.
var dummy_mode: String = "opponent: medium":
	set(mode):
		dummy_mode = mode
		_seat_opponent()
var paused: bool = false
## Every frame's inputs since the fight began, as `FightReplay` reads them.
var input_log: Array = []
## The opponent in the dummy's place, seated behind its reaction time, or
## null while the dummy is scripted.
var seat: FightDelay
var opponent: FightOpponent
## Fights begun since the scene opened: the seed of each new opponent's
## chances, so a restart does not open the same way every time, while the
## input log still replays the fight exactly.
var fights_begun: int = 0
var _characters: Array[String] = ["lancer", "dancer"]

@onready var _view: FightView = $FightView
@onready var _status: Label = $Interface/Status
@onready var _panel: Label = $Interface/Decision
@onready var _legend: Legend = $Interface/Legend


func _ready() -> void:
	_legend.set_entries([
		[FightView.SIDES[0], "left health bar: you (player one)"],
		[FightView.SIDES[1], "right health bar: the dummy (player two)"],
		[FightView.HURTBOX, "outline: hurtbox, where it can be hit"],
		[FightView.HITBOX, "red box: hitbox, where it reaches"],
		[FightView.THROW, "orange box: a throw, which no guard stops"],
		[FightView.STUNNED_SPRITE, "paler: stunned, taking off or landing"],
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
	_seat_opponent()
	_refresh()


# A fresh opponent for an "opponent" mode, none for the others, its chances
# seeded by how many fights have begun.
func _seat_opponent() -> void:
	opponent = null
	seat = null
	if dummy_mode.begins_with(OPPONENT_MODE):
		fights_begun += 1
		opponent = FightOpponent.new(dummy_mode.trim_prefix(OPPONENT_MODE), data, fights_begun)
		seat = FightDelay.new(opponent, 1)


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
	return {"frame": state.frame, "fighters": fighters, "events": happened, "dummy": dummy_mode,
			"opponent": opponent_overlay()}


## What the opponent saw and drew: the situation, the frame it saw it on --
## never this one -- and its choice. -1 and words saying so while the dummy
## is scripted or the opponent has not seen the fight yet.
func opponent_overlay() -> Dictionary:
	if opponent == null:
		return {"level": "none, the dummy is scripted", "situation": "none", "seen_frame": -1, "choice": "none"}
	return {"level": opponent.level, "reaction": seat.reaction, "situation": opponent.situation,
			"seen_frame": opponent.seen_frame, "choice": opponent.choice}


func _fighter_overlay(fighter: FighterState) -> Dictionary:
	var hitbox: Array[int] = FightBoxes.hitbox(fighter, data)
	return {"character": fighter.character, "move": fighter.move if fighter.move != "" else "free",
			"move_frame": fighter.move_frame, "phase": FightBoxes.phase(fighter, data) if fighter.move != "" else "free",
			"hitbox": str(hitbox) if not hitbox.is_empty() else "none", "hurtbox": str(FightBoxes.hurtbox(fighter, data)),
			"height": data.move(fighter.character, fighter.move)["height"] if fighter.move != "" else "none",
			"crouching": fighter.crouching,
			"stun": fighter.stun, "buffered": fighter.buffered if fighter.buffered != "" else "nothing",
			"health": fighter.health}


func _held_keys() -> int:
	var held: int = 0
	for keycode: Key in KEYS:
		if Input.is_physical_key_pressed(keycode):
			held |= KEYS[keycode]
	return held


# The dummy holds away to guard -- holding down as well to guard crouching --
# or presses light punch, throw or a low kick once every `JAB_EVERY` frames,
# or stands; or the opponent decides, from the fight as it was. The anti-air
# dummy is the one mode that reads the present: it uppercuts as soon as you
# are in the air and near -- a drill for being knocked out of the
# air, not an opponent, and its name says so.
func _dummy_input() -> int:
	if seat != null:
		return seat.input_for(state)
	var dummy: FighterState = state.fighters[1]
	var away: int = FightInput.RIGHT if state.fighters[0].x < dummy.x else FightInput.LEFT
	var on_the_beat: bool = state.frame % JAB_EVERY == 0
	match dummy_mode:
		"guard standing":
			return away
		"guard crouching":
			return away | FightInput.DOWN
		"jab":
			return FightInput.LIGHT_PUNCH if on_the_beat else 0
		"throw":
			return FightInput.THROW if on_the_beat else 0
		"low kick":
			return FightInput.DOWN | FightInput.LIGHT_KICK if on_the_beat else 0
		"anti-air (sees you now)":
			var you: FighterState = state.fighters[0]
			var near: bool = absi(you.x - dummy.x) <= ANTI_AIR_RANGE
			return FightInput.DOWN | FightInput.HEAVY_PUNCH if you.is_airborne() and near else 0
	return 0


func _refresh() -> void:
	if not is_node_ready():
		return
	if data.refusal != "":
		_status.text = "the frame data was refused: " + data.refusal
		return
	_view.show_fight(state, data)
	_status.text = ("A/D walk, W jump, S crouch, U/I punch, J/K kick, S+I uppercut, L throw, hold away to guard\n"
			+ "C swap characters  ·  M dummy: %s  ·  P pause, space one frame  ·  R restart" % dummy_mode)
	_panel.text = FightingPanel.describe(state, data, paused, seat)
