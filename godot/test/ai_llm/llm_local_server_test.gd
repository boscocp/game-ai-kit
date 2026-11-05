# LlmLocalServer (T130): started when nothing answers, left alone when
# something does, stopped on leaving only when it was started here, and
# `BY_HAND` when there is nothing to start. The server is
# `fake_llm_server.py`, which answers `/health` as llama.cpp's does and
# loads no model; each test has a port of its own, away from the real one.
extends GdUnitTestSuite

const FAKE: String = "res://test/ai_llm/fake_llm_server.py"
## Seconds a test waits for a state before it fails.
const PATIENCE: float = 10.0


func _fake() -> String:
	return ProjectSettings.globalize_path(FAKE)


# A server on `port` that starts the fake, ready `loading` seconds after.
func _server(port: int, loading: String = "0.5") -> LlmLocalServer:
	var server: LlmLocalServer = LlmLocalServer.new(_fake(), PackedStringArray([str(port), loading]), port)
	add_child(server)
	return server


# Frames pass until `server` is in `wanted`, or PATIENCE runs out.
func _until(server: LlmLocalServer, wanted: String) -> void:
	var started: int = Time.get_ticks_msec()
	while server.state != wanted and Time.get_ticks_msec() - started < PATIENCE * 1000.0:
		await get_tree().process_frame


# Whether a server answers on `port`, asked by a node with nothing to start.
func _answers(port: int) -> bool:
	var asker: LlmLocalServer = auto_free(LlmLocalServer.new("", PackedStringArray(), port))
	add_child(asker)
	asker.begin()
	var started: int = Time.get_ticks_msec()
	while asker.state == LlmLocalServer.CHECKING and Time.get_ticks_msec() - started < PATIENCE * 1000.0:
		await get_tree().process_frame
	return asker.state in [LlmLocalServer.LOADING, LlmLocalServer.READY]


func test_nothing_answers_so_it_starts_the_program_and_waits_for_it() -> void:
	var server: LlmLocalServer = _server(39941)
	var seen: Array[String] = []
	server.changed.connect(func(state: String) -> void: seen.append(state))
	assert_int(server.begin()).is_equal(OK)
	await _until(server, LlmLocalServer.READY)
	assert_str(server.state).is_equal(LlmLocalServer.READY)
	assert_bool(server.started_here()).is_true()
	assert_array(seen).contains_exactly([LlmLocalServer.CHECKING, LlmLocalServer.LOADING, LlmLocalServer.READY])
	assert_float(server.waited).is_greater(0.4)
	assert_bool(await _answers(39941)).is_true()
	server.free()
	assert_bool(await _answers(39941)).is_false()


func test_a_server_already_answering_is_used_and_never_stopped() -> void:
	var first: LlmLocalServer = _server(39942)
	first.begin()
	await _until(first, LlmLocalServer.READY)
	var second: LlmLocalServer = _server(39942)
	second.begin()
	await _until(second, LlmLocalServer.READY)
	assert_str(second.state).is_equal(LlmLocalServer.READY)
	assert_bool(second.started_here()).is_false()
	assert_int(second.pid).is_equal(-1)
	second.free()
	assert_bool(await _answers(39942)).is_true()
	first.free()
	assert_bool(await _answers(39942)).is_false()


func test_a_server_still_loading_when_found_is_waited_for_not_started() -> void:
	var first: LlmLocalServer = _server(39943, "1.5")
	first.begin()
	await _until(first, LlmLocalServer.LOADING)
	await get_tree().create_timer(0.3).timeout
	var second: LlmLocalServer = _server(39943)
	second.begin()
	await _until(second, LlmLocalServer.LOADING)
	assert_bool(second.started_here()).is_false()
	await _until(second, LlmLocalServer.READY)
	assert_str(second.state).is_equal(LlmLocalServer.READY)
	second.free()
	first.free()


func test_with_nothing_to_start_it_says_by_hand() -> void:
	var server: LlmLocalServer = auto_free(LlmLocalServer.new("", PackedStringArray(), 39944))
	add_child(server)
	server.begin()
	await _until(server, LlmLocalServer.BY_HAND)
	assert_str(server.state).is_equal(LlmLocalServer.BY_HAND)
	assert_bool(server.started_here()).is_false()


func test_a_program_that_exits_while_loading_is_said_to_have_stopped() -> void:
	var server: LlmLocalServer = auto_free(_server(39945, "exit"))
	server.begin()
	await _until(server, LlmLocalServer.STOPPED)
	assert_str(server.state).is_equal(LlmLocalServer.STOPPED)
	assert_str(server.reason).contains("exited with code 2")


func test_before_the_tree_there_is_nothing_to_ask_with() -> void:
	var server: LlmLocalServer = auto_free(LlmLocalServer.new("", PackedStringArray(), 39946))
	assert_int(server.begin()).is_equal(ERR_UNCONFIGURED)
