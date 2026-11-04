# T85: `WeighedSquad`, the first enemy of the XCOM-style mode that weighs.
#
# It does not cheat: over seeded positions, every unseen enemy moved to
# another cell it cannot see -- and the dice seed changed -- leaves every one
# of its decisions as it was, the racer's and the bot match's "does not
# cheat" shape. The same check is shown a controller that reads the whole
# board, and must catch it.
#
# A seeded game of it against itself replays to the digest written below; a
# change to the rules or the weighing that moves a single die moves the
# digest, and it is then written again, in the same commit, on purpose.
#
# And it weighs as it says: the shot that destroys, a walk that keeps the
# shot, every option kept with one chosen.
extends GdUnitTestSuite

const RED: int = TacticalScenario.RED
const BLUE: int = TacticalScenario.BLUE
const POSITIONS: int = 60
const MOST_ACTIONS_BEFORE: int = 40
## The seeded self-play game's digest, as `SquadMatch.play` writes it.
## Measured in wave 119: blue wins in round 8, no decision refused.
const SEEDED_GAME_DIGEST: String = "84e68b7045069e409e577f589f5b50cdac3336e9cedb883f471fe4d50607dc9c"


## A controller that weighs as `WeighedSquad` does, on the whole board:
## the planted case the does-not-cheat check must catch.
class SeesEverything extends WeighedSquad:
	func _look(state: BoardState) -> SideView:
		return SideView.new(state.current_faction, state, {} as Dictionary[int, Vector2i])


var _rules := SquadRuleset.new()
var _positions: Array[BoardState] = []


func before() -> void:
	for seed_number: int in range(POSITIONS):
		_positions.append(_position(seed_number))


func test_moving_what_it_cannot_see_changes_none_of_its_decisions() -> void:
	for seed_number: int in range(POSITIONS):
		var changed: String = _first_changed_decision(_positions[seed_number], seed_number, func() -> BlueController: return WeighedSquad.new())
		if changed != "":
			fail("position %d: %s" % [seed_number, changed])
			return


func test_the_check_catches_a_controller_that_sees_everything() -> void:
	var caught: int = 0
	for seed_number: int in range(POSITIONS):
		if _first_changed_decision(_positions[seed_number], seed_number, func() -> BlueController: return SeesEverything.new()) != "":
			caught += 1
	assert_int(caught).is_greater(0)


func test_a_seeded_game_against_itself_replays_to_its_digest() -> void:
	var played: Dictionary = SquadMatch.play(WeighedSquad.new(), WeighedSquad.new(), 11)
	assert_str(SquadMatch.play(WeighedSquad.new(), WeighedSquad.new(), 11)["digest"]).is_equal(played["digest"])
	assert_str(played["digest"]).is_equal(SEEDED_GAME_DIGEST)


func test_it_takes_the_shot_that_destroys() -> void:
	var state: BoardState = _board([[RED, TacticalRules.MORTAR, Vector2i(5, 4), 7],
		[BLUE, TacticalRules.RUNNER, Vector2i(8, 4), 8], [BLUE, TacticalRules.WADER, Vector2i(5, 7), 4]])
	var decision: TacticalDecision = WeighedSquad.new().decide_attack(state, 1)
	assert_object(decision).is_not_null()
	assert_int(decision.attack.target_id).is_equal(3)  # the wader has 4 left, the mortar deals 5


func test_it_shoots_nobody_it_cannot_hit() -> void:
	var state: BoardState = _board([[RED, TacticalRules.RUNNER, Vector2i(1, 2), 8], [BLUE, TacticalRules.RUNNER, Vector2i(12, 6), 8]])
	assert_object(WeighedSquad.new().decide_attack(state, 1)).is_null()


func test_every_walk_it_weighed_is_kept_and_one_is_chosen() -> void:
	var weighing := WeighedSquad.new()
	var state: BoardState = _rules.start()
	var decision: TacticalDecision = weighing.decide_move(state, 1)
	var walks: Dictionary = TacticalReach.walks_for(state, state.unit_by_id(1))
	assert_int(weighing.weighed().size()).is_equal(walks.size() + 1)  # every walk, and holding
	var chosen: Array = weighing.weighed().filter(func(option: Dictionary) -> bool: return option["chosen"])
	assert_int(chosen.size()).is_equal(1)
	assert_object(chosen[0]["cell"]).is_equal(decision.target)
	for option: Dictionary in weighing.weighed():
		assert_float(option["score"]).is_less_equal(chosen[0]["score"])


