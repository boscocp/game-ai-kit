## Blue played by a plan: STRIPS over the tactical domain, asked "how does
## their workshop fall?", and the answer carried out a step at a time.
##
## The plan is the strategy layer of ADR 0010 and nothing below it. What it
## decides is what the workshop buys -- including the forge, which the rules
## never buy, and the turns spent saving for it. It moves no walker the rules
## would not: every walking step in this domain ends where the rules' walk
## ends (across the river, at their workshop), so a walker a step names
## takes the rules' route and its reason names the step it is carrying out --
## the plan says *whom* it counts on, not *how* they go. Whom a walker
## strikes is the rules' attack too: units use A* and reflexes, as the layers
## in `docs/concepts/planning-in-strategy-games.md` have it. A walker no step
## of the plan names is the rules', and its reason says so.
##
## **Where the plan is** is read off the board, not remembered. Each call
## finds the latest step from which the rest of the plan still runs, from the
## board's predicates (`TacticalPlanBridge.world_of`), to the goal. So a step
## done is a step the board shows done, and a purchase the dice undid -- a ram
## destroyed on the bridge -- is a step to do again, without bookkeeping.
##
## **When it replans** (T11, step 8), at the start of one of its own turns:
##
## * every `REPLAN_EVERY` of its turns, even if nothing broke. Three, because
##   that is how long the dearest chain of purchases takes -- the forge and a
##   ram are nine funds, three turns of income -- so a fresh plan sooner than
##   that mostly re-derives the one it has, and a plan kept much longer misses
##   what the board offers meanwhile: a guard walking away from red's workshop
##   makes a runner's siege legal, and only a new plan will see it;
## * whenever the plan no longer runs from the board as it is -- a
##   precondition it relied on stopped holding, such as `crossing_open` -- which
##   is Killzone 3's invalidation, and the sentence on screen names the step
##   and the fact;
## * when it has no plan, or the last call ran out of budget and its partial
##   plan's steps are done. A partial plan is followed step by step like a
##   whole one, not only its first step: the cadence above re-plans it anyway,
##   and in practice the game never sees one -- the largest tactical plan
##   needs a handful of worlds under h_max, and `BUDGET` is 2000.
##
## It plans only in `begin_turn`, never in the middle of a turn: the turn's
## decisions are made against the plan the turn started with, so what is
## drawn is what is done.
##
## Complexity: one planner call per turn at most, bounded by `BUDGET` worlds;
## per decision, a replay of the plan from each step, O(steps^2) actions.
##
## When not to use it: as a reactive opponent. A plan answers "what must be
## true, in what order", and a fight on the bridge is not that question.
class_name PlannedBlue
extends RuleBasedBlue

## Of its own turns, how many a plan is kept before it is made again.
const REPLAN_EVERY: int = 3

## The search the game plays with: picked by `test/tactical/planner_benchmark.gd`'s
## table, published in `heuristic_planner.gd`.
const GUIDE: HeuristicPlanner.Guide = HeuristicPlanner.Guide.H_MAX

## Worlds per planning call. The benchmark's largest tactical plan needs far
## fewer under the chosen guide; the budget is what bounds a board nobody
## measured.
const BUDGET: int = 2000

## The budget this controller plans with: `BUDGET`, unless a test hands a
## smaller one to see what a partial plan does on the board.
var budget: int = BUDGET
## How many actions ahead it plans: as far as the budget allows, unless a
## difficulty level (T12, `LeveledBlue`) says fewer.
var horizon: int = HeuristicPlanner.NO_HORIZON

## The plan being carried out, or null before the first turn.
var plan: PlanResult = null
## The index of the next step in `plan.steps`, as the board shows it; -1 when
## no remaining part of the plan runs from the board.
var next_step: int = -1
## Why the plan was last made, in words for the screen.
var why_planned: String = ""

var _planner := HeuristicPlanner.new()
var _aim: PackedStringArray = PackedStringArray()
var _planned_on_turn: int = -1
var _seen_turn: int = -1
# Worlds visited and plans made since it was made: `work_done`, `replans`.
var _worlds: int = 0
var _plans_made: int = 0


## "planner": the name the header and the overlay use.
func controller_name() -> String:
	return "planner"  # shown through tr()


## What decides, in one line for the screen.
func describe() -> String:
	return tr("a plan: STRIPS over the tactical domain with {guide}, made every {turns} turns or when it stops running; its walkers take the rules' routes").format({
		guide = guide_name(GUIDE), turns = REPLAN_EVERY})


