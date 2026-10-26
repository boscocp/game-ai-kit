# T80: the bot match shows its identifiers through `BotMatchWords`, which
# lists every one so the table holds it. A list can drift from what it
# lists, so every name the data and the constants write must be in it --
# a new action missing here would show English on a Portuguese screen.
extends GdUnitTestSuite

var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func test_every_name_the_match_can_show_is_listed() -> void:
	var names: Array[String] = _names_in_actions_json()
	assert_int(names.size()).override_failure_message("read no name from actions.json").is_greater_equal(10)
	names.append_array([MatchBot.DEAD, MatchBot.RELOAD, MatchBot.FALL_BACK, MatchBot.SHOOT, MatchBot.MOVE,
		MatchBot.HOLD, MatchBot.LOOK, ErrandChoice.RESUPPLY, ErrandChoice.FETCH, ErrandChoice.HIDE,
		MatchSupply.RIFLE, MatchSupply.POWER, SquadConfidence.ATTACK, SquadConfidence.HOLD, SquadConfidence.RETREAT])
	names.append_array(MatchAim.ZONES)
	names.append_array(PassageChoice.WAYS)
	for name: String in names:
		assert_bool(name in BotMatchWords.SHOWN).override_failure_message(
			"\"%s\" is shown but not in BotMatchWords.SHOWN" % name).is_true()
	for name: String in BotMatch.TEAM_NAMES + [MatchBot.PLAYED]:
		assert_bool(BotMatchWords.SAID_AS.has(name)).override_failure_message(
			"\"%s\" is shown but has no key in BotMatchWords.SAID_AS" % name).is_true()


func test_in_portuguese_the_names_are_words_and_in_english_identifiers() -> void:
	TranslationServer.set_locale("pt_BR")
	assert_str(BotMatchWords.word("fall back")).is_equal("recuar")
	assert_str(BotMatchWords.word("blue")).is_equal("time azul")
	TranslationServer.set_locale("en")
	assert_str(BotMatchWords.word("fall back")).is_equal("fall back")
	assert_str(BotMatchWords.word("blue")).is_equal("blue team")


func test_the_health_line_reads_in_portuguese() -> void:
	TranslationServer.set_locale("pt_BR")
	var rules := MatchRules.new()
	var world := BotMatch.new(1, MatchTeam.new("blue", 0, rules), MatchTeam.new("red", 1, rules), rules)

	assert_str(BotMatchHud.health_text(rules, world.bots[0], 0.0)).is_equal("100 de vida")


static func _names_in_actions_json() -> Array[String]:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MatchBot.ACTIONS))
	var names: Array[String] = []
	for group: String in ["actions", "postures", "paces"]:
		for row: Dictionary in data[group]:
			names.append(str(row["name"]))
	return names
