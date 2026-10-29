## The GOAP team (T25), one of the board's controllers: for each walker, choose
## the most pressing goal, plan the cheapest way to it backwards from the goal,
## and do the first step -- then plan again for the next walker, and next turn,
## from scratch.
##
## What lets GOAP stand apart from the tree here is what T15's guard lacked
## (the owner's note on wave 57): **two ways to a goal, at two costs, and the
## costs read off the board.** "Pressure" -- making their side's game worse --
## comes three ways: a fight it wins in reach, a control point, or a siege,
## each priced in turns by the walker's route round their pieces; "home safe" comes two ways: walk back to the
## intruder, or strike it where it stands if it is prey. The tree ranks hunt
## above a point above a siege, always; GOAP takes a near point over a far
## workshop and a far point under a near one, because the price changed.
##
## Prices, in turns:
##
## - **hunt**: `HUNT_COST` -- one blow, in reach now;
## - **take point**: the turns to walk there, plus `POINT_COST` -- it pays
##   only while it is held, and holding it is the work;
## - **siege**: the turns to walk to their workshop, plus `SIEGE_COST` -- the
##   same as a point's, so the nearer of the two is the one taken, and at a
##   tie the point (it is listed first, and the search keeps the first);
## - **defend**: the turns to walk to the intruder;
## - **fall back**: `HUNT_COST`.
##
## One difference the prices make that the tree's ranking does not: beside
## their workshop with a fight in reach only by walking, GOAP takes the fight
## (1 against at least 3) and walks off the siege, where the tree and the HTN
## rank "at their workshop" above every hunt. Neither is wrong; it is what a
## price says and a ranking does not.
##
## Choosing the goal is not planning, as T15 says of its guard: "safe" when in
## danger and wounded, "home safe" when home is threatened, and "pressure"
## otherwise. With no plan to it -- every way shut -- it marches by the rules.
##
## When not to use it: see `GoapPlanner`.
class_name GoapTeam
extends TechniqueTeam

const HUNT_COST: int = 1
const POINT_COST: int = 2
const SIEGE_COST: int = 2
## The price of a deed whose place no route reaches: dearer than any walk on
## this board, so it is taken only when nothing else gets there.
const FAR: int = 99

## The last plan made, for the screen and the tests.
var plan: BehaviourPlan = BehaviourPlan.new()
## The goal it was made for.
var goal: Dictionary = {}

var _planner := GoapPlanner.new()
# Walker id -> its goal and plan, said, from its last decision.
var _said: Dictionary[int, Array] = {}
# The board and walker the prices are read for: `decide` is handed the facts,
# and a price needs the route.
var _pricing_state: BoardState


## The name the league table and the screen give it.
func controller_name() -> String:
	return "GOAP"  # shown through tr()


## One line for the screen: what kind of thinking this is.
func describe() -> String:
	return tr("GOAP: a goal per walker, the cheapest plan to it by turns on this board, replanned every decision; builds by the rules")


## The board is kept for the prices, then the rules' decision is made as
## every team's is.
func decide_move(state: BoardState, unit_id: int) -> TacticalDecision:
	_pricing_state = state
	return super.decide_move(state, unit_id)


## Choose the goal, price the actions, plan, and take the first step.
func decide(unit: Unit, known: TeamFacts) -> String:
	goal = goal_for(known.facts)
	plan = _planner.plan(actions_for(_pricing_state, unit, known), known.facts, goal)
	_work += plan.visited
	var first: String = plan.steps[0] if not plan.steps.is_empty() else SIEGE
	var planned: Array = TacticalStatus.in_order(plan.steps) if plan.solved else Sentence.of("none")  # shown through tr()
	_said[unit.id] = Sentence.of("goal {goal}, plan {plan}", {goal = ", ".join(goal.keys()), plan = planned})  # shown through tr()
	return first


## The walker's goal and the plan to it, from its last decision.
func thinking(unit_id: int) -> Array:
	return _said.get(unit_id, Sentence.of("no plan yet"))  # shown through tr()


## "Worlds": the goals-still-to-do the backward search looked at.
func work_unit() -> String:
	return "worlds"


## The goal on these facts, most pressing first.
static func goal_for(facts: Dictionary) -> Dictionary:
	if facts["in_danger"] and facts["wounded"]:
		return {"safe": true}
	if facts["home_threatened"]:
		return {"home_safe": true}
	return {"pressure": true}


## The five deeds as GOAP actions for `unit`, priced in turns on `state`.
## The deed is the action's name, so a plan's first step is what to do --
## save "strike the intruder", which is a hunt.
func actions_for(state: BoardState, unit: Unit, known: TeamFacts) -> Array[GoapAction]:
	var routes: Dictionary = TacticalReach.route_costs(_past_red(state, unit.type), unit.cell)
	var workshop: Unit = _nearest_workshop(state, unit)
	var to_point: int = _turns(unit, routes, known.point) if known.facts["point_free"] else FAR
	var to_workshop: int = _turns(unit, routes, workshop.cell) if workshop != null else FAR
	var to_intruder: int = _turns_beside(unit, routes, known.intruder.cell) if known.intruder != null else FAR
	return [
		GoapAction.new(HUNT, HUNT_COST, {"prey_in_reach": true}, {"pressure": true}),
		GoapAction.new(TAKE_POINT, to_point + POINT_COST, {"point_free": true}, {"pressure": true}),
		GoapAction.new(SIEGE, to_workshop + SIEGE_COST, {"way_to_their_workshop": true}, {"pressure": true}),
		GoapAction.new(DEFEND, to_intruder, {"home_threatened": true}, {"home_safe": true}),
		GoapAction.new(HUNT, HUNT_COST, {"prey_is_intruder": true}, {"home_safe": true}),
		GoapAction.new(FALL_BACK, HUNT_COST, {"in_danger": true}, {"safe": true}),
	] as Array[GoapAction]


# Turns to walk to `cell` by `routes` -- flooded from the walker, round their
# pieces -- at the walker's movement; `FAR` when no route reaches it.
static func _turns(unit: Unit, routes: Dictionary, cell: Vector2i) -> int:
	if not routes.has(cell):
		return FAR
	return ceili(float(routes[cell]) / maxi(unit.type.movement, 1))


# Turns to walk beside `cell`, which a piece stands on and so no route enters.
static func _turns_beside(unit: Unit, routes: Dictionary, cell: Vector2i) -> int:
	var nearest: int = FAR
	for step: Vector2i in GridGraph.DIRECTIONS:
		nearest = mini(nearest, _turns(unit, routes, cell + step))
	return nearest
