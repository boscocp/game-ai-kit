# T80: the RTS shows its identifiers through `RtsWords`, which lists every
# one so the table holds it, and its rules' refusals through `RtsRefusal`,
# which copies their shapes. A copy can drift from what it copies, so every
# name the game writes must be listed, and every refusal `rts_rules.gd` can
# return is read from the source and must match a shape -- a reworded one
# fails here rather than reaching a Portuguese screen in English.
extends GdUnitTestSuite

const RULES_SOURCE: String = "res://addons/ai_rts_core/rts_rules.gd"

var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func test_every_name_the_game_can_show_is_listed() -> void:
	var names: Array[String] = [RtsKinds.WORKER, RtsKinds.RUNNER, RtsKinds.SHIELD, RtsKinds.MORTAR, RtsKinds.BASE,
		RtsKinds.BARRACKS, RtsKinds.LAB, RtsKinds.DEPOT, RtsKinds.TOWER, RtsKinds.ARM, RtsKinds.ROCKS, RtsKinds.VENT,
		RtsKinds.ORE, RtsKinds.MAGMA, Squad.GATHER, Squad.ADVANCE, Squad.FIGHT, Squad.RETREAT,
		RtsCommand.MOVE, RtsCommand.ATTACK, RtsCommand.GATHER, RtsCommand.BUILD, RtsCommand.TRAIN, RtsCommand.REPAIR]
	names.append_array(RtsScenario.REGIONS.keys())
	for level: Difficulty in RtsLevels.presets():
		names.append(level.name)
	for name: String in names:
		assert_bool(name in RtsWords.SHOWN).override_failure_message(
			"\"%s\" is shown but not in RtsWords.SHOWN" % name).is_true()


func test_every_refusal_the_rules_can_write_has_a_shape() -> void:
	TranslationServer.set_locale("pt_BR")
	var refusals: Array[String] = _rules_refusals()

	assert_int(refusals.size()).override_failure_message("read no refusal from " + RULES_SOURCE).is_greater_equal(20)
	for refusal: String in refusals:
		var sample: String = refusal.replace("%d", "7").replace("%s", "runner")
		assert_str(RtsRefusal.words(sample)).override_failure_message(
			"no shape in RtsRefusal for the rules' \"%s\"" % refusal).is_not_equal(sample)


func test_a_refusal_reads_in_portuguese_with_its_names_and_in_english_as_written() -> void:
	TranslationServer.set_locale("pt_BR")
	assert_str(RtsRefusal.words("a lab needs a barracks first")).is_equal("laboratório: antes é preciso quartel")
	TranslationServer.set_locale("en")
	assert_str(RtsRefusal.words("a lab needs a barracks first")).is_equal("a lab needs a barracks first")
	assert_str(RtsRefusal.words("")).is_equal("")


# Every string literal the rules return, in the `return "..."` form and in
# the `else "..."` arm of a returned conditional.
func _rules_refusals() -> Array[String]:
	var source: String = FileAccess.get_file_as_string(RULES_SOURCE)
	var found: Array[String] = []
	for line: RegExMatch in RegEx.create_from_string("(?:return|else) \"([^\"]+)\"").search_all(source):
		found.append(line.get_string(1))
	return found