## Worlds every planning call has visited, added up.
func work_done() -> int:
	return _worlds


## "worlds", which is what `HeuristicPlanner` counts.
func work_unit() -> String:
	return "worlds"


## Plans made, the first included: every one past the first is a replan.
func replans() -> int:
	return _plans_made


## The workshop carries out the next purchase the plan has, or saves for it;
## with none left, it builds by the rules.
func decide_build(state: BoardState, workshop_id: int) -> TacticalDecision:
	_find_the_place(state)
	var index: int = _next_purchase(next_step)
	if index == -1:
		return _by_the_rules(super.decide_build(state, workshop_id), tr("the plan buys nothing more"))
	return _purchase(state, state.unit_by_id(workshop_id), index)


## Every walker walks the rules' route towards their workshop (see the
## header for why the plan changes no walk); one a step names says which
## step it is carrying out, any other says the rules decide.
func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
	_find_the_place(state)
	var unit: Unit = state.unit_by_id(unit_id)
	var index: int = _step_for(state, unit)
	var walk: TacticalDecision = super.decide_move(state, unit_id)
	if index == -1:
		return _by_the_rules(walk, tr("no step of the plan is this {piece}'s").format({piece = TacticalStatus.piece(unit.type.type_name)}))
	walk.reason = "%s: %s" % [_step_label(index), walk.reason]
	return walk


## The plan as lines for the screen and the console: how it was made, then
## each step, marked done, next, or to come.
func plan_lines() -> Array[String]:
	if plan == null:
		return [tr("no plan yet")]
	var lines: Array[String] = [tr("plan ({guide}, {worlds} worlds searched): made {why}").format({
		guide = guide_name(GUIDE), worlds = plan.visited, why = why_planned})]
	if not plan.solved and not plan.partial:
		lines.append("  " + tr("no plan found: everything is the rules'"))
	for index: int in range(plan.steps.size()):
		lines.append("  %s  %d. %s" % [_mark(index), index + 1, plan.steps[index].name])
	if next_step == -1 and (plan.solved or plan.partial):
		lines.append("  " + tr("(off: no remaining part of the plan runs from this board; it plans again next turn)"))
	if plan.partial:
		lines.append("  " + tr("(partial: the budget ran out; these steps head for the goal, and it plans again when they are done)"))
	return lines


# The mark beside step `index` in the plan's lines -- off, done, next or
# nothing -- padded to the widest of them in the language on screen, so the
# step numbers stay in one column.
func _mark(index: int) -> String:
	var marks: Array[String] = [tr("off"), tr("done"), tr("next"), ""]
	var width: int = marks.map(func(word: String) -> int: return word.length()).max()
	var which: int = 3
	if next_step == -1:
		which = 0
	elif index <= next_step:
		which = 1 if index < next_step else 2
	return marks[which].rpad(width)


## What to draw for the plan: for each piece that has a step still to do, its
## cell and the step's number -- the workshop for a purchase, a walker for a
## move -- so a person sees on the board who the plan is counting on.
func plan_marks(state: BoardState) -> Dictionary[Vector2i, String]:
	var marks: Dictionary[Vector2i, String] = {}
	if plan == null or next_step == -1:
		return marks
	var ours: Unit = _our_workshop(state)
	var purchase: int = _next_purchase(next_step)
	if purchase != -1 and ours != null:
		marks[ours.cell] = str(purchase + 1)
	for unit: Unit in state.units_of(state.current_faction):
		var index: int = _step_for(state, unit) if unit.type.mobile else -1
		if index != -1:
			marks[unit.cell] = str(index + 1)
	return marks


## The search's name, as the screen says it.
static func guide_name(guide: HeuristicPlanner.Guide) -> String:
	return ["breadth-first", "h_max", "h_add"][guide]


## Plan again if this turn should (see the header), and find where on the
## plan the board is. A turn no later than the last one seen is a new game,
## and the old plan is forgotten with it.
func begin_turn(state: BoardState) -> void:
	super.begin_turn(state)
	if state.turn_number <= _seen_turn:
		plan = null
	_seen_turn = state.turn_number
	var why: String = _why_plan_again(state)
	if why != "":
		_make_plan(state, why)
	next_step = _where_the_board_is(state)


# Where on the plan the board is now -- every call, because a purchase or a
# walk made this turn moves the board along it. A caller that never began
# the turn, such as a test asking one question, gets it begun.
func _find_the_place(state: BoardState) -> void:
	if state.turn_number != _seen_turn:
		begin_turn(state)
	next_step = _where_the_board_is(state)


