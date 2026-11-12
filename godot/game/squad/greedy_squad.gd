## A careless player for the XCOM-style mode (T125): it takes the best shot
## it has, and otherwise walks toward the nearest enemy it knows of. It never
## asks what the enemy could do to it -- no cover sought, no flank feared.
##
## Perceive: its side's view (`SideView`), remembering where it last saw each
## enemy, as `WeighedSquad` does; of the state it is handed it reads nothing
## else but the turn's number. Decide, for the piece about to act:
## 1. a walk -- holding included -- that keeps a shot, the one whose best
##    shot expects the most damage (chance times damage, no more than the
##    target has left);
## 2. with no such walk, the walk that ends nearest, by its own ground, to
##    the nearest enemy it knows of -- the other squad's starting cells
##    while it knows of none, which the map tells everybody;
## 3. then the shot that expects the most damage, never one at 0%.
## Equal options go to the first listed: holding, then the walks in the
## board's order. A walk the board refuses is answered with a hold.
##
## It is the second floor of `make test-squad-floor`: `RandomSquad` loses
## every game to `WeighedSquad` whatever the weighing, so it cannot tell a
## good weighing from a worse one, and this does. The decision's reason is
## its whole thought: the shot it keeps, or the steps it closes.
##
## O(walks x enemies seen) a decision. When not to use it: as an opponent
## for a person who has learnt cover. It walks into the open every time;
## that is what it is for.
class_name GreedySquad
extends BlueController

## The steps a cell with no route to any enemy it knows of is counted at.
const NO_ROUTE: int = 1000

# What its side saw at its last look, remembered from one decision to the
# next; forgotten when a new game starts.
var _memory: SideView
var _last_turn: int = -1


func _init(_seed_number: int = 0) -> void:
	pass


## "greedy".
func controller_name() -> String:
	return "greedy"  # not shown: a roster key


## What it is, for the screen.
func describe() -> String:
	return TranslationServer.translate("the best shot it has, else straight at the nearest enemy, cover never weighed")


## A turn numbered no later than the last one it saw is a new game: what it
## remembered seeing belongs to the old one.
func begin_turn(state: BoardState) -> void:
	if state.turn_number <= _last_turn:
		_memory = null
	_last_turn = state.turn_number


## A squad has no workshop: it never builds.
func decide_build(state: BoardState, workshop_id: int) -> TacticalDecision:
	return TacticalDecision.hold(workshop_id, [], state.unit_by_id(workshop_id).cell)


## The walk that keeps the best shot, or with none, the one that closes in.
func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
	var seen: SideView = _look(state)
	var unit: Unit = seen.state.unit_by_id(unit_id)
	var walks: Dictionary = {unit.cell: [] as Array[Vector2i]}
	walks.merge(TacticalReach.walks_for(seen.state, unit))
	var best_cell: Vector2i = unit.cell
	var best_damage: float = 0.0
	for cell: Vector2i in walks:
		if not SquadRuleset.leaves_a_shot(seen.state, unit, walks[cell]):
			continue
		var damage: float = _best_expected_from(seen, unit, cell)
		if damage > best_damage:
			best_damage = damage
			best_cell = cell
	var why: Array = Sentence.of("keeps its best shot: {damage} damage expected", {damage = "%.1f" % best_damage})  # shown through tr()
	if best_damage <= 0.0:
		best_cell = _closest_to_the_known(seen, unit, walks)
		why = Sentence.of("no shot to keep: walks straight at the nearest enemy it knows of")  # shown through tr()
	if best_cell == unit.cell:
		return TacticalDecision.hold(unit_id, why, unit.cell)
	return TacticalDecision.walk(unit_id, walks[best_cell], why, best_cell)


