## Bram, the guard at the door: one conversation, and the rules that judge it.
##
## The language model is his ears and his mouth, nothing more. Each line the
## player says goes, through `ai_llm`'s `LlmConversation`, to whichever
## runtime this guard was given -- a recording, a local server, or a server
## being recorded -- with Bram's instructions and the talk so far. What comes
## back passes `LlmValidator` first; only the act it admits reaches
## `TalkRules`, which move trust and suspicion and decide the door. When the
## rules decide, the guard's last line is the scene's own ending, never the
## model's: no sentence the model writes can say "go in" when the rules said
## no.
##
## Each ruled turn is signalled as one Dictionary -- the line, what the guard
## said, the act or the refusal, the rule, what it moved, the guard after it,
## the seconds the answer took -- which is everything the reasoning panel
## shows (invariant 13). A Node, because a runtime needs the frame loop.
##
## When not to use it: for a character whose replies change nothing. A guard
## who only chats needs a validator's R8 to R11 and no rules at all.
class_name TalkGuard
extends Node

## One turn, ruled: see the class's description for its fields.
signal ruled(turn: Dictionary)

## `en` or `pt_BR`: the language the guard is told to answer in.
var language: String = Language.ENGLISH
## What the guard thinks of the player: `TalkRules.new_guard()`'s fields.
var state: Dictionary = TalkRules.new_guard()
## Every turn ruled so far, oldest first.
var turns: Array[Dictionary] = []

var _runtime: GakLlmRuntime = null
var _conversation: LlmConversation = null
var _line: String = ""
var _asked_at: int = 0


## A guard who answers in `in_language`, with no runtime yet: `use_runtime`.
func _init(in_language: String = Language.ENGLISH) -> void:
	language = in_language


## Answers through `runtime` from now on, which becomes this node's child.
## The talk so far stays with the old runtime's conversation: a recorded
## turn needs none, and a live game keeps one runtime from start to end.
func use_runtime(runtime: GakLlmRuntime) -> void:
	if _runtime != null:
		_runtime.queue_free()
	_runtime = runtime
	add_child(_runtime)
	_conversation = LlmConversation.new(_runtime, TalkRules.validator(language),
		TalkRules.words(language)["instructions"])
	_conversation.answered.connect(_on_answered)


## Why the guard cannot talk, or "": the conversation's own problem.
func problem() -> String:
	if _conversation == null:
		return "no runtime"  # not shown: a test's message
	return _conversation.problem()


## Sends what the player said; the guard's answer comes by `ruled`, later.
## ERR_BUSY while he is thinking, ERR_UNAVAILABLE once he has decided,
## ERR_PARAMETER_RANGE_ERROR for an empty line or one longer than the
## scene's `player_line_limit` -- the bound that, with the turn limit, keeps
## a whole conversation inside the server's context.
func say(line: String) -> Error:
	if state["outcome"] != TalkRules.PLAYING:
		return ERR_UNAVAILABLE
	if line.strip_edges() == "" or line.length() > int(TalkRules.scene()["player_line_limit"]):
		return ERR_PARAMETER_RANGE_ERROR
	if _conversation == null:
		return ERR_UNCONFIGURED
	var sent: Error = _conversation.say(line)
	if sent == OK:
		_line = line
		_asked_at = Time.get_ticks_msec()
	return sent


## True from `say` until `ruled`: the time to draw him thinking.
func is_thinking() -> bool:
	return _conversation != null and _conversation.is_thinking()


## True once the door opened, the alarm sounded or the turns ran out.
func has_decided() -> bool:
	return state["outcome"] != TalkRules.PLAYING


## Writes what the runtime recorded to `path`, when it is a
## `RecordingRuntime`; ERR_UNAVAILABLE when it is not. `about` says what
## made the recording.
func save_recording(path: String, about: Dictionary) -> Error:
	var recording := _runtime as RecordingRuntime
	if recording == null:
		return ERR_UNAVAILABLE
	return recording.save(path, about)


## The talk so far as the model would be shown it on the next line: what a
## test measures against the server's context.
func conversation_length() -> int:
	if _conversation == null:
		return 0
	var length: int = _conversation.system_prompt().length()
	for message: Dictionary in _conversation.history():
		length += str(message["content"]).length()
	return length


func _on_answered(reply: LlmReply) -> void:
	var ruling: Dictionary = TalkRules.step(state, reply.intent, reply.argument)
	state = ruling["guard"]
	var speech: String = reply.speech
	if has_decided():
		speech = TalkRules.words(language)["endings"][state["outcome"]]
	var turn: Dictionary = {
		"player": _line, "speech": speech, "intent": reply.intent, "argument": reply.argument,
		"refusal": reply.refusal, "refusal_code": reply.refusal_code(),
		"rule": ruling["rule"], "trust_moved": ruling["trust"],
		"suspicion_moved": ruling["suspicion"], "trust": state["trust"],
		"suspicion": state["suspicion"], "turn": state["turn"], "outcome": state["outcome"],
		"seconds": (Time.get_ticks_msec() - _asked_at) / 1000.0,
	}
	turns.append(turn)
	ruled.emit(turn)