# Why to plan again at the start of this turn, or "" to keep the plan. A
# horizon of no actions is no plan at all, and the rules buy (T12).
func _why_plan_again(state: BoardState) -> String:
	if horizon == 0:
		return ""
	if plan == null:
		return tr("at the start of the game")
	if state.turn_number - _planned_on_turn >= REPLAN_EVERY * TacticalScenario.FACTIONS:
		return tr("because {turns} of its turns had passed").format({turns = REPLAN_EVERY})
	if not plan.solved and not plan.partial and plan.gave_up:
		return tr("again, because the last call ran out of budget with nothing to follow")
	if not plan.solved and not plan.partial:
		return tr("again, because the last call proved there is none")
	var at: int = _where_the_board_is(state)
	if at == -1:
		return tr("because the plan stopped running: {why}").format({why = _what_broke(state)})
	if at == plan.steps.size():
		return tr("because the partial plan's steps were done")
	return ""


func _make_plan(state: BoardState, why: String) -> void:
	var world: WorldState = TacticalPlanBridge.world_of(state)
	plan = _planner.plan(TacticalPlanBridge.actions(), world, TacticalPlanBridge.goal(), GUIDE, budget, horizon)
	_worlds += plan.visited
	_plans_made += 1
	_planned_on_turn = state.turn_number
	why_planned = tr("on round {round}, {why}").format({round = state.turn_number / TacticalScenario.FACTIONS + 1, why = why})
	_aim = TacticalPlanBridge.goal() if not plan.partial else _what_it_adds(world)


# What a partial plan is for: what holds at its end that did not at the
# start. A solved plan is for the goal.
func _what_it_adds(start: WorldState) -> PackedStringArray:
	var world: WorldState = start
	for step: StripsAction in plan.steps:
		world = step.apply(world)
	var added := PackedStringArray()
	for predicate: String in world.predicates():
		if not start.holds(predicate):
			added.append(predicate)
	return added


# The latest step from which the rest of the plan runs on this board and
# arrives at what the plan is for; -1 when there is none.
func _where_the_board_is(state: BoardState) -> int:
	if plan == null or (not plan.solved and not plan.partial):
		return -1
	var world: WorldState = TacticalPlanBridge.world_of(state)
	for start: int in range(plan.steps.size(), -1, -1):
		if _runs_from(world, start):
			return start
	return -1


func _runs_from(world: WorldState, start: int) -> bool:
	for index: int in range(start, plan.steps.size()):
		if not plan.steps[index].is_applicable(world):
			return false
		world = plan.steps[index].apply(world)
	return world.holds_all(_aim)


# The sentence for a plan that stopped running: the first step from where
# the plan was that cannot run on this board, and the fact it is missing.
#
# The rest of the plan is replayed from that step on the board as it is, and
# the first step that cannot run names the fact: a crossing shut three steps
# ahead is the reason, not the step the plan happened to be at.
func _what_broke(state: BoardState) -> String:
	var world: WorldState = TacticalPlanBridge.world_of(state)
	var start: int = clampi(next_step, 0, plan.steps.size() - 1)
	for index: int in range(start, plan.steps.size()):
		var missing: String = _first_missing(plan.steps[index], world)
		var said: Dictionary = {step = index + 1, name = plan.steps[index].name, fact = missing}
		if missing != "":
			return tr("step {step}, {name}, needs {fact}, which no longer holds").format(said)
		world = plan.steps[index].apply(world)
	return tr("from step {step}, {name}, the rest no longer reaches {facts}").format({
		step = start + 1, name = plan.steps[start].name, facts = ", ".join(_aim)})


static func _first_missing(step: StripsAction, world: WorldState) -> String:
	for predicate: String in step.preconditions:
		if not world.holds(predicate):
			return predicate
	return ""


# The first purchase -- banking, the forge, a unit -- at or after `from`, or
# -1.
func _next_purchase(from: int) -> int:
	if plan == null or from == -1:
		return -1
	for index: int in range(from, plan.steps.size()):
		if TacticalPlanBridge.asks(plan.steps[index].name)[0] in [TacticalPlanBridge.BANK, TacticalPlanBridge.BUY, TacticalPlanBridge.BUILD]:
			return index
	return -1


