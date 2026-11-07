## The fighting scenario in training mode: you against a dummy, with every
## box and every frame on show.
##
## You are player one: A and D walk, W jumps -- with A or D, that way -- S
## crouches, U and I punch light and heavy, J and K kick light and heavy --
## in the air, each is a jump-in attack, one a jump -- S with I is the
## anti-air uppercut, L throws, O -- or back tapped twice -- evades: a
## backdash, which strikes and throws pass through at first and which cannot
## guard at the end (T40);
## jump forwards from close and you cross over
## to the dummy's other side; holding back from a strike guards, standing or
## -- with S -- crouching. C swaps which character you play. The dummy, player two, does
## what its mode says -- stand, guard standing, guard crouching, jab, throw or
## low kick every second, uppercut you out of the air, or fight back as the
## fixed opponent at one of its three levels, or as the learner, the same
## levels with a table of your habits behind them, or as the bandit, the same
## levels learning which of their answers work against you (T99) -- and M cycles the mode: each
## guard has a height that gets through it. Three more modes imitate a
## recorded player (T18): two ghosts, which look up what the player did in
## the situation, and the clone, a model fitted to it. The last three are
## the learner's levels with a decision tree reading you instead of the
## n-gram (T113), its path on the panel. P pauses, and space then plays
## one frame: the step every example offers (T21), here one frame of the
## resolution order, which is what a person learning frame data needs to see.
##
## The opponent (T37) sees the fight a quarter of a second late or more, and
## the panel says what it saw, on which frame, and what it drew. T17 puts an
## opponent model in the same place, and reads the same input log this scene
## keeps.
##
## Opened with `-- --record` (`make record-fights`), it keeps every fight
## you play, as its input log, in `data/fights/`: what T18 learns from.
## Nothing is kept otherwise.
##
## When not to use it: as a game. It is a frame-data bench.
class_name FightingExample
extends Node2D

const MODES: Array[String] = ["stand", "guard standing", "guard crouching", "jab", "throw", "low kick",  # shown through tr(): FightWords.word says each mode
		"anti-air (sees you now)", "opponent: easy", "opponent: medium", "opponent: hard", "learner: easy",  # shown through tr(): FightWords.word says each mode
		"learner: medium", "learner: hard", "bandit: easy", "bandit: medium", "bandit: hard",  # shown through tr(): FightWords.word says each mode
		"ghost: exact", "ghost: nearest", "clone", "tree: easy", "tree: medium", "tree: hard"]  # shown through tr(): FightWords.word says each mode
const OPPONENT_MODE: String = "opponent: "
## The same levels with an n-gram behind them, learning you as you fight (T17).
const LEARNER_MODE: String = "learner: "
## The same levels with a bandit in each situation, learning which of their
## answers pay against you (T99).
const BANDIT_MODE: String = "bandit: "
## The learner's levels with a decision tree, fitted on your recordings,
## reading what you will do next (T113).
const TREE_MODE: String = "tree: "
## Punches on the top row and kicks below them, as an arcade panel has them.
const KEYS: Dictionary = {KEY_A: FightInput.LEFT, KEY_D: FightInput.RIGHT, KEY_S: FightInput.DOWN, KEY_W: FightInput.UP,
		KEY_U: FightInput.LIGHT_PUNCH, KEY_I: FightInput.HEAVY_PUNCH, KEY_J: FightInput.LIGHT_KICK,
		KEY_K: FightInput.HEAVY_KICK, KEY_L: FightInput.THROW, KEY_O: FightInput.EVADE}
## How often the dummy presses in its "jab", "throw" and "low kick" modes,
## in frames.
const JAB_EVERY: int = 60
## How near you must be, in the air, for the anti-air dummy to answer, in
## stage units: about where its uppercut comes out in time to meet you.
const ANTI_AIR_RANGE: int = 110

