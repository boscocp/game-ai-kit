# T80: the fighting game shows its identifiers through `FightWords`, which
# lists every one so the table holds it, and each frame's events -- English
# in the rules, since every digest carries them -- through the shapes
# `FightWords` copies. Both copies can drift: every name the game writes must
# be listed, and every event the rules can write must match a shape. The
# events are read from the rules' source, as `rts_words_test` reads the RTS
# rules' refusals: the recorded fights alone never cancel or clash throws,
# and a reworded one of those passed (T80's review).
extends GdUnitTestSuite

const RULES_SOURCE: String = "res://game/fighting/fight_rules.gd"
const BOXES_SOURCE: String = "res://game/fighting/fight_boxes.gd"

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
	names.append_array(FightOpponent.LEVELS.keys())
	names.append_array(FightCloneOpponent.SOURCES)
	names.append("(anything)")
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


func test_every_event_the_rules_can_write_reads_in_portuguese() -> void:
	TranslationServer.set_locale("pt_BR")
	var samples: Array[String] = _events_in_the_source()

	assert_int(samples.size()).override_failure_message("read no event from the rules").is_greater_equal(25)
	for sample: String in samples:
		var shown: String = FightWords.event(sample)
		var reason: int = sample.find(" (")
		var english_left: bool = shown == sample or (reason >= 0 and shown.contains(sample.substr(reason + 1)))
		assert_bool(english_left).override_failure_message(
			"no shape in FightWords for the event \"%s\": shown as \"%s\"" % [sample, shown]).is_false()


# Every event the rules and the boxes can write, as text: each whole event
# literal, each verb with each reason in brackets, each miss -- %d a player,
# %s a move.
static func _events_in_the_source() -> Array[String]:
	var rules: String = FileAccess.get_file_as_string(RULES_SOURCE)
	var boxes: String = FileAccess.get_file_as_string(BOXES_SOURCE)
	var samples: Array[String] = []
	for found: RegExMatch in RegEx.create_from_string("events\\.append\\(\"([^\"]+)\"").search_all(rules):
		var event: String = found.get_string(1)
		if event != "p%d's %s %s" and event != "p%d %s p%d with %s%s":
			samples.append(event.replace("%d", "1").replace("%s", "jab"))
	var reasons: Array[String] = [""]
	for found: RegExMatch in RegEx.create_from_string("\" (\\([^\"]+\\))\"").search_all(rules):
		reasons.append(" " + found.get_string(1))
	var heights: Array[String] = []
	for found: RegExMatch in RegEx.create_from_string("\"(?:low|overhead|high)\": \"([^\"]+)\"").search_all(rules):
		heights.append(found.get_string(1))
	for found: RegExMatch in RegEx.create_from_string("\"(?:block|counter-hit|hit|throw)\": \"([^\"]+)\"").search_all(rules):
		for reason: String in _with_heights(reasons, heights):
			samples.append("p1 %s p2 with jab%s" % [found.get_string(1), reason.replace("%s", "standing")])
	for found: RegExMatch in RegEx.create_from_string("\"(passes (?:over|under) p%d)\"").search_all(boxes):
		samples.append("p1's jab " + found.get_string(1).replace("%d", "2"))
		for why: RegExMatch in RegEx.create_from_string("\" (\\([^\"]+\\))\"").search_all(boxes):
			samples.append("p1's jab " + found.get_string(1).replace("%d", "2") + " " + why.get_string(1))
	return samples


# The reasons, the one naming a height written once with each height.
static func _with_heights(reasons: Array[String], heights: Array[String]) -> Array[String]:
	var found: Array[String] = []
	for reason: String in reasons:
		if not reason.contains("%s through"):
			found.append(reason)
			continue
		for height: String in heights:
			found.append(reason.replace("%s through", height + " through"))
	return found


func test_an_event_and_a_row_read_in_portuguese_and_in_english_as_written() -> void:
	TranslationServer.set_locale("pt_BR")
	assert_str(FightWords.event("p1 hits p2 with jab (caught starting up)")).is_equal(
		"p1 acerta p2 com jab (pego no startup)")
	assert_str(FightWords.row("high > low -> mid 3.0, low 1.0")).is_equal("alto > baixo -> médio 3.0, baixo 1.0")
	assert_str(FightWords.row("(anything) -> mid 1.0")).is_equal("(qualquer coisa) -> médio 1.0")
	TranslationServer.set_locale("en")
	assert_str(FightWords.event("p1 hits p2 with jab (caught starting up)")).is_equal(
		"p1 hits p2 with jab (caught starting up)")
