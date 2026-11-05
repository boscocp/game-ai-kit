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

# HTTPRequest.RESULT_SUCCESS, written as its value: the gate (V1) keeps the
# class out of every script outside the addon but the frame probe.
const SUCCESS: int = 0

const GREETING: String = '{"speech": "Evening.", "intent": "greet", "argument": ""}'


func _validator() -> LlmValidator:
	return LlmValidator.new(GAME_INTENTS, "Again?", PackedStringArray(["owl-eyes"]))


func _in_scene(runtime: GakLlmRuntime) -> GakLlmRuntime:
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


func test_a_ruling_cannot_be_changed_after_it() -> void:
	# A game that wrote `intent = "open"` on a refused reply would decide what
	# the model is not allowed to: the fields refuse, and keep the ruling.
	var reply: LlmReply = _validator().validate("I'd rather not say.")
	await assert_error(func() -> void: reply.intent = "open").is_push_error(any_string())
	await assert_error(func() -> void: reply.refusal = "").is_push_error(any_string())
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
	var shapes: Array = validator.json_schema()["anyOf"]
	assert_array(shapes.map(func(shape: Dictionary) -> Array:
		return shape["properties"]["intent"]["enum"])).is_equal([["claim"], ["greet"]])
	# One shape per intent, offering only its own arguments: what took R7
	# out of the pinned server's replies (T94, docs/godot/talk.md).
	assert_array(shapes.map(func(shape: Dictionary) -> Array:
		return shape["properties"]["argument"]["enum"])).is_equal([["merchant", ""], [""]])
	for shape: Dictionary in shapes:
		assert_array(shape["required"]).is_equal(["speech", "intent", "argument"])
		assert_bool(shape["additionalProperties"]).is_false()
	assert_str(validator.instructions()).contains("- claim: merchant")
	assert_str(validator.instructions()).contains("- greet: (none)")


# --- the runtimes ------------------------------------------------------------


# Every reply a conversation hands over, in order. Listened to here, never
# on the runtime's `replied`: that is the text no validator saw, and the gate
# (V2) refuses a listener to it outside the addon -- tests included.
func _replies_of(conversation: LlmConversation) -> Array[LlmReply]:
	var replies: Array[LlmReply] = []
	conversation.answered.connect(func(reply: LlmReply) -> void: replies.append(reply))
	return replies


func test_a_recording_answers_after_its_frames_and_never_inside_send() -> void:
	var runtime: RecordedRuntime = _in_scene(RecordedRuntime.new(PackedStringArray([GREETING])))
	runtime.frames_to_wait = 3
	var conversation := LlmConversation.new(runtime, _validator(), "You guard a gate.")
	var replies: Array[LlmReply] = _replies_of(conversation)
	assert_int(conversation.say("Hello.")).is_equal(OK)
	assert_int(runtime.send([], {})).is_equal(ERR_BUSY)
	for frame: int in 2:
		await get_tree().process_frame
		assert_int(replies.size()).is_equal(0)
	await get_tree().process_frame
	assert_int(replies.size()).is_equal(1)
	assert_str(replies[0].speech).is_equal("Evening.")
	assert_bool(runtime.is_busy()).is_false()


func test_a_recording_taken_out_of_the_tree_mid_answer_still_answers() -> void:
	# Measured by the review: without this, the conversation thought forever
	# and every later `say` was ERR_BUSY.
	var runtime: RecordedRuntime = _in_scene(RecordedRuntime.new(PackedStringArray([GREETING])))
	var parent: Node = runtime.get_parent()
	var conversation := LlmConversation.new(runtime, _validator(), "You guard a gate.")
	var replies: Array[LlmReply] = _replies_of(conversation)
	conversation.say("Hello.")
	parent.remove_child(runtime)
	for frame: int in 3:
		await get_tree().process_frame
	parent.add_child(runtime)
	assert_bool(conversation.is_thinking()).is_false()
	assert_int(replies.size()).is_equal(1)
	assert_str(replies[0].refusal_code()).is_equal("F1")
	assert_int(conversation.say("Hello again.")).is_equal(OK)


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
	assert_int(runtime.get_child_count()).is_equal(1)
	var request: Node = runtime.get_child(0)
	assert_str(request.get_class()).is_equal("HTTPRequest")
	assert_bool(request.get("use_threads")).is_true()
	assert_int(request.get("body_size_limit")).is_equal(HttpRuntime.BODY_SIZE_LIMIT)


func test_an_http_runtime_taken_out_of_the_tree_mid_request_still_answers() -> void:
	# Nobody answers at this address: the request would wait for its timeout.
	var runtime: HttpRuntime = _in_scene(HttpRuntime.new("http://10.255.255.1/v1/chat/completions"))
	var parent: Node = runtime.get_parent()
	var conversation := LlmConversation.new(runtime, _validator(), "You guard a gate.")
	var replies: Array[LlmReply] = _replies_of(conversation)
	assert_int(conversation.say("Hello?")).is_equal(OK)
	parent.remove_child(runtime)
	await get_tree().process_frame
	parent.add_child(runtime)
	assert_bool(conversation.is_thinking()).is_false()
	assert_int(replies.size()).is_equal(1)
	assert_str(replies[0].refusal_code()).is_equal("F1")