## The controller, as the keys (wave 84): the stick or the D-pad walks,
## jumps and crouches -- both at once, as the owner asked (wave 85): a key
## either one holds stays down until both let go; X and Y punch, A and B
## kick, light then heavy; RB throws, LB evades, Menu pauses.
const PAD_BUTTONS: Dictionary = {JOY_BUTTON_X: KEY_U, JOY_BUTTON_Y: KEY_I, JOY_BUTTON_A: KEY_J,
		JOY_BUTTON_B: KEY_K, JOY_BUTTON_RIGHT_SHOULDER: KEY_L, JOY_BUTTON_LEFT_SHOULDER: KEY_O,
		JOY_BUTTON_START: KEY_P, JOY_BUTTON_DPAD_LEFT: KEY_A, JOY_BUTTON_DPAD_RIGHT: KEY_D,
		JOY_BUTTON_DPAD_UP: KEY_W, JOY_BUTTON_DPAD_DOWN: KEY_S}

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
## The recorded player the ghosts and the clone imitate, loaded once.
var cloned: ClonedPlayer = ClonedPlayer.load_from(FightCloneOpponent.PUBLISHED_PATH)
## The decision tree the "tree:" modes read you with, loaded once.
var opponent_tree: ModelFile = ModelFile.load_from(FightTreeOpponent.PUBLISHED_PATH)
## True when the scene was opened to record, and how many fights it has kept.
var recording: bool = OS.get_cmdline_user_args().has("--record")
var fights_kept: int = 0
var _kept: bool = false
var _characters: Array[String] = ["lancer", "dancer"]
# Back tapped twice becomes the evade bit before the frame is logged (wave 86).
var _double_tap: FightDoubleTap = FightDoubleTap.new()
var _pad := PadAsKeys.new()

@onready var _view: FightView = $FightView
@onready var _status: Label = $Interface/Status
@onready var _panel: Label = $Interface/Decision
@onready var _legend: Legend = $Interface/Legend


func _ready() -> void:
	_pad.use(PAD_BUTTONS, [KEY_A, KEY_D, KEY_W, KEY_S])
	add_child(_pad)
	_show_legend()
	restart()
	Language.apply_if_opened_alone(self)


# The legend, then the pad's buttons under it when a pad is connected.
func _show_legend() -> void:
	_legend.set_entries([
		[FightView.SIDES[0], tr("left health bar: you (player one)")],
		[FightView.SIDES[1], tr("right health bar: the dummy (player two)")],
		[FightView.HURTBOX, tr("outline: hurtbox, where it can be hit")],
		[FightView.INVULNERABLE, tr("grey outline: evading, nothing can hit it")],
		[FightView.HITBOX, tr("red box: hitbox, where it reaches")],
		[FightView.THROW, tr("orange box: a throw, which no guard stops")],
		[FightView.STUNNED_SPRITE, tr("paler: stunned, taking off, landing or evading")],
	] as Array[Array])
	_pad.add_to(_legend)


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
			_next_mode()
		KEY_C:
			_characters.reverse()
			restart()
		KEY_R:
			restart()
	_refresh()


# The next dummy mode. When recording, the fight so far is kept under the
# mode it was fought against and a new one begins, so a recording never
# names an opponent it did not face.
func _next_mode() -> void:
	keep_fight()
	dummy_mode = MODES[(MODES.find(dummy_mode) + 1) % MODES.size()]
	if recording:
		restart()


## The opening frame, the log emptied -- and kept first, when recording.
func restart() -> void:
	if data.refusal != "":
		_refresh()
		return
	keep_fight()
	_kept = false
	state = FightState.starting(data, _characters[0], _characters[1])
	input_log.clear()
	_double_tap = FightDoubleTap.new()
	_seat_opponent()
	_refresh()


# A fresh opponent for an "opponent", "learner", "bandit" or "tree" mode -- a learner
# with an empty table, a bandit with no bandits -- none for the others, its chances seeded by how many fights
# have begun.
func _seat_opponent() -> void:
	opponent = null
	seat = null
	if dummy_mode.begins_with(OPPONENT_MODE):
		fights_begun += 1
		opponent = FightOpponent.new(dummy_mode.trim_prefix(OPPONENT_MODE), data, fights_begun)
	elif dummy_mode.begins_with(LEARNER_MODE):
		fights_begun += 1
		opponent = FightModelOpponent.new(dummy_mode.trim_prefix(LEARNER_MODE), data, fights_begun)
	elif dummy_mode.begins_with(BANDIT_MODE):
		fights_begun += 1
		opponent = FightBanditOpponent.new(dummy_mode.trim_prefix(BANDIT_MODE), data, fights_begun)
	elif dummy_mode.begins_with(TREE_MODE):
		fights_begun += 1
		opponent = FightTreeOpponent.new(dummy_mode.trim_prefix(TREE_MODE), opponent_tree, data, fights_begun)
	elif dummy_mode in FightCloneOpponent.SOURCES:
		fights_begun += 1
		opponent = FightCloneOpponent.new(dummy_mode, cloned, data, fights_begun)
	if opponent != null:
		seat = FightDelay.new(opponent, 1)


