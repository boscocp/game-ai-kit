## The commander's build order: what the side has, as STRIPS facts, and the
## plan from there to a goal -- searched by T11's planner or decomposed by
## T15's HTN, over one domain, so the two can be measured against each other.
##
## The domain is `spec/pddl/rts-build-order-domain.pddl`, read here from a
## byte-for-byte copy of its JSON. It has no numbers in it (ADR 0010, point
## 4): `facts` turns the snapshot into "enough of" facts, and how long each
## step will wait for its price is `BuildSchedule`'s question, asked after.
##
## **STRIPS** (`Planner.STRIPS`) searches: A* with h_max over bits, inside a
## budget, looking `horizon` actions ahead -- the difficulty knob. It finds
## an order nobody wrote. **HTN** (`Planner.HTN`) decomposes: `RECIPES` is
## the designer's order for getting each fact, written by hand, and the
## planner only chooses among the orders written there (Humphreys, Game AI
## Pro ch. 12). ADR 0010 asked which the RTS commander should use; T20
## measures both in `test/rts/rts_match.gd` and the ADR records the answer.
##
## `arm_tower` and `tower_armed` (T56) are in the domain, and no goal the
## commander sets asks for them: the arm is weighed beside the plan
## (`TowerWorth`), not planned. The step stays because `BuildSchedule` times
## the gun by it, and the HTN and STRIPS still answer it alike.
##
## When not to use it: a side whose economy has no chain -- one producer,
## one resource. A priority queue alone does that, and costs nothing.
class_name BuildOrder
extends RefCounted

enum Planner { STRIPS, HTN }

const DOMAIN_PATH: String = "res://game/rts/build_order_domain.json"
## A squad's worth of one kind: what "ready" means in `runners_ready`.
const SQUAD: int = 4
## Free room that counts as `supply_room`: one batch of the dearest unit.
const ROOM_FOR_A_BATCH: int = 4
## Worlds taken off the frontier, or tasks taken up, before a call gives up.
const BUDGET: int = 2000
## The most worlds one STRIPS call at normal's horizon may visit, over every
## set of the seven economy facts held against every goal the commander can
## set -- counted, not timed, so the gate holds on any machine. Measured 69.
## A goal with `tower_armed` in it would make it 76; none has it.
const WORST_VISITED: int = 70

## Each action's purchase: the kind it wishes for. `mine_magma` buys
## nothing; it turns workers onto the vents. `arm_tower` buys an upgrade,
## `RtsKinds.ARM`, which a tower queues as a barracks queues a fighter.
const BUYS: Dictionary = {
	"train_workers": RtsKinds.WORKER, "build_depot": RtsKinds.DEPOT, "mine_magma": "",
	"build_barracks": RtsKinds.BARRACKS, "build_lab": RtsKinds.LAB, "build_tower": RtsKinds.TOWER,
	"arm_tower": RtsKinds.ARM, "expand": RtsKinds.BASE, "train_runners": RtsKinds.RUNNER, "train_shields": RtsKinds.SHIELD,
	"train_mortars": RtsKinds.MORTAR,
}

## The HTN's methods, by hand: to get a fact that does not hold, get these
## first, in this order, then take the last, which is an action. The order is
## the designer's judgement -- room is got last before training, because
## training uses it up -- and the HTN never invents another.
const RECIPES: Dictionary = {
	"supply_room": ["build_depot"],
	"workers_saturated": ["supply_room", "train_workers"],
	"magma_flowing": ["workers_saturated", "mine_magma"],
	"barracks_up": ["build_barracks"],
	"lab_up": ["barracks_up", "magma_flowing", "build_lab"],
	"tower_up": ["magma_flowing", "build_tower"],
	"tower_armed": ["tower_up", "magma_flowing", "arm_tower"],
	"expansion_up": ["workers_saturated", "expand"],
	"runners_ready": ["barracks_up", "supply_room", "train_runners"],
	"shields_ready": ["barracks_up", "magma_flowing", "supply_room", "train_shields"],
	"mortars_ready": ["lab_up", "magma_flowing", "supply_room", "train_mortars"],
}

static var _actions: Array[StripsAction] = []


## The domain's actions, read once from its JSON.
static func actions() -> Array[StripsAction]:
	if not _actions.is_empty():
		return _actions
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DOMAIN_PATH))
	for entry: Dictionary in parsed["actions"]:
		var needs := PackedStringArray(entry["preconditions"])
		_actions.append(StripsAction.new(entry["name"], needs, PackedStringArray(entry["deletes"]),
			PackedStringArray(entry["adds"])))
	return _actions


## The action called `step`, or null.
static func action_named(step: String) -> StripsAction:
	for action: StripsAction in actions():
		if action.name == step:
			return action
	return null


