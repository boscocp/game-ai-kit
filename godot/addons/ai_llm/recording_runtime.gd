## A runtime that passes every request to another one and keeps a recording.
##
## Wrap a live runtime in it and play: each request goes to the wrapped
## runtime unchanged, each answer comes back by the same signal, and the
## player's line with the model's text, untouched, is kept for `save` to
## write in the shape `RecordedRuntime.from_file` reads back. That is how a
## game records conversations a person can later replay with no model
## (tier 1), and the reason it lives in the addon: the text it keeps is the
## model's before any validator ruled on it, which no game may read
## (`check_llm_validated.py`, V2). A game hands it a path and never sees the
## text.
##
## A turn the wrapped runtime could not answer (`failed`, `refused`) has no
## text to replay, so a recording holding one is not saved.
##
## When not to use it: to record a person's play without asking. A game
## records only when asked (ADR 0017), and says so on screen.
class_name RecordingRuntime
extends GakLlmRuntime

var _inner: GakLlmRuntime = null
var _turns: Array[Dictionary] = []
var _player_line: String = ""
var _missed: int = 0


## A recording of what `inner` answers. `inner` becomes this node's child.
func _init(inner: GakLlmRuntime) -> void:
	_inner = inner
	add_child(_inner)
	_inner.replied.connect(_on_replied)
	_inner.failed.connect(_on_failed)
	_inner.refused.connect(_on_refused)


## Passes the request on, remembering the player's line -- the last message,
## which `LlmConversation` always makes the player's.
func send(messages: Array[Dictionary], schema: Dictionary) -> Error:
	var sent: Error = _inner.send(messages, schema)
	if sent == OK:
		_player_line = str(messages.back().get("content", "")) if not messages.is_empty() else ""
	return sent


## True while the wrapped runtime has a request in flight.
func is_busy() -> bool:
	return _inner.is_busy()


## How many turns were answered with a text, and kept.
func kept() -> int:
	return _turns.size()


## Writes the recording to `path`: `about`'s fields, then `turns`, each the
## player's line and the model's text. ERR_INVALID_DATA when a turn went
## unanswered (nothing to replay it with) or none was kept; otherwise the
## error opening the file, or OK.
func save(path: String, about: Dictionary) -> Error:
	if _missed > 0 or _turns.is_empty():
		return ERR_INVALID_DATA
	var recording: Dictionary = about.duplicate(true)
	recording["turns"] = _turns.duplicate(true)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(recording, "  ", false) + "\n")
	file.close()
	return OK


func _on_replied(raw_text: String) -> void:
	_turns.append({"player": _player_line, "raw": raw_text})
	replied.emit(raw_text)


func _on_failed(reason: String) -> void:
	_missed += 1
	failed.emit(reason)


func _on_refused(reason: String) -> void:
	_missed += 1
	refused.emit(reason)
