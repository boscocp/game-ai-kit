# T104: the tactical teams keep their reasons as keys, and the screen words
# them.
#
# T79 had every team word its reason with tr() when it decided, so the
# reason an AI kept, and the overlay `test-demo-overlays` reads, were in the
# language on screen at that moment. Now a reason is a `Sentence` -- its
# English key and its values -- and the status words it where it shows it.
# So the same seeded game must give the same decisions and the same overlay
# in English and in pt-BR, under every controller; the status must show the
# reason translated in pt-BR; and a language switched mid-turn must reword
# the reason already on the panel.
extends GdUnitTestSuite

## Rounds of a seeded game played under each controller, the person waiting:
## enough for the walkers to meet and the planner to plan again.
const ROUNDS: int = 6
## A bound on one computer turn's decisions, so a turn that never ends fails
## here rather than hanging the suite.
const STEPS_A_TURN: int = 200

var _locale_before: String


func before() -> void:
	_locale_before = TranslationServer.get_locale()


func after() -> void:
	TranslationServer.set_locale(_locale_before)


func test_every_controller_decides_the_same_in_english_and_in_portuguese() -> void:
	for row_name: String in TacticalRoster.names():
		var in_english: Array[String] = _overlays_over_a_game("en", row_name)
		var in_portuguese: Array[String] = _overlays_over_a_game("pt_BR", row_name)
		assert_int(in_english.size()).override_failure_message(
			"%s: the computer decided nothing in %d rounds" % [row_name, ROUNDS]).is_greater(ROUNDS)
		assert_array(in_portuguese).override_failure_message(
			"%s: the overlays differ with the language\n%s" % [row_name, _first_difference(in_english, in_portuguese)]).is_equal(in_english)


func test_the_status_words_the_reason_in_the_language_on_screen() -> void:
	var scene: TacticalGame = _mounted_scene("pt_BR", "rules")
	_play_to_the_computers_turn(scene)
	var next: TacticalDecision = scene._computer_turn.next
	var status: String = _status_of(scene)
	assert_str(status).contains(TacticalStatus.said(next.reason))
	assert_str(status).not_contains(next.english())


# The manual check's half that a command can hold: a language switched in
# the middle of the computer's turn rewords the reason already on the panel,
# both ways.
func test_a_language_switched_mid_turn_rewords_the_reason_on_the_panel() -> void:
	var scene: TacticalGame = _mounted_scene("pt_BR", "planner")
	_play_to_the_computers_turn(scene)
	scene.step_decision()
	var next: TacticalDecision = scene._computer_turn.next
	assert_object(next).is_not_null()
	TranslationServer.set_locale("en")
	assert_str(_status_of(scene)).contains(next.english())
	TranslationServer.set_locale("pt_BR")
	assert_str(_status_of(scene)).contains(TacticalStatus.said(next.reason)).not_contains(next.english())


func test_a_kept_sentence_nests_its_pieces_and_its_lists() -> void:
	# The article travels with the piece, and a list is worded name by name.
	var reason: Array = Sentence.of("builds {piece} at {cell}: it beats {count} enemy piece(s), {beaten}", {  # not shown
		piece = TacticalStatus.a_piece_sentence(TacticalRules.BOLT_TOWER), cell = Vector2i(3, 4), count = 2,
		beaten = TacticalStatus.listed([TacticalRules.RUNNER, TacticalRules.WADER])})
	assert_str(Sentence.english(reason)).is_equal("builds a bolt tower at (3, 4): it beats 2 enemy piece(s), runner, wader")
	TranslationServer.set_locale("pt_BR")
	var said: String = TacticalStatus.said(reason)
	TranslationServer.set_locale("en")
	assert_str(said).contains("(3, 4)").not_contains("bolt tower").not_contains("runner").not_contains("wader")
	assert_str(Sentence.english(TacticalStatus.in_order(["hunt", "siege"]))).is_equal("hunt then siege")
	assert_str(Sentence.english(TacticalStatus.listed([]))).is_equal("")


# Every overlay the computer's side gave over ROUNDS rounds of a seeded game
# under `row_name`, the person waiting each turn, in `locale`.
func _overlays_over_a_game(locale: String, row_name: String) -> Array[String]:
	var scene: TacticalGame = _mounted_scene(locale, row_name)
	var overlays: Array[String] = []
	for round_number: int in range(ROUNDS):
		scene.step_decision()
		var steps: int = 0
		while not scene._persons_turn() and scene.winner == TacticalVictory.NOBODY and steps < STEPS_A_TURN:
			overlays.append(var_to_str(scene.decision_overlay()))
			scene.step_decision()
			steps += 1
		if scene.winner != TacticalVictory.NOBODY:
			break
	return overlays


# The person ends their turn, and the computer's first decision is drawn.
func _play_to_the_computers_turn(scene: TacticalGame) -> void:
	scene.step_decision()
	assert_bool(scene._computer_thinking()).is_true()


func _status_of(scene: TacticalGame) -> String:
	var status: Label = scene.get_node("Interface/Status")
	return status.atr(status.text)


func _first_difference(expected: Array[String], got: Array[String]) -> String:
	for index: int in range(mini(expected.size(), got.size())):
		if expected[index] != got[index]:
			return "decision %d:\n  en:    %s\n  pt_BR: %s" % [index, expected[index], got[index]]
	return "%d decisions in English, %d in pt-BR" % [expected.size(), got.size()]


# The scene in `locale`, its computer `row_name`, seeded so the game is the
# same every time it is mounted.
func _mounted_scene(locale: String, row_name: String) -> TacticalGame:
	TranslationServer.set_locale(locale)
	var scene: TacticalGame = auto_free((load("res://game/tactical/tactical.tscn") as PackedScene).instantiate())
	add_child(scene)
	scene.computer = TacticalRoster.build(row_name, 0)
	scene.new_game()
	return scene
