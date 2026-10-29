# Measures the worst frame while an HTTPRequest is in flight, threads on and off.
#
# Not a test: a measurement, rerun when the engine is bumped, whose numbers
# are written down in docs/godot/llm-requests.md. Start the stub first -- it
# answers like a local LLM server, after a delay, with no model behind it:
#
#     PYTHONPATH=python python3 -m gameaikit.llm.stub_server --port 8765 --delay 0.5 &
#     ./scripts/godot --headless --path godot -s res://test/ai_llm/http_frame_probe.gd -- 8765
#
# For each case it prints how long `request()` itself took, the worst frame
# and the median, in milliseconds, and the result `request_completed` handed over. The baseline case sends
# nothing, so the frames it reports are what the loop costs on its own.
extends SceneTree

const ROUNDS: int = 3

var _cases: Array[Dictionary] = []
var _current: int = -1
var _round: int = 0
var _request: HTTPRequest = null
var _frames: PackedFloat64Array = PackedFloat64Array()
var _last_ticks: int = 0
var _started_ticks: int = 0
var _finished: bool = false
var _result: int = -1
# How long `request()` itself took: a stall shorter than a frame would be
# absorbed by the frame's own wait, so the call is timed on its own as well.
var _request_call_ms: float = 0.0


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var port: String = arguments[0] if not arguments.is_empty() else "8765"
	var stub: String = "http://127.0.0.1:%s/v1/chat/completions" % port
	_cases = [
		{"name": "baseline, nothing sent", "url": "", "threads": false},
		{"name": "stub, threads off", "url": stub, "threads": false},
		{"name": "stub, threads on", "url": stub, "threads": true},
		{"name": "closed port, threads off", "url": "http://127.0.0.1:1/", "threads": false},
		{"name": "closed port, threads on", "url": "http://127.0.0.1:1/", "threads": true},
		{"name": "nobody answers, threads off", "url": "http://10.255.255.1/", "threads": false},
		{"name": "nobody answers, threads on", "url": "http://10.255.255.1/", "threads": true},
		{"name": "a name to resolve, threads off", "url": "http://llm.invalid/", "threads": false},
		{"name": "a name to resolve, threads on", "url": "http://llm.invalid/", "threads": true},
	]
	_next_case()


func _process(_delta: float) -> bool:
	var now: int = Time.get_ticks_usec()
	_frames.append((now - _last_ticks) / 1000.0)
	_last_ticks = now
	var waited: float = (now - _started_ticks) / 1000000.0
	var done: bool = _finished or (_cases[_current]["url"] == "" and waited > 1.0)
	if done:
		_report()
		_round += 1
		if _round >= ROUNDS:
			_round = 0
			_current += 1
		if _current >= _cases.size():
			quit(0)
			return true
		_start(_cases[_current])
	return false


func _next_case() -> void:
	_current += 1
	_start(_cases[_current])


func _start(case: Dictionary) -> void:
	if _request != null:
		_request.queue_free()
	_frames = PackedFloat64Array()
	_finished = false
	_result = -1
	_request_call_ms = 0.0
	_started_ticks = Time.get_ticks_usec()
	_last_ticks = _started_ticks
	if case["url"] == "":
		return
	_request = HTTPRequest.new()
	_request.use_threads = case["threads"]
	_request.timeout = 2.0
	root.add_child(_request)
	_request.request_completed.connect(_on_completed)
	var body: String = JSON.stringify({"messages": [{"role": "user", "content": "hello"}]})
	var before: int = Time.get_ticks_usec()
	var sent: Error = _request.request(case["url"],
		PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, body)
	_request_call_ms = (Time.get_ticks_usec() - before) / 1000.0
	if sent != OK:
		print("%s: request() returned %s" % [case["name"], error_string(sent)])
		_finished = true


func _on_completed(result: int, _code: int, _headers: PackedStringArray,
		_body: PackedByteArray) -> void:
	_result = result
	_finished = true


func _report() -> void:
	var sorted: PackedFloat64Array = _frames.duplicate()
	sorted.sort()
	var worst: float = sorted[sorted.size() - 1] if not sorted.is_empty() else 0.0
	var median: float = sorted[sorted.size() / 2] if not sorted.is_empty() else 0.0
	print("%-30s round %d: request() %6.3f ms, %4d frames, worst %7.3f ms, median %6.3f ms, result %d" % [
		_cases[_current]["name"], _round + 1, _request_call_ms, sorted.size(), worst, median, _result,
	])
