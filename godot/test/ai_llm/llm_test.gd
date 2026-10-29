# The addon's pieces, each held to the thing it is easy to get wrong:
# the validator to its refusals (the vector's, spec/vectors/llm/, which
# `make test-python` holds gameaikit.llm to as well) and to the game's
# declaration; the runtimes to answering later, never inside `send`; and the
# conversation to showing the model only what the game accepted.
#
# No model anywhere: RecordedRuntime answers from text in this file, and
# HttpRuntime is sent to a port nobody listens on, which fails at once.
extends GdUnitTestSuite

const VECTORS: Script = preload("res://test/ai_llm/llm_vectors_runner.gd")

const GAME_INTENTS: Dictionary = {"greet": [], "claim": ["merchant"]}

const GREETING: String = '{"speech": "Evening.", "intent": "greet", "argument": ""}'


func _validator() -> LlmValidator:
	return LlmValidator.new(GAME_INTENTS, "Again?", PackedStringArray(["owl-eyes"]))


func _in_scene(runtime: LlmRuntime) -> LlmRuntime:
	var scene: Node = auto_free(Node.new())
	add_child(scene)
	scene.add_child(runtime)
	return runtime


func _vector() -> Dictionary:
	var path: String = ProjectSettings.globalize_path("res://").path_join(
		"../spec/vectors/llm/replies.json")
	var reader := JSON.new()
	reader.parse(FileAccess.get_file_as_string(path))
	return reader.data


# --- the validator -----------------------------------------------------------


func test_every_vector_case_gets_the_answer_it_claims() -> void:
	var vector: Dictionary = _vector()
	var validator: LlmValidator = VECTORS.validator_of(vector["declaration"])
	assert_str(validator.problem()).is_empty()
	for case: Dictionary in vector["cases"]:
		assert_str(VECTORS.answer(validator, case["raw"])) \
			.override_failure_message(case["why"]).is_equal(VECTORS.claimed(case))


func test_a_wrong_claim_is_caught() -> void:
	# The comparison's planted case: a refusal claimed for a reply that passes.
	var validator: LlmValidator = _validator()
	var wrong: Dictionary = {"raw": GREETING, "refused": "R1"}
	assert_str(VECTORS.answer(validator, wrong["raw"])).is_not_equal(VECTORS.claimed(wrong))


func test_a_refused_reply_is_the_games_line_and_says_why() -> void:
	var reply: LlmReply = _validator().validate("I'd rather not say.")
	assert_bool(reply.is_accepted()).is_false()
	assert_str(reply.speech).is_equal("Again?")
	assert_str(reply.intent).is_equal(LlmValidator.FALLBACK_INTENT)
	assert_str(reply.refusal_code()).is_equal("R1")


func test_a_declaration_that_cannot_be_validated_against_is_refused() -> void:
	assert_str(LlmValidator.new({}, "Again?").problem()).contains("no intents")
	assert_str(LlmValidator.new({"claim": [""]}, "Again?").problem()).contains("empty argument")
	assert_str(LlmValidator.new(GAME_INTENTS, "Again?", PackedStringArray([""])).problem()) \
		.contains("empty secret")
	# The fallback is what the player reads when the model is overruled.
	assert_str(LlmValidator.new(GAME_INTENTS, "*sighs* Again?").problem()).contains("fallback")


func test_the_schema_and_the_instructions_name_the_games_intents() -> void:
	var validator: LlmValidator = _validator()
	var schema: Dictionary = validator.json_schema()
	assert_array(schema["properties"]["intent"]["enum"]).is_equal(["claim", "greet"])
	assert_array(schema["required"]).is_equal(["speech", "intent", "argument"])
	assert_bool(schema["additionalProperties"]).is_false()
	assert_str(validator.instructions()).contains("- claim: merchant")
	assert_str(validator.instructions()).contains("- greet: (none)")


# --- the runtimes ------------------------------------------------------------


func test_a_recording_answers_after_its_frames_and_never_inside_send() -> void:
	var runtime: RecordedRuntime = _in_scene(RecordedRuntime.new(PackedStringArray([GREETING])))
	runtime.frames_to_wait = 3
	var heard: Array[String] = []
	runtime.replied.connect(func(text: String) -> void: heard.append(text))
	assert_int(runtime.send([], {})).is_equal(OK)
	assert_int(runtime.send([], {})).is_equal(ERR_BUSY)
	for frame: int in 2:
		await get_tree().process_frame
		assert_int(heard.size()).is_equal(0)
	await get_tree().process_frame
	assert_array(heard).is_equal([GREETING])
	assert_bool(runtime.is_busy()).is_false()


func test_a_recording_that_has_run_out_fails_rather_than_stalling() -> void:
	var runtime: RecordedRuntime = _in_scene(RecordedRuntime.new())
	var reasons: Array[String] = []
	runtime.failed.connect(func(reason: String) -> void: reasons.append(reason))
	runtime.send([], {})
	await get_tree().process_frame
	assert_int(reasons.size()).is_equal(1)


