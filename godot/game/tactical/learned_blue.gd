## Blue played by the two fitted models: the combat model says whether a fight
## is worth starting, and the capture model which control point falls first.
## Everything else is the rules', and says so.
##
## Each walker, in this order:
##
## 1. **A fight.** Every red walker it could attack this turn -- from a cell
##    it can walk to, within its reach -- is put to the combat model, from
##    the cell the model likes best. If the best fight clears the walker's
##    bar (below), or a fight its side started is beside it, it walks there,
##    and attacks once it has: asked again after the walk, on the board as it
##    then stands. If none does, it walks away from the nearest of them --
##    when red's strength near it outweighs blue's (below); otherwise it
##    stands its ground and goes on down this list, and its reason says it
##    did not retreat and why. That is the skirmish's lesson, a probability
##    against a threshold -- two, since T46 -- now on a board where an attack
##    does something.
## 2. **A point it stands on**: it stays, because a point left is not paid.
## 3. **A point red holds**: it walks at it -- T41's rule, not the model.
## 4. **A point no blue piece stands on**: the one the capture model says
##    falls first.
## 5. Otherwise **red's workshop**, by the route the rules walk.
##
## Steps 3 and 4 give a point to one walker a turn, and a walker no walk
## brings nearer its point takes the rules' fallback (T45): two walkers
## heading for one point were half of what queued at the bridge.
##
## The workshop builds by the rules (`RuleBasedBlue`), and red's workshop in
## reach is attacked by the rules: the dataset has no buildings, so the model
## has nothing to say about a siege, and is not asked.
##
## **Two thresholds, a target kept, a fight joined** (T46). One threshold
## flickers: a walker at p(win) 0.5 set out for a red walker one turn and ran
## from it the next. So a walker sets out for a fight at `COMMIT_AT` (0.5),
## and, while it is on its way to *that same red walker*, gives up only at or
## below `GIVE_UP_AT` (0.3) -- a thermostat's two set points. Only the way
## there: every fight between walkers kills somebody, so once the blow is
## struck there is no fight left to be committed to, and the commitment ends
## with the attack. On this board that way is one walk long -- a walker only
## sets out for a fight it can reach this turn -- so what the second bar
## decides is the blow after the walk, when the board as it stands once the
## walker has arrived gives worse odds than the cell promised. Measured, it
## changes nothing here (T46's record); it is kept because it is right, and
## a board with longer approaches is where it can. And a walker within
## `JOIN_RADIUS` cells of an attack another walker of its side made this
## turn joins that fight at any odds rather than retreat: Wesnoth's
## `attack_close` lets an attack near one already made pass the check that
## refuses near-hopeless ones; using it to stop a retreat is this board's own
## rule, and the reason says so. Which bar decided is in every reason.
##
## **Retreat on strength, this board's version of Wesnoth's.** A walker that
## will not fight retreats only when `CAUTION` times red's strength near it
## outweighs blue's. Wesnoth's `should_retreat` (`ca.cpp`) weighs the power
## each side can bring onto the hex and how exposed its terrain is; here
## strength is simply the health of the walkers within `STRENGTH_RADIUS`
## cells as the crow flies -- so a red walker across the river counts in
## full. The caution is Wesnoth's default.
##
## Nothing trains here, and nothing outlives a game (invariant 6): which red
## walker each walker is on its way to is kept for one game and forgotten
## when the next begins, never saved. The
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

## p(win) at or above which a walker sets out for a fight.
##
## The reference's starting points were 0.55 and 0.35; what was measured
## against them is in T46's record. At 0.5 the bar is the model's own line,
## "more likely to win than not".
const COMMIT_AT: float = 0.5
## p(win) at or below which a walker on its way to a fight gives it up.
const GIVE_UP_AT: float = 0.3
## Cells within which an attack its side made this turn keeps a walker from
## retreating -- Wesnoth's `attack_close` distance (closer than 4 hexes).
const JOIN_RADIUS: int = 3

## Wesnoth's caution: a walker that will not fight retreats only when
## `CAUTION` times red's strength near it outweighs blue's (its default 0.25,
## "caution x their_power > our_power"). Strength is the health of the
## walkers within `STRENGTH_RADIUS` cells, its own included.
const CAUTION: float = 0.25
const STRENGTH_RADIUS: int = 4

## Where the numbers come from: the addon's policy, given the points.
var policy: LearnedPolicy

## True to retreat on the two sides' strength near the walker (T46, step 3);
## false to retreat whenever its own best fight is under its bar.
var retreat_on_strength: bool = true

