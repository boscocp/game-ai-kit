# T132: a change of language gives the talk scene a guard inside the tree.
#
# The owner opened `make demo-talk` with pt-BR saved and the engine said
# "Parent node is busy setting up children, `add_child()` failed": the new
# guard, in Portuguese, was never added. Measured on 4.7.2, the cause is
# not `_ready` itself. `TranslationServer.set_locale` hands
# NOTIFICATION_TRANSLATION_CHANGED down the tree through
# `propagate_notification`, which holds each node busy while its own
# notification runs, so a node cannot `add_child` to itself from it -- in
# `_ready` or at any later change of language
# (`docs/godot/localisation.md`).
#
# Two ways in, one test each: the scene opened on its own, as `make
# demo-talk` opens it, where `Language.apply_if_opened_alone` changes the
# language inside `_ready`; and a change of language while it is open.
# Neither the menu nor any other suite reached either.
extends GdUnitTestSuite

const SCENE: String = "res://game/talk/talk.tscn"

var _locale_before: String = ""
var _settings_before: String = ""
var _had_settings: bool = false


## Counts the engine's errors that name a parent busy with its children.
class BusyParentCounter extends Logger:
	var busy: int = 0

	func _log_error(_function: String, _file: String, _line: int, _code: String,
			rationale: String, _editor_notify: bool, _error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if "busy setting up children" in rationale:
			busy += 1


func before() -> void:
	_locale_before = TranslationServer.get_locale()


# The scene reads the person's own settings file, which has no other path to
# be given. So the test keeps that file's text and puts it back afterwards;
# `user://` is this checkout's alone (ADR 0022).
func before_test() -> void:
	TranslationServer.set_locale("en")
	_had_settings = FileAccess.file_exists(Language.SETTINGS)
	_settings_before = FileAccess.get_file_as_string(Language.SETTINGS) if _had_settings else ""


func after_test() -> void:
	if _had_settings:
		FileAccess.open(Language.SETTINGS, FileAccess.WRITE).store_string(_settings_before)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Language.SETTINGS))


func after() -> void:
	TranslationServer.set_locale(_locale_before)


# The talk scene added to the root as the engine adds a main scene: already
# `current_scene` when its `_ready` runs (the engine sets it before adding
# the scene; `tree_entered` comes before `_ready`). The suite's own current
# scene is put back as soon as the scene is ready.
func _open_alone() -> TalkDemo:
	var demo: TalkDemo = (load(SCENE) as PackedScene).instantiate()
	var tree: SceneTree = get_tree()
	var runner_scene: Node = tree.current_scene
	demo.tree_entered.connect(func() -> void: tree.current_scene = demo, CONNECT_ONE_SHOT)
	tree.root.add_child(demo)
	tree.current_scene = runner_scene
	return demo


# The guard is the scene's child, in the tree, speaking `language`.
func _assert_guard_in_tree(demo: TalkDemo, language: String) -> void:
	assert_object(demo.guard.get_parent()).is_same(demo)
	assert_bool(demo.guard.is_inside_tree()).is_true()
	assert_str(demo.guard.language).is_equal(language)


func test_opened_alone_with_portuguese_saved_its_guard_is_in_the_tree() -> void:
	var saved := ConfigFile.new()
	saved.set_value(Language.SECTION, Language.KEY, Language.PORTUGUESE)
	assert_int(saved.save(Language.SETTINGS)).is_equal(OK)
	var counter := BusyParentCounter.new()
	OS.add_logger(counter)
	var demo: TalkDemo = auto_free(_open_alone())
	await get_tree().process_frame
	await get_tree().process_frame
	OS.remove_logger(counter)
	assert_str(TranslationServer.get_locale()).is_equal(Language.PORTUGUESE)
	assert_int(counter.busy).is_equal(0)
	_assert_guard_in_tree(demo, Language.PORTUGUESE)
	demo.get_parent().remove_child(demo)


func test_a_change_of_language_while_open_gives_a_guard_in_the_tree() -> void:
	var demo: TalkDemo = auto_free((load(SCENE) as PackedScene).instantiate())
	add_child(demo)
	await get_tree().process_frame
	var counter := BusyParentCounter.new()
	OS.add_logger(counter)
	TranslationServer.set_locale(Language.PORTUGUESE)
	await get_tree().process_frame
	OS.remove_logger(counter)
	assert_int(counter.busy).is_equal(0)
	_assert_guard_in_tree(demo, Language.PORTUGUESE)
	TranslationServer.set_locale(Language.ENGLISH)
	await get_tree().process_frame
	_assert_guard_in_tree(demo, Language.ENGLISH)
