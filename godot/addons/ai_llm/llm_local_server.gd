## A local language-model server: used if one answers, started if none does.
##
## A game in live mode needs a server listening on `HttpRuntime.PORT`. This
## node asks the server's `/health` first. Something answers: it is used and
## never touched, whoever started it. Nothing answers: `program` is started,
## and `/health` is asked again every `POLL_SECONDS` until the model has
## loaded -- llama.cpp answers 503 while it loads and 200 once ready, and
## `/health` needs no key (its server README at the pinned tag,
## docs/local-llm/server.md). `begin` asks again from any settled state, so
## a server that went away is noticed and, if it can be, started again.
##
## A server started here gets a key made for that one launch, in the
## environment as LLAMA_API_KEY, never on a command line: llama.cpp allows
## any origin, and the key keeps a web page open in a browser from using
## the model. `api_key` is what `HttpRuntime` must send. It is also started
## with `--parent-pid` and this game's process id, so `scripts/llm` can
## have the server die with the game however the game ends (Linux).
##
## Never on the frame (invariant 7). `OS.create_process` returns at once.
## Each ask is a raw, non-blocking `StreamPeerTCP`, read a little every
## frame and dropped after `ASK_TIMEOUT`. An `HTTPRequest` is not used
## here: with threads on, a timed-out request joins a thread blocked
## reading a socket that accepted and never answers, and the frame waits
## for as long as the socket does (measured, docs/godot/talk.md). Only
## leaving waits: `OS.kill` waits for the process to end, so it runs in
## `_exit_tree` alone, as `check_llm_validated.py` holds.
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
## The server exited, stopped answering, or never became ready: see `reason`.
const STOPPED: String = "stopped"

## Seconds between two asks while a model loads.
const POLL_SECONDS: float = 0.25
## Seconds before one ask is given up on. The server is on this machine.
const ASK_TIMEOUT: float = 1.0
## Asks in a row a server found loading may leave unanswered before it is
## taken as gone. One started here is watched by its process instead.
const SILENT_ASKS: int = 4
## The one request sent: HTTP/1.0, so the server closes when it is done.
const HEALTH_REQUEST: String = "GET /health HTTP/1.0\r\nHost: 127.0.0.1\r\n\r\n"

## Where it stands: one of the constants above, "" before `begin`.
var state: String = ""
## The port the server is asked on, and started on.
var port: int = HttpRuntime.PORT
## The program that serves the model, as a path; "" when there is none.
var program: String = ""
## What `program` is started with, before the parent's id.
var arguments: PackedStringArray = PackedStringArray()
## The process started here, or -1: the only one this node ever stops.
var pid: int = -1
## The key the server started here asks for; "" when none was started.
var api_key: String = ""
## Seconds since the program was started here.
var waited: float = 0.0
## Seconds a started server may take to load before it is given up on.
## `scripts/llm smoke` allows the same (tools/llm/llm.py); a test shortens it.
var load_seconds: float = 180.0
## Why the state is `STOPPED`, for a person.
var reason: String = ""

var _peer: StreamPeerTCP = null
var _heard: PackedByteArray = PackedByteArray()
var _sent: bool = false
var _ask_age: float = 0.0
var _since_ask: float = 0.0
var _alive: bool = false
var _silent: int = 0


## A server reached on `server_port`, started with `program_path` and
## `program_arguments` when none answers there.
func _init(program_path: String = "", program_arguments: PackedStringArray = PackedStringArray(),
		server_port: int = HttpRuntime.PORT) -> void:
	program = program_path
	arguments = program_arguments
	port = server_port


## Find a server, or start one. While one is being found or loads, nothing:
## the answer is on its way. From any other state it asks again, so a
## server that went away since is noticed -- and started again when it can
## be -- and one started by hand meanwhile is found. ERR_UNCONFIGURED
## before the node is in the tree.
func begin() -> Error:
	if not is_inside_tree():
		return ERR_UNCONFIGURED
	if state in [CHECKING, LOADING]:
		return OK
	reason = ""
	if started_here() and not _still_running():
		pid = -1
		api_key = ""
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
	if _peer != null:
		_read_answer(delta)
	if state != LOADING:
		return
	_since_ask += delta
	if started_here():
		waited += delta
		if not _still_running():
			_give_up("the server exited with code %d while loading" % OS.get_process_exit_code(pid))
			return
		if waited > load_seconds:
			_give_up("the server did not load in %d s; it stops when you leave" % int(load_seconds))
			return
	if _peer == null and _since_ask >= POLL_SECONDS:
		_ask_health()


