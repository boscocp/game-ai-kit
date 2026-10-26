# Wave 100: a difficulty level on the tactical screen speaks the screen's
# language. `Difficulty.describe()`, in the `ai_planning` addon, writes
# English and keeps writing it; `DifficultyWords` is the tactical game's copy
# of that sentence as keys of its table. These hold the copy to the addon: a
# field added to `Difficulty`, or a reworded `describe()`, fails here rather
# than showing English on a Portuguese screen without a sound.
extends GdUnitTestSuite

## English words of `Difficulty.describe()` that must not reach a pt-BR screen.
const ENGLISH: Array[String] = ["plans", "ahead", "searches", "ply", "noise", "any length", "actions"]

var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func test_every_field_of_a_level_is_worded() -> void:
	var fields: Array[String] = []
	for property: Dictionary in (Difficulty as Script).get_script_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(property["name"])
	assert_array(fields).override_failure_message(
		"Difficulty has the fields %s; DifficultyWords words %s" % [fields, DifficultyWords.FIELDS]
	).contains_exactly_in_any_order(DifficultyWords.FIELDS)
	for knob: String in Difficulty.KNOBS:
		assert_array(DifficultyWords.FIELDS).contains([knob])


func test_in_english_the_copy_says_what_the_addon_says() -> void:
	TranslationServer.set_locale("en")
	for level: Difficulty in _levels():
		assert_str(DifficultyWords.said(level)).is_equal(level.describe())


func test_in_portuguese_no_word_of_the_addon_s_english_is_left() -> void:
	TranslationServer.set_locale("pt_BR")
	for level: Difficulty in _levels():
		var said: String = DifficultyWords.said(level)
		assert_str(said).is_not_equal(level.describe())
		for english: String in ENGLISH:
			assert_str(said).override_failure_message("%s still says \"%s\"" % [said, english]).not_contains(english)
		assert_str(said).contains(str(level.search_depth))


func test_the_leveled_controller_shows_the_translated_words() -> void:
	TranslationServer.set_locale("pt_BR")
	var level: Difficulty = Difficulty.named("hard")
	assert_str(LeveledBlue.new(level, 1).describe()).is_equal(DifficultyWords.said(level))


# The presets, and two made here for what they never set: a plan of any
# length and a plan of a few actions.
func _levels() -> Array[Difficulty]:
	var levels: Array[Difficulty] = Difficulty.presets()
	levels.append(Difficulty.new("easy", HeuristicPlanner.NO_HORIZON, 1, 0.25))
	levels.append(Difficulty.new("normal", 3, 2, 1.0))
	return levels