## One frame: read both inputs, resolve, and keep them in the log.
func step_decision() -> void:
	step_decision_with(_held_keys())


## One frame with `held` as your keys: what `step_decision` does once it has
## read them, and what a test drives. Back tapped twice is turned into the
## evade here, so the log keeps the bit and replays without knowing why.
func step_decision_with(held: int) -> void:
	if data.refusal != "":
		return
	var inputs: Array[int] = [_double_tap.read(held, state.fighters[0].facing), _dummy_input()]
	input_log.append([inputs[0], inputs[1]])
	state = FightRules.step(state, inputs, data)
	if state.winner != FightState.NOBODY:
		keep_fight()
	_refresh()


## When recording, write this fight's log to `data/fights/`, once: at the
## knockout, or at a restart, a change of mode or a close before one. Only a
## fight against an opponent that decides is kept: what a person does
## against a dummy that stands or jabs on a beat is not how they fight.
func keep_fight() -> void:
	if not recording or _kept or input_log.is_empty() or seat == null:
		return
	_kept = true
	var path: String = FightRecording.save(input_log.duplicate(), _characters, dummy_mode, FightRecording.PERSON,
			FightRecording.directory())
	if path != "":
		fights_kept += 1


# Kept when the window closes; and rebuilt in the language just chosen
# (T80): the status and the panel are set from code, and the legend is drawn.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		keep_fight()
	elif what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_show_legend()
		_refresh()


## What the frame is resolving with: each fighter's move, the frame of it and
## its phase, its boxes, its stun and its buffer, and what happened. Nothing
## is left blank: "free", "none" and "nothing connected" say so in words, as
## the panel does.
func decision_overlay() -> Dictionary:
	var fighters: Array[Dictionary] = []
	for fighter: FighterState in state.fighters:
		fighters.append(_fighter_overlay(fighter))
	var happened: String = ", ".join(state.events) if not state.events.is_empty() else "nothing connected"  # not shown: the gate's overlay
	return {"frame": state.frame, "fighters": fighters, "events": happened, "dummy": dummy_mode,
			"opponent": opponent_overlay()}


## What the opponent saw and drew: the situation, the frame it saw it on --
## never this one -- and its choice. -1 and words saying so while the dummy
## is scripted or the opponent has not seen the fight yet.
func opponent_overlay() -> Dictionary:
	if opponent == null:
		return {"level": "none, the dummy is scripted", "situation": "none", "seen_frame": -1, "choice": "none"}  # not shown
	var shown: Dictionary = {"level": opponent.level, "reaction": seat.reaction, "situation": opponent.situation,
			"seen_frame": opponent.seen_frame, "choice": opponent.choice}
	var learner := opponent as FightModelOpponent
	if learner != null:
		shown.merge(_model_overlay(learner))
	var imitator := opponent as FightCloneOpponent
	if imitator != null:
		shown.merge(_clone_overlay(imitator))
	var gambler := opponent as FightBanditOpponent
	if gambler != null:
		shown.merge(_bandit_overlay(gambler))
	var reader := opponent as FightTreeOpponent
	if reader != null:
		shown.merge(_tree_overlay(reader), true)
	return shown


