## Blue played by two rules: the simplest opponent that still does something
## on purpose, and the baseline T11's planner and T12's difficulties are
## measured against.
##
## - **Build** the type that beats the most red pieces, by the counter table,
##   among the types it can build and pay for now **and that can still reach
##   red's workshop** -- and, when no piece of blue's can, one that can even
##   if it beats nothing.
## - **Walk** every unit at red's workshop, which is what wins the game, by
##   the route it would really walk -- for anything that is not a wader, over
##   the bridge.
##
## T30 first asked for "walk at the nearest enemy". Measured, that never won:
## the nearest red piece is a bolt tower, and sixty rounds later thirty blue
## shields stood round it while the workshop two cells away stood untaken.
## Aiming at the goal is still a reflex, and now it is one that can win.
##
## Both rules count red's pieces as walls, and that is T41. Until T26 brings
## combat nothing can *push* a piece aside, so a red runner parked on the
## bridge shuts it for as long as red leaves it there. Blue's route used to
## ignore who stood on it: it built a shield a turn, piled two dozen behind
## the river, and drew at round 40 -- with the water open all along to the
## wader it never built. Of the two halves it is the build rule that wins
## those games; the walking half is what makes a shut-out walker say why.
##
## Rules are a reflex: they answer what is on the board now and never what is
## coming. That is the weakness T11's plan exists to beat, and why the screen
## calls this "rules, not a plan".
##
## Complexity: per walking unit per turn, three floods of the board -- to
## find the nearest workshop, for its reach, and back from the target -- each
## O(cells^2) with the plain-array frontier `TacticalReach` uses. The
## workshop adds one flood per buildable type and one per walker of blue's,
## for the reach rule. Over 40 games against a random red, a blue turn
## averages 4.9 ms against 3.6 before it (the second figure the review's).
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


## The type that beats the most enemy pieces, among those it can build, pay
## for, and walk to red's workshop from where it would stand. Ties go to the
## earlier type in `TacticalRules.BUILDABLE`, so the same board always gets
## the same answer.
func decide_build(state: BoardState, workshop_id: int) -> TacticalDecision:
	var workshop: Unit = state.unit_by_id(workshop_id)
	var enemies: Array[Unit] = _enemies(state)
	var best: ProductionOrder = null
	# Beating nothing is worth a build only when no piece of blue's can get
	# there: a shut bridge then makes the wader the only move that matters.
	var best_count: int = -1 if _nobody_reaches(state) else 0
	for kind: UnitType in _buildable(state, workshop):
		if not _reaches(state, kind, TacticalRules.free_cell_beside(state, workshop, kind)):
			continue
		var count: int = _beaten_by(kind, enemies).size()
		if count > best_count:
			best = ProductionOrder.new(workshop_id, kind, TacticalRules.free_cell_beside(state, workshop, kind))
			best_count = count
	if best == null:
		return TacticalDecision.hold(workshop_id, "builds nothing: " + _why_nothing(state, workshop), workshop.cell)
	var beaten: Array[String] = _beaten_by(best.unit_type, enemies)
	if beaten.is_empty():
		return TacticalDecision.build(workshop_id, best, (
			"builds a %s at %s: red's pieces shut every way blue's walkers have, and a %s still gets there"
		) % [best.unit_type.type_name, best.cell, best.unit_type.type_name])
	return TacticalDecision.build(workshop_id, best, (
		"builds a %s at %s: it beats %d red piece(s), %s. There is no combat until T26, so for now the choice changes nothing"
	) % [best.unit_type.type_name, best.cell, best_count, ", ".join(beaten)])


## A walk towards the nearest enemy workshop, as far as this turn's movement
## goes, or a hold when no walk brings it nearer.
func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
	var unit: Unit = state.unit_by_id(unit_id)
	var target: Unit = _nearest_workshop(state, unit)
	if target == null:
		return TacticalDecision.hold(unit_id,
			"stays: red's pieces stand on every way to red's workshop this turn", unit.cell)
	var walks: Dictionary = TacticalReach.walks_for(state, unit)
	var to_target: Dictionary = TacticalReach.route_costs(_past_red(state, unit.type), target.cell)
	var best: Vector2i = unit.cell
	for cell: Vector2i in walks:
		if _remaining(state, unit, cell, to_target, target) < _remaining(state, unit, best, to_target, target):
			best = cell
	var aim: String = "the %s at %s" % [target.type.type_name, target.cell]
	if best == unit.cell:
		return TacticalDecision.hold(unit_id, "stays: no walk this turn brings it nearer %s" % aim, unit.cell)
	return TacticalDecision.walk(unit_id, walks[best], "walks to %s, towards %s%s" % [
		best, aim, _crossing(unit, target)], best)


# The board as `kind` walks it, with every red piece but its workshops made a
# wall. A workshop stays open because it is the target: winning is standing
# beside it, and a flood out of a wall would reach nothing.
func _past_red(state: BoardState, kind: UnitType) -> GridGraph:
	var graph: GridGraph = state.graph_for_type(kind).duplicate_graph()
	for enemy: Unit in _enemies(state):
		if enemy.type.type_name != TacticalRules.WORKSHOP:
			graph.block(enemy.cell)
	return graph


# True when a `kind` standing on `cell` has a way to a red workshop.
func _reaches(state: BoardState, kind: UnitType, cell: Vector2i) -> bool:
	var costs: Dictionary = TacticalReach.route_costs(_past_red(state, kind), cell)
	for enemy: Unit in _enemies(state):
		if enemy.type.type_name == TacticalRules.WORKSHOP and costs.has(enemy.cell):
			return true
	return false


# True when no walker of blue's has a way to a red workshop -- including when
# blue has no walker at all.
func _nobody_reaches(state: BoardState) -> bool:
	for unit: Unit in state.units_of(state.current_faction):
		if unit.type.mobile and _reaches(state, unit.type, unit.cell):
			return false
	return true


# Why the workshop builds nothing: no room, no money, nothing worth it, or
# nothing worth it that could get there.
# Asked of the cheapest type, because if that cannot be built, none can.
func _why_nothing(state: BoardState, workshop: Unit) -> String:
	var cheapest: UnitType = TacticalRules.unit_types()[TacticalRules.RUNNER]
	var order := ProductionOrder.new(workshop.id, cheapest, TacticalRules.free_cell_beside(state, workshop, cheapest))
	var refusal: String = state.why_production_refused(order)
	if refusal != BoardState.LEGAL:
		return refusal
	for kind: UnitType in _buildable(state, workshop):
		if not _beaten_by(kind, _enemies(state)).is_empty():
			return "what would beat red's pieces cannot get past them to red's workshop, and a walker of blue's already can"
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


# The enemy workshop the cheapest walk reaches, counting terrain and red's
# pieces as walls, and ignoring blue's own, which move. Ties go to the lower
# id.
func _nearest_workshop(state: BoardState, unit: Unit) -> Unit:
	var costs: Dictionary = TacticalReach.route_costs(_past_red(state, unit.type), unit.cell)
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
