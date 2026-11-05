## Talk your way past the guard: a text game whose challenge is a conversation.
##
## Like Suck Up!'s doorstep, at the research station the infiltration level
## sneaks into: Bram, the night guard, must be talked into opening the door.
## A language model reads what you say as one of the acts the scene declares
## and voices Bram's answer; the rules in `gate.json` (`TalkRules`) decide,
## by trust and suspicion, whether the door opens, the alarm sounds, or the
## turns run out. `TalkGuard` is the conversation; this node only reads the
## keys, swaps modes and draws.
##
## Recorded mode (the default) needs nothing installed: the lines on offer
## are those a local model was once asked, and its answers come from
## `data/talk/recordings/` through `RecordedRuntime` (`TalkBook`). Live mode
## (Tab) sends what you type to `make llm-serve` through `HttpRuntime`.
## Opened with `-- --record` (`make record-talk-live`), live mode also writes
## each finished conversation to `data/talk/recordings/` (ADR 0017: only
## when asked, and said on screen). V shows what the model heard and which
## rule decided, turn by turn (invariant 13).
class_name TalkDemo
extends Node2D

const RECORDED: String = "recorded"  # not shown: a mode's identifier
const LIVE: String = "live"  # not shown: a mode's identifier
## Where the picture is drawn: the door, the guard, the two bars.
const PICTURE: Vector2 = Vector2(40, 40)

## RECORDED or LIVE.
var mode: String = RECORDED
## Whether live conversations are written down when they end.
var recording: bool = false
## Whether the reasoning panel is shown.
var view_on: bool = true
## The guard of this conversation.
var guard: TalkGuard
## The recorded lines of this conversation's language.
var book: TalkBook
## What the player has said in this conversation, in order.
var said: PackedStringArray = PackedStringArray()

var _note: String = ""
var _clock: float = 0.0

@onready var _status: Label = $Interface/Status
@onready var _history: Label = $Interface/History
@onready var _choices: Label = $Interface/Choices
@onready var _typed: LineEdit = $Interface/Typed
@onready var _panel: Label = $Interface/Decision
@onready var _legend: Legend = $Interface/Legend


func _ready() -> void:
	recording = "--record" in OS.get_cmdline_user_args()
	mode = LIVE if recording else RECORDED
	_typed.max_length = int(TalkRules.scene()["player_line_limit"])
	_typed.text_submitted.connect(_on_typed)
	_show_legend()
	restart()
	Language.apply_if_opened_alone(self)


# A new language is a new guard: he answers in the language he was told.
# The restart waits for the end of the frame (T132): this notification comes
# through `propagate_notification`, which holds this node busy while it runs,
# and a guard added now would never reach the tree.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_show_legend()
		restart.call_deferred()


## The guard's language: the one the examples speak now.
static func language() -> String:
	return Language.PORTUGUESE if Language.is_portuguese() else Language.ENGLISH


func _show_legend() -> void:
	_legend.set_entries([
		[TalkView.DOOR, tr("the door: it opens when trust reaches its mark")],
		[TalkView.GUARD, tr("Bram, the guard: a language model hears and speaks for him")],
		[TalkView.PLAYER, tr("you, at the door")],
		[TalkView.THINKING, tr("three dots: the model is answering; the game keeps running")],
		[TalkView.TRUST, tr("green bar: trust; at the white mark the door opens")],
		[TalkView.SUSPICION, tr("red bar: suspicion; at the white mark the alarm sounds")],
		[TalkView.ALARM_LAMP, tr("red lamp: the alarm")],
	] as Array[Array])


func _process(delta: float) -> void:
	_clock += delta
	if guard.is_thinking() or guard.state["outcome"] == TalkRules.ALARM:
		queue_redraw()


# Tab is read before the text box, which would otherwise take it.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		switch_mode()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or mode != RECORDED:
		return
	if key.keycode >= KEY_1 and key.keycode <= KEY_9:
		choose(key.keycode - KEY_1)
	elif key.keycode == KEY_V:
		view_on = not view_on
	elif key.keycode == KEY_R:
		restart()
	_refresh()


## Tab: from the recorded lines to typing to the local model, and back. A
## new conversation either way: a recorded guard and a live one have not
## heard the same things.
func switch_mode() -> void:
	mode = LIVE if mode == RECORDED else RECORDED
	restart()


## A new conversation: a guard who has heard nothing, in the language spoken.
func restart() -> void:
	if guard != null:
		guard.queue_free()
	guard = TalkGuard.new(language())
	add_child(guard)
	guard.ruled.connect(_on_ruled)
	said = PackedStringArray()
	_note = ""
	book = TalkBook.load_from(TalkBook.folder(), language())
	if mode == LIVE:
		var server := HttpRuntime.new()
		guard.use_runtime(RecordingRuntime.new(server) if recording else server)
	_typed.visible = mode == LIVE
	_typed.clear()
	if mode == LIVE:
		_typed.grab_focus.call_deferred()
	_refresh()


