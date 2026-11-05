# T130 in the scene: Tab into live mode starts the model when nothing serves
# it, typing waits while it loads, leaving the scene stops what the scene
# started, and an exported game or a headless run never starts anything.
# The server is ai_llm's stand-in, `fake_llm_server.py`: no model loads.
extends GdUnitTestSuite

const SCENE: String = "res://game/talk/talk.tscn"
const FAKE: String = "res://test/ai_llm/fake_llm_server.py"
## Seconds a test waits for a state before it fails.
const PATIENCE: float = 10.0

var _locale_before: String = ""


func before() -> void:
	_locale_before = TranslationServer.get_locale()


func before_test() -> void:
	TranslationServer.set_locale("en")


func after() -> void:
	TranslationServer.set_locale(_locale_before)


# The scene, pointed at the stand-in on `port`, ready `loading` s after it starts.
func _demo(port: int, loading: String) -> TalkDemo:
	var demo: TalkDemo = (load(SCENE) as PackedScene).instantiate()
	demo.server_program = ProjectSettings.globalize_path(FAKE)
	demo.server_arguments = PackedStringArray([str(port), loading])
	demo.server_port = port
	add_child(demo)
	await get_tree().process_frame
	return demo


# Frames pass until `demo`'s server is in `wanted`, or PATIENCE runs out.
func _until(demo: TalkDemo, wanted: String) -> void:
	var started: int = Time.get_ticks_msec()
	while demo.server.state != wanted and Time.get_ticks_msec() - started < PATIENCE * 1000.0:
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


func test_recorded_mode_starts_nothing() -> void:
	var demo: TalkDemo = auto_free(await _demo(39951, "0.2"))
	for frame: int in 5:
		await get_tree().process_frame
	assert_object(demo.server).is_null()
	assert_bool(await _answers(39951)).is_false()


func test_tab_starts_the_model_typing_waits_and_leaving_stops_it() -> void:
	var demo: TalkDemo = await _demo(39952, "1.0")
	var typed: LineEdit = demo.get_node("Interface/Typed")
	demo.switch_mode()
	await _until(demo, LlmLocalServer.LOADING)
	assert_bool(demo.server.started_here()).is_true()
	assert_bool(typed.editable).is_false()
	assert_str(demo.get_node("Interface/Status").text).contains("loading")
	assert_str(demo.decision_overlay()["server"]).is_equal(LlmLocalServer.LOADING)
	await _until(demo, LlmLocalServer.READY)
	assert_bool(typed.editable).is_true()
	demo.switch_mode()
	demo.switch_mode()
	assert_bool(demo.server.started_here()).is_true()
	assert_bool(await _answers(39952)).is_true()
	demo.free()
	assert_bool(await _answers(39952)).is_false()


func test_a_server_already_running_is_used_and_outlives_the_scene() -> void:
	var running: LlmLocalServer = LlmLocalServer.new(ProjectSettings.globalize_path(FAKE),
		PackedStringArray(["39953", "0.2"]), 39953)
	add_child(running)
	running.begin()
	var started: int = Time.get_ticks_msec()
	while not running.is_ready() and Time.get_ticks_msec() - started < PATIENCE * 1000.0:
		await get_tree().process_frame
	var demo: TalkDemo = await _demo(39953, "exit")
	demo.switch_mode()
	await _until(demo, LlmLocalServer.READY)
	assert_bool(demo.server.started_here()).is_false()
	assert_bool((demo.get_node("Interface/Typed") as LineEdit).editable).is_true()
	demo.free()
	assert_bool(await _answers(39953)).is_true()
	running.free()


func test_an_exported_game_or_a_headless_run_never_starts_the_model() -> void:
	var project: String = ProjectSettings.globalize_path("res://")
	assert_str(TalkDemo.server_program_for(true, project)).ends_with("/scripts/llm")
	assert_str(TalkDemo.server_program_for(false, project)).is_empty()
	assert_str(TalkDemo.server_program_for(true, "/nowhere/godot/")).is_empty()
	var demo: TalkDemo = auto_free((load(SCENE) as PackedScene).instantiate())
	assert_str(demo.server_program).is_empty()


func test_with_nothing_to_start_live_mode_says_to_start_one_by_hand() -> void:
	var demo: TalkDemo = auto_free(await _demo(39954, "0.2"))
	demo.server_program = ""
	demo.switch_mode()
	await _until(demo, LlmLocalServer.BY_HAND)
	assert_str(demo.server.state).is_equal(LlmLocalServer.BY_HAND)
	assert_bool((demo.get_node("Interface/Typed") as LineEdit).editable).is_true()
	assert_str(demo.get_node("Interface/Status").text).contains("make llm-serve")


func test_a_turn_no_server_answered_starts_one_in_its_place() -> void:
	var running: LlmLocalServer = LlmLocalServer.new(ProjectSettings.globalize_path(FAKE),
		PackedStringArray(["39955", "0.2"]), 39955)
	add_child(running)
	running.begin()
	var started: int = Time.get_ticks_msec()
	while not running.is_ready() and Time.get_ticks_msec() - started < PATIENCE * 1000.0:
		await get_tree().process_frame
	var demo: TalkDemo = await _demo(39955, "0.2")
	demo.switch_mode()
	await _until(demo, LlmLocalServer.READY)
	assert_bool(demo.server.started_here()).is_false()
	running.free()
	assert_int(demo.guard.say("Hello there.")).is_equal(OK)
	await _until(demo, LlmLocalServer.CHECKING)
	await _until(demo, LlmLocalServer.READY)
	assert_bool(demo.server.started_here()).is_true()
	demo.free()
	assert_bool(await _answers(39955)).is_false()
