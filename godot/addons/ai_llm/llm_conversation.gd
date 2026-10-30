## One conversation with a character a language model voices.
##
## It holds what has been said, the one request in flight, and whether the
## character is thinking -- the state a game draws while it waits, because an
## answer takes seconds and the frame must not (invariant 7). The player's
## line goes in with `say`; the answer comes out by `answered`, always an
## `LlmReply` the validator built: the model's words if they passed, the
## game's fallback if they did not or if no answer came.
##
## The history the model is shown holds only what the game accepted: the
## player's lines, and each reply as the validator ruled it -- never a
## refused text, so a model cannot build on what it was overruled on.
##
## The game's secrets never enter a prompt. The instructions are checked for
## them when the conversation is built (`problem`), and every reply for them
## again by the validator (R11), as a net.
##
## A conversation dies with its runtime: free the runtime mid-request and
## no answer comes, so free them together. Taking the runtime out of the
## tree and putting it back is answered, with F1.
##
## When not to use it: for a single question with no history, which is a
## runtime's `send` and a validator's `validate`, and nothing to hold.
class_name LlmConversation
extends RefCounted

## The character's answer to the player's last line, after the validator.
signal answered(reply: LlmReply)

var _runtime: GakLlmRuntime = null
var _validator: LlmValidator = null
var _instructions: String = ""
var _history: Array[Dictionary] = []
var _thinking: bool = false


## A conversation through `runtime`, judged by `validator`. `instructions`
## describe the character to the model; the shape and the game's intents
## are appended from the validator itself, so the prompt and the rules
## cannot disagree.
func _init(runtime: GakLlmRuntime, validator: LlmValidator, instructions: String) -> void:
	_runtime = runtime
	_validator = validator
	_instructions = instructions
	_runtime.replied.connect(_on_replied)
	_runtime.failed.connect(_on_failed)
	_runtime.refused.connect(_on_refused)


## Why this conversation cannot start, or "": the validator's own problem,
## or a secret written into the instructions the model would be sent.
func problem() -> String:
	var wrong: String = _validator.problem()
	if wrong != "":
		return wrong
	if _validator.gives_away_a_secret(_instructions):
		return "the instructions contain a secret; what the model is not told it cannot leak"
	return ""


## Sends the player's line. The answer arrives by `answered`, later.
## ERR_BUSY while the character is still thinking: one request at a time.
## ERR_INVALID_DATA when `problem()` is not "". Any other error is the
## runtime's, and then nothing was sent and nothing will be answered.
func say(player_line: String) -> Error:
	if _thinking:
		return ERR_BUSY
	if problem() != "":
		return ERR_INVALID_DATA
	var messages: Array[Dictionary] = [{"role": "system", "content": system_prompt()}]
	messages.append_array(_history)
	messages.append({"role": "user", "content": player_line})
	var sent: Error = _runtime.send(messages, _validator.json_schema())
	if sent != OK:
		return sent
	_history.append({"role": "user", "content": player_line})
	_thinking = true
	return OK


## True from `say` until `answered`: the time to draw the character thinking.
func is_thinking() -> bool:
	return _thinking


## What the model is told before the conversation: the game's instructions,
## then the shape and the intents, in words, from the validator.
func system_prompt() -> String:
	return "%s\n\n%s" % [_instructions, _validator.instructions()]


## The conversation so far, as the model is shown it: a copy.
func history() -> Array[Dictionary]:
	return _history.duplicate(true)


func _on_replied(raw_text: String) -> void:
	_answer(_validator.validate(raw_text))


func _on_failed(reason: String) -> void:
	_answer(_validator.fallback("F1 no reply came: %s" % reason))


# Not the model's fault and not bad luck: the request itself was refused,
# and will be again on every turn until it is fixed.
func _on_refused(reason: String) -> void:
	_answer(_validator.fallback("F2 the server refused the request: %s" % reason))


# Records the reply as the game took it -- never the raw text -- and hands
# it over.
func _answer(reply: LlmReply) -> void:
	_thinking = false
	var as_ruled: String = JSON.stringify({
		"speech": reply.speech, "intent": reply.intent, "argument": reply.argument,
	})
	_history.append({"role": "assistant", "content": as_ruled})
	answered.emit(reply)
