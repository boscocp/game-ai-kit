# T80: the fighting game shows its identifiers through `FightWords`, which
# lists every one so the table holds it, and each frame's events -- English
# in the rules, since every digest carries them -- through the shapes
# `FightWords` copies. Both copies can drift: every name the game writes must
# be listed, and every event the recorded fights produce must match a shape.
extends GdUnitTestSuite

var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func test_every_name_the_game_can_show_is_listed() -> void:
	var names: Array[String] = []
	names.append_array(FightAction.ACTIONS)
	names.append_array(FightOpponent.SITUATIONS.keys())
	names.append_array(FightingExample.MODES)
	names.append_array(FightData.STANCES)
	names.append_array(FightInput.BUTTONS.keys())
	for name: String in names:
		assert_bool(name in FightWords.SHOWN).override_failure_message(
			"\"%s\" is shown but not in FightWords.SHOWN" % name).is_true()


func test_every_event_the_recorded_fights_make_reads_in_portuguese() -> void:
	TranslationServer.set_locale("pt_BR")
	var data: FightData = FightData.read()
	var refused: Array[String] = []
	var fights: Dictionary = FightRecording.read_all(FightRecording.directory(), refused)
	var events: Dictionary = {}
	for name: String in fights:
		_collect_events(fights[name], data, events)

	assert_int(events.size()).override_failure_message("the recorded fights made no event").is_greater_equal(10)
	for event: String in events:
		assert_str(FightWords.event(event)).override_failure_message(
			"no shape in FightWords for the event \"%s\"" % event).is_not_equal(event)


# Every event the fight `recorded` makes, replayed, as keys of `events`.
static func _collect_events(recorded: Dictionary, data: FightData, events: Dictionary) -> void:
	var state: FightState = FightState.starting(data, recorded["characters"][0], recorded["characters"][1])
	for pair: Array in recorded["inputs"]:
		state = FightRules.step(state, [int(pair[0]), int(pair[1])] as Array[int], data)
		for event: String in state.events:
			events[event] = true


func test_an_event_and_a_row_read_in_portuguese_and_in_english_as_written() -> void:
	TranslationServer.set_locale("pt_BR")
	assert_str(FightWords.event("p1 hits p2 with jab (caught starting up)")).is_equal(
		"p1 acerta p2 com jab (pego no startup)")
	assert_str(FightWords.row("high > low -> mid 3.0, low 1.0")).is_equal("alto > baixo -> médio 3.0, baixo 1.0")
	TranslationServer.set_locale("en")
	assert_str(FightWords.event("p1 hits p2 with jab (caught starting up)")).is_equal(
		"p1 hits p2 with jab (caught starting up)")
