## A runtime that asks a local language-model server, over HTTP.
##
## It speaks the OpenAI-compatible `/v1/chat/completions` that llama.cpp's
## server offers (T93 pins and measures the server; this file only speaks
## to one). The game's schema goes in `response_format`, so a server that
## constrains its output to a schema can -- a convenience: whatever comes
## back is validated anyway, by `LlmConversation`'s `LlmValidator`.
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

## The server's chat endpoint.
var url: String = "http://127.0.0.1:8080/v1/chat/completions"

## The model name the server is asked for; llama.cpp's server ignores it.
var model: String = "local"

## Seconds before a request is given up on, and `failed` says so.
var timeout_seconds: float = 30.0

var _request: HTTPRequest = null
var _in_flight: bool = false


## A runtime for the server at `endpoint`.
func _init(endpoint: String = "") -> void:
	if endpoint != "":
		url = endpoint


func _ready() -> void:
	_request = HTTPRequest.new()
	_request.use_threads = true
	_request.timeout = timeout_seconds
	add_child(_request)
	_request.request_completed.connect(_on_request_completed)


func _exit_tree() -> void:
	if _request != null:
		_request.cancel_request()
	_in_flight = false


## Starts one request to the server. ERR_BUSY while one is in flight;
## ERR_UNCONFIGURED before the runtime is in the scene tree. Any other error
## is the one `HTTPRequest.request` returned.
func send(messages: Array[Dictionary], schema: Dictionary) -> Error:
	if _request == null:
		return ERR_UNCONFIGURED
	if is_busy():
		return ERR_BUSY
	var headers := PackedStringArray(["Content-Type: application/json"])
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


## The model's text inside a chat-completions answer, as
## `{"text": ..., "failure": ""}`, or `{"text": "", "failure": why}`. This is
## the server's envelope, not the reply: the text it holds is validated next.
static func text_of(body: String) -> Dictionary:
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


func _on_request_completed(result: int, response_code: int,
		_headers: PackedStringArray, body: PackedByteArray) -> void:
	_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS:
		failed.emit("the request did not complete (HTTPRequest result %d)" % result)
		return
	if response_code != 200:
		failed.emit("the server answered HTTP %d" % response_code)
		return
	var answer: Dictionary = text_of(body.get_string_from_utf8())
	if answer["failure"] != "":
		failed.emit(answer["failure"])
		return
	replied.emit(answer["text"])