## Recorded mode: say the `index`th line on offer, answered as recorded.
func choose(index: int) -> void:
	var lines: PackedStringArray = book.choices(said)
	if mode != RECORDED or guard.is_thinking() or guard.has_decided() or index < 0 or index >= lines.size():
		return
	guard.use_runtime(book.runtime_for(said, lines[index]))
	if guard.say(lines[index]) == OK:
		said.append(lines[index])
	_refresh()


## Live mode: say what was typed. The answer comes from the server, later.
func _on_typed(text: String) -> void:
	if mode != LIVE or guard.is_thinking():
		return
	var sent: Error = guard.say(text)
	if sent == OK:
		said.append(text)
		_typed.clear()
	elif sent == ERR_UNAVAILABLE:
		_note = tr("The guard has decided: Tab, then R, for a new conversation.")
	else:
		_note = tr("Say something, in at most {limit} characters.").format({
			"limit": int(TalkRules.scene()["player_line_limit"])})
	_refresh()


func _on_ruled(_turn: Dictionary) -> void:
	if recording and guard.has_decided():
		_save_recording()
	_refresh()


# The finished conversation, written beside the others, and said so.
func _save_recording() -> void:
	DirAccess.make_dir_recursive_absolute(TalkBook.folder())
	var name: String = Time.get_datetime_string_from_system().replace(":", "-")
	var path: String = TalkBook.folder().path_join("%s.%s.json" % [name, language()])
	var saved: Error = guard.save_recording(path, {"conversation": name, "language": language(),
		"recorded_on": Time.get_date_string_from_system()})
	_note = tr("Recorded to {path}").format({"path": path}) if saved == OK \
		else tr("Not recorded: a turn had no answer from the model.")


## One decision, for a test or somebody stepping through: say the first
## recorded line on offer -- or, once the guard has decided, start again.
## While he thinks, nothing: the answer is the runtime's to give, later.
func step_decision() -> void:
	if guard.has_decided():
		restart()
	elif not guard.is_thinking() and mode == RECORDED:
		choose(0)


## What the guard is reasoning with: the two numbers and their marks, the
## turn, whether the model is answering, the lines on offer, and every
## ruled turn's act, rule and moves. Empty fields are left out.
func decision_overlay() -> Dictionary:
	var overlay: Dictionary = {"mode": mode, "language": language(), "turn": guard.state["turn"],
		"turns": TalkRules.scene()["turns"], "trust": guard.state["trust"],
		"suspicion": guard.state["suspicion"], "open_at": TalkRules.scene()["open_at"],
		"alarm_at": TalkRules.scene()["alarm_at"], "outcome": guard.state["outcome"],
		"thinking": guard.is_thinking(), "lines_said": said.size()}
	var lines: PackedStringArray = book.choices(said)
	if not lines.is_empty() and not guard.has_decided():
		overlay["choices"] = lines
	if not guard.turns.is_empty():
		overlay["ruled"] = guard.turns.map(_without_empty)
	return overlay


static func _without_empty(turn: Dictionary) -> Dictionary:
	var kept: Dictionary = {}
	for field: String in turn:
		if not (turn[field] is String and (turn[field] as String).is_empty()):
			kept[field] = turn[field]
	return kept


func _refresh() -> void:
	if not is_node_ready():
		return
	queue_redraw()
	var pending: String = said[said.size() - 1] if guard.is_thinking() else ""
	_history.text = TalkPanel.history(guard.turns, pending)
	_choices.text = _choices_text()
	_panel.text = TalkPanel.describe(guard.turns, guard.state, language()) if view_on \
		else tr("V shows what the model heard and which rule decided.")
	var status := PackedStringArray([_mode_line(), _turn_line()])
	if _note != "":
		status.append(_note)
	_status.text = "\n".join(status)


func _choices_text() -> String:
	if guard.has_decided():
		return TalkPanel.outcome(guard.state) + "  " + (tr("R again.") if mode == RECORDED else tr("Tab, then R, again."))
	if mode == LIVE:
		return tr("Type to the guard, Enter says it.")
	var lines: PackedStringArray = book.choices(said)
	if book.recordings.is_empty():
		return tr("No recordings in data/talk/recordings/: Tab to talk live.")
	if lines.is_empty():
		return tr("The recordings end here: R again, or Tab to talk live.")
	var numbered := PackedStringArray()
	for index: int in mini(lines.size(), 9):
		numbered.append("%d. %s" % [index + 1, lines[index]])
	return "\n".join(numbered)


func _mode_line() -> String:
	if mode == RECORDED:
		return tr("Recorded: lines a local model was once asked, answered as it answered. 1-9 say one, V the reasoning, R again, Tab live.")
	if recording:
		return tr("Live, recording: each finished conversation is written to data/talk/recordings/. Tab recorded.")
	return tr("Live: what you type goes to the local model (make llm-serve). Enter says it, Tab recorded.")


func _turn_line() -> String:
	return tr("Turn {turn} of {turns}.").format({"turn": guard.state["turn"], "turns": int(TalkRules.scene()["turns"])}) \
		+ ("  " + tr("Bram is thinking...") if guard.is_thinking() else "")


func _draw() -> void:
	draw_set_transform(PICTURE)
	TalkView.draw_scene(self, guard.state, guard.is_thinking(), _clock)