# Walker id -> the id of the red walker it set out for and has not reached.
var _committed: Dictionary[int, int] = {}
# Where its side attacked this turn: attacker id -> the cell it attacked from.
var _attacked_from: Dictionary[int, Vector2i] = {}
var _seen_turn: int = -1


## `published` defaults to the weights the game ships; a test hands its own.
## The policy's own threshold is not used: the bars above decide.
func _init(published: ModelFile = null) -> void:
	var weights: ModelFile = published if published != null else ModelFile.load_from(ModelFile.DEFAULT_PATH)
	policy = LearnedPolicy.new(weights, TacticalScenario.POINTS)


## A new turn: no attacks made yet. A turn no later than the last one seen is
## a new game, and every commitment of the last one is forgotten.
func begin_turn(state: BoardState) -> void:
	super.begin_turn(state)
	if state.turn_number <= _seen_turn:
		_committed.clear()
	_seen_turn = state.turn_number
	_attacked_from.clear()


## One walk asked for outside a turn, as `DecisionPolicy` asks it: whatever
## it would remember -- a walker setting out, an attack beside it -- is put
## back afterwards, so asking changes nothing.
func choose(state: BoardState, unit_id: int) -> Move:
	var committed: Dictionary[int, int] = _committed.duplicate()
	var attacked: Dictionary[int, Vector2i] = _attacked_from.duplicate()
	var move: Move = super.choose(state, unit_id)
	_committed = committed
	_attacked_from = attacked
	return move


## "learned": the name the header and the overlay use.
func controller_name() -> String:
	return "learned"


## What decides, in one line for the screen.
func describe() -> String:
	return "the learned policy: the combat model's p(win) sets a walker out for a fight at %.2f, and it gives that fight up at %.2f or below; a walker beside its side's attack joins it; it retreats only when red is far stronger near it; the capture model picks the point; builds and sieges by the rules" % [
		COMMIT_AT, GIVE_UP_AT]


## A walk decided by the order the header gives: a fight, a point held, a
## point contested, the point the capture model ranks first, red's workshop.
func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
	var unit: Unit = state.unit_by_id(unit_id)
	var unusable: String = policy.why_unusable()
	if unusable != "":
		return TacticalDecision.hold(unit_id, "stays: the learned blue cannot decide -- " + unusable, unit.cell)
	var walks: Dictionary = TacticalReach.walks_for(state, unit)
	var fight: Dictionary = _best_fight(state, unit, walks)
	var fought: TacticalDecision = null if fight.is_empty() else _attack_or_retreat(state, unit, walks, fight)
	if fought != null:
		return fought
	var decision: TacticalDecision = _walk_at_a_goal(state, unit, walks)
	if not fight.is_empty():
		decision.reason += " -- " + _stood_its_ground(unit, fight)
	return decision


# Steps 2 to 5 of the header: a point held, a point contested, the point the
# capture model ranks first, red's workshop.
func _walk_at_a_goal(state: BoardState, unit: Unit, walks: Dictionary) -> TacticalDecision:
	var unit_id: int = unit.id
	if unit.cell in TacticalScenario.POINTS:
		_claim(state, unit.cell)
		return TacticalDecision.hold(unit_id, "stays on the point at %s: a point left is a point not paid for (a rule, not the model)" % unit.cell, unit.cell)
	var contested: Vector2i = _point_red_holds(state)
	if contested != Vector2i(-1, -1) and _claim(state, contested):
		return _walk_at(state, unit, walks, contested,
			"red holds it, and standing beside it breaks the hold (a rule, not the model)")
	var ranked: Array[Dictionary] = policy.rank_nodes(state, unit.faction, _points_nobody_of_ours_is_on(state))
	for index: int in range(ranked.size()):
		if _claim(state, ranked[index]["cell"]):
			return _walk_at(state, unit, walks, ranked[index]["cell"], _ranking(ranked.slice(index)))
	return super.decide_move(state, unit_id)


## Whom the unit attacks from where it stands, or null: red's workshop if it
## reaches it, by the rules; else the red walker in reach the combat model
## gives the best chance, if that chance clears the walker's bar or a fight
## its side started is beside it (`_why_fight`).
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
	if best == null:
		return null
	var why: String = _why_fight(unit, best, best_chance)
	if why == "":
		return null
	# The blow ends the fight one way or the other, and the way there with it.
	_committed.erase(unit_id)
	_attacked_from[unit_id] = unit.cell
	return TacticalDecision.strike(unit_id, best, "attacks the %s at %s: %s" % [best.type.type_name, best.cell, why])


