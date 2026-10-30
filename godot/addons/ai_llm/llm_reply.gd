## One reply from the character's language model, after the validator ruled.
##
## Either the model's own words passed every rule -- `refusal` is "" and the
## game's rules may act on `intent` and `argument` -- or they did not, and this
## is the game's fallback: its own line, the intent `unclear`, and in
## `refusal` the code and sentence of the rule the model broke, for the game
## to show beside the line (invariant 13: the decision, not only the outcome).
##
## Read-only: every field refuses to be written after the validator ruled.
## Built only by `LlmValidator`: `check_llm_validated.py` (V2) refuses an
## `LlmReply.new` anywhere else, because a reply built by hand is a model's
## text that skipped the door.
##
## When not to use it: for anything the game did not ask a model.
class_name LlmReply
extends RefCounted

## What the character says. One line, no markup, no secret.
var speech: String:
	get:
		return _speech
	set(_value):
		_refuse_change("speech")

## Which of the game's declared discourse acts the player's words were.
var intent: String:
	get:
		return _intent
	set(_value):
		_refuse_change("intent")

## One of that intent's declared values, or "".
var argument: String:
	get:
		return _argument
	set(_value):
		_refuse_change("argument")

## "" when the model's reply passed; otherwise why it was refused.
var refusal: String:
	get:
		return _refusal
	set(_value):
		_refuse_change("refusal")

## What the runtime handed over, untouched. For the addon's own use only:
## `check_llm_validated.py` (V2) refuses a read of it outside `ai_llm`,
## because text nobody validated is exactly what must not reach a rule.
## A game shows `refusal` instead.
var raw_text: String:
	get:
		return _raw_text
	set(_value):
		_refuse_change("raw_text")

# The ruling itself. Read through the properties above, which refuse to be
# written: a game that set `intent = "open"` after the validator ruled
# would have made the decision the model is not allowed to make.
var _speech: String = ""
var _intent: String = ""
var _argument: String = ""
var _refusal: String = ""
var _raw_text: String = ""


func _init(given_speech: String, given_intent: String, given_argument: String,
		given_refusal: String, given_raw_text: String) -> void:
	_speech = given_speech
	_intent = given_intent
	_argument = given_argument
	_refusal = given_refusal
	_raw_text = given_raw_text


## True when the model's own words passed, and the game may act on them.
func is_accepted() -> bool:
	return _refusal == ""


## The code of the rule the reply broke (`R1` to `R11`; `F1` when the
## runtime gave no reply at all, `F2` when the server refused the request
## itself), or "" -- what a test or an overlay
## compares, since the sentence after it is free to change.
func refusal_code() -> String:
	return _refusal.get_slice(" ", 0) if _refusal != "" else ""


# Every field is the validator's ruling, and a ruling is not edited.
func _refuse_change(field: String) -> void:
	push_error("LlmReply.%s is read-only: the validator's ruling is not changed after it" % field)
