## A local language-model server: used if one answers, started if none does.
##
## A game in live mode needs a server listening on `HttpRuntime.PORT`. This
## node asks the server's `/health` first. Something answers: it is used and
## never touched, whoever started it. Nothing answers: `program` is started
## with `arguments`, and `/health` is asked again every `POLL_SECONDS` until
## the model has loaded -- llama.cpp answers 503 while it loads and 200 once
## ready (its server README at the pinned tag, docs/local-llm/server.md).
## When the node leaves the tree it stops the server, only if it started it.
##
## Never on the frame (invariant 7): `OS.create_process` returns at once,
## the program runs beside the game, and each ask is an `HTTPRequest` with
## threads on. Loading takes seconds; the game draws through all of them.
##
## When not to use it: in an exported game, or wherever the program that
## serves the model is not known -- pass "" and it says `BY_HAND`, so the
## person is told to start one. And not to keep a server alive past the
## game: a server started here dies with this node.
class_name LlmLocalServer
extends Node

## The state changed; `state` holds the new one.
signal changed(state: String)

## Asking whether a server answers. Not shown: states are identifiers.
const CHECKING: String = "checking"
## A server is loading its model: one started here, or one already there.
const LOADING: String = "loading"
## A server answered that it is ready.
const READY: String = "ready"
## Nothing answers and there is nothing to start: a person must start one.
const BY_HAND: String = "by_hand"
## The program started here exited, or never became ready: see `reason`.
const STOPPED: String = "stopped"

## Seconds between two asks while a model loads.
const POLL_SECONDS: float = 0.25
## Seconds before one ask is given up on. The server is on this machine.
const ASK_TIMEOUT: float = 1.0
## Seconds a started server may take to load before it is given up on and
## stopped. `scripts/llm smoke` allows the same (tools/llm/llm.py).
const LOAD_SECONDS: float = 180.0

## Where it stands: one of the constants above, "" before `begin`.
var state: String = ""
## The server's health endpoint.
var health_url: String = ""
## The program that serves the model, as a path; "" when there is none.
var program: String = ""
## What `program` is started with.
var arguments: PackedStringArray = PackedStringArray()
## The process started here, or -1: the only one this node ever stops.
var pid: int = -1
## Seconds since the program was started here.
var waited: float = 0.0
## Why the state is `STOPPED`, for a person.
var reason: String = ""

var _ask: HTTPRequest = null
var _asking: bool = false
var _since_ask: float = 0.0
var _alive: bool = false


## A server reached on `port`, started with `program_path` and
## `program_arguments` when none answers there.
func _init(program_path: String = "", program_arguments: PackedStringArray = PackedStringArray(),
		port: int = HttpRuntime.PORT) -> void:
	program = program_path
	arguments = program_arguments
	health_url = "http://127.0.0.1:%d/health" % port


func _ready() -> void:
	_ask = HTTPRequest.new()
	_ask.use_threads = true
	_ask.timeout = ASK_TIMEOUT
	add_child(_ask)
	_ask.request_completed.connect(_on_answer)


## Find a server, or start one. Does nothing while one is being found or
## loads, or once one is ready; after `BY_HAND` or `STOPPED` it asks again,
## so a server started by hand meanwhile is found. ERR_UNCONFIGURED before
## the node is in the tree.
func begin() -> Error:
	if _ask == null:
		return ERR_UNCONFIGURED
	if state in [CHECKING, LOADING, READY]:
		return OK
	reason = ""
	if started_here() and not _still_running():
		pid = -1
	_set_state(CHECKING)
	_ask_health()
	return OK


## True once a server said it is ready.
func is_ready() -> bool:
	return state == READY


## True when the server was started by this node, and so is stopped by it.
func started_here() -> bool:
	return pid != -1


func _process(delta: float) -> void:
	if state != LOADING:
		return
	_since_ask += delta
	if started_here():
		waited += delta
		if not _still_running():
			_give_up("the server exited with code %d while loading" % OS.get_process_exit_code(pid))
			return
		if waited > LOAD_SECONDS:
			_give_up("the server did not load in %d s" % int(LOAD_SECONDS))
			return
	if not _asking and _since_ask >= POLL_SECONDS:
		_ask_health()


# A server started here stops with the node; one found running never does.
func _exit_tree() -> void:
	if _ask != null:
		_ask.cancel_request()
	_asking = false
	_stop()


func _ask_health() -> void:
	_since_ask = 0.0
	_asking = _ask.request(health_url) == OK


# No answer at all means nothing listens; any HTTP answer means a server
# does. 503 is llama.cpp loading its model; anything else is taken as ready,
# and what it says to a chat request is `HttpRuntime`'s to report.
func _on_answer(result: int, response_code: int, _headers: PackedStringArray,
		_body: PackedByteArray) -> void:
	_asking = false
	if result != HTTPRequest.RESULT_SUCCESS:
		if state == CHECKING:
			_start()
		return
	_set_state(LOADING if response_code == 503 else READY)


func _start() -> void:
	if program == "" or not FileAccess.file_exists(program):
		_set_state(BY_HAND)
		return
	pid = OS.create_process(program, arguments)
	if pid == -1:
		reason = "%s could not be started" % program
		_set_state(STOPPED)
		return
	_alive = true
	waited = 0.0
	_set_state(LOADING)


func _give_up(why: String) -> void:
	reason = why
	_stop()
	_set_state(STOPPED)


# Asked of a process this node started and has not yet seen end. Once
# ended, Godot forgets it, and asking again prints an error.
func _still_running() -> bool:
	if _alive:
		_alive = OS.is_process_running(pid)
	return _alive


# SIGKILL, and then Godot waits for the process to be gone (OS_Unix::kill
# at 4.7). For llama-server letting go of the card that is about 90 ms,
# measured (docs/godot/talk.md): one long frame, once, on leaving.
func _stop() -> void:
	if _still_running():
		OS.kill(pid)
	_alive = false


func _set_state(next: String) -> void:
	if next == state:
		return
	state = next
	changed.emit(state)