# Why `unit` fights `enemy` at `chance`, or "" when it should not: above the
# give-up bar while on its way to that same enemy, at or above the commit
# bar, or beside a fight another walker of its side started this turn.
func _why_fight(unit: Unit, enemy: Unit, chance: float) -> String:
	if _committed.get(unit.id, -1) == enemy.id and chance > GIVE_UP_AT:
		return "p(win) %.2f, above the give-up bar %.2f: it set out for this %s and keeps on" % [chance, GIVE_UP_AT, enemy.type.type_name]
	if chance >= COMMIT_AT:
		return "p(win) %.2f, at or above the commit bar %.2f" % [chance, COMMIT_AT]
	if _beside_a_fight(unit):
		return "p(win) %.2f, under its bar, but another walker of its side attacked within %d cells this turn and it joins in rather than leave (this board's rule, after Wesnoth's attack_close)" % [
			chance, JOIN_RADIUS]
	return ""


# The bar `unit` holds its fight with `enemy` to: the give-up bar while on
# its way to that enemy, the commit bar otherwise.
func _bar_for(unit: Unit, enemy: Unit) -> float:
	return GIVE_UP_AT if _committed.get(unit.id, -1) == enemy.id else COMMIT_AT


# Why a walker whose best fight is under its bar did not retreat, for the
# end of the reason of whatever it did instead.
func _stood_its_ground(unit: Unit, fight: Dictionary) -> String:
	var enemy: Unit = fight["enemy"]
	return "it did not retreat from the %s at %s, though p(win) %.2f is under its bar %.2f: red's strength near it does not outweigh blue's by Wesnoth's caution %.2f" % [
		enemy.type.type_name, enemy.cell, fight["chance"], _bar_for(unit, enemy), CAUTION]


# True when `CAUTION` times red's strength near `unit` is more than blue's:
# Wesnoth's retreat rule, on the side and not on one fight.
func _outweighed(state: BoardState, unit: Unit) -> bool:
	var ours: int = 0
	var theirs: int = 0
	for other: Unit in state.units:
		if not other.type.mobile or TacticalCombat.distance(other.cell, unit.cell) > STRENGTH_RADIUS:
			continue
		if other.faction == unit.faction:
			ours += other.health
		else:
			theirs += other.health
	return CAUTION * theirs > ours


# True when another walker of its side attacked from within `JOIN_RADIUS`
# cells this turn. Another: a walker's own attack is not a fight beside it,
# and counting it kept every attacker from ever giving up.
func _beside_a_fight(unit: Unit) -> bool:
	for attacker: int in _attacked_from:
		if attacker != unit.id and TacticalCombat.distance(_attacked_from[attacker], unit.cell) <= JOIN_RADIUS:
			return true
	return false


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


# Walk to the fight if `_why_fight` says so -- its bar, or a fight beside it
# -- and away from the nearest fight if it does not. A walker that gives up
# is no longer committed.
func _attack_or_retreat(state: BoardState, unit: Unit, walks: Dictionary, fight: Dictionary) -> TacticalDecision:
	var enemy: Unit = fight["enemy"]
	var odds: String = "p(win) %.2f" % fight["chance"]
	var why_fight: String = _why_fight(unit, enemy, fight["chance"])
	if why_fight != "":
		var why: String = "to attack the %s at %s: %s" % [enemy.type.type_name, enemy.cell, why_fight]
		# Setting out on its own odds is a commitment; joining is not.
		if fight["chance"] >= COMMIT_AT or _committed.get(unit.id, -1) == enemy.id:
			_committed[unit.id] = enemy.id
		if fight["cell"] == unit.cell:
			return TacticalDecision.hold(unit.id, "stays " + why, unit.cell)
		return TacticalDecision.walk(unit.id, walks[fight["cell"]], "walks to %s %s" % [fight["cell"], why], fight["cell"])
	var bar: float = _bar_for(unit, enemy)
	_committed.erase(unit.id)
	if retreat_on_strength and not _outweighed(state, unit):
		return null
	var threat: Unit = fight["nearest"]
	var away: Vector2i = _out_of_reach(state, unit, walks, threat)
	var why_not: String = "the best fight in reach, the %s at %s, is %s, below %s %.2f" % [
		enemy.type.type_name, enemy.cell, odds, "the give-up bar" if bar == GIVE_UP_AT else "the commit bar", bar]
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


# A walk at `point` by the rules' route, or the rules' fallback when no walk
# gets nearer -- giving the point back for another walker to take.
func _walk_at(state: BoardState, unit: Unit, walks: Dictionary, point: Vector2i, why: String) -> TacticalDecision:
	var best: Vector2i = _nearest_walk_to(state, unit, walks, point)
	if best == unit.cell:
		_claims[point] -= 1
		return _fallback(state, unit, walks, "no walk this turn brings it nearer the point at %s, which it wants because %s" % [point, why])
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
