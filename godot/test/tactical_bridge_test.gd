# T41: the owner's report that blue "got stuck at the bridge".
#
# Reproduced headless before anything was changed: red walks one runner onto
# the bridge, or the cell in front of it, and leaves it there. There was no
# combat then (T26 came later), so the bridge was shut -- and blue, whose
# route ignored who stood on it, built a shield every turn and piled 24 of them
# behind the river, each one saying "no walk this turn brings it nearer".
# Round 40 came and it was a draw. The water was open the whole time, to the
# one piece blue never built.
#
# Each game here is played to the end, with red doing nothing else, and blue
# must win it.
extends GdUnitTestSuite

const RED: int = TacticalScenario.RED
const BLUE: int = TacticalScenario.BLUE
const BRIDGE_WEST := Vector2i(6, 4)
const IN_FRONT_OF_THE_BRIDGE := Vector2i(5, 4)


func test_blue_wins_when_red_parks_a_runner_on_the_bridge() -> void:
	assert_int(_play_against_a_parked_runner(BRIDGE_WEST)).is_equal(BLUE)


func test_blue_wins_when_red_parks_a_runner_in_front_of_the_bridge() -> void:
	assert_int(_play_against_a_parked_runner(IN_FRONT_OF_THE_BRIDGE)).is_equal(BLUE)


func test_with_the_bridge_shut_blue_builds_a_piece_that_can_wade() -> void:
	var state: BoardState = _parked_on(BRIDGE_WEST)
	var workshop: Unit = state.unit_at(Vector2i(12, 1))

	var decision: TacticalDecision = RuleBasedBlue.new().decide_build(state, workshop.id)

	assert_str(decision.kind()).is_equal("build")
	assert_str(decision.order.unit_type.type_name).is_equal(TacticalRules.WADER)
	assert_str(decision.reason).contains("still gets there")


func test_a_walker_the_bridge_is_shut_to_says_so_and_takes_the_fallback() -> void:
	# It used to stay. Since T45 a walker whose goal is out of reach walks at
	# the nearest red piece it can -- here, the runner shutting the bridge --
	# and still says why its goal was out of reach.
	var state: BoardState = _parked_on(BRIDGE_WEST)
	var shield: Unit = _first_of(state, BLUE, TacticalRules.SHIELD)

	var decision: TacticalDecision = RuleBasedBlue.new().decide_move(state, shield.id)

	assert_object(decision.move).is_not_null()
	assert_str(decision.reason).contains("red's pieces stand on every way")
	assert_str(decision.reason).contains("fallback")


# The winner of a whole game in which red's only act is to walk its runner to
# `park` and leave it there.
func _play_against_a_parked_runner(park: Vector2i) -> int:
	var state: BoardState = TacticalScenario.build()
	var turn := BlueTurn.new(RuleBasedBlue.new())
	var winner: int = TacticalVictory.NOBODY
	while winner == TacticalVictory.NOBODY:
		state = _red_walks_towards(state, park)
		winner = TacticalVictory.winner(state)
		if winner != TacticalVictory.NOBODY:
			break
		turn.begin(state)
		while not turn.finished():
			state = turn.play(state)
		assert_array(turn.refused).is_empty()
		state = TurnStart.open(state)[0]
		winner = TacticalVictory.winner(state)
	return winner


# The start of blue's turn with red's runner standing on `park`.
func _parked_on(park: Vector2i) -> BoardState:
	var state: BoardState = TacticalScenario.build()
	var runner: Unit = _first_of(state, RED, TacticalRules.RUNNER)
	runner.cell = park
	return TurnStart.open(state)[0]


# Red's turn: its runner walks as far towards `park` as it can, and nothing
# else of red's moves or is built.
func _red_walks_towards(state: BoardState, park: Vector2i) -> BoardState:
	var runner: Unit = _first_of(state, RED, TacticalRules.RUNNER)
	var walks: Dictionary = TacticalReach.walks_for(state, runner)
	var to_park: Dictionary = TacticalReach.route_costs(state.graph_for(runner), park)
	var best: Vector2i = runner.cell
	for cell: Vector2i in walks:
		if to_park.get(cell, 1 << 30) < to_park.get(best, 1 << 30):
			best = cell
	if best != runner.cell:
		var path: Array[Vector2i] = []
		path.assign(walks[best])
		state = state.apply(Move.new(runner.id, path))
	return TurnStart.open(state)[0]


func _first_of(state: BoardState, faction: int, type_name: String) -> Unit:
	for unit: Unit in state.units_of(faction):
		if unit.type.type_name == type_name:
			return unit
	return null
