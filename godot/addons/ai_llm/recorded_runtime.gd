## A runtime that answers from a recording: nothing installed, no model.
##
## Each request is answered with the next recorded text, in order -- the
## text a model once gave, untouched, so the validator meets exactly what it
## would have met live. It is what every test and every recorded demo uses,
## and it is why `ai_llm` needs no hardware above tier 1 (invariant 5).
##
## It answers asynchronously, as a server does: `send` returns at once and
## the text arrives by `replied` `frames_to_wait` frames later, never inside
## the call. A game written against this runtime therefore cannot come to
## depend on an instant answer, and works unchanged against `HttpRuntime`.
##
## When not to use it: to see what a model says to something new. A
## recording only knows the lines it was recorded with; past its last turn
## it fails every request.
class_name RecordedRuntime
extends LlmRuntime

## How many frames pass between `send` and `replied`. At least one.
var frames_to_wait: int = 1

var _recorded: PackedStringArray = PackedStringArray()
var _next: int = 0
var _busy: bool = false


## A runtime that answers with `recorded`, one text per request, in order.
func _init(recorded: PackedStringArray = PackedStringArray()) -> void:
	_recorded = recorded


## The model texts of a recording file (spec/llm/recordings/), in order, or
## an empty runtime when the file cannot be read -- every request then fails,
## saying so, rather than the game stopping.
static func from_file(path: String) -> RecordedRuntime:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return RecordedRuntime.new()
	var reader := JSON.new()
	if reader.parse(file.get_as_text()) != OK or not (reader.data is Dictionary):
		return RecordedRuntime.new()
	var texts := PackedStringArray()
	for turn: Variant in (reader.data as Dictionary).get("turns", []):
		if turn is Dictionary and (turn as Dictionary).get("raw") is String:
			texts.append(turn["raw"])
	return RecordedRuntime.new(texts)


## How many recorded texts have not been answered yet.
func remaining() -> int:
	return _recorded.size() - _next


## Queues the next recorded text, to arrive by a signal after
## `frames_to_wait` frames. ERR_BUSY while one is still on its way;
## ERR_UNCONFIGURED outside the scene tree, which has no frames to wait on.
func send(_messages: Array[Dictionary], _schema: Dictionary) -> Error:
	if _busy:
		return ERR_BUSY
	if not is_inside_tree():
		return ERR_UNCONFIGURED
	_busy = true
	_answer_later()
	return OK


## True from `send` until its answer has been signalled.
func is_busy() -> bool:
	return _busy


# Waits the frames, then answers. Started by `send` and not awaited there,
# so `send` returns at the first `await` -- that is the asynchrony.
func _answer_later() -> void:
	for frame: int in maxi(frames_to_wait, 1):
		await get_tree().process_frame
		if not is_inside_tree():
			# Taken out of the tree mid-answer: say so, or a conversation
			# waiting on this runtime thinks forever.
			_busy = false
			failed.emit("the runtime left the scene tree mid-request")
			return
	_busy = false
	if _next >= _recorded.size():
		failed.emit("the recording has no more replies")
		return
	_next += 1
	replied.emit(_recorded[_next - 1])
