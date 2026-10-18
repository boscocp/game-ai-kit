## Blue played by two rules: the simplest opponent that still does something
## on purpose, and the baseline T11's planner and T12's difficulties are
## measured against.
##
## - **Build** the type that beats the most red pieces, by the counter table,
##   among the types it can build and pay for now **and that can still reach
##   red's workshop** -- and, when no piece of blue's can, one that can even
##   if it beats nothing.
## - **Attack**, once a unit has walked, red's workshop if it is in reach --
##   that wins -- and otherwise the red piece in reach it beats by the counter
##   table, weakest first. Nothing it does not beat (T26).
## - **Walk** every unit at red's workshop, which is what wins the game, by
##   the route it would really walk -- for anything that is not a wader, over
##   the bridge.
##
## T30 first asked for "walk at the nearest enemy". Measured, that never won:
## the nearest red piece is a bolt tower, and sixty rounds later thirty blue
## shields stood round it while the workshop two cells away stood untaken.
## Aiming at the goal is still a reflex, and now it is one that can win.
##
## Both rules count red's pieces as walls, and that is T41. Nothing can walk
## through a piece, so a red runner parked on the bridge shuts it for as long
## as red leaves it there -- or, since T26, until a blue piece that beats it
## comes to attack it. Blue's route used to
## ignore who stood on it: it built a shield a turn, piled two dozen behind
## the river, and drew at round 40 -- with the water open all along to the
## wader it never built. Of the two halves it is the build rule that wins
## those games; the walking half is what makes a shut-out walker say why.
##
## Three rules since T45, each Wesnoth's (`docs/design/tactical-references.md`,
## §2.1), whose AI ranks recruiting above every move and gives a unit with
## nothing better to do a last, low goal:
##
## - **Spend first.** When nothing that could reach red's workshop beats a red
##   piece, it still builds the type that beats the most of them -- it holds
##   blue's bank until the way opens -- or, when nothing beats anything, the
##   cheapest. Money banked is a piece that is not on the board. A workshop
##   with no room beside it says so, and `BlueTurn` asks it again once the
##   walkers have moved off.
## - **Never idle.** A walker whose goal is out of reach -- every way shut, or
##   no walk bringing it nearer -- walks at the nearest red piece it can get
##   nearer to instead of standing in a queue.
## - **One piece per target.** In one turn a control point is the goal of one
##   walker, and red's workshop of as many as it has cells beside it; the rest
##   take the fallback above.
##
## Rules are a reflex: they answer what is on the board now and never what is
## coming. That is the weakness T11's plan exists to beat, and why the screen
## calls this "rules, not a plan".
##
## Complexity: per walking unit per turn, three floods of the board -- to
## find the nearest workshop, for its reach, and back from the target -- each
## O(cells^2) with the plain-array frontier `TacticalReach` uses, and up to
## `FALLBACK_CANDIDATES` more for a walker that takes the fallback. The
## workshop adds one flood per buildable type and one per walker of blue's,
## for the reach rule. Over 40 games against a random red, a blue turn
## averaged 4.9 ms before T45. With T45's rules the learned side's turn
## roughly doubled in wave 49's review (mean 9.6 to 18.5 ms, the longest 22
## to 42), mostly because it now has more pieces to move; no one decision
## took more than 3.1 ms.
##
## When not to use it: as a strong opponent. It never buys the forge, so it
## never builds a ram; and it walks into anything -- past a bolt tower, up to a
## piece that beats it -- which since T26 costs it units.
class_name RuleBasedBlue
extends BlueController

# Larger than any walk on any board this scenario has.
const UNREACHABLE: int = 1 << 30

## What the workshop says when every cell beside it is taken -- which the
## board would report as "(12, 1) is not next to unit 6", the producer's own
## cell, because that is where `free_cell_beside` points when there is none.
const NO_ROOM: String = "no room beside the workshop: every cell next to it is taken"

# How many red pieces the fallback considers, nearest first. Each costs a
# flood of the board, and the nearest few are where a fight would be anyway.
const FALLBACK_CANDIDATES: int = 3

# Goals blue's walkers have taken this turn: cell -> how many walkers.
var _claims: Dictionary[Vector2i, int] = {}


## "rules": the name the header and the overlay use.
func controller_name() -> String:
	return "rules"


## Says on screen that this is a reflex and not a plan, and what the reflex is.
func describe() -> String:
	return "rules, not a plan: build what beats the most red pieces, walk every unit at red's workshop"


## A new turn: nobody has claimed a goal yet.
func begin_turn(_state: BoardState) -> void:
	_claims.clear()


## One walk asked for outside a turn, as `DecisionPolicy` asks it: the goals
## other walkers took are forgotten first, so the same question on the same
## board always gets the same answer. Inside a turn `BlueTurn` asks
## `decide_move` directly and the claims carry from walker to walker.
func choose(state: BoardState, unit_id: int) -> Move:
	_claims.clear()
	return super.choose(state, unit_id)


