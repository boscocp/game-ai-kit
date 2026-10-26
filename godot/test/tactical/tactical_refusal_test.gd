# T79's review: the board writes its refusals in English, and the tactical
# match and the skirmish show them translated by matching the shapes
# `TacticalRefusal` copies. A copy can drift from what it copies, so every
# refusal `board_state.gd` can return is read from the source and must match
# a shape -- a reworded refusal fails here rather than reaching a Portuguese
# screen in English.
extends GdUnitTestSuite

const BOARD_SOURCE: String = "res://game/board/board_state.gd"

var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()


func before_test() -> void:
	TranslationServer.set_locale("pt_BR")


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func test_every_refusal_the_board_can_write_has_a_shape() -> void:
	var refusals: Array[String] = _board_refusals()

	assert_int(refusals.size()).override_failure_message("read no refusal from " + BOARD_SOURCE).is_greater_equal(10)
	for refusal: String in refusals:
		var sample: String = refusal.replace("%d", "7").replace("%s", "runner")
		assert_str(TacticalRefusal.words(sample)).override_failure_message(
			"no shape in TacticalRefusal for the board's \"%s\"" % refusal).is_not_equal(sample)


func test_a_refusal_the_board_made_reads_in_portuguese_with_its_names() -> void:
	var state: BoardState = TacticalScenario.build()
	var workshop: Unit = null
	for unit: Unit in state.units:
		if unit.faction == state.current_faction and unit.type.type_name == TacticalRules.WORKSHOP:
			workshop = unit
	var ram: UnitType = TacticalRules.unit_types()[TacticalRules.RAM]
	var order := ProductionOrder.new(workshop.id, ram, TacticalRules.free_cell_beside(state, workshop, ram))

	assert_str(TacticalRefusal.words(state.why_production_refused(order))).is_equal(
		"aríete: antes, compre a melhoria forja")


func test_in_english_a_refusal_is_left_as_the_board_wrote_it() -> void:
	TranslationServer.set_locale("en")

	assert_str(TacticalRefusal.words("(3, 4) is blocked")).is_equal("(3, 4) is blocked")
	assert_str(TacticalRefusal.words("")).is_equal("")


# Every string literal returned by the board's `why_*` functions.
func _board_refusals() -> Array[String]:
	var source: String = FileAccess.get_file_as_string(BOARD_SOURCE)
	var found: Array[String] = []
	for line: RegExMatch in RegEx.create_from_string("return \"([^\"]+)\"").search_all(source):
		found.append(line.get_string(1))
	return found
