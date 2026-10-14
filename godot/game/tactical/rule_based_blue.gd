## Blue played by two rules: the simplest opponent that still does something
## on purpose, and the baseline T11's planner and T12's difficulties are
## measured against.
##
## - **Build** the type that beats the most red pieces, by the counter table,
##   among the types it can build and pay for now.
## - **Walk** every unit at red's workshop, which is what wins the game, by
##   the route it would really walk -- for anything that is not a wader, over
##   the bridge.
##
## T30 first asked for "walk at the nearest enemy". Measured, that never won:
## the nearest red piece is a bolt tower, and sixty rounds later thirty blue
## shields stood round it while the workshop two cells away stood untaken.
## Aiming at the goal is still a reflex, and now it is one that can win.
##
## Rules are a reflex: they answer what is on the board now and never what is
## coming. That is the weakness T11's plan exists to beat, and why the screen
## calls this "rules, not a plan".
##
## Complexity: per walking unit per turn, three floods of the board -- to
## find the nearest workshop, for its reach, and back from the target -- each
## O(cells^2) with the plain-array frontier `TacticalReach` uses.
##
## When not to use it: as a strong opponent. It never buys the forge, so it
## never builds a ram; it walks into anything; and until T26 brings combat
## nothing punishes it for either.
class_name RuleBasedBlue
extends BlueController

# Larger than any walk on any board this scenario has.
const UNREACHABLE: int = 1 << 30


## "rules": the name the header and the overlay use.
func controller_name() -> String:
	return "rules"


## Says on screen that this is a reflex and not a plan, and what the reflex is.
func describe() -> String:
	return "rules, not a plan: build what beats the most red pieces, walk every unit at red's workshop"


## The type that beats the most enemy pieces, among those it can build and
## pay for now. Ties go to the earlier type in `TacticalRules.BUILDABLE`, so
## the same board always gets the same answer.
func decide_build(state: BoardState, workshop_id: int) -> TacticalDecision:
	var workshop: Unit = state.unit_by_id(workshop_id)
	var enemies: Array[Unit] = _enemies(state)
	var best: ProductionOrder = null
	var best_count: int = 0
	for kind: UnitType in _buildable(state, workshop):
		var count: int = _beaten_by(kind, enemies).size()
		if count > best_count:
			best = ProductionOrder.new(workshop_id, kind, TacticalRules.free_cell_beside(state, workshop, kind))
			best_count = count
	if best == null:
		return TacticalDecision.hold(workshop_id, "builds nothing: " + _why_nothing(state, workshop), workshop.cell)
	var beaten: Array[String] = _beaten_by(best.unit_type, enemies)
	return TacticalDecision.build(workshop_id, best, (
		"builds a %s at %s: it beats %d red piece(s), %s. There is no combat until T26, so for now the choice changes nothing"
	) % [best.unit_type.type_name, best.cell, best_count, ", ".join(beaten)])


## A walk towards the nearest enemy workshop, as far as this turn's movement
## goes, or a hold when no walk brings it nearer.
func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
	var unit: Unit = state.unit_by_id(unit_id)
	var target: Unit = _nearest_workshop(state, unit)
	if target == null:
		return TacticalDecision.hold(unit_id, "stays: no route reaches a red workshop at all", unit.cell)
	var walks: Dictionary = TacticalReach.walks_for(state, unit)
	var to_target: Dictionary = TacticalReach.route_costs(state.graph_for(unit), target.cell)
	var best: Vector2i = unit.cell
	for cell: Vector2i in walks:
		if _remaining(state, unit, cell, to_target, target) < _remaining(state, unit, best, to_target, target):
			best = cell
	var aim: String = "the %s at %s" % [target.type.type_name, target.cell]
	if best == unit.cell:
		return TacticalDecision.hold(unit_id, "stays: no walk this turn brings it nearer %s" % aim, unit.cell)
	return TacticalDecision.walk(unit_id, walks[best], "walks to %s, towards %s%s" % [
		best, aim, _crossing(unit, target)], best)


# Why the workshop builds nothing: no room, no money, or nothing worth it.
# Asked of the cheapest type, because if that cannot be built, none can.
func _why_nothing(state: BoardState, workshop: Unit) -> String:
	var cheapest: UnitType = TacticalRules.unit_types()[TacticalRules.RUNNER]
	var order := ProductionOrder.new(workshop.id, cheapest, TacticalRules.free_cell_beside(state, workshop, cheapest))
	var refusal: String = state.why_production_refused(order)
	if refusal != BoardState.LEGAL:
		return refusal
	return "nothing it can build and pay for beats any red piece"


# Every buildable type the workshop could build and pay for this turn.
func _buildable(state: BoardState, workshop: Unit) -> Array[UnitType]:
	var types: Dictionary = TacticalRules.unit_types()
	var found: Array[UnitType] = []
	for type_name: String in TacticalRules.BUILDABLE:
		var kind: UnitType = types[type_name]
		var order := ProductionOrder.new(workshop.id, kind, TacticalRules.free_cell_beside(state, workshop, kind))
		if state.why_production_refused(order) == BoardState.LEGAL:
			found.append(kind)
	return found


# The names of the enemy pieces `kind` beats, by the counter table.
func _beaten_by(kind: UnitType, enemies: Array[Unit]) -> Array[String]:
	var beaten: Array[String] = []
	for enemy: Unit in enemies:
		if enemy.type.type_name in kind.strong_against:
			beaten.append(enemy.type.type_name)
	return beaten


func _enemies(state: BoardState) -> Array[Unit]:
	var found: Array[Unit] = []
	for unit: Unit in state.units:
		if unit.faction != state.current_faction:
			found.append(unit)
	return found


# The enemy workshop the cheapest walk reaches, counting terrain and ignoring
# who stands in the way. Ties go to the lower id.
func _nearest_workshop(state: BoardState, unit: Unit) -> Unit:
	var costs: Dictionary = TacticalReach.route_costs(state.graph_for(unit), unit.cell)
	var nearest: Unit = null
	for enemy: Unit in _enemies(state):
		if enemy.type.type_name != TacticalRules.WORKSHOP or not costs.has(enemy.cell):
			continue
		if nearest == null or costs[enemy.cell] < costs[nearest.cell]:
			nearest = enemy
	return nearest


# What is left to walk from `cell` to the target. `to_target` was flooded out
# *from* the target, so it charges for entering `cell` and not for entering
# the target; walking the other way charges the opposite. The difference is
# the same on every route, so it is corrected exactly by those two cells.
func _remaining(state: BoardState, unit: Unit, cell: Vector2i, to_target: Dictionary,
		target: Unit) -> int:
	if not to_target.has(cell):
		return UNREACHABLE
	var graph: GridGraph = state.graph_for(unit)
	return to_target[cell] - graph.cost_at(cell) + graph.cost_at(target.cell)


# Said when the walk is on its way over the river, and only then.
func _crossing(unit: Unit, target: Unit) -> String:
	if not TacticalScenario.across_the_river(unit.cell, target.cell):
		return ""
	if TacticalScenario.MAP[unit.cell.y][unit.cell.x] == TacticalRules.BRIDGE:
		return ", crossing the bridge"
	if unit.type.mover == TacticalRules.WATER_MOVER:
		return ", wading across the river"
	return ", making for the bridge"
