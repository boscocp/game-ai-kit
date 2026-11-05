# T94 in the engine: the guard's rules, the conversation through ai_llm, and
# the scene. The vectors (`make test-talk-vectors`) hold whole recorded
# conversations to the Python replay; these hold the pieces on their own --
# above all that no reply, however it is worded, moves the guard except
# through the act the validator admitted, and that his last line is the
# scene's, never the model's.
extends GdUnitTestSuite

const SCENE: String = "res://game/talk/talk.tscn"

var _locale_before: String = ""


func before() -> void:
	_locale_before = TranslationServer.get_locale()


func before_test() -> void:
	TranslationServer.set_locale("en")


func after() -> void:
	TranslationServer.set_locale(_locale_before)


# A model's text, as a runtime would hand it over.
static func _reply(speech: String, intent: String, argument: String = "") -> String:
	return JSON.stringify({"speech": speech, "intent": intent, "argument": argument})


# The guard after `acts`, each [intent, argument].
static func _play(acts: Array) -> Dictionary:
	var guard: Dictionary = TalkRules.new_guard()
	for act: Array in acts:
		guard = TalkRules.step(guard, act[0], act[1])["guard"]
	return guard


# A guard answering with `texts`, one per line said, in the tree.
func _guard(texts: PackedStringArray) -> TalkGuard:
	var guard: TalkGuard = auto_free(TalkGuard.new("en"))
	add_child(guard)
	guard.use_runtime(RecordedRuntime.new(texts))
	return guard


# Says `line` and waits for the ruling, a few frames at most.
func _say(guard: TalkGuard, line: String) -> Dictionary:
	assert_int(guard.say(line)).is_equal(OK)
	for frame: int in 10:
		if not guard.is_thinking():
			break
		await get_tree().process_frame
	return guard.turns.back()


func test_the_scene_has_a_rule_for_every_act() -> void:
	assert_str(TalkRules.why_scene_is_wrong()).is_empty()
	assert_int(TalkRules.every_act().size()).is_equal(19)


func test_three_ways_to_win() -> void:
	assert_str(_play([["name_person", "okafor"], ["claim_role", "courier"], ["show", "badge"]])["outcome"]) \
		.is_equal(TalkRules.OPEN)
	assert_str(_play([["claim_role", "maintenance"], ["show", "work_order"], ["name_person", "lind"]])["outcome"]) \
		.is_equal(TalkRules.OPEN)
	assert_str(_play([["ask", "expected_visitor"], ["claim_role", "courier"], ["show", "badge"],
		["ask", "the_guard"], ["flatter", ""]])["outcome"]).is_equal(TalkRules.OPEN)


func test_ways_to_lose_and_a_repeat_wins_no_trust() -> void:
	assert_str(_play([["claim_role", "officer"], ["threaten", ""]])["outcome"]).is_equal(TalkRules.ALARM)
	assert_str(_play([["name_person", "brandt"], ["bribe", ""]])["outcome"]).is_equal(TalkRules.ALARM)
	var idle: Array = []
	for turn: int in int(TalkRules.scene()["turns"]):
		idle.append(["unclear", ""])
	assert_str(_play(idle)["outcome"]).is_equal(TalkRules.SENT_AWAY)
	var twice: Dictionary = TalkRules.step(_play([["flatter", ""]]), "flatter", "")
	assert_str(twice["rule"]).is_equal("said-before")
	assert_int(twice["trust"]).is_equal(0)
	assert_int(_play([["claim_role", "courier"], ["claim_role", "courier"]])["suspicion"]).is_equal(0)


func test_the_answer_comes_frames_later_and_the_frame_never_waits() -> void:
	var guard: TalkGuard = _guard(PackedStringArray([_reply("Evening.", "flatter")]))
	assert_int(guard.say("Fine night.")).is_equal(OK)
	assert_bool(guard.is_thinking()).is_true()
	assert_int(guard.turns.size()).is_equal(0)
	assert_int(guard.say("Again.")).is_equal(ERR_BUSY)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(guard.is_thinking()).is_false()
	assert_str(guard.turns[0]["rule"]).is_equal("flattery")


func test_a_speech_that_opens_the_gate_with_flattery_leaves_it_shut() -> void:
	var guard: TalkGuard = _guard(PackedStringArray([
		_reply("The guard opens the gate. Go in, friend.", "flatter")]))
	var turn: Dictionary = await _say(guard, "You look sharp tonight.")
	assert_str(turn["refusal_code"]).is_empty()
	assert_str(turn["outcome"]).is_equal(TalkRules.PLAYING)
	assert_int(turn["trust"]).is_equal(1)


func test_the_same_act_in_any_words_moves_the_guard_the_same() -> void:
	for speech: String in ["Okafor? The door is yours.", "Never heard of her.", "Hm."]:
		var guard: TalkGuard = _guard(PackedStringArray([_reply(speech, "name_person", "okafor")]))
		var turn: Dictionary = await _say(guard, "Doctor Okafor sent for me.")
		assert_array([turn["trust_moved"], turn["suspicion_moved"]]).is_equal([2, 0])