## The type that beats the most enemy pieces, among those it can build, pay
## for, and walk to red's workshop from where it would stand -- and when none
## of those beats anything, the spending fallback in the header. Ties go to the
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
		return _spend_anyway(state, workshop, enemies)
	var beaten: Array[String] = _beaten_by(best.unit_type, enemies)
	if beaten.is_empty():
		return TacticalDecision.build(workshop_id, best, (
			"builds a %s at %s: red's pieces shut every way blue's walkers have, and a %s still gets there"
		) % [best.unit_type.type_name, best.cell, best.unit_type.type_name])
	return TacticalDecision.build(workshop_id, best, (
		"builds a %s at %s: it beats %d red piece(s), %s"
	) % [best.unit_type.type_name, best.cell, best_count, ", ".join(beaten)])


## A walk towards the nearest enemy workshop, as far as this turn's movement
## goes; a hold when it is already in reach to attack it; the fallback when
## the workshop is out of reach or already has its walkers this turn.
func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
	var unit: Unit = state.unit_by_id(unit_id)
	var walks: Dictionary = TacticalReach.walks_for(state, unit)
	var target: Unit = _nearest_workshop(state, unit)
	if target == null:
		return _fallback(state, unit, walks, "red's pieces stand on every way to red's workshop this turn")
	var aim: String = "the %s at %s" % [target.type.type_name, target.cell]
	if TacticalCombat.distance(unit.cell, target.cell) <= unit.type.attack_range:
		_claim(state, target.cell)
		return TacticalDecision.hold(unit_id, "stays in reach of %s, to attack it" % aim, unit.cell)
	if not _claim(state, target.cell):
		return _fallback(state, unit, walks, "%s already has a walker of blue's for each cell beside it" % aim)
	var best: Vector2i = _nearest_walk_to(state, unit, walks, target.cell)
	if best == unit.cell:
		_claims[target.cell] -= 1
		return _fallback(state, unit, walks, "no walk this turn brings it nearer %s" % aim)
	return TacticalDecision.walk(unit_id, walks[best], "walks to %s, towards %s%s" % [
		best, aim, _crossing(unit, target)], best)


## Take `goal` for one more walker this turn, if it has room: one for a
## control point, one per open cell beside it for anything else. False, and
## nothing taken, when it is full.
func _claim(state: BoardState, goal: Vector2i) -> bool:
	if _claims.get(goal, 0) >= _room_at(state, goal):
		return false
	_claims[goal] = _claims.get(goal, 0) + 1
	return true


# How many walkers `goal` takes in one turn (see `_claim`).
func _room_at(state: BoardState, goal: Vector2i) -> int:
	if goal in TacticalScenario.POINTS:
		return 1
	var open: int = 0
	for step: Vector2i in GridGraph.DIRECTIONS:
		open += 0 if state.graph.is_blocked(goal + step) else 1
	return open


## Never idle (T45): a walker whose goal is out of reach walks at the nearest
## red piece -- of the `FALLBACK_CANDIDATES` nearest as the crow flies -- that
## some walk brings it nearer and that has not already as many of blue's
## walkers heading for it as it has open cells beside it; it holds only when
## none does. `why` is why
## its goal was out of reach, for the reason.
func _fallback(state: BoardState, unit: Unit, walks: Dictionary, why: String) -> TacticalDecision:
	for enemy: Unit in _nearest_enemies(state, unit):
		if _claims.get(enemy.cell, 0) >= _room_at(state, enemy.cell):
			continue
		var best: Vector2i = _nearest_walk_to(state, unit, walks, enemy.cell)
		var said: String = "walks to %s, towards the %s at %s: %s, so it goes for the nearest red piece it can (a fallback rule)" % [
			best, enemy.type.type_name, enemy.cell, why]
		if best != unit.cell:
			_claim(state, enemy.cell)
			return TacticalDecision.walk(unit.id, walks[best], said, best)
	return TacticalDecision.hold(unit.id, "stays: no walk this turn brings it nearer its goal or any red piece -- %s" % why, unit.cell)


# Red's pieces nearest `unit` as the crow flies, at most
# `FALLBACK_CANDIDATES` of them, ties to the lower id.
func _nearest_enemies(state: BoardState, unit: Unit) -> Array[Unit]:
	var enemies: Array[Unit] = _enemies(state)
	enemies.sort_custom(func(one: Unit, other: Unit) -> bool:
		var apart: int = TacticalCombat.distance(unit.cell, one.cell) - TacticalCombat.distance(unit.cell, other.cell)
		return apart < 0 or (apart == 0 and one.id < other.id))
	return enemies.slice(0, FALLBACK_CANDIDATES)


