# The language switch (T78): which locale the examples start in, that a
# choice is remembered, that the menu's switch changes the words at once,
# and the engine behaviour all of it stands on, measured in step 1 and
# written in docs/godot/localisation.md.
#
# Every file this writes is its own, under user://, and is removed after:
# each checkout has its own user:// since T83 (ADR 0022), but every suite of
# one run shares it, so a test that read or left the real settings.cfg would
# depend on whoever ran last.
extends GdUnitTestSuite

const SETTINGS: String = "user://language_test_settings.cfg"

var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	TranslationServer.set_locale(_locale_before)


func test_a_portuguese_system_gets_the_brazilian_words_and_any_other_english() -> void:
	assert_str(Language.for_system("pt")).is_equal(Language.PORTUGUESE)
	assert_str(Language.for_system("en")).is_equal(Language.ENGLISH)
	assert_str(Language.for_system("fr")).is_equal(Language.ENGLISH)


func test_nothing_saved_means_the_system_decides() -> void:
	assert_str(Language.saved(SETTINGS)).is_empty()
	assert_str(Language.chosen(SETTINGS)).is_equal(Language.for_system(OS.get_locale_language()))


func test_a_choice_is_spoken_at_once_and_remembered() -> void:
	assert_int(Language.choose(Language.PORTUGUESE, SETTINGS)).is_equal(OK)

	assert_str(TranslationServer.get_locale()).is_equal(Language.PORTUGUESE)
	assert_str(Language.saved(SETTINGS)).is_equal(Language.PORTUGUESE)
	TranslationServer.set_locale(Language.ENGLISH)
	Language.apply(SETTINGS)
	assert_str(TranslationServer.get_locale()).is_equal(Language.PORTUGUESE)


func test_a_scene_a_test_or_the_menu_opened_keeps_the_language_it_was_given() -> void:
	Language.choose(Language.PORTUGUESE, SETTINGS)
	TranslationServer.set_locale(Language.ENGLISH)
	var scene: Node = auto_free(Node.new())
	add_child(scene)

	Language.apply_if_opened_alone(scene, SETTINGS)

	assert_str(TranslationServer.get_locale()).is_equal(Language.ENGLISH)


func test_a_saved_value_that_is_no_language_here_is_ignored() -> void:
	var settings := ConfigFile.new()
	settings.set_value(Language.SECTION, Language.KEY, "klingon")
	settings.save(SETTINGS)

	assert_str(Language.saved(SETTINGS)).is_empty()


func test_the_tables_are_loaded_and_answer_in_portuguese() -> void:
	TranslationServer.set_locale(Language.PORTUGUESE)

	assert_str(TranslationServer.translate("wins")).is_equal("vence")
	assert_str(TranslationServer.translate("no route")).is_equal("sem rota")
	assert_str(TranslationServer.translate("Play  (Enter)")).is_equal("Jogar  (Enter)")


func test_a_number_read_as_prose_takes_the_language_s_decimal_separator() -> void:
	TranslationServer.set_locale(Language.ENGLISH)
	assert_str(Language.decimal(1.24, 1)).is_equal("1.2")
	assert_str(Language.decimal(3.0, 1)).is_equal("3.0")
	TranslationServer.set_locale(Language.PORTUGUESE)
	assert_str(Language.decimal(1.24, 1)).is_equal("1,2")
	assert_str(Language.decimal(12.4, 0)).is_equal("12")


# Step 1's measurement, kept: the property holds the English key, and the
# screen -- the lookup that honours the node's mode -- the Portuguese.
func test_a_label_keeps_its_key_and_shows_the_translation() -> void:
	TranslationServer.set_locale(Language.ENGLISH)
	var label: Label = auto_free(Label.new())
	label.text = "Play  (Enter)"
	add_child(label)
	await await_idle_frame()
	var english_width: float = label.get_minimum_size().x
	TranslationServer.set_locale(Language.PORTUGUESE)
	await await_idle_frame()

	assert_str(label.text).is_equal("Play  (Enter)")
	assert_str(label.atr(label.text)).is_equal("Jogar  (Enter)")
	assert_float(label.get_minimum_size().x).is_not_equal(english_width)


func test_a_label_with_auto_translation_off_shows_its_key() -> void:
	var label: Label = auto_free(Label.new())
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = "Play  (Enter)"
	add_child(label)
	TranslationServer.set_locale(Language.PORTUGUESE)

	assert_str(label.atr(label.text)).is_equal("Play  (Enter)")
	assert_str(label.tr(label.text)).is_equal("Jogar  (Enter)")


func test_the_menu_switch_changes_the_words_and_back() -> void:
	var menu: ExampleMenu = auto_free((load("res://menu/menu.tscn") as PackedScene).instantiate())
	menu.settings_path = SETTINGS
	add_child(menu)
	# Nothing is saved, so the menu opened in the system's language; English
	# from here, whatever the machine speaks.
	TranslationServer.set_locale(Language.ENGLISH)
	var play: Button = _button_named(menu, "Jogar  (Enter)", "Play  (Enter)")

	menu.switch_language()
	await await_idle_frame()

	assert_str(play.text).is_equal("Jogar  (Enter)")
	assert_str(Language.saved(SETTINGS)).is_equal(Language.PORTUGUESE)
	menu.switch_language()
	await await_idle_frame()
	assert_str(play.text).is_equal("Play  (Enter)")
	assert_str(Language.saved(SETTINGS)).is_equal(Language.ENGLISH)


func test_checkers_rebuilds_its_words_when_the_language_changes() -> void:
	TranslationServer.set_locale(Language.ENGLISH)
	var scene: CheckersExample = auto_free((load("res://game/checkers/checkers.tscn") as PackedScene).instantiate())
	add_child(scene)
	var status: Label = scene.get_node("Interface/Status")
	assert_str(status.text).contains("your move")

	TranslationServer.set_locale(Language.PORTUGUESE)
	await await_idle_frame()

	assert_str(status.text).contains("sua vez")
	assert_str(str((scene.get_node("Interface/Legend") as Legend).entries[0][1])).starts_with("vermelhas")


func test_the_search_demo_rebuilds_its_words_when_the_language_changes() -> void:
	TranslationServer.set_locale(Language.ENGLISH)
	var demo: SearchDemo = auto_free((load("res://demos/search/search_demo.tscn") as PackedScene).instantiate())
	add_child(demo)

	TranslationServer.set_locale(Language.PORTUGUESE)
	await await_idle_frame()

	assert_str((demo.get_node("Interface/Status") as Label).text).contains("busca em largura")
	assert_str((demo.get_node("Interface/Help") as Label).text).contains("Edite o tabuleiro")


# The menu's play button, found by what it says in either language.
func _button_named(menu: Node, portuguese: String, english: String) -> Button:
	for child: Node in menu.get_children():
		if child is Button and (child as Button).text in [portuguese, english]:
			return child
	return null
