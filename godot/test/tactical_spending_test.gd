# T45: the AI spends its money and keeps its pieces moving. Wesnoth's three
# answers, each held here: spend first, never idle, one piece per target.
extends GdUnitTestSuite

const RED: int = TacticalScenario.RED
const BLUE: int = TacticalScenario.BLUE
const SEEDS: int = 4


func test_a_boxed_in_workshop_says_there_is_no_room() -> void:
	var state: BoardState = _scenario_with([[BLUE, TacticalRules.SHIELD, Vector2i(11, 1)],
		[BLUE, TacticalRules.SHIELD, Vector2i(13, 1)], [BLUE, TacticalRules.SHIELD, Vector2i(12, 0)],
		[BLUE, TacticalRules.SHIELD, Vector2i(12, 2)]])

	var decision: TacticalDecision = RuleBasedBlue.new().decide_build(state, _workshop(state).id)

	assert_str(decision.reason).contains(RuleBasedBlue.NO_ROOM)


func test_a_boxed_in_workshop_is_asked_again_after_its_walkers_move() -> void:
	var state: BoardState = _scenario_with([[BLUE, TacticalRules.RUNNER, Vector2i(11, 1)],
		[BLUE, TacticalRules.RUNNER, Vector2i(13, 1)], [BLUE, TacticalRules.RUNNER, Vector2i(12, 0)],
		[BLUE, TacticalRules.RUNNER, Vector2i(12, 2)]])
	var turn := BlueTurn.new(RuleBasedBlue.new())

	turn.begin(state)
	while not turn.finished():
		state = turn.play(state)

	var asked: Array = turn.played.filter(func(done: TacticalDecision) -> bool: return done.unit_id == _workshop(state).id)
	assert_int(asked.size()).is_equal(2)
	assert_str((asked[1] as TacticalDecision).kind()).is_equal("build")


func test_it_builds_even_when_nothing_that_reaches_beats_a_red_piece() -> void:
	# Red shuts the bridge with runners, which only the shield and the bolt
	# tower beat, and a blue walker already reaches red's workshop by water.
	var state: BoardState = _scenario_with([[RED, TacticalRules.RUNNER, Vector2i(6, 4)],
		[RED, TacticalRules.RUNNER, Vector2i(7, 4)], [BLUE, TacticalRules.WADER, Vector2i(8, 6)]])
	state.funds[BLUE] = 10

	var decision: TacticalDecision = RuleBasedBlue.new().decide_build(state, _workshop(state).id)

	assert_str(decision.kind()).is_equal("build")


func test_a_walker_with_no_way_to_its_goal_takes_the_fallback() -> void:
	# Red's runners on both bridge cells: a blue shield has no way to red's
	# workshop, and walks at the nearest red piece instead of staying.
	var state: BoardState = _scenario_with([[RED, TacticalRules.RUNNER, Vector2i(6, 4)],
		[RED, TacticalRules.RUNNER, Vector2i(7, 4)], [BLUE, TacticalRules.SHIELD, Vector2i(9, 3)]])
	var shield: Unit = state.unit_at(Vector2i(9, 3))

	var decision: TacticalDecision = RuleBasedBlue.new().decide_move(state, shield.id)

	assert_str(decision.kind()).is_equal("move")
	assert_str(decision.reason).contains("fallback")


func test_two_walkers_of_one_side_never_head_for_the_same_point_in_one_turn() -> void:
	for dice: int in range(SEEDS):
		var recorder := _Recording.new(LearnedBlue.new())
		TacticalMatch.play(RuleBasedBlue.new(), recorder, dice)
		for turn: int in recorder.points_by_turn:
			var points: Array = recorder.points_by_turn[turn]
			assert_int(points.size()).override_failure_message("seed %d, turn %d: %s" % [dice, turn, points]).is_equal(_distinct(points).size())


# --- helpers -------------------------------------------------------------------

func _scenario_with(extra: Array) -> BoardState:
	var state: BoardState = TurnStart.open(TacticalScenario.build())[0]
	var units: Array[Unit] = state.units.duplicate()
	var types: Dictionary = TacticalRules.unit_types()
	for piece: Array in extra:
		var kind: UnitType = types[piece[1]]
		units.append(Unit.new(100 + units.size(), piece[0], piece[2], 10, kind.movement, kind))
	var built := BoardState.new(state.graph, units, BLUE)
	built.movement_graphs = state.movement_graphs
	built.funds = state.funds.duplicate()
	built.turn_number = state.turn_number
	return built


func _workshop(state: BoardState) -> Unit:
	for unit: Unit in state.units_of(BLUE):
		if unit.type.type_name == TacticalRules.WORKSHOP:
			return unit
	return null


static func _distinct(items: Array) -> Array:
	var found: Array = []
	for item: Variant in items:
		if not item in found:
			found.append(item)
	return found


# A controller that asks another, and writes down which point each walk in
# each turn heads for.
class _Recording extends BlueController:
	var inner: BlueController
	var points_by_turn: Dictionary = {}

	func _init(asked: BlueController) -> void:
		inner = asked

	## The inner controller's name.
	func controller_name() -> String:
		return inner.controller_name()

	## The inner controller's line.
	func describe() -> String:
		return inner.describe()

	## The inner start of turn.
	func begin_turn(state: BoardState) -> void:
		inner.begin_turn(state)
		points_by_turn[state.turn_number] = []

	## The inner build.
	func decide_build(state: BoardState, workshop_id: int) -> TacticalDecision:
		return inner.decide_build(state, workshop_id)

	## The inner walk, with the point it names written down.
	func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
		var decision: TacticalDecision = inner.decide_move(state, unit_id)
		var found: int = decision.reason.find("towards the point at ")
		if decision.move != null and found != -1:
			points_by_turn[state.turn_number].append(decision.reason.substr(found, 30).get_slice(":", 0))
		return decision

	## The inner attack.
	func decide_attack(state: BoardState, unit_id: int) -> TacticalDecision:
		return inner.decide_attack(state, unit_id)