# A server started here stops with the node; one found running never does.
# The one place `OS.kill` runs: it sends SIGKILL and then waits for the
# process to end (OS_Unix::kill at 4.7), about 90 ms for llama-server
# letting go of the card (docs/godot/talk.md) -- one frame, on leaving.
func _exit_tree() -> void:
	_drop_ask()
	if _still_running():
		OS.kill(pid)
	_alive = false


func _ask_health() -> void:
	_since_ask = 0.0
	_ask_age = 0.0
	_sent = false
	_heard = PackedByteArray()
	_peer = StreamPeerTCP.new()
	if _peer.connect_to_host("127.0.0.1", port) != OK:
		_drop_ask()
		_on_silence()


# One frame's worth of the ask: connect, send, read what has come. Nothing
# here waits; a server that says nothing in ASK_TIMEOUT is silence.
func _read_answer(delta: float) -> void:
	_ask_age += delta
	_peer.poll()
	var status: StreamPeerTCP.Status = _peer.get_status()
	if status == StreamPeerTCP.STATUS_CONNECTED and not _sent:
		_sent = _peer.put_partial_data(HEALTH_REQUEST.to_ascii_buffer())[0] == OK
	if status == StreamPeerTCP.STATUS_CONNECTED and _peer.get_available_bytes() > 0:
		_heard.append_array(_peer.get_partial_data(_peer.get_available_bytes())[1])
	var code: int = status_code(_heard)
	if code != -1:
		_drop_ask()
		_on_answer(code)
	elif status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE \
			or _ask_age > ASK_TIMEOUT:
		_drop_ask()
		_on_silence()


## The status code on the first line of an HTTP answer, or -1 until that
## line has arrived whole. Public so a test can read it without a server.
static func status_code(answer: PackedByteArray) -> int:
	var text: String = answer.get_string_from_ascii()
	var line_end: int = text.find("\r\n")
	if not text.begins_with("HTTP/") or line_end == -1:
		return -1
	var words: PackedStringArray = text.substr(0, line_end).split(" ")
	return int(words[1]) if words.size() > 1 and words[1].is_valid_int() else -1


func _drop_ask() -> void:
	if _peer != null:
		_peer.disconnect_from_host()
	_peer = null


# Any HTTP answer means a server listens. 503 is llama.cpp loading its
# model; anything else is taken as ready, and what it says to a chat
# request is `HttpRuntime`'s to report.
func _on_answer(code: int) -> void:
	_silent = 0
	_set_state(LOADING if code == 503 else READY)


# Checking, and the server started here still running but silent: hung, or
# gone deaf -- said so, never a second one started over it. Checking, with
# nothing of ours running: start one. Loading one found here: a few silent
# asks in a row and it is gone. Loading one started here: not yet
# listening, which its process, not the port, says is fine.
func _on_silence() -> void:
	if state == CHECKING and started_here() and _still_running():
		reason = "the server started here stopped answering; it stops when you leave"
		_set_state(STOPPED)
	elif state == CHECKING:
		_start()
	elif state == LOADING and not started_here():
		_silent += 1
		if _silent >= SILENT_ASKS:
			_silent = 0
			reason = "the server that was loading stopped answering"
			_set_state(STOPPED)


# The key travels in the environment the child inherits, set just for the
# call: never on a command line, where `ps` would show it.
func _start() -> void:
	if program == "" or not FileAccess.file_exists(program):
		_set_state(BY_HAND)
		return
	var key: String = Crypto.new().generate_random_bytes(16).hex_encode()
	var launch: PackedStringArray = arguments.duplicate()
	launch.append_array(PackedStringArray(["--parent-pid", str(OS.get_process_id())]))
	OS.set_environment("LLAMA_API_KEY", key)
	pid = OS.create_process(program, launch)
	OS.unset_environment("LLAMA_API_KEY")
	if pid == -1:
		reason = "%s could not be started" % program
		_set_state(STOPPED)
		return
	api_key = key
	_alive = true
	waited = 0.0
	_set_state(LOADING)


# Said, not killed: `OS.kill` waits, and this runs during play. A server
# still running is stopped when the node leaves, as any started here.
func _give_up(why: String) -> void:
	reason = why
	_set_state(STOPPED)


# Asked of a process this node started, until it is seen to end. Godot
# keeps the exit code of an ended child and answers again from it; only
# after `OS.kill`, which reaps the child itself, does asking print an error.
func _still_running() -> bool:
	if _alive:
		_alive = OS.is_process_running(pid)
	return _alive


func _set_state(next: String) -> void:
	if next == state:
		return
	state = next
	changed.emit(state)
