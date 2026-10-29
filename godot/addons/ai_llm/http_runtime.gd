## A runtime that asks a local language-model server, over HTTP.
##
## It speaks the OpenAI-compatible `/v1/chat/completions` that llama.cpp's
## server offers (T93 pins and measures the server; this file only speaks
## to one). The game's schema goes in `response_format`, in OpenAI's form,
## `{"type": "json_schema", "json_schema": {"schema": ...}}`: measured at
## the pinned build, the server constrains its output to it -- and silently
## ignores the form its own README shows, with `schema` one level up
## (docs/local-llm/server.md). A convenience: whatever comes back is
## validated anyway, by `LlmConversation`'s `LlmValidator`.
##
## No text, two ways: `failed` when no answer came (unreachable, timed out,
## not ready, an envelope with no reply in it), `refused` when the server
## answered that it will not take the request, with its reason -- that one
## comes back every turn until the request is fixed, so it is kept apart.
##
## Never on the frame (invariant 7). The request goes through an
## `HTTPRequest` with `use_threads` on and a fixed `timeout`, one in flight
## at a time; `send` returns at once and the text arrives by `replied`.
## Measured on 4.7.2 with threads off as well: no frame stalled either way
## on this machine (docs/godot/llm-requests.md) -- threads stay on because
## the documentation does not promise that, and the gate holds every
## `HTTPRequest` here to it (check_llm_validated.py, V3).
##
## When not to use it: in a test, or wherever no server is running -- that is
## `RecordedRuntime`'s job, and it needs nothing installed.
class_name HttpRuntime
extends LlmRuntime

## The port the local server listens on, and the one place it is written:
## the kit's server wrapper reads this line to start llama.cpp's server
## here, and the acceptance gate to know a task naming it needs a model
## (T93, docs/local-llm/). 9931 is also the server's default at the pin.
const PORT: int = 9931

## The server's chat endpoint.
var url: String = "http://127.0.0.1:%d/v1/chat/completions" % PORT

## The model name the server is asked for; llama.cpp's server ignores it.
var model: String = "local"

## The largest answer read, in bytes. A reply is one line of at most 280
## characters inside a small envelope; a server sending megabytes is wrong,
## and is refused rather than read.
const BODY_SIZE_LIMIT: int = 65536

## Seconds before a request is given up on, and `failed` says so. Read by
## every `send`, so a change applies to the next request.
var timeout_seconds: float = 30.0

## How much of the server's reason for refusing a request is kept: enough
## to say what was wrong, short enough to show beside a line.
const ERROR_LENGTH: int = 160

var _request: HTTPRequest = null
var _in_flight: bool = false


## A runtime for the server at `endpoint`.
func _init(endpoint: String = "") -> void:
	if endpoint != "":
		url = endpoint


func _ready() -> void:
	_request = HTTPRequest.new()
	_request.use_threads = true
	_request.body_size_limit = BODY_SIZE_LIMIT
	add_child(_request)
	_request.request_completed.connect(_on_request_completed)


# A request in flight when the runtime leaves the tree is cancelled, and
# says so: without `failed`, a conversation waiting on it thinks forever.
# Deferred, so the answer never arrives inside the call that removed it.
func _exit_tree() -> void:
	if _request != null:
		_request.cancel_request()
	if _in_flight:
		_in_flight = false
		failed.emit.call_deferred("the runtime left the scene tree mid-request")


## Starts one request to the server. ERR_BUSY while one is in flight;
## ERR_UNCONFIGURED before the runtime is in the scene tree. Any other error
## is the one `HTTPRequest.request` returned.
func send(messages: Array[Dictionary], schema: Dictionary) -> Error:
	if _request == null:
		return ERR_UNCONFIGURED
	if is_busy():
		return ERR_BUSY
	var headers := PackedStringArray(["Content-Type: application/json"])
	_request.timeout = timeout_seconds
	var sent: Error = _request.request(url, headers, HTTPClient.METHOD_POST,
		request_body(messages, schema))
	_in_flight = sent == OK
	return sent


## True while a request is in flight.
func is_busy() -> bool:
	return _in_flight


## The body of one chat-completions request, as text. Public so a test can
## read what would be sent without a server.
func request_body(messages: Array[Dictionary], schema: Dictionary) -> String:
	return JSON.stringify({
		"model": model,
		"messages": messages,
		"response_format": {
			"type": "json_schema",
			"json_schema": {"name": "reply", "strict": true, "schema": schema},
		},
	})


# The model's text inside a chat-completions answer, as
# `{"text": ..., "failure": ""}`, or `{"text": "", "failure": why}`. This is
# the server's envelope, not the reply: the text it holds is validated next.
# Private, and the gate (V2) refuses a call to it outside the addon: what it
# returns is the text no validator has seen.
static func _text_of(body: String) -> Dictionary:
	var reader := JSON.new()
	if reader.parse(body) != OK or not (reader.data is Dictionary):
		return {"text": "", "failure": "the server's answer is not a JSON object"}
	var choices: Variant = (reader.data as Dictionary).get("choices")
	if not (choices is Array) or (choices as Array).is_empty() \
			or not ((choices as Array)[0] is Dictionary):
		return {"text": "", "failure": "the server's answer has no choices"}
	var message: Variant = (choices as Array)[0].get("message")
	if not (message is Dictionary) or not ((message as Dictionary).get("content") is String):
		return {"text": "", "failure": "the server's answer has no message content"}
	return {"text": message["content"], "failure": ""}


# The server's own sentence for why it refused a request, on one short line:
# llama.cpp answers `{"error": {"code": 400, "message": ...}}` (measured at
# the pinned build, docs/local-llm/server.md).
static func _error_of(body: String) -> String:
	var data: Variant = JSON.parse_string(body)
	var error: Variant = (data as Dictionary).get("error") if data is Dictionary else null
	var message: Variant = (error as Dictionary).get("message") if error is Dictionary else null
	if not (message is String):
		return "the server gave no reason"
	return " ".join((message as String).split("\n")).left(ERROR_LENGTH)


func _on_request_completed(result: int, response_code: int,
		_headers: PackedStringArray, body: PackedByteArray) -> void:
	_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS:
		failed.emit("the request did not complete (HTTPRequest result %d)" % result)
		return
	# 503 is the server not ready yet ("Loading model", measured): a turn
	# lost, and the next one may land. Any other error is the request
	# refused, with the server's reason -- a 400 for a response_format it
	# does not know, a 500 for a schema it cannot turn into a grammar
	# (both measured at the pinned build) -- and it will be refused again.
	if response_code == 503:
		failed.emit("the server is not ready: %s" % _error_of(body.get_string_from_utf8()))
		return
	if response_code != 200:
		refused.emit("HTTP %d: %s" % [response_code, _error_of(body.get_string_from_utf8())])
		return
	var answer: Dictionary = _text_of(body.get_string_from_utf8())
	if answer["failure"] != "":
		failed.emit(answer["failure"])
		return
	replied.emit(answer["text"])
