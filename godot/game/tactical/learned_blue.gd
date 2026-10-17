## Blue played by the two fitted models: the combat model says whether a fight
## is worth starting, and the capture model which control point falls first.
## Everything else is the rules', and says so.
##
## Each walker, in this order:
##
## 1. **A fight.** Every red walker it could attack this turn -- from a cell
##    it can walk to, within its reach -- is put to the combat model, from
##    the cell the model likes best. If the best fight clears the threshold
##    it walks there, and attacks once it has: asked again after the walk, on
##    the board as it then stands. If none does, it walks away from the
##    nearest of them. That is the skirmish's lesson, a probability against a
##    threshold, now on a board where an attack does something.
## 2. **A point it stands on**: it stays, because a point left is not paid.
## 3. **A point red holds**: it walks at it -- T41's rule, not the model.
## 4. **A point no blue piece stands on**: the one the capture model says
##    falls first.
## 5. Otherwise **red's workshop**, by the route the rules walk.
##
## The workshop builds by the rules (`RuleBasedBlue`), and red's workshop in
## reach is attacked by the rules: the dataset has no buildings, so the model
## has nothing to say about a siege, and is not asked.
##
## Nothing trains here, and nothing remembers a game (invariant 6). The
## numbers come from `LearnedPolicy`, the `ai_learning` addon's, which is
## asked two questions; the walking is the board's own (`TacticalReach`), so
## a wader wades.
##
## Complexity: per walker, one flood for its walks; then, per red walker in
## reach, one combat row for each cell it could attack from -- a state copied
## and five numbers counted -- and a flood back from the point it walks at.
##
## When not to use it: towers. The model never saw one, so a bolt tower is
## walked past exactly as the rules walk past it, and never attacked.
class_name LearnedBlue
extends RuleBasedBlue

## Where the numbers come from: the addon's policy, given the points.
var policy: LearnedPolicy


## `published` defaults to the weights the game ships; a test hands its own.
func _init(published: ModelFile = null, threshold: float = LearnedPolicy.DEFAULT_THRESHOLD) -> void:
	var weights: ModelFile = published if published != null else ModelFile.load_from(ModelFile.DEFAULT_PATH)
	policy = LearnedPolicy.new(weights, TacticalScenario.POINTS, threshold)


## "learned": the name the header and the overlay use.
func controller_name() -> String:
	return "learned"


## What decides, in one line for the screen.
func describe() -> String:
	return "the learned policy: the combat model's p(win) against %.2f says attack or retreat, the capture model picks the point; builds and sieges by the rules" % policy.threshold()


## A walk decided by the order the header gives: a fight, a point held, a
## point contested, the point the capture model ranks first, red's workshop.
func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
	var unit: Unit = state.unit_by_id(unit_id)
	var unusable: String = policy.why_unusable()
	if unusable != "":
		return TacticalDecision.hold(unit_id, "stays: the learned blue cannot decide -- " + unusable, unit.cell)
	var walks: Dictionary = TacticalReach.walks_for(state, unit)
	var fight: Dictionary = _best_fight(state, unit, walks)
	if not fight.is_empty():
		return _attack_or_retreat(state, unit, walks, fight)
	if unit.cell in TacticalScenario.POINTS:
		return TacticalDecision.hold(unit_id, "stays on the point at %s: a point left is a point not paid for (a rule, not the model)" % unit.cell, unit.cell)
	var contested: Vector2i = _point_red_holds(state)
	if contested != Vector2i(-1, -1):
		return _walk_at(state, unit, walks, contested,
			"red holds it, and standing beside it breaks the hold (a rule, not the model)")
	var ranked: Array[Dictionary] = policy.rank_nodes(state, unit.faction, _points_nobody_of_ours_is_on(state))
	if not ranked.is_empty():
		return _walk_at(state, unit, walks, ranked[0]["cell"], _ranking(ranked))
	return super.decide_move(state, unit_id)


