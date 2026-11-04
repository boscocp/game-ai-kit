# T85: `WeighedSquad`, the first enemy of the XCOM-style mode that weighs.
#
# It does not cheat: over seeded positions, what its side cannot see is
# changed -- every unseen enemy moved to another cell it cannot see, its
# health changed, one of them taken off the board, the dice re-seeded -- and
# every one of its decisions stays as it was, the racer's and the bot
# match's "does not cheat" shape. Each decision is asked of a controller
# that has already looked once, at the same side's last turn, so what it
# remembers is under the check too. The same check is shown two controllers
# that cheat -- one reads the whole board, one only the unseen enemies'
# health -- and must catch each on at least a pinned share of the positions.
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


## The share of the positions each planted controller must be caught on,
## a floor under what was measured in wave 119 (SeesEverything 42,
## ReadsUnseenHealth 40, of the 60).
const AT_LEAST_ALL: int = 30
const AT_LEAST_HEALTH: int = 30


## A controller that weighs as `WeighedSquad` does, on the whole board:
## a planted case the does-not-cheat check must catch.
class SeesEverything extends WeighedSquad:
	func _look(state: BoardState) -> SideView:
		return SideView.new(state.current_faction, state, {} as Dictionary[int, Vector2i])


## A controller that weighs on its view, except that it holds whenever the
## enemies' health, read off the whole board, sums to an odd number: the
## planted case for an AI that reads what it was not shown of a piece.
class ReadsUnseenHealth extends WeighedSquad:
	func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
		if SquadVictory.health_left(state, TacticalScenario.FACTIONS - 1 - state.current_faction) % 2 == 1:
			return TacticalDecision.hold(unit_id, [], state.unit_by_id(unit_id).cell)
		return super.decide_move(state, unit_id)


var _rules := SquadRuleset.new()
# Each position, and the same side's position on its turn before, when
# there was one: what the controller looks at first.
var _positions: Array[BoardState] = []
var _earlier: Array[BoardState] = []


func before() -> void:
	for seed_number: int in range(POSITIONS):
		var reached: Array[BoardState] = _position(seed_number)
		_positions.append(reached[1])
		_earlier.append(reached[0])


func test_changing_what_it_cannot_see_changes_none_of_its_decisions() -> void:
	for index: int in range(POSITIONS):
		var changed: String = _first_changed_decision(index, func() -> BlueController: return WeighedSquad.new())
		if changed != "":
			fail("position %d: %s" % [index, changed])
			return


func test_the_check_catches_a_controller_that_sees_everything() -> void:
	assert_int(_caught(func() -> BlueController: return SeesEverything.new())).is_greater_equal(AT_LEAST_ALL)


func test_the_check_catches_a_controller_that_reads_unseen_health() -> void:
	assert_int(_caught(func() -> BlueController: return ReadsUnseenHealth.new())).is_greater_equal(AT_LEAST_HEALTH)


func test_a_refused_walk_is_answered_with_another_that_avoids_its_route() -> void:
	var weighing := WeighedSquad.new()
	var state: BoardState = _rules.start()
	var first: TacticalDecision = weighing.decide_move(state, 1)
	if first.move == null:
		return
	var instead: TacticalDecision = weighing.after_refusal(state, first)
	assert_object(instead).is_not_null()
	assert_int(instead.unit_id).is_equal(1)
	var path: Array[Vector2i] = []
	if instead.move != null:
		path = instead.move.path
	for step: Vector2i in path:
		assert_bool(step in first.move.path).is_false()


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
	var path: Array[Vector2i] = []
	if decision.move != null:
		path = decision.move.path
	assert_bool(SquadRuleset.leaves_a_shot(state, state.unit_by_id(1), path)).is_true()
	assert_object(weighing.decide_attack(_rules.walk(state, Move.new(1, path)) if not path.is_empty() else state, 1)).is_not_null()


# How many positions the check catches `make`'s controllers on.
func _caught(make: Callable) -> int:
	var caught: int = 0
	for index: int in range(POSITIONS):
		if _first_changed_decision(index, make) != "":
			caught += 1
	print("caught on %d of %d positions" % [caught, POSITIONS])
	return caught


