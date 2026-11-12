# T125: `GreedySquad`, the careless player that is the XCOM mode's second
# floor (`make test-squad-floor`).
#
# It shoots when it can: the shot that expects the most damage, never one at
# 0%. It walks to keep a shot when one is to be had, and otherwise straight
# at the nearest enemy it knows of, holding when it can come no closer. A
# walk the board refuses is answered with a hold, so no action is lost.
#
# It does not cheat: T85's check (`SquadUnseenCheck`) holds it as it holds
# the weighed enemy, and is shown a greedy shooter that reads the whole
# board, which it must catch on at least a pinned share of the positions.
extends GdUnitTestSuite

const RED: int = TacticalScenario.RED
const BLUE: int = TacticalScenario.BLUE
const POSITIONS: int = 40
## The positions the planted greedy shooter that sees everything must be
## caught on: a floor under the 22 of 40 measured in wave 192.
const AT_LEAST_ALL: int = 15


## A greedy shooter on the whole board: the planted case the check must catch.
class SeesEverything extends GreedySquad:
	func _look(state: BoardState) -> SideView:
		return SideView.new(state.current_faction, state, {} as Dictionary[int, Vector2i])


var _rules := SquadRuleset.new()
var _check: SquadUnseenCheck


func before() -> void:
	_check = SquadUnseenCheck.new(POSITIONS)


func test_changing_what_it_cannot_see_changes_none_of_its_decisions() -> void:
	for index: int in range(POSITIONS):
		var changed: String = _check.first_changed_decision(index, func() -> BlueController: return GreedySquad.new())
		if changed != "":
			fail("position %d: %s" % [index, changed])
			return


func test_the_check_catches_a_greedy_shooter_that_sees_everything() -> void:
	assert_int(_check.caught(func() -> BlueController: return SeesEverything.new())).is_greater_equal(AT_LEAST_ALL)


func test_it_takes_the_shot_that_expects_the_most_damage() -> void:
	# The mortar deals 5: the runner at 8 is worth all 5 of it, the wader at 2
	# only 2. The wader is listed first, so the first shot found is the worse.
	var state: BoardState = _board([[RED, TacticalRules.MORTAR, Vector2i(5, 4), 7],
		[BLUE, TacticalRules.WADER, Vector2i(5, 7), 2], [BLUE, TacticalRules.RUNNER, Vector2i(8, 4), 8]])
	var decision: TacticalDecision = GreedySquad.new().decide_attack(state, 1)
	assert_object(decision).is_not_null()
	assert_int(decision.attack.target_id).is_equal(3)


func test_it_shoots_nobody_it_cannot_hit() -> void:
	var state: BoardState = _board([[RED, TacticalRules.RUNNER, Vector2i(1, 2), 8], [BLUE, TacticalRules.RUNNER, Vector2i(12, 6), 8]])
	assert_object(GreedySquad.new().decide_attack(state, 1)).is_null()


func test_with_a_shot_to_be_had_it_walks_to_keep_one() -> void:
	var state: BoardState = _board([[RED, TacticalRules.RUNNER, Vector2i(3, 4), 8], [BLUE, TacticalRules.SHIELD, Vector2i(9, 4), 10]])
	var greedy := GreedySquad.new()
	var decision: TacticalDecision = greedy.decide_move(state, 1)
	var path: Array[Vector2i] = []
	if decision.move != null:
		path = decision.move.path
	assert_bool(SquadRuleset.leaves_a_shot(state, state.unit_by_id(1), path)).is_true()
	assert_object(greedy.decide_attack(_rules.walk(state, Move.new(1, path)) if not path.is_empty() else state, 1)).is_not_null()


func test_with_nobody_in_sight_it_walks_toward_the_other_squads_start() -> void:
	var state: BoardState = _rules.start()
	var unit: Unit = state.unit_by_id(1)
	var decision: TacticalDecision = GreedySquad.new().decide_move(state, 1)
	assert_object(decision.move).is_not_null()
	var goal: Vector2i = SquadScenario.TURNED - SquadScenario.RED_CELLS[0]
	var costs: Dictionary = TacticalReach.route_costs(state.graph_for(unit), goal)
	assert_int(costs[decision.target]).is_less(costs[unit.cell])


func test_a_refused_walk_is_answered_with_a_hold() -> void:
	var greedy := GreedySquad.new()
	var state: BoardState = _rules.start()
	var first: TacticalDecision = greedy.decide_move(state, 1)
	var instead: TacticalDecision = greedy.after_refusal(state, first)
	assert_object(instead).is_not_null()
	assert_int(instead.unit_id).is_equal(1)
	assert_object(instead.move).is_null()


func test_it_is_a_row_of_the_squad_roster() -> void:
	assert_str(SquadRoster.build("greedy", 3).controller_name()).is_equal("greedy")


# A board with only `pieces` -- `[side, piece, cell, health]` each, ids from
# 1 in order -- red to move, on the tactical map.
func _board(pieces: Array) -> BoardState:
	var types: Dictionary = SquadTable.unit_types()
	var units: Array[Unit] = []
	for piece: Array in pieces:
		var kind: UnitType = types[piece[1]]
		units.append(Unit.new(units.size() + 1, piece[0], piece[2], piece[3], kind.movement, kind))
	var start: BoardState = _rules.start()
	var state := BoardState.new(start.graph, units, RED)
	state.movement_graphs = start.movement_graphs
	return state
