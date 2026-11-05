# RecordingRuntime (T94): it passes requests on, answers by the same signals,
# and writes what it kept in the shape RecordedRuntime reads back -- so a
# conversation recorded live replays with no model. A turn with no text is
# never saved.
extends GdUnitTestSuite

const REPLY: String = '{"speech": "Evening.", "intent": "greet", "argument": ""}'


func _conversation(recording: RecordingRuntime) -> LlmConversation:
	add_child(recording)
	return LlmConversation.new(recording, LlmValidator.new({"greet": []}, "Again?"), "A guard.")


func _path() -> String:
	return ProjectSettings.globalize_path("user://recording_runtime_test.json")


func test_it_answers_as_the_runtime_it_wraps_and_saves_what_replays() -> void:
	var recording: RecordingRuntime = auto_free(RecordingRuntime.new(RecordedRuntime.new(PackedStringArray([REPLY]))))
	var conversation: LlmConversation = _conversation(recording)
	assert_int(conversation.say("Hello there.")).is_equal(OK)
	assert_bool(recording.is_busy()).is_true()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(conversation.is_thinking()).is_false()
	assert_int(recording.kept()).is_equal(1)
	assert_int(recording.save(_path(), {"language": "en"})).is_equal(OK)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_path()))
	assert_str(saved["language"]).is_equal("en")
	assert_str(saved["turns"][0]["player"]).is_equal("Hello there.")
	assert_int(auto_free(RecordedRuntime.from_file(_path())).remaining()).is_equal(1)
	DirAccess.remove_absolute(_path())


func test_a_turn_with_no_text_is_never_saved() -> void:
	var recording: RecordingRuntime = auto_free(RecordingRuntime.new(RecordedRuntime.new()))
	var conversation: LlmConversation = _conversation(recording)
	assert_int(conversation.say("Hello?")).is_equal(OK)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(conversation.is_thinking()).is_false()
	assert_int(recording.save(_path(), {})).is_equal(ERR_INVALID_DATA)
	assert_bool(FileAccess.file_exists(_path())).is_false()


func test_nothing_said_is_nothing_to_save() -> void:
	var recording: RecordingRuntime = auto_free(RecordingRuntime.new(RecordedRuntime.new()))
	add_child(recording)
	assert_int(recording.save(_path(), {})).is_equal(ERR_INVALID_DATA)
