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
	# 15 acts with their arguments, and each of the 8 intents alone: the
	# validator lets an empty argument through for every intent (R7).
	assert_int(TalkRules.every_act().size()).is_equal(23)


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


func test_an_act_with_its_argument_left_empty_is_ruled_not_lost() -> void:
	var expected: Dictionary = {"claim_role": "a-role-he-cannot-place", "show": "something-shown",
		"name_person": "a-name-nobody-knows", "ask": "a-stray-question"}
	for intent: String in expected:
		var guard: TalkGuard = _guard(PackedStringArray([_reply("Hm.", intent)]))
		var turn: Dictionary = await _say(guard, "Well.")
		assert_str(turn["refusal_code"]).is_empty()
		assert_str(turn["rule"]).is_equal(expected[intent])
	var vague: Dictionary = TalkRules.step(_play([["claim_role", "courier"]]), "claim_role", "")
	assert_str(vague["rule"]).is_equal("a-role-he-cannot-place")


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


# An answer that wraps to four lines of the History label.
const LONG_SPEECH: String = "Then step aside and let me check the serial number before you burn out the " \
	+ "lamp, the battery and my patience, because nobody comes to this door at night without a reason " \
	+ "I have heard before, and I have heard every one of them twice this week alone, friend."


func test_the_guards_newest_line_is_shown_whole_however_long_the_talk() -> void:
	# T136: the third answer wraps past the sixth line, all a label 150 px
	# tall shows. The oldest turns give way; the newest is never the one cut.
	var demo: TalkDemo = auto_free((load(SCENE) as PackedScene).instantiate())
	add_child(demo)
	await get_tree().process_frame
	demo.guard.use_runtime(RecordedRuntime.new(PackedStringArray([
		_reply("Hm.", "flatter"), _reply("Go on.", "flatter"), _reply(LONG_SPEECH, "flatter")])))
	for said: int in 3:
		await _say(demo.guard, "You look sharp tonight.")
	var history: Label = demo.get_node("Interface/History")
	var all_three: Label = auto_free(history.duplicate())
	demo.get_node("Interface").add_child(all_three)
	all_three.text = TalkPanel.history(demo.guard.turns, "")
	# Lines first: that shapes the text, and the visible count reads the last shaping.
	var lines_of_all_three: int = all_three.get_line_count()
	assert_int(lines_of_all_three).is_greater(all_three.get_visible_line_count())  # the case is real
	assert_str(history.text).not_contains("Bram: Hm.")  # the oldest gave way
	var lines: int = history.get_line_count()
	assert_int(lines).is_less_equal(history.get_visible_line_count())


# The scene's History label on its own, in the tree: its size, font and wrapping.
func _history_label() -> Label:
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	var label: Label = auto_free(scene.get_node("Interface/History").duplicate())
	scene.free()
	add_child(label)
	return label


# Exchanges as the guard keeps them, one per [player, speech].
static func _exchanges(pairs: Array) -> Array[Dictionary]:
	var turns: Array[Dictionary] = []
	for pair: Array in pairs:
		turns.append({"player": pair[0], "speech": pair[1]})
	return turns


func test_a_pending_line_pushes_out_the_newest_exchange_when_it_must() -> void:
	# The newest exchange (five lines) and the pending line (two) make seven.
	var label: Label = _history_label()
	var turns: Array[Dictionary] = _exchanges([["One.", "Hm."], ["Two.", "Go on."], ["Three.", LONG_SPEECH]])
	TalkPanel.show_history(label, turns, "One more thing.")
	assert_str(label.text).ends_with(tr("Bram is thinking..."))
	var lines: int = label.get_line_count()
	assert_int(lines).is_less_equal(label.get_visible_line_count())


func test_one_exchange_taller_than_the_label_loses_its_top_not_its_end() -> void:
	# Wide glyphs: a speech within the 280 characters that wraps past six lines.
	var label: Label = _history_label()
	var word: String = "MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM"
	var wide: String = " ".join(PackedStringArray([word, word, word, word, word, word, word]))
	TalkPanel.show_history(label, _exchanges([["Who goes there?", wide]]), "")
	var lines: int = label.get_line_count()
	assert_int(lines).is_greater(label.get_visible_line_count())  # the case is real
	assert_int(label.lines_skipped + label.get_visible_line_count()).is_equal(lines)
	TalkPanel.show_history(label, _exchanges([["One.", "Hm."]]), "")
	assert_int(label.lines_skipped).is_equal(0)


func test_the_lines_are_counted_before_the_visible_ones() -> void:
	# A label last shaped with one line: asked first, its visible count is 1.
	var label: Label = _history_label()
	label.text = "x"
	label.get_line_count()
	TalkPanel.show_history(label, _exchanges([["a", "b"], ["c", "d"], ["e", "f"]]), "")
	assert_str(label.text).starts_with(tr("You: {line}").format({"line": "a"}))


# T121: the talk vectors runner refuses a file of the wrong types before it
# plays one. A list of turns given as text, in a copy of a real file, used
# to abort the runner's awaiting `_run` and hang the run for good.
func test_a_talk_vector_of_the_wrong_types_is_refused() -> void:
	var runner: GDScript = preload("res://test/talk/talk_vectors_runner.gd")
	var vector: Dictionary = VectorShape.read_spec("vectors/talk/becoming-the-expected.en.json")
	assert_str(VectorShape.why_not(vector, runner.SHAPE)).is_empty()
	var paths: Array = [["turns"], ["turns", 0], ["turns", 0, "trust"]]
	for path: Array in paths:
		var why: String = VectorShape.why_not(VectorShape.planted(vector, path, "x"), runner.SHAPE)
		assert_str(why).override_failure_message(str(path)).is_not_empty()
	var recording: Variant = VectorShape.read_spec("../" + vector["recording"])
	assert_str(VectorShape.why_not(recording, runner.RECORDING_SHAPE)).is_empty()
	assert_str(VectorShape.why_not(VectorShape.planted(recording, ["turns"], "x"), runner.RECORDING_SHAPE)).is_not_empty()


# T121's review: a recording of the wrong type was a failure, exit 1. It is
# a file the run cannot read, so it is refused like the vector's own.
func test_a_recording_of_the_wrong_type_or_too_short_is_refused() -> void:
	var runner: GDScript = preload("res://test/talk/talk_vectors_runner.gd")
	var vector: Dictionary = VectorShape.read_spec("vectors/talk/becoming-the-expected.en.json")
	var recording: Dictionary = VectorShape.read_spec("../" + vector["recording"])
	assert_str(runner.why_not_its_recording(vector, recording)).is_empty()
	var planted: Dictionary = VectorShape.planted(recording, ["turns"], "x")
	assert_str(runner.why_not_its_recording(vector, planted)).contains("turns is not a list")
	var short: Dictionary = VectorShape.planted(recording, ["turns"], [])
	assert_str(runner.why_not_its_recording(vector, short)).contains("fewer turns")
	assert_str(runner.why_not_its_recording(vector, null)).contains("missing")