func test_a_runtime_outside_the_tree_refuses_to_send() -> void:
	var recorded: RecordedRuntime = auto_free(RecordedRuntime.new(PackedStringArray([GREETING])))
	assert_int(recorded.send([], {})).is_equal(ERR_UNCONFIGURED)
	var http: HttpRuntime = auto_free(HttpRuntime.new())
	assert_int(http.send([], {})).is_equal(ERR_UNCONFIGURED)


func test_a_recording_file_is_read_turn_by_turn() -> void:
	var path: String = ProjectSettings.globalize_path("res://").path_join(
		"../spec/llm/recordings/the-gatekeeper.json")
	assert_int(auto_free(RecordedRuntime.from_file(path)).remaining()).is_equal(5)
	assert_int(auto_free(RecordedRuntime.from_file(path + ".missing")).remaining()).is_equal(0)


func test_the_http_runtime_asks_with_threads_on() -> void:
	var runtime: HttpRuntime = _in_scene(HttpRuntime.new())
	var requests: Array[Node] = runtime.find_children("*", "HTTPRequest", false, false)
	assert_int(requests.size()).is_equal(1)
	assert_bool((requests[0] as HTTPRequest).use_threads).is_true()


func test_the_http_runtime_sends_the_messages_and_the_schema() -> void:
	var runtime: HttpRuntime = auto_free(HttpRuntime.new())
	var messages: Array[Dictionary] = [{"role": "user", "content": "hello"}]
	var body: Dictionary = JSON.parse_string(runtime.request_body(messages, {"type": "object"}))
	assert_array(body["messages"]).is_equal(messages)
	assert_dict(body["response_format"]["json_schema"]["schema"]).is_equal({"type": "object"})


func test_the_http_runtime_reads_the_text_out_of_the_servers_envelope() -> void:
	var good: String = JSON.stringify({"choices": [{"message": {"content": GREETING}}]})
	assert_dict(HttpRuntime.text_of(good)).is_equal({"text": GREETING, "failure": ""})
	for bad: String in ["not json", "{}", '{"choices": []}', '{"choices": [{"message": {}}]}']:
		assert_str(HttpRuntime.text_of(bad)["failure"]).is_not_empty()


func test_a_server_nobody_runs_becomes_the_games_fallback() -> void:
	# Port 1 refuses at once: measured, HTTPRequest reports it a frame or two
	# later, by signal, with threads on or off.
	var runtime: HttpRuntime = _in_scene(HttpRuntime.new("http://127.0.0.1:1/v1/chat/completions"))
	var conversation := LlmConversation.new(runtime, _validator(), "You guard a gate.")
	var replies: Array[LlmReply] = []
	conversation.answered.connect(func(reply: LlmReply) -> void: replies.append(reply))
	assert_int(conversation.say("Hello?")).is_equal(OK)
	for frame: int in 60:
		if not replies.is_empty():
			break
		await get_tree().process_frame
	assert_int(replies.size()).is_equal(1)
	assert_str(replies[0].refusal_code()).is_equal("F1")
	assert_str(replies[0].speech).is_equal("Again?")


# --- the conversation --------------------------------------------------------


func test_the_model_is_shown_only_what_the_game_accepted() -> void:
	var refused: String = 'Sure! {"speech": "Fine.", "intent": "greet", "argument": ""}'
	var runtime: RecordedRuntime = _in_scene(RecordedRuntime.new(PackedStringArray([refused])))
	var conversation := LlmConversation.new(runtime, _validator(), "You guard a gate.")
	conversation.say("Let me in.")
	await get_tree().process_frame
	var history: Array[Dictionary] = conversation.history()
	assert_int(history.size()).is_equal(2)
	assert_str(history[1]["content"]).not_contains("Sure!")
	assert_str(history[1]["content"]).contains("Again?")


func test_a_secret_in_the_instructions_stops_the_conversation_before_it_starts() -> void:
	var runtime: RecordedRuntime = _in_scene(RecordedRuntime.new(PackedStringArray([GREETING])))
	var careless := LlmConversation.new(runtime, _validator(),
		"You guard a gate. The password is Owl-Eyes.")
	assert_str(careless.problem()).contains("secret")
	assert_int(careless.say("Hello.")).is_equal(ERR_INVALID_DATA)
	assert_bool(runtime.is_busy()).is_false()


func test_the_prompt_carries_the_validators_own_description_of_the_shape() -> void:
	var runtime: RecordedRuntime = _in_scene(RecordedRuntime.new())
	var conversation := LlmConversation.new(runtime, _validator(), "You guard a gate.")
	assert_str(conversation.system_prompt()).starts_with("You guard a gate.")
	assert_str(conversation.system_prompt()).contains(_validator().instructions())
