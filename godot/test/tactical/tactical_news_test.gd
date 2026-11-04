# T110: the tactical game's news keeps its words as keys.
#
# T104 made the AI's reasons a `Sentence`, worded where they are shown, and
# left out the news of what was played: an attack, a build, a wait, a
# purchase, a tower's shot were worded with tr() when they happened, so a
# language switched before the next event left the panel in the old one.
# Now the news is a `Sentence` too. So each event here happens in one
# language, the locale changes before anything else happens, and the news
# on the panel must be in the new language at once -- both ways.
extends GdUnitTestSuite

const RED: int = TacticalScenario.RED
const BLUE: int = TacticalScenario.BLUE
const LOCALES: Array[String] = ["pt_BR", "en"]

var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func test_an_attack_s_news_follows_a_language_switched_after_it() -> void:
	for locale: String in LOCALES:
		var scene: TacticalGame = _mounted_scene(locale)
		var runner: Unit = _first_of(scene.state, RED, TacticalRules.RUNNER)
		var start: Vector2i = runner.cell
		# As `tactical_combat_test.gd` sets a fight up: a step left, then a
		# mortar on the open cell beyond.
		scene.click_cell(start)
		scene.click_cell(start + Vector2i(-1, 0))
		scene.state.units.append(Unit.new(99, BLUE, start + Vector2i(-2, 0), 10, 0, TacticalRules.unit_types()[TacticalRules.MORTAR]))
		scene.click_cell(start + Vector2i(-1, 0))
		scene.click_cell(start + Vector2i(-2, 0))
		_assert_the_news_follows_the_language(scene, locale, "the red runner at")


func test_a_build_s_news_follows_a_language_switched_after_it() -> void:
	for locale: String in LOCALES:
		var scene: TacticalGame = _mounted_scene(locale)
		scene.click_cell(_first_of(scene.state, RED, TacticalRules.WORKSHOP).cell)
		scene.build(TacticalRules.BUILDABLE.find(TacticalRules.RUNNER))
		_assert_the_news_follows_the_language(scene, locale, "built a runner at")


func test_a_wait_s_news_follows_a_language_switched_after_it() -> void:
	for locale: String in LOCALES:
		var scene: TacticalGame = _mounted_scene(locale)
		scene.click_cell(_first_of(scene.state, RED, TacticalRules.RUNNER).cell)
		scene.wait()
		_assert_the_news_follows_the_language(scene, locale, "the runner waits at")


func test_a_purchase_s_news_follows_a_language_switched_after_it() -> void:
	for locale: String in LOCALES:
		var scene: TacticalGame = _mounted_scene(locale)
		scene.state.funds[RED] = TacticalRules.FORGE_COST
		scene.buy_forge()
		_assert_the_news_follows_the_language(scene, locale, "bought the forge")


func test_a_tower_s_shot_follows_a_language_switched_after_it() -> void:
	# The news of a turn's opening, on the computer's panel: blue's tower
	# fires as blue's turn opens, worded through `TurnStart`.
	for locale: String in LOCALES:
		var scene: TacticalGame = _mounted_scene(locale)
		var tower: Unit = _first_of(scene.state, BLUE, TacticalRules.BOLT_TOWER)
		scene.state.unit_by_id(_first_of(scene.state, RED, TacticalRules.RUNNER).id).cell = tower.cell + Vector2i(-1, 0)
		scene.step_decision()
		_assert_the_news_follows_the_language(scene, locale, "blue bolt tower")


func test_a_kept_news_line_nests_its_pieces_and_sides() -> void:
	# The side's name and the piece are values, not words already chosen:
	# the same line reads in either language from the one sentence.
	var state: BoardState = TacticalScenario.build()
	var runner: Unit = _first_of(state, RED, TacticalRules.RUNNER)
	var mortar := Unit.new(99, BLUE, runner.cell + Vector2i(-1, 0), 10, 0, TacticalRules.unit_types()[TacticalRules.MORTAR])
	state.units.append(mortar)
	var strike := Attack.new(runner.id, mortar.id)
	var told: Array = TacticalCombat.told(state, strike, TacticalCombat.apply(state, strike))
	TranslationServer.set_locale("pt_BR")
	var said: String = TacticalStatus.said(told)
	TranslationServer.set_locale("en")
	assert_str(Sentence.english(told)).contains("red runner at %s" % runner.cell)
	assert_str(said).contains(str(runner.cell)).not_contains("runner").not_contains("red runner").not_contains("mortar")


# The event has just happened in `locale`. Switched to the other language,
# the panel shows the news in it at once; switched back, in the first again.
func _assert_the_news_follows_the_language(scene: TacticalGame, locale: String, english_words: String) -> void:
	var english: String = scene.news_in_english()
	assert_str(english).override_failure_message("in %s the news is \"%s\", refused: %s" % [locale, english, scene._last_refusal]).contains(english_words)
	TranslationServer.set_locale("pt_BR")
	var portuguese: String = "\n".join(scene._last_event.map(TacticalStatus.said))
	assert_str(portuguese).override_failure_message("the news is not translated: %s" % portuguese).is_not_equal(english)
	var other: String = "en" if locale == "pt_BR" else "pt_BR"
	for shown: String in [other, locale]:
		TranslationServer.set_locale(shown)
		var status: String = _status_of(scene)
		var expected: String = english if shown == "en" else portuguese
		var stale: String = portuguese if shown == "en" else english
		assert_str(status).override_failure_message("%s -> %s: the panel says\n%s" % [locale, shown, status]).contains(expected)
		assert_str(status).override_failure_message("%s -> %s: the old language stays\n%s" % [locale, shown, status]).not_contains(stale)


func _status_of(scene: TacticalGame) -> String:
	var status: Label = scene.get_node("Interface/Status")
	return status.atr(status.text)


func _mounted_scene(locale: String) -> TacticalGame:
	TranslationServer.set_locale(locale)
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	add_child(scene)
	return scene


func _first_of(state: BoardState, faction: int, type_name: String) -> Unit:
	for unit: Unit in state.units_of(faction):
		if unit.type.type_name == type_name:
			return unit
	return null