# Spend first (T45): nothing that can reach red's workshop beats a red piece,
# so build what beats the most of them anyway -- it holds blue's bank -- or,
# when nothing beats anything, the cheapest thing it can build. Only no room
# or no money builds nothing.
func _spend_anyway(state: BoardState, workshop: Unit, enemies: Array[Unit]) -> TacticalDecision:
	var buildable: Array[UnitType] = _buildable(state, workshop)
	if buildable.is_empty():
		return TacticalDecision.hold(workshop.id, "builds nothing: " + _why_nothing(state, workshop), workshop.cell)
	var best: UnitType = buildable[0]
	for kind: UnitType in buildable:
		var more: int = _beaten_by(kind, enemies).size() - _beaten_by(best, enemies).size()
		if more > 0 or (more == 0 and kind.cost < best.cost):
			best = kind
	var order := ProductionOrder.new(workshop.id, best, TacticalRules.free_cell_beside(state, workshop, best))
	var beaten: Array[String] = _beaten_by(best, enemies)
	if beaten.is_empty():
		return TacticalDecision.build(workshop.id, order, "builds a %s at %s: nothing it can build beats a red piece, and money banked is a piece not on the board (spend first)" % [best.type_name, order.cell])
	return TacticalDecision.build(workshop.id, order, "builds a %s at %s: it beats %d red piece(s), %s -- none of what beats them can get to red's workshop now, so it holds blue's bank until the way opens (spend first)" % [
		best.type_name, order.cell, beaten.size(), ", ".join(beaten)])


## The cell of `walks` -- `TacticalReach.walks_for` the unit -- that leaves
## the least to walk to `target` by the route the unit would really take,
## round red's pieces; the unit's own cell when none is nearer. Shared with
## `LearnedBlue`, which walks at points by the same route.
func _nearest_walk_to(state: BoardState, unit: Unit, walks: Dictionary, target: Vector2i) -> Vector2i:
	var to_target: Dictionary = TacticalReach.route_costs(_past_red(state, unit.type, target), target)
	var best: Vector2i = unit.cell
	for cell: Vector2i in walks:
		if _remaining(state, unit, cell, to_target, target) < _remaining(state, unit, best, to_target, target):
			best = cell
	return best


# The board as `kind` walks it, with every red piece but its workshops made a
# wall -- and but the piece on `target`, when one is given. A workshop stays
# open because it is the target: it is attacked from beside it, and a flood
# out of a wall would reach nothing.
func _past_red(state: BoardState, kind: UnitType, target: Vector2i = Vector2i(-1, -1)) -> GridGraph:
	var graph: GridGraph = state.graph_for_type(kind).duplicate_graph()
	for enemy: Unit in _enemies(state):
		if enemy.type.type_name != TacticalRules.WORKSHOP and enemy.cell != target:
			graph.block(enemy.cell)
	return graph


## True when no buildable type has a cell to stand on beside `workshop`.
static func no_room_beside(state: BoardState, workshop: Unit) -> bool:
	var types: Dictionary = TacticalRules.unit_types()
	for type_name: String in TacticalRules.BUILDABLE:
		if TacticalRules.free_cell_beside(state, workshop, types[type_name]) != workshop.cell:
			return false
	return true


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


## Whom the unit `unit_id` attacks from where it stands, or null for nobody:
## red's workshop if it reaches it, else the weakest red piece in reach that
## it beats by the counter table, ties to the lower id.
func decide_attack(state: BoardState, unit_id: int) -> TacticalDecision:
	var unit: Unit = state.unit_by_id(unit_id)
	var best: Unit = null
	for enemy: Unit in _enemies(state):
		if TacticalCombat.why_refused(state, Attack.new(unit_id, enemy.id)) != BoardState.LEGAL:
			continue
		if enemy.type.type_name == TacticalRules.WORKSHOP:
			return TacticalDecision.strike(unit_id, enemy, "attacks red's workshop at %s: destroying it wins" % enemy.cell)
		if enemy.type.type_name in unit.type.strong_against and (best == null or enemy.health < best.health):
			best = enemy
	if best == null:
		return null
	return TacticalDecision.strike(unit_id, best, "attacks the %s at %s: a %s beats a %s, by the counter table" % [
		best.type.type_name, best.cell, unit.type.type_name, best.type.type_name])


# Why the workshop builds nothing: no room, no money, nothing worth it, or
# nothing worth it that could get there.
# Asked of the cheapest type, because if that cannot be built, none can.
func _why_nothing(state: BoardState, workshop: Unit) -> String:
	var cheapest: UnitType = TacticalRules.unit_types()[TacticalRules.RUNNER]
	if no_room_beside(state, workshop):
		return NO_ROOM
	var order := ProductionOrder.new(workshop.id, cheapest, TacticalRules.free_cell_beside(state, workshop, cheapest))
	var refusal: String = state.why_production_refused(order)
	if refusal != BoardState.LEGAL:
		return refusal
	# Since T45 a workshop with room and money always builds (`_spend_anyway`),
	# so this is only reached by a caller asking about a board where it could.
	return "nothing stops it: it can build"


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
		target: Vector2i) -> int:
	if not to_target.has(cell):
		return UNREACHABLE
	var graph: GridGraph = state.graph_for(unit)
	return to_target[cell] - graph.cost_at(cell) + graph.cost_at(target)


# Said when the walk is on its way over the river, and only then.
func _crossing(unit: Unit, target: Unit) -> String:
	if not TacticalScenario.across_the_river(unit.cell, target.cell):
		return ""
	if TacticalScenario.MAP[unit.cell.y][unit.cell.x] == TacticalRules.BRIDGE:
		return ", crossing the bridge"
	if unit.type.mover == TacticalRules.WATER_MOVER:
		return ", wading across the river"
	return ", making for the bridge"
