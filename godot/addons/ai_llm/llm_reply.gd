## One reply from the character's language model, after the validator ruled.
##
## Either the model's own words passed every rule -- `refusal` is "" and the
## game's rules may act on `intent` and `argument` -- or they did not, and this
## is the game's fallback: its own line, the intent `unclear`, and in
## `refusal` the code and sentence of the rule the model broke, for the game
## to show beside the line (invariant 13: the decision, not only the outcome).
##
## Built only by `LlmValidator`: `check_llm_validated.py` (V2) refuses an
## `LlmReply.new` anywhere else, because a reply built by hand is a model's
## text that skipped the door.
##
## When not to use it: for anything the game did not ask a model.
class_name LlmReply
extends RefCounted

## What the character says. One line, no markup, no secret.
var speech: String = ""

## Which of the game's declared discourse acts the player's words were.
var intent: String = ""

## One of that intent's declared values, or "".
var argument: String = ""

## "" when the model's reply passed; otherwise why it was refused.
var refusal: String = ""

## What the runtime handed over, untouched. For the addon's own use only:
## `check_llm_validated.py` (V2) refuses a read of it outside `ai_llm`,
## because text nobody validated is exactly what must not reach a rule.
## A game shows `refusal` instead.
var raw_text: String = ""


func _init(given_speech: String, given_intent: String, given_argument: String,
		given_refusal: String, given_raw_text: String) -> void:
	speech = given_speech
	intent = given_intent
	argument = given_argument
	refusal = given_refusal
	raw_text = given_raw_text


## True when the model's own words passed, and the game may act on them.
func is_accepted() -> bool:
	return refusal == ""


## The code of the rule the reply broke (`R1` to `R11`, or `F1` when the
## runtime gave no reply at all), or "" -- what a test or an overlay
## compares, since the sentence after it is free to change.
func refusal_code() -> String:
	return refusal.get_slice(" ", 0) if refusal != "" else ""
