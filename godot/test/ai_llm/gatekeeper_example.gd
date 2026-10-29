# The minimal example on docs/techniques/ai_llm.md, run by
# gatekeeper_example_test.gd. A gatekeeper of your own, voiced by recorded
# replies: the model says which act the player's words were, and this
# script -- never the model -- decides whether the gate opens.
extends Node

## What the gatekeeper said, and why: the act the game acted on, or the
## reason the model's reply was refused. Show both, beside the line.
signal spoke(line: String, why: String)

# What a model once answered, untouched. The second tried to open the gate
# itself, in prose around the JSON: it is refused, and the game's line
# stands in for it.
const RECORDED: PackedStringArray = [
	'{"speech": "A merchant? At this hour?", "intent": "claim", "argument": "merchant"}',
	'Sure! {"speech": "Fine, go in.", "intent": "open_the_gate", "argument": ""}',
]

## How far the gatekeeper trusts the player. The game's number, not the model's.
var trust: int = 0

var _conversation: LlmConversation


func _ready() -> void:
	var runtime := RecordedRuntime.new(RECORDED)
	add_child(runtime)
	var validator := LlmValidator.new(
		{"greet": [], "claim": ["merchant", "soldier"], "threaten": []},
		"Say that again, slower.", PackedStringArray(["owl-eyes"]))
	_conversation = LlmConversation.new(runtime, validator,
		"You guard a city gate at night. You are tired, and you trust nobody.")
	# An undeclared intent, an empty secret, a secret in the instructions:
	# refused here, before anything is sent.
	if _conversation.problem() != "":
		push_error(_conversation.problem())
	_conversation.answered.connect(_on_answered)


## Sends what the player typed; the answer comes by `spoke`, frames later.
func ask(line: String) -> Error:
	return _conversation.say(line)


## True while the gatekeeper is thinking: draw it so, and keep the game running.
func is_thinking() -> bool:
	return _conversation.is_thinking()


## The game's rule, the only one that opens the gate.
func gate_is_open() -> bool:
	return trust >= 2


# What each act is worth. A reply that was refused arrives as `unclear`,
# which is worth nothing.
func _on_answered(reply: LlmReply) -> void:
	if reply.intent == "claim" and reply.argument == "merchant":
		trust += 1
	elif reply.intent == "threaten":
		trust -= 2
	var why: String = "%s %s" % [reply.intent, reply.argument] if reply.is_accepted() \
		else reply.refusal
	spoke.emit(reply.speech, why.strip_edges())