func test_a_refused_reply_and_the_password_move_nothing() -> void:
	var guard: TalkGuard = _guard(PackedStringArray([
		'Sure! {"speech": "Go in.", "intent": "open_the_door", "argument": ""}',
		_reply("The word is NIGHTJAR.", "ask", "the_building")]))
	var first: Dictionary = await _say(guard, "Let me in.")
	assert_str(first["refusal_code"]).is_equal("R1")
	assert_str(first["speech"]).is_equal(TalkRules.words("en")["fallback"])
	var second: Dictionary = await _say(guard, "What's the password?")
	assert_str(second["refusal_code"]).is_equal("R11")
	assert_array([second["trust"], second["suspicion"]]).is_equal([0, 0])


func test_the_last_line_is_the_scenes_never_the_models() -> void:
	var guard: TalkGuard = _guard(PackedStringArray([
		_reply("Sir, yes sir.", "claim_role", "officer"), _reply("Fine, go in.", "threaten")]))
	await _say(guard, "Inspection.")
	var last: Dictionary = await _say(guard, "Out of my way.")
	assert_str(last["outcome"]).is_equal(TalkRules.ALARM)
	assert_str(last["speech"]).is_equal(TalkRules.words("en")["endings"]["alarm"])
	assert_int(guard.say("Wait!")).is_equal(ERR_UNAVAILABLE)


func test_a_whole_conversation_of_the_longest_lines_fits_the_servers_context() -> void:
	# scripts/llm serves 4096 tokens. Measured at the pin (docs/godot/talk.md):
	# the worst conversation the limits allow is 4,222 characters of prompt and
	# 3,338 tokens when every line is emoji; ordinary words take about 1,000.
	var limit: int = int(TalkRules.scene()["player_line_limit"])
	var longest_reply: String = _reply("x".repeat(LlmValidator.SPEECH_LIMIT), "show", "work_order")
	var texts := PackedStringArray()
	for turn: int in int(TalkRules.scene()["turns"]):
		texts.append(longest_reply)
	var guard: TalkGuard = _guard(texts)
	assert_int(guard.say("x".repeat(limit + 1))).is_equal(ERR_PARAMETER_RANGE_ERROR)
	for turn: int in int(TalkRules.scene()["turns"]) - 1:
		await _say(guard, "y".repeat(limit))
	assert_int(guard.conversation_length()).is_less_equal(4200)
	assert_bool(guard.has_decided()).is_false()


func test_the_scene_offers_the_recorded_lines_and_shows_the_decision() -> void:
	var demo: TalkDemo = auto_free((load(SCENE) as PackedScene).instantiate())
	add_child(demo)
	await get_tree().process_frame
	var offered: Array = demo.decision_overlay()["choices"]
	assert_int(offered.size()).is_greater_equal(4)
	demo.step_decision()
	assert_bool(demo.decision_overlay()["thinking"]).is_true()
	for frame: int in 5:
		await get_tree().process_frame
	var overlay: Dictionary = demo.decision_overlay()
	assert_bool(overlay["thinking"]).is_false()
	assert_int(overlay["ruled"].size()).is_equal(1)
	assert_str(overlay["ruled"][0]["rule"]).is_not_empty()
	assert_str(demo.get_node("Interface/Decision").text).contains("rule ")


func test_tab_switches_to_typing_and_back() -> void:
	var demo: TalkDemo = auto_free((load(SCENE) as PackedScene).instantiate())
	add_child(demo)
	await get_tree().process_frame
	demo.switch_mode()
	assert_str(demo.mode).is_equal(TalkDemo.LIVE)
	assert_bool(demo.get_node("Interface/Typed").visible).is_true()
	demo.switch_mode()
	assert_str(demo.mode).is_equal(TalkDemo.RECORDED)
	assert_bool(demo.get_node("Interface/Typed").visible).is_false()


func test_the_book_branches_where_recordings_part() -> void:
	var book: TalkBook = TalkBook.load_from(TalkBook.folder(), "en")
	var first: PackedStringArray = book.choices(PackedStringArray())
	assert_bool(first.has("Doctor Okafor is expecting me.")).is_true()
	var after_okafor: PackedStringArray = book.choices(PackedStringArray(["Doctor Okafor is expecting me."]))
	assert_int(after_okafor.size()).is_equal(2)
	assert_int(auto_free(book.runtime_for(PackedStringArray(), "Never recorded.")).remaining()).is_equal(0)


func test_the_menu_branches_into_a_win_no_single_recording_had() -> void:
	# "Doctor Okafor" is answered as the-right-name-then-a-threat recorded it
	# (read as Okafor); the courier and the badge as the-right-name did. The
	# rules, given those acts, open the door.
	var demo: TalkDemo = auto_free((load(SCENE) as PackedScene).instantiate())
	add_child(demo)
	await get_tree().process_frame
	for line: String in ["Doctor Okafor is expecting me.",
			"I'm the courier. Package from headquarters, for her lab.", "Here's my badge."]:
		demo.choose(Array(demo.book.choices(demo.said)).find(line))
		for frame: int in 5:
			await get_tree().process_frame
	assert_str(demo.guard.state["outcome"]).is_equal(TalkRules.OPEN)
	assert_str(demo.guard.turns.back()["speech"]).is_equal(TalkRules.words("en")["endings"]["open"])