## What holds for the side `view` belongs to, as the domain's facts. A
## building counts from the moment it is paid for, so a plan never asks for
## a second barracks while the first goes up; a unit counts from the moment
## it is queued, for the same reason, and so does a tower's arm.
static func facts(view: RtsSnapshot) -> PackedStringArray:
	var counts: Dictionary = _counts(view)
	var held := PackedStringArray()
	if counts.get(RtsKinds.WORKER, 0) >= EconomyQueue.WORKERS_PER_BASE * maxi(counts.get(RtsKinds.BASE, 0), 1):
		held.append("workers_saturated")
	if free_room(view) >= ROOM_FOR_A_BATCH:
		held.append("supply_room")
	if _on_magma(view) > 0:
		held.append("magma_flowing")
	for pair: Array in [[RtsKinds.BARRACKS, "barracks_up"], [RtsKinds.LAB, "lab_up"], [RtsKinds.TOWER, "tower_up"],
			[RtsKinds.ARM, "tower_armed"]]:
		if counts.get(pair[0], 0) > 0:
			held.append(pair[1])
	if counts.get(RtsKinds.BASE, 0) >= 2:
		held.append("expansion_up")
	for pair: Array in [[RtsKinds.RUNNER, "runners_ready"], [RtsKinds.SHIELD, "shields_ready"], [RtsKinds.MORTAR, "mortars_ready"]]:
		if counts.get(pair[0], 0) >= SQUAD:
			held.append(pair[1])
	return held


## A plan from `held` to every fact of `goal`, by `planner`, looking at most
## `horizon` actions ahead (STRIPS only; `HeuristicPlanner.NO_HORIZON` for
## no limit). {steps: PackedStringArray, solved, partial, visited}.
static func plan(held: PackedStringArray, goal: PackedStringArray, planner: Planner,
		horizon: int = HeuristicPlanner.NO_HORIZON) -> Dictionary:
	if planner == Planner.HTN:
		return _decompose(held, goal)
	var found: PlanResult = HeuristicPlanner.new().plan(actions(), WorldState.new(held), goal,
		HeuristicPlanner.Guide.H_MAX, BUDGET, horizon)
	return {"steps": found.action_names(), "solved": found.solved, "partial": found.partial,
		"visited": found.visited}


static func _decompose(held: PackedStringArray, goal: PackedStringArray) -> Dictionary:
	var domain := HtnDomain.new()
	for action: StripsAction in actions():
		var needs: Dictionary = {}
		var makes: Dictionary = {}
		for fact: String in action.preconditions:
			needs[fact] = true
		for fact: String in action.deletes:
			makes[fact] = false
		for fact: String in action.adds:
			makes[fact] = true
		domain.add_primitive(action.name, needs, makes)
	for fact: String in RECIPES:
		domain.add_method("get " + fact, "have it", {fact: true}, [] as Array[String])
		var subtasks: Array[String] = []
		for part: String in RECIPES[fact]:
			subtasks.append(part if BUYS.has(part) else "get " + part)
		domain.add_method("get " + fact, "make it", {}, subtasks)
	var top: Array[String] = []
	for fact: String in goal:
		top.append("get " + fact)
	domain.add_method("the goal", "in order", {}, top)
	var world: Dictionary = {}
	for fact: String in held:
		world[fact] = true
	var found: BehaviourPlan = HtnPlanner.new().plan(domain, world, "the goal", BUDGET)
	return {"steps": PackedStringArray(found.steps), "solved": found.solved, "partial": false,
		"visited": found.visited}


# Own units by kind, queued ones counted as if standing, and an armed
# tower's arm as one of `RtsKinds.ARM`.
static func _counts(view: RtsSnapshot) -> Dictionary:
	var counts: Dictionary = {}
	for unit: Dictionary in view.mine():
		counts[unit["kind"]] = counts.get(unit["kind"], 0) + 1
		if unit["armed"]:
			counts[RtsKinds.ARM] = counts.get(RtsKinds.ARM, 0) + 1
		for queued: String in unit.get("queue", []):
			counts[queued] = counts.get(queued, 0) + 1
	return counts


## Free room, a depot still going up counted as the room it will give: it is
## paid for, and planning a second one meanwhile is the classic waste.
static func free_room(view: RtsSnapshot) -> int:
	var coming: int = 0
	for unit: Dictionary in view.mine():
		if not unit["complete"]:
			coming += int(RtsKinds.of(unit["kind"], "provides"))
	return mini(view.supply_cap + coming, RtsKinds.SUPPLY_LIMIT) - view.supply_used


static func _on_magma(view: RtsSnapshot) -> int:
	var vents: Dictionary = {}
	for deposit: Dictionary in view.deposits(RtsKinds.MAGMA):
		vents[deposit["id"]] = true
	var count: int = 0
	for worker: Dictionary in view.mine(RtsKinds.WORKER):
		if worker["order"] == RtsCommand.GATHER and vents.has(worker["target"]):
			count += 1
	return count
