# T104: the skirmish's learned opponent keeps its reasons as keys, and the
# status words them.
#
# Blue's reasons were worded with tr() when it decided (T79). Now each is a
# `Sentence` -- its English key and its values -- worded where the status
# shows it. So the same game gives the same overlay in English and in pt-BR,
# and a language switched in the middle of blue's turn rewords the reasons
# already on the panel.
extends GdUnitTestSuite

## Rounds played, red waiting: enough for blue to walk at the nodes and
## meet red's units.
const ROUNDS: int = 6
## A bound on blue's decisions in one turn, so a turn that never ends fails
## here rather than hanging the suite.
const STEPS_A_TURN: int = 20

var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func test_blue_decides_the_same_in_english_and_in_portuguese() -> void:
	var in_english: Array[String] = _overlays_over_a_game("en")
	var in_portuguese: Array[String] = _overlays_over_a_game("pt_BR")
	assert_int(in_english.size()).is_greater(ROUNDS)
	assert_array(in_portuguese).is_equal(in_english)


func test_a_language_switched_mid_turn_rewords_blue_s_reasons() -> void:
	var main: BoardGame = _mounted_scene("pt_BR")
	main.step_decision()
	main.step_decision()
	assert_object(main._plan).is_not_null()
	var played: LearnedDecision = main._played[0]
	assert_str(_status_of(main)).contains(TacticalStatus.said(played.reason)).not_contains(played.english())
	TranslationServer.set_locale("en")
	assert_str(_status_of(main)).contains(played.english()).contains(main._plan.english())
	TranslationServer.set_locale("pt_BR")
	assert_str(_status_of(main)).not_contains(played.english()).not_contains(main._plan.english())


# Every overlay blue gave over ROUNDS rounds, red waiting, in `locale`.
func _overlays_over_a_game(locale: String) -> Array[String]:
	var main: BoardGame = _mounted_scene(locale)
	var overlays: Array[String] = []
	for round_number: int in range(ROUNDS):
		main.step_decision()
		var steps: int = 0
		while main._state.current_faction == BoardGame.AI_FACTION and steps < STEPS_A_TURN:
			overlays.append(var_to_str(main.decision_overlay()))
			main.step_decision()
			steps += 1
	return overlays


func _status_of(main: BoardGame) -> String:
	var status: Label = main.get_node("Interface/Status")
	return status.atr(status.text)


func _mounted_scene(locale: String) -> BoardGame:
	TranslationServer.set_locale(locale)
	var main: BoardGame = auto_free((load("res://game/main.tscn") as PackedScene).instantiate())
	add_child(main)
	return main
