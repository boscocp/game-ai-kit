# T63: the one table of the board's controllers, and the game and the league
# reading it. The table is only worth having if every reader agrees with it,
# so these hold each reader to it rather than to a second list.
extends GdUnitTestSuite

## C's order before the table, written out once more on purpose: the manual
## check is "the same order as before", and this is that order, measured off
## the `if` chain the table replaced.
const ORDER_BEFORE: Array[String] = ["rules", "planner", "learned", "easy", "normal", "hard",
	"state machine", "behaviour tree", "GOAP", "HTN"]


func test_every_row_builds_a_controller_that_answers_to_its_name() -> void:
	# The game finds the row it is on by the name the controller gives
	# itself, so a row whose controller called itself something else would
	# send C back to the top.
	for row: Array in TacticalRoster.rows():
		var built: BlueController = (row[TacticalRoster.BUILD] as Callable).call(7)

		assert_str(built.controller_name()).is_equal(row[TacticalRoster.NAME])


func test_the_names_are_unique() -> void:
	var names: Array[String] = TacticalRoster.names()
	var seen: Dictionary = {}
	for name: String in names:
		seen[name] = true

	assert_int(seen.size()).is_equal(names.size())


func test_c_cycles_the_rows_in_the_order_it_always_did_and_comes_round() -> void:
	var playing: BlueController = RuleBasedBlue.new()
	var met: Array[String] = []
	for _press: int in range(ORDER_BEFORE.size()):
		playing = TacticalGame.next_controller(playing)
		met.append(playing.controller_name())

	# One press from the rules is the planner; the last press comes round to
	# the rules again.
	var expected: Array[String] = ORDER_BEFORE.slice(1)
	expected.append(ORDER_BEFORE[0])
	assert_array(met).is_equal(expected)


func test_a_controller_from_outside_the_table_is_followed_by_the_first_row() -> void:
	assert_str(TacticalRoster.after("somebody else")).is_equal(TacticalRoster.names()[0])


func test_the_sentence_on_screen_names_every_row() -> void:
	var sentence: String = TacticalGame.controllers_to_come()
	for name: String in TacticalRoster.names():
		assert_str(sentence).contains(name)


func test_every_row_s_walk_is_one_the_board_takes() -> void:
	var state: BoardState = TacticalScenario.build()
	var walkers: Array[Unit] = state.units_of(state.current_faction).filter(func(unit: Unit) -> bool: return unit.type.mobile)
	for row: Array in TacticalRoster.rows():
		var controller: BlueController = (row[TacticalRoster.BUILD] as Callable).call(0)
		controller.begin_turn(state)
		for unit: Unit in walkers:
			var move: Move = controller.choose(state, unit.id)
			var said: String = state.why_refused(move) if not move.path.is_empty() else BoardState.LEGAL
			assert_str(said).override_failure_message("%s's walk for unit %d: %s" % [row[TacticalRoster.NAME], unit.id, said]).is_equal(BoardState.LEGAL)
