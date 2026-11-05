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


func test_leaving_while_the_model_loads_stops_the_server() -> void:
	var server: LlmLocalServer = _server(39947, "30")
	server.begin()
	await _until(server, LlmLocalServer.LOADING)
	await get_tree().create_timer(0.5).timeout
	assert_bool(await _answers(39947)).is_true()
	server.free()
	assert_bool(await _answers(39947)).is_false()


func test_a_found_server_that_went_away_is_started_again_on_begin() -> void:
	var first: LlmLocalServer = _server(39948)
	first.begin()
	await _until(first, LlmLocalServer.READY)
	var second: LlmLocalServer = _server(39948)
	second.begin()
	await _until(second, LlmLocalServer.READY)
	assert_bool(second.started_here()).is_false()
	first.free()
	assert_int(second.begin()).is_equal(OK)
	assert_str(second.state).is_equal(LlmLocalServer.CHECKING)
	await _until(second, LlmLocalServer.READY)
	assert_str(second.state).is_equal(LlmLocalServer.READY)
	assert_bool(second.started_here()).is_true()
	second.free()


func test_a_found_server_that_dies_while_loading_is_said_to_have_stopped() -> void:
	var first: LlmLocalServer = _server(39949, "30")
	first.begin()
	await _until(first, LlmLocalServer.LOADING)
	await get_tree().create_timer(0.5).timeout
	var second: LlmLocalServer = auto_free(_server(39949))
	second.begin()
	await _until(second, LlmLocalServer.LOADING)
	assert_bool(second.started_here()).is_false()
	first.free()
	await _until(second, LlmLocalServer.STOPPED)
	assert_str(second.state).is_equal(LlmLocalServer.STOPPED)
	assert_str(second.reason).contains("stopped answering")


func test_a_load_past_its_limit_is_said_not_killed_during_play() -> void:
	var server: LlmLocalServer = _server(39950, "30")
	server.load_seconds = 0.5
	server.begin()
	await _until(server, LlmLocalServer.STOPPED)
	assert_str(server.state).is_equal(LlmLocalServer.STOPPED)
	assert_str(server.reason).contains("did not load")
	assert_bool(await _answers(39950)).is_true()
	server.free()
	assert_bool(await _answers(39950)).is_false()


# What a conversation through HttpRuntime gets from the server on `port`,
# sending `key`: the refusal code of its one answer ("" for a reply).
func _code_of_a_turn(port: int, key: String) -> String:
	var runtime: HttpRuntime = HttpRuntime.new("http://127.0.0.1:%d/v1/chat/completions" % port)
	runtime.api_key = key
	add_child(runtime)
	var conversation := LlmConversation.new(runtime, LlmValidator.new({"greet": []}, "Again?"), "A guard.")
	var answers: Array[LlmReply] = []
	conversation.answered.connect(func(reply: LlmReply) -> void: answers.append(reply))
	conversation.say("Hello there.")
	var started: int = Time.get_ticks_msec()
	while answers.is_empty() and Time.get_ticks_msec() - started < PATIENCE * 1000.0:
		await get_tree().process_frame
	runtime.free()
	return answers[0].refusal_code() if not answers.is_empty() else "none"


func test_a_server_started_here_asks_for_a_key_made_for_it() -> void:
	var server: LlmLocalServer = _server(39951, "0.2")
	server.begin()
	await _until(server, LlmLocalServer.READY)
	assert_int(server.api_key.length()).is_equal(32)
	assert_str(await _code_of_a_turn(39951, server.api_key)).is_equal("")
	assert_str(await _code_of_a_turn(39951, "")).is_equal("F2")
	assert_str(await _code_of_a_turn(39951, "not-the-key")).is_equal("F2")
	var found: LlmLocalServer = auto_free(_server(39951))
	found.begin()
	await _until(found, LlmLocalServer.READY)
	assert_str(found.api_key).is_empty()
	server.free()