func test_the_http_runtime_sends_the_messages_and_the_schema() -> void:
	var runtime: HttpRuntime = auto_free(HttpRuntime.new())
	var messages: Array[Dictionary] = [{"role": "user", "content": "hello"}]
	var body: Dictionary = JSON.parse_string(runtime.request_body(messages, {"type": "object"}))
	assert_array(body["messages"]).is_equal(messages)
	assert_dict(body["response_format"]["json_schema"]["schema"]).is_equal({"type": "object"})


func test_the_http_runtime_reads_the_text_out_of_the_servers_envelope() -> void:
	# Through the conversation, as a game would meet it: the server's answer
	# handed to the runtime as `request_completed` would hand it.
	var runtime: HttpRuntime = _in_scene(HttpRuntime.new())
	var conversation := LlmConversation.new(runtime, _validator(), "You guard a gate.")
	var replies: Array[LlmReply] = _replies_of(conversation)
	var good: String = JSON.stringify({"choices": [{"message": {"content": GREETING}}]})
	var bodies: Array[String] = [good, "not json", "{}", '{"choices": []}',
		'{"choices": [{"message": {}}]}']
	for body: String in bodies:
		runtime._on_request_completed(SUCCESS, 200, PackedStringArray(),
			body.to_utf8_buffer())
	runtime._on_request_completed(SUCCESS, 400, PackedStringArray(),
		good.to_utf8_buffer())
	assert_int(replies.size()).is_equal(6)
	assert_str(replies[0].speech).is_equal("Evening.")
	for index: int in range(1, 5):
		assert_str(replies[index].refusal_code()).is_equal("F1")
	# A 400 is the request refused, whatever its body says: never the reply.
	assert_str(replies[5].refusal_code()).is_equal("F2")
	assert_str(replies[5].refusal).contains("the server gave no reason")


func test_the_server_refusing_the_request_is_told_apart_from_the_reply_refused() -> void:
	# What the pinned llama.cpp server answered (spec/llm/server-answers.json),
	# handed over as request_completed would, with no server running. Before
	# T93 a 400 and a 500 both became F1: a server refusing every request
	# turned every turn into "no reply came", and nothing said why.
	var path: String = ProjectSettings.globalize_path("res://").path_join(
		"../spec/llm/server-answers.json")
	var recorded: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))["answers"]
	var runtime: HttpRuntime = _in_scene(HttpRuntime.new())
	var conversation := LlmConversation.new(runtime, _validator(), "You guard a gate.")
	var replies: Array[LlmReply] = _replies_of(conversation)
	for name: String in recorded:
		var answer: Dictionary = recorded[name]
		runtime._on_request_completed(SUCCESS, int(answer["status"]), PackedStringArray(),
			(answer["body"] as String).to_utf8_buffer())
		assert_str(replies.back().refusal_code()).override_failure_message(name) \
			.is_equal(answer["code"])
		assert_str(replies.back().intent).is_equal("unclear")
	assert_int(replies.size()).is_equal(recorded.size())
	# The server's own reason reaches the game, on one short line.
	assert_str(replies[0].refusal).contains("HTTP 400").contains("but got: bogus")
	assert_str(replies[1].refusal).contains("HTTP 500").contains("cannot resolve $ref")
	assert_str(replies[2].refusal).contains("Loading model")


func test_the_servers_reason_is_cleaned_before_a_game_can_show_it() -> void:
	# The server's words reach `refusal`, which a game shows, and no
	# validator read them (T93's review): line breaks and control characters
	# become spaces, markup is dropped, and the sentence is cut.
	var runtime: HttpRuntime = _in_scene(HttpRuntime.new())
	var conversation := LlmConversation.new(runtime, _validator(), "You guard a gate.")
	var replies: Array[LlmReply] = _replies_of(conversation)
	var message: String = "first line\nsecond\tline [b]bold[/b] <i>*x*</i> `code`\u0007end"
	var long_message: String = "y".repeat(HttpRuntime.ERROR_LENGTH + 50)
	for text: String in [message, long_message]:
		var body: String = JSON.stringify({"error": {"code": 500, "message": text}})
		runtime._on_request_completed(SUCCESS, 500, PackedStringArray(), body.to_utf8_buffer())
	var shown: String = replies[0].refusal.get_slice("HTTP 500: ", 1)
	assert_str(shown).is_equal("first line second line bbold/b ix/i code end")
	assert_str(replies[0].refusal_code()).is_equal("F2")
	assert_int(replies[1].refusal.get_slice("HTTP 500: ", 1).length()).is_equal(HttpRuntime.ERROR_LENGTH)


func test_the_http_runtime_asks_on_the_one_port() -> void:
	var runtime: HttpRuntime = auto_free(HttpRuntime.new())
	assert_str(runtime.url).is_equal("http://127.0.0.1:%d/v1/chat/completions" % HttpRuntime.PORT)


func test_the_schema_goes_in_the_form_the_pinned_server_honours() -> void:
	# Measured at b11960 (docs/local-llm/server.md): the schema nested under
	# `json_schema` is honoured; the README's form, `schema` beside `type`,
	# is read as "any object" and the schema silently dropped.
	var runtime: HttpRuntime = auto_free(HttpRuntime.new())
	var messages: Array[Dictionary] = [{"role": "user", "content": "hello"}]
	var body: Dictionary = JSON.parse_string(runtime.request_body(messages, {"type": "object"}))
	assert_str(body["response_format"]["type"]).is_equal("json_schema")
	assert_bool((body["response_format"] as Dictionary).has("schema")).is_false()
	assert_dict(body["response_format"]["json_schema"]["schema"]).is_equal({"type": "object"})


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
