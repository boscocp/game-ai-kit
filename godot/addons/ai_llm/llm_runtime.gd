## Where a conversation's requests go: the port every runtime implements.
##
## A runtime takes the messages so far and answers, later, by a signal --
## `replied` with the model's text untouched, or `failed` with why there is
## none. Never by a return value: an answer that arrived inside `send` would
## be a frame the game could not draw (invariant 7: the LLM never blocks a
## frame). It does not validate; `LlmConversation` hands every text to an
## `LlmValidator` before the game sees it.
##
## Two implementations: `RecordedRuntime`, answering from a committed
## recording with nothing installed (tier 1 and 2), and `HttpRuntime`, a
## local server (tier 3). A Node, because both need the frame loop -- one to
## wait on, the other for its `HTTPRequest`.
##
## When not to use it: to reach anything that is not a language model. This
## port carries chat messages and one text back.
class_name LlmRuntime
extends Node

## The model's text, exactly as the runtime received it.
signal replied(raw_text: String)

## No text came: the server could not be reached, timed out, or answered
## something that is not a reply. `reason` is a sentence for a person.
signal failed(reason: String)


## Starts one request; the answer comes by `replied` or `failed`, never
## before this returns. `messages` are chat messages (`role`, `content`);
## `schema` is the JSON schema a runtime that can constrain its output may
## use. ERR_BUSY while a request is in flight: one at a time.
func send(_messages: Array[Dictionary], _schema: Dictionary) -> Error:
	return ERR_UNAVAILABLE


## True while a request is in flight and its answer has not come.
func is_busy() -> bool:
	return false