# Your situation as the tree read it, the path it took -- each test, the
# word it read, which way it went -- the leaf's counts, and the n-gram's
# guess beside its own. Merged over the learner's, whose `expects` it is.
func _tree_overlay(reader: FightTreeOpponent) -> Dictionary:
	if reader.reader == null:
		return {"tree_path": "no tree: " + reader.refusal, "leaf": "none"}  # not shown
	if reader.walked.is_empty():
		return {"tree_path": "nothing read yet", "leaf": "none", "ngram_expects": reader.ngram_expected}  # not shown
	var last: Dictionary = reader.walked.back()
	return {"tree_path": reader.walked, "leaf": last.get("counts", "unread"),  # not shown
			"situation_words": reader.person_situation, "ngram_expects": reader.ngram_expected,
			"tree_score": reader.tree_score(), "ngram_score": reader.ngram_score()}


# The bandit of the situation it last named, as it stood when it chose:
# each option's pulls, mean payoff and UCB1 bound, the one it chose, and the
# last option paid.
func _bandit_overlay(gambler: FightBanditOpponent) -> Dictionary:
	if gambler.chosen_from.is_empty():
		return {"arms": "nothing chosen yet", "chosen_arm": -1, "last_paid": "nothing paid yet"}  # not shown
	return {"arms": gambler.chosen_from, "chosen_arm": gambler.chosen_arm,
			"last_paid": gambler.last_paid if not gambler.last_paid.is_empty() else "nothing paid yet"}  # not shown


# Whom it imitates, the situation it saw in the recordings' words, where its
# answers came from and what it drew among.
func _clone_overlay(imitator: FightCloneOpponent) -> Dictionary:
	var seen: Dictionary = imitator.seen_situation
	return {"imitates": cloned.trained_on.get("player", "nobody: " + cloned.error),  # not shown
			"situation_words": cloned.cases.key_of(seen) if cloned.is_loaded() and not seen.is_empty() else "nothing seen yet",  # not shown
			"found": imitator.found, "considered": str(imitator.considered) if not imitator.considered.is_empty() else "nothing yet"}  # not shown


# What the learner expects, from which context, and its table.
func _model_overlay(learner: FightModelOpponent) -> Dictionary:
	var table: PackedStringArray = learner.model.rows()
	var context: String = learner.expected_after
	return {"expects": learner.expected, "confidence": learner.confidence, "answered": learner.answered,
			"expected_after": context if context != "" else "nothing seen yet",  # not shown
			"table": table if not table.is_empty() else PackedStringArray(["nothing counted yet"])}  # not shown


func _fighter_overlay(fighter: FighterState) -> Dictionary:
	var hitbox: Array[int] = FightBoxes.hitbox(fighter, data)
	return {"character": fighter.character, "move": fighter.move if fighter.move != "" else "free",
			"move_frame": fighter.move_frame, "phase": FightBoxes.phase(fighter, data) if fighter.move != "" else "free",
			"hitbox": str(hitbox) if not hitbox.is_empty() else "none", "hurtbox": str(FightBoxes.hurtbox(fighter, data)),
			"height": data.move(fighter.character, fighter.move)["height"] if fighter.move != "" else "none",
			"crouching": fighter.crouching, "evading": _evading(fighter),
			"stun": fighter.stun, "buffered": fighter.buffered if fighter.buffered != "" else "nothing",  # not shown: an identifier
			"health": fighter.health}


# The backdash's frame and part, in words, or "not evading".
func _evading(fighter: FighterState) -> String:
	var frame: int = FightBackdash.frame_of(fighter, data)
	if frame == 0:
		return "not evading"  # not shown: the gate's overlay
	return "frame %d, %s" % [frame, "invulnerable" if FightBackdash.invulnerable(fighter, data) else "cannot guard"]  # not shown


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
		_status.text = tr("the frame data was refused: {why}").format({why = data.refusal})
		return
	_view.show_fight(state, data)
	var lines: Array[String] = [
		tr("A/D walk, W jump, S crouch, U/I punch, J/K kick, S+I uppercut, L throw, O or back twice evade, hold away to guard"),
		tr("C swap characters  ·  M dummy: {mode}  ·  P pause, space one frame  ·  R restart").format({
			mode = FightWords.word(dummy_mode)}),
	]
	if recording:
		lines.append(tr("recording: {count} fight(s) kept in data/fights/").format({count = fights_kept}))
	_status.text = "\n".join(lines)
	_panel.text = FightingPanel.describe(state, data, paused, seat)