## Whom the unit attacks from where it stands, or null: red's workshop if it
## reaches it, by the rules; else the red walker in reach the combat model
## gives the best chance, if that chance clears the threshold.
func decide_attack(state: BoardState, unit_id: int) -> TacticalDecision:
	var unit: Unit = state.unit_by_id(unit_id)
	var best: Unit = null
	var best_chance: float = -1.0
	for enemy: Unit in _enemies(state):
		if TacticalCombat.why_refused(state, Attack.new(unit_id, enemy.id)) != BoardState.LEGAL:
			continue
		if enemy.type.type_name == TacticalRules.WORKSHOP:
			return TacticalDecision.strike(unit_id, enemy, "attacks red's workshop at %s: destroying it wins (a rule, not the model)" % enemy.cell)
		var chance: float = policy.chance_to_win(state, unit, enemy) if enemy.type.mobile else NAN
		if is_finite(chance) and chance > best_chance:
			best = enemy
			best_chance = chance
	if best == null or best_chance < policy.threshold():
		return null
	return TacticalDecision.strike(unit_id, best, "attacks the %s at %s: p(win) %.2f, at or above %.2f" % [
		best.type.type_name, best.cell, best_chance, policy.threshold()])


# The best fight this unit could start this turn, as {"enemy", "cell",
# "chance", "nearest"} -- the red walker, the cell to attack it from, what the
# combat model says, and the nearest red walker it could attack at all -- or
# {} when it could attack none. Each cell is weighed on the board as it would
# stand once walked to, because who is near, and how far a friend is, change
# with the cell.
func _best_fight(state: BoardState, unit: Unit, walks: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var nearest: Unit = null
	for enemy: Unit in _enemies(state):
		if not enemy.type.mobile:
			continue
		var cells: Array[Vector2i] = _attack_cells(unit, walks, enemy)
		if cells.is_empty():
			continue
		if nearest == null or _apart(unit, enemy) < _apart(unit, nearest):
			nearest = enemy
		var here: Dictionary = _best_cell_against(state, unit, walks, enemy, cells)
		if not here.is_empty() and (best.is_empty() or here["chance"] > best["chance"]):
			best = here
	if not best.is_empty():
		best["nearest"] = nearest
	return best


# Of `cells`, the one the combat model likes best for attacking `enemy`, as
# {"enemy", "cell", "chance"}, or {} when it can read none of them.
func _best_cell_against(state: BoardState, unit: Unit, walks: Dictionary, enemy: Unit,
		cells: Array[Vector2i]) -> Dictionary:
	var best: Dictionary = {}
	for cell: Vector2i in cells:
		var moved: BoardState = state if cell == unit.cell else state.apply(Move.new(unit.id, walks[cell]))
		var chance: float = policy.chance_to_win(moved, moved.unit_by_id(unit.id), moved.unit_by_id(enemy.id))
		if is_finite(chance) and (best.is_empty() or chance > best["chance"]):
			best = {"enemy": enemy, "cell": cell, "chance": chance}
	return best


# The cells -- where it stands, and each it can walk to -- from which `unit`
# reaches `enemy`.
func _attack_cells(unit: Unit, walks: Dictionary, enemy: Unit) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in [unit.cell] + walks.keys():
		if TacticalCombat.distance(cell, enemy.cell) <= unit.type.attack_range:
			cells.append(cell)
	return cells


# Walk to the fight if the model clears the threshold; away from the nearest
# fight if it does not.
func _attack_or_retreat(state: BoardState, unit: Unit, walks: Dictionary, fight: Dictionary) -> TacticalDecision:
	var enemy: Unit = fight["enemy"]
	var odds: String = "p(win) %.2f" % fight["chance"]
	if fight["chance"] >= policy.threshold():
		var why: String = "to attack the %s at %s: %s, at or above %.2f" % [
			enemy.type.type_name, enemy.cell, odds, policy.threshold()]
		if fight["cell"] == unit.cell:
			return TacticalDecision.hold(unit.id, "stays " + why, unit.cell)
		return TacticalDecision.walk(unit.id, walks[fight["cell"]], "walks to %s %s" % [fight["cell"], why], fight["cell"])
	var threat: Unit = fight["nearest"]
	var away: Vector2i = _out_of_reach(state, unit, walks, threat)
	var why_not: String = "the best fight in reach, the %s at %s, is %s, below %.2f" % [
		enemy.type.type_name, enemy.cell, odds, policy.threshold()]
	if away == unit.cell:
		return TacticalDecision.hold(unit.id, "stays, out of the reach of the %s at %s or as far from it as it can be: %s" % [threat.type.type_name, threat.cell, why_not], unit.cell)
	return TacticalDecision.walk(unit.id, walks[away], "retreats to %s, out of the reach of the %s at %s or as far as it can: %s" % [
		away, threat.type.type_name, threat.cell, why_not], away)


# Where a retreat ends: of the cells `threat` cannot attack next turn, the
# one nearest red's workshop by the rules' route; when every cell is in its
# reach, the one furthest from it.
#
# Not simply the furthest. Measured: running as far as it could, a unit was
# out of reach the next turn, walked back at the workshop, was in reach again
# and ran -- every other turn, for forty rounds, with the pieces behind it
# jammed at the bridge: 20 draws in 20 games against the rules. Stopping at
# the edge of the threat's reach keeps the line, and lets the numbers the
# combat model weighs gather behind it.
#
# The threat's reach is its movement and its attack range in Manhattan
# cells, which ignores terrain and so errs towards caution.
func _out_of_reach(state: BoardState, unit: Unit, walks: Dictionary, threat: Unit) -> Vector2i:
	var reach: int = threat.type.movement + threat.type.attack_range
	var safe: Array[Vector2i] = []
	var furthest: Vector2i = unit.cell
	for cell: Vector2i in [unit.cell] + walks.keys():
		if TacticalCombat.distance(cell, threat.cell) > reach:
			safe.append(cell)
		if TacticalCombat.distance(cell, threat.cell) > TacticalCombat.distance(furthest, threat.cell):
			furthest = cell
	var workshop: Unit = _nearest_workshop(state, unit)
	if safe.is_empty() or workshop == null:
		return furthest
	var to_workshop: Dictionary = TacticalReach.route_costs(_past_red(state, unit.type, workshop.cell), workshop.cell)
	var best: Vector2i = safe[0]
	for cell: Vector2i in safe:
		if _remaining(state, unit, cell, to_workshop, workshop.cell) < _remaining(state, unit, best, to_workshop, workshop.cell):
			best = cell
	return best


# A walk at `point` by the rules' route, or a hold when no walk gets nearer.
func _walk_at(state: BoardState, unit: Unit, walks: Dictionary, point: Vector2i, why: String) -> TacticalDecision:
	var best: Vector2i = _nearest_walk_to(state, unit, walks, point)
	if best == unit.cell:
		return TacticalDecision.hold(unit.id, "stays: no walk this turn brings it nearer the point at %s, which it wants because %s" % [point, why], unit.cell)
	return TacticalDecision.walk(unit.id, walks[best], "walks to %s, towards the point at %s: %s" % [best, point, why], best)


# The first point red holds, or (-1, -1).
func _point_red_holds(state: BoardState) -> Vector2i:
	for point: Vector2i in TacticalScenario.POINTS:
		var side: int = ControlPoints.holder(state, point)
		if side != ControlPoints.NOBODY and side != state.current_faction:
			return point
	return Vector2i(-1, -1)


# The points no piece of blue's stands on: the ones still worth walking at.
func _points_nobody_of_ours_is_on(state: BoardState) -> Array[Vector2i]:
	var open: Array[Vector2i] = []
	for point: Vector2i in TacticalScenario.POINTS:
		var standing: Unit = state.unit_at(point)
		if standing == null or standing.faction != state.current_faction:
			open.append(point)
	return open


# Why the first point: what the capture model said of it, and of the next.
static func _ranking(ranked: Array[Dictionary]) -> String:
	var said: String = "the capture model says %.1f turns" % ranked[0]["turns"]
	if ranked.size() > 1:
		said += ", against %.1f for %s" % [ranked[1]["turns"], ranked[1]["cell"]]
	return said


static func _apart(unit: Unit, other: Unit) -> int:
	return TacticalCombat.distance(unit.cell, other.cell)