## The shot that expects the most damage from where `unit_id` stands, or
## null when none expects any.
func decide_attack(state: BoardState, unit_id: int) -> TacticalDecision:
	var seen: SideView = _look(state)
	var shooter: Unit = seen.state.unit_by_id(unit_id)
	var damage: int = SquadTable.number(shooter.type.type_name, "damage")
	var best_target: Unit = null
	var best_expected: float = 0.0
	for enemy: Unit in seen.state.units:
		if SquadCombat.why_refused(seen.state, SquadScenario.rows(), Attack.new(unit_id, enemy.id)) != BoardState.LEGAL:
			continue
		var expected: float = SquadCombat.chance_of(SquadScenario.rows(), shooter, enemy) / 100.0 * mini(damage, enemy.health)
		if expected > best_expected:
			best_expected = expected
			best_target = enemy
	if best_target == null:
		return null
	return TacticalDecision.strike(unit_id, best_target, Sentence.of(  # shown through tr()
		"shoots {piece} at {cell}: {chance}%, the most damage it can expect", {
			piece = TacticalStatus.the_piece_sentence(best_target.type.type_name), cell = best_target.cell,
			chance = SquadCombat.chance_of(SquadScenario.rows(), shooter, best_target)}))


## A hold, for the piece whose walk ran into a piece its side does not see:
## a careless player stops where it is. A hold is never refused.
func after_refusal(state: BoardState, refused: TacticalDecision) -> TacticalDecision:
	var unit: Unit = _look(state).state.unit_by_id(refused.unit_id)
	return TacticalDecision.hold(refused.unit_id, Sentence.of("its way was blocked: it stops"), unit.cell)  # shown through tr()


# Its side's view of `state`, remembering its last look: the only thing it
# reads of the board.
func _look(state: BoardState) -> SideView:
	_memory = SideView.seen_by(state, SquadScenario.rows(), state.current_faction, _memory)
	return _memory


# The most damage `unit` could expect from `cell` with one shot at an enemy
# it sees: chance times damage, no more than the target has left; 0 for no
# shot. The target's cover is in the chance; the shooter's own is never asked.
# Its twin is `WeighedSquad._best_shot_from`: a change to one is owed the other.
func _best_expected_from(seen: SideView, unit: Unit, cell: Vector2i) -> float:
	var rows: Array[String] = SquadScenario.rows()
	var best: float = 0.0
	for enemy: Unit in seen.state.units:
		if enemy.faction == seen.side or not SquadCombat.reaches(rows, cell, unit.type, enemy.cell):
			continue
		var cover: int = SquadCover.of(rows, cell, enemy.cell)["cover"]
		var chance: int = SquadCombat.hit_chance(SquadTable.number(unit.type.type_name, "aim"),
			SquadTable.number(enemy.type.type_name, "defence"), cover)
		best = maxf(best, chance / 100.0 * mini(SquadTable.number(unit.type.type_name, "damage"), enemy.health))
	return best


# Of `walks`, the cell whose route to the nearest enemy `seen` knows of is
# cheapest, on `unit`'s own ground; holding when none is cheaper. The routes
# are `WeighedSquad._routes_to_the_known`'s: a change to one is owed the other.
func _closest_to_the_known(seen: SideView, unit: Unit, walks: Dictionary) -> Vector2i:
	var known: Array[Vector2i] = []
	for enemy_id: int in seen.seen_enemies():
		known.append(seen.state.unit_by_id(enemy_id).cell)
	known.append_array(seen.last_seen.values())
	if known.is_empty():
		for cell: Vector2i in SquadScenario.RED_CELLS:
			known.append(cell if seen.side == TacticalScenario.BLUE else SquadScenario.TURNED - cell)
	var nearest: Dictionary = {}
	for goal: Vector2i in known:
		var costs: Dictionary = TacticalReach.route_costs(seen.state.graph_for(unit), goal)
		for cell: Vector2i in costs:
			nearest[cell] = mini(nearest.get(cell, NO_ROUTE), costs[cell])
	var closest: Vector2i = unit.cell
	for cell: Vector2i in walks:
		if nearest.get(cell, NO_ROUTE) < nearest.get(closest, NO_ROUTE):
			closest = cell
	return closest