func test_with_an_enemy_in_sight_it_keeps_a_shot_rather_than_dash() -> void:
	var state: BoardState = _board([[RED, TacticalRules.RUNNER, Vector2i(3, 4), 8], [BLUE, TacticalRules.SHIELD, Vector2i(9, 4), 10]])
	var weighing := WeighedSquad.new()
	var decision: TacticalDecision = weighing.decide_move(state, 1)
	var path: Array[Vector2i] = decision.move.path if decision.move != null else [] as Array[Vector2i]
	assert_bool(SquadRuleset.leaves_a_shot(state, state.unit_by_id(1), path)).is_true()
	assert_object(weighing.decide_attack(_rules.walk(state, Move.new(1, path)) if not path.is_empty() else state, 1)).is_not_null()


# What changes when every enemy the side to move cannot see is moved to
# another cell it cannot see, and the dice are re-seeded: the first decision
# of `make`'s controllers that differs, said; "" when none does.
func _first_changed_decision(state: BoardState, seed_number: int, make: Callable) -> String:
	var moved: BoardState = _unseen_moved(state, seed_number)
	if moved == null:
		return ""
	for unit: Unit in state.units_of(state.current_faction):
		var before: String = _decisions(make.call(), state, unit.id)
		var after: String = _decisions(make.call(), moved, unit.id)
		if before != after:
			return "unit %d decided %s, and with the unseen moved %s" % [unit.id, before, after]
	return ""


# A controller's walk and its shot for `unit_id`, both asked of `state`, as
# one line. Both of the same state: a walk played first could end on a cell
# an unseen enemy was moved to, and the board's refusal is not the
# controller's decision.
func _decisions(controller: BlueController, state: BoardState, unit_id: int) -> String:
	var walk: TacticalDecision = controller.decide_move(state, unit_id)
	var shot: TacticalDecision = controller.decide_attack(state, unit_id)
	return "%s %s %s / %s" % [walk.kind(), walk.target, walk.english(), shot.english() if shot != null else "no shot"]


# `state` with every enemy the side to move does not see on another free
# cell it does not see either, and another dice seed; null when no enemy is
# unseen or none can move.
func _unseen_moved(state: BoardState, seed_number: int) -> BoardState:
	var rows: Array[String] = SquadScenario.rows()
	var side: int = state.current_faction
	var moved: BoardState = state.duplicate_state()
	moved.dice_seed = state.dice_seed + 7919
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_number
	var any: bool = false
	for unit: Unit in moved.units:
		if unit.faction == side or SideView.is_seen(moved, rows, side, unit.cell):
			continue
		var cells: Array[Vector2i] = _unseen_free_cells(moved, unit, side)
		if not cells.is_empty():
			unit.cell = cells[dice.randi_range(0, cells.size() - 1)]
			any = true
	return moved if any else null


func _unseen_free_cells(state: BoardState, unit: Unit, side: int) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for cell: Vector2i in SquadRuleset.every_cell():
		var free: bool = cell != unit.cell and state.unit_at(cell) == null and not state.graph_for(unit).is_blocked(cell)
		if free and not SideView.is_seen(state, SquadScenario.rows(), side, cell):
			found.append(cell)
	return found


# The position seed `seed_number` reaches, as `squad_properties_test.gd`
# reaches its own: random legal actions from the start.
func _position(seed_number: int) -> BoardState:
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_number
	var state: BoardState = _rules.start()
	state.dice_seed = seed_number
	for _step: int in range(dice.randi_range(0, MOST_ACTIONS_BEFORE)):
		if _rules.winner(state) != TacticalVictory.NOBODY:
			break
		var actions: Array = _rules.actions(state)
		if actions.is_empty() or dice.randi_range(0, 5) == 0:
			state = _rules.open_turn(state)[0]
		else:
			state = _rules.play(state, actions[dice.randi_range(0, actions.size() - 1)])
	return state


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
