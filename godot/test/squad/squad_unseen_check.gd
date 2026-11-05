# The does-not-cheat check of the XCOM-style mode (T85), for any controller
# of it: over seeded positions, what the side to move cannot see is changed
# -- every unseen enemy moved to another cell it cannot see, its health
# changed, one of them taken off the board, the dice re-seeded -- and every
# one of the controller's decisions must stay as it was. Each decision is
# asked of a controller that has already looked once, at the same side's
# last turn, so what it remembers is under the check too.
#
# Written for `WeighedSquad` in wave 119 and moved here for `MctsSquad`
# (T87), so the two are held by one check: `weighed_squad_test.gd` and
# `mcts_squad_test.gd` each show it its planted cheats.
class_name SquadUnseenCheck
extends RefCounted

const MOST_ACTIONS_BEFORE: int = 40

var _rules := SquadRuleset.new()
# Each position, and the same side's position on its turn before, when
# there was one: what the controller looks at first.
var _positions: Array[BoardState] = []
var _earlier: Array[BoardState] = []


## The check over `count` positions, reached once: reaching them is most of
## what it costs.
func _init(count: int) -> void:
	for seed_number: int in range(count):
		var reached: Array[BoardState] = _position(seed_number)
		_positions.append(reached[1])
		_earlier.append(reached[0])


## How many positions there are.
func size() -> int:
	return _positions.size()


## The position numbered `index`.
func position(index: int) -> BoardState:
	return _positions[index]


## How many positions `make`'s controllers change a decision on.
func caught(make: Callable) -> int:
	var found: int = 0
	for index: int in range(_positions.size()):
		if first_changed_decision(index, make) != "":
			found += 1
	print("caught on %d of %d positions" % [found, _positions.size()])
	return found


## What changes when what the side to move cannot see is changed: the first
## decision of `make`'s controllers that differs, said; "" when none does.
func first_changed_decision(index: int, make: Callable) -> String:
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
	var shot_said: String = "no shot"
	if shot != null:
		shot_said = "%s %s %s" % [shot.kind(), shot.target, shot.english()]
	return "%s %s %s / %s" % [walk.kind(), walk.target, walk.english(), shot_said]


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