# What changes when what the side to move cannot see is changed: the first
# decision of `make`'s controllers that differs, said; "" when none does.
# Each controller has looked once already, at the side's turn before.
func _first_changed_decision(index: int, make: Callable) -> String:
	var state: BoardState = _positions[index]
	var changed: BoardState = _unseen_changed(state, _earlier[index], index)
	if changed == null:
		return ""
	for unit: Unit in state.units_of(state.current_faction):
		var before: String = _decisions(_having_looked(make, index), state, unit.id)
		var after: String = _decisions(_having_looked(make, index), changed, unit.id)
		if before != after:
			return "unit %d decided %s, and with the unseen changed %s" % [unit.id, before, after]
	return ""


# A controller from `make` that has looked at the side's turn before
# position `index` -- asked one decision there -- so it remembers something.
func _having_looked(make: Callable, index: int) -> BlueController:
	var controller: BlueController = make.call()
	var earlier: BoardState = _earlier[index]
	controller.begin_turn(earlier)
	controller.decide_move(earlier, earlier.units_of(earlier.current_faction)[0].id)
	return controller


# A controller's walk and its shot for `unit_id`, both asked of `state`, as
# one line. Both of the same state: a walk played first could end on a cell
# an unseen enemy was moved to, and the board's refusal is not the
# controller's decision.
func _decisions(controller: BlueController, state: BoardState, unit_id: int) -> String:
	var walk: TacticalDecision = controller.decide_move(state, unit_id)
	var shot: TacticalDecision = controller.decide_attack(state, unit_id)
	return "%s %s %s / %s" % [walk.kind(), walk.target, walk.english(), shot.english() if shot != null else "no shot"]


# `state` with what the side to move cannot see changed: every unseen enemy
# on another free cell it does not see either, with one more or one less
# health; one of them -- one it did not see on `earlier` either, so it
# remembers nothing of it -- taken off the board; another dice seed. Null
# when no enemy is unseen.
func _unseen_changed(state: BoardState, earlier: BoardState, seed_number: int) -> BoardState:
	var side: int = state.current_faction
	var changed: BoardState = state.duplicate_state()
	changed.dice_seed = state.dice_seed + 7919
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_number
	var unseen: Array[Unit] = _unseen_enemies(changed, side)
	if unseen.is_empty():
		return null
	for unit: Unit in unseen:
		var cells: Array[Vector2i] = _unseen_free_cells(changed, unit, side)
		if not cells.is_empty():
			unit.cell = cells[dice.randi_range(0, cells.size() - 1)]
		unit.health += -1 if unit.health > 1 else 1
	var seen_before: Array[int] = SideView.seen_by(earlier, SquadScenario.rows(), side).seen_enemies()
	for unit: Unit in unseen:
		if unseen.size() > 1 and not unit.id in seen_before:
			unit.health = 0
			break
	return changed.duplicate_state()  # built again, so a piece at 0 is gone


func _unseen_enemies(state: BoardState, side: int) -> Array[Unit]:
	var found: Array[Unit] = []
	for unit: Unit in state.units:
		if unit.faction != side and not SideView.is_seen(state, SquadScenario.rows(), side, unit.cell):
			found.append(unit)
	return found


func _unseen_free_cells(state: BoardState, unit: Unit, side: int) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for cell: Vector2i in SquadRuleset.every_cell():
		var free: bool = cell != unit.cell and state.unit_at(cell) == null and not state.graph_for(unit).is_blocked(cell)
		if free and not SideView.is_seen(state, SquadScenario.rows(), side, cell):
			found.append(cell)
	return found


# The position seed `seed_number` reaches, as `squad_properties_test.gd`
# reaches its own -- random legal actions from the start -- and, first, the
# last state before it with the same side to move on an earlier turn (the
# start when there is none): `[earlier, position]`.
func _position(seed_number: int) -> Array[BoardState]:
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_number
	var state: BoardState = _rules.start()
	state.dice_seed = seed_number
	var turns: Array[BoardState] = [state]
	for _step: int in range(dice.randi_range(0, MOST_ACTIONS_BEFORE)):
		if _rules.winner(state) != TacticalVictory.NOBODY:
			break
		var actions: Array = _rules.actions(state)
		if actions.is_empty() or dice.randi_range(0, 5) == 0:
			state = _rules.open_turn(state)[0]
			turns.append(state)
		else:
			state = _rules.play(state, actions[dice.randi_range(0, actions.size() - 1)])
	var earlier: BoardState = turns[maxi(0, turns.size() - 1 - TacticalScenario.FACTIONS)]
	if earlier.current_faction != state.current_faction:
		earlier = turns[0] if turns[0].current_faction == state.current_faction else state
	return [earlier, state]


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