# The step at or after `next_step` this walker is the one to carry out: its
# type, starting from the zone it stands in. -1 for none.
func _step_for(state: BoardState, unit: Unit) -> int:
	var theirs: Unit = TacticalPlanBridge.their_workshop(state)
	if plan == null or next_step == -1 or theirs == null:
		return -1
	var zone: String = TacticalPlanBridge.zone_of(unit, theirs)
	for index: int in range(next_step, plan.steps.size()):
		var asked: Array[String] = TacticalPlanBridge.asks(plan.steps[index].name)
		if asked[1] == unit.type.type_name and TacticalPlanBridge.zone_for(asked[0]) == zone:
			return index
	return -1


# Carry out purchase step `index`, or hold the workshop and say what it is
# saving for. Banking is waiting for income, so it is skipped when the next
# purchase can be paid for already.
func _purchase(state: BoardState, workshop: Unit, index: int) -> TacticalDecision:
	var asked: Array[String] = TacticalPlanBridge.asks(plan.steps[index].name)
	if asked[0] == TacticalPlanBridge.BANK:
		var then: int = _next_purchase(index + 1)
		if then != -1 and _why_not_now(state, workshop, then) == BoardState.LEGAL:
			return _purchase(state, workshop, then)
		return TacticalDecision.hold(workshop.id, tr("{step}: saves, with {funds} funds, for {what}").format({
			step = _step_label(index), funds = state.funds_of(state.current_faction), what = _what(then)}), workshop.cell)
	var refusal: String = _why_not_now(state, workshop, index)
	if refusal != BoardState.LEGAL:
		var waits: String = tr("{step}: cannot -- {why}")
		if _plan_cost(asked) > state.funds_of(state.current_faction):
			waits = tr("{step}: saves -- {why}")
		return TacticalDecision.hold(workshop.id, waits.format({step = _step_label(index), why = TacticalRefusal.words(refusal)}), workshop.cell)
	if asked[0] == TacticalPlanBridge.BUY:
		return TacticalDecision.buy(workshop.id, TacticalRules.forge(), tr("{step}: buys the forge, which a ram needs").format({
			step = _step_label(index)}), workshop.cell)
	var order: ProductionOrder = _order(state, workshop, asked[1])
	return TacticalDecision.build(workshop.id, order, tr("{step}: builds {piece} at {cell}").format({
		step = _step_label(index), piece = TacticalStatus.a_piece(asked[1]), cell = order.cell}))


# Why purchase step `index` cannot be made on this board, or LEGAL.
func _why_not_now(state: BoardState, workshop: Unit, index: int) -> String:
	var asked: Array[String] = TacticalPlanBridge.asks(plan.steps[index].name)
	if asked[0] == TacticalPlanBridge.BUY:
		return state.why_upgrade_refused(TacticalRules.forge())
	if asked[0] == TacticalPlanBridge.BUILD:
		return state.why_production_refused(_order(state, workshop, asked[1]))
	return tr("step {step}, {name}, is not a purchase").format({step = index + 1, name = plan.steps[index].name})


# What purchase `asked` costs: the forge's price, or the unit type's.
static func _plan_cost(asked: Array[String]) -> int:
	if asked[0] == TacticalPlanBridge.BUY:
		return TacticalRules.FORGE_COST
	return (TacticalRules.unit_types()[asked[1]] as UnitType).cost


func _order(state: BoardState, workshop: Unit, type_name: String) -> ProductionOrder:
	var kind: UnitType = TacticalRules.unit_types()[type_name]
	return ProductionOrder.new(workshop.id, kind, TacticalRules.free_cell_beside(state, workshop, kind))


# What step `index` buys, in words: "the forge", "a ram", or "nothing".
func _what(index: int) -> String:
	if index == -1:
		return tr("nothing the plan names")
	var asked: Array[String] = TacticalPlanBridge.asks(plan.steps[index].name)
	return tr("the forge") if asked[0] == TacticalPlanBridge.BUY else TacticalStatus.a_piece(asked[1])


func _step_label(index: int) -> String:
	return tr("plan step {step} of {steps}, {name}").format({step = index + 1, steps = plan.steps.size(), name = plan.steps[index].name})


# A decision the rules made, saying why the plan did not make it.
static func _by_the_rules(decision: TacticalDecision, why: String) -> TacticalDecision:
	decision.reason = TranslationServer.translate("{reason} ({why}: the rules decide)").format({reason = decision.reason, why = why})
	return decision


func _our_workshop(state: BoardState) -> Unit:
	for unit: Unit in state.units_of(state.current_faction):
		if unit.type.type_name == TacticalRules.WORKSHOP:
			return unit
	return null
