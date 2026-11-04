# T85: the tactical card's two modes on the menu -- M, or the mode button,
# chooses; the example is handed both rulesets and starts in the one chosen;
# `--open` and `--mode`, as `make demo-tactical MODE=squad` passes them,
# choose the card and its mode before it is played.
extends GdUnitTestSuite

const SETTINGS: String = "user://menu_modes_test_settings.cfg"
const TACTICAL: String = "demo-tactical"


func after() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))


func test_a_card_with_modes_opens_in_its_first_and_m_chooses_the_next() -> void:
	var menu: ExampleMenu = _menu()
	menu.select(_index_of(menu, TACTICAL))
	assert_str(menu.chosen_mode()).is_equal(AdvanceWarsRuleset.MODE)
	assert_bool(menu._mode.visible).is_true()
	menu.switch_mode()
	assert_str(menu.chosen_mode()).is_equal("squad")
	assert_str(menu._mode.text).contains("XCOM")
	menu.switch_mode()
	assert_str(menu.chosen_mode()).is_equal(AdvanceWarsRuleset.MODE)


func test_a_card_with_one_mode_shows_no_mode_button() -> void:
	var menu: ExampleMenu = _menu()
	menu.select(_index_of(menu, "run"))
	assert_str(menu.chosen_mode()).is_empty()
	assert_bool(menu._mode.visible).is_false()


func test_the_example_is_handed_every_mode_and_starts_in_the_one_chosen() -> void:
	var menu: ExampleMenu = _menu()
	var index: int = _index_of(menu, TACTICAL)
	menu.select(index)
	menu.switch_mode()
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	menu._in_its_modes(scene, index)
	assert_int(scene.modes.size()).is_equal(2)
	assert_str(scene.ruleset.mode_name()).is_equal("squad")
	assert_str(scene.computer.controller_name()).is_equal(SquadRoster.names()[0])


func test_open_and_mode_choose_the_card_and_its_mode() -> void:
	var menu: ExampleMenu = _menu()
	menu._open_as_asked(PackedStringArray(["--open=" + TACTICAL, "--mode=squad"]))
	assert_int(menu._selected()).is_equal(_index_of(menu, TACTICAL))
	assert_str(menu.chosen_mode()).is_equal("squad")
	await await_idle_frame()
	assert_bool(menu.is_playing()).is_true()
	var playing: TacticalGame = get_tree().current_scene as TacticalGame
	assert_object(playing).is_not_null()
	assert_str(playing.ruleset.mode_name()).is_equal("squad")
	menu.back()
	await await_idle_frame()


func _menu() -> ExampleMenu:
	var menu: ExampleMenu = auto_free((load("res://menu/menu.tscn") as PackedScene).instantiate())
	menu.settings_path = SETTINGS
	add_child(menu)
	return menu


func _index_of(menu: ExampleMenu, target: String) -> int:
	for index: int in range(menu.catalogue.cards.size()):
		if menu.catalogue.cards[index].get("target", "") == target:
			return index
	return -1
