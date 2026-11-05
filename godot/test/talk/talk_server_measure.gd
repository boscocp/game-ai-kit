# How long Tab into live mode takes to load the real model, and whether the
# frame stalls meanwhile (T130): the talk scene, its server program set as
# a checkout's (`scripts/llm serve`, the real model), Tab, and every frame
# timed until the server is ready; then the scene freed, timing the frame
# that stops the server. Needs `make llm-bootstrap` and nothing on
# HttpRuntime.PORT. A table for docs/godot/talk.md, not a gate.
#
#     ./scripts/godot --path godot -s res://test/talk/talk_server_measure.gd
#
# Exit codes: 0 measured, 1 the server was not started here or never ready.
extends SceneTree

const SCENE: String = "res://game/talk/talk.tscn"
## Seconds before the run gives up on the model loading.
const PATIENCE: float = 200.0

var _demo: TalkDemo = null
var _pressed: int = 0
var _last_tick: int = 0
var _longest: int = 0
var _frames: int = 0
## The three longest frames, as [microseconds, microseconds after Tab].
var _worst: Array[Array] = []


func _initialize() -> void:
	_demo = load(SCENE).instantiate()
	_demo.server_program = TalkDemo.server_program_for(true, ProjectSettings.globalize_path("res://"))
	root.add_child(_demo)


func _process(_delta: float) -> bool:
	var now: int = Time.get_ticks_usec()
	if _pressed == 0:
		_pressed = now
		_last_tick = now
		_demo.switch_mode()
		return false
	_longest = maxi(_longest, now - _last_tick)
	_worst.append([now - _last_tick, now - _pressed])
	_worst.sort_custom(func(one: Array, other: Array) -> bool: return one[0] > other[0])
	_worst.resize(mini(_worst.size(), 3))
	_last_tick = now
	_frames += 1
	var server: LlmLocalServer = _demo.server
	if server.is_ready() or server.state in [LlmLocalServer.STOPPED, LlmLocalServer.BY_HAND] \
			or now - _pressed > PATIENCE * 1000000.0:
		_finish(server, now)
		return true
	return false


func _finish(server: LlmLocalServer, now: int) -> void:
	var ours: bool = server.started_here()
	var ready: bool = server.is_ready()
	print("state %s, started here %s" % [server.state, ours])
	print("Tab to ready: %.2f s over %d frames; longest frame %.1f ms"
		% [(now - _pressed) / 1000000.0, _frames, _longest / 1000.0])
	for frame: Array in _worst:
		print("  a frame of %.1f ms, ending %.2f s after Tab" % [frame[0] / 1000.0, frame[1] / 1000000.0])
	var stopping: int = Time.get_ticks_usec()
	_demo.free()
	print("freeing the scene, which stops the server: %.1f ms" % ((Time.get_ticks_usec() - stopping) / 1000.0))
	quit(0 if ours and ready else 1)
