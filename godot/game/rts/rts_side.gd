## A computer side in the RTS: the three layers under one controller, all
## but the top one shared.
##
## ADR 0010's layers, bottom up. **Units** move and fight by themselves, on
## T19's flow fields. **Squads** gather fighters into groups of
## `Squad.SIZE`, each run by its state machine and sent where
## `SquadTactics` scores highest over this side's `RtsInfluence`. The
## **economy** is an `EconomyQueue`. What tops it is the one thing a
## subclass decides: `QueueSide` fills the queue from fixed rules, the way
## shipped RTS economies do; `RtsCommander` from a plan. Everything below is
## the same for both, so a match between them measures the top layer alone.
##
## Every layer is timed into `timings`, so `test/rts_match.gd` can hold
## each to its share of `FrameBudget` and the screen can show what each
## cost. The clock is read to measure, never to cut a decision short.
##
## When not to use it: a side a person plays. A person's clicks go through
## `RtsMatch.give`; nothing here runs for them.
class_name RtsSide
extends RtsController

## Barracks a side raises when ore piles up, and how much is piling up.
const MOST_BARRACKS: int = 3
const FLOATING_ORE: int = 500
## Every squad there can be at once; spare fighters wait in the forming one.
const MOST_SQUADS: int = 4

var side: int
var level: Difficulty
var queue: EconomyQueue
var belief: RtsInfluence
var tactics: SquadTactics
var squads: Array[Squad] = []
## Layer -> every decision's microseconds for it: "strategy", "tactics".
var timings: Dictionary = {FrameBudget.STRATEGY: PackedInt64Array(), FrameBudget.TACTICS: PackedInt64Array()}
## The last arrow each squad took, by squad id: what the screen prints.
var squad_news: Dictionary = {}

var _next_squad: int = 1


## A side played at `side_level`, its dice drawn from `seed_value`.
func _init(side_played: int, side_level: Difficulty, seed_value: int) -> void:
	side = side_played
	level = side_level
	queue = EconomyQueue.new(side, seed_value)
	belief = RtsInfluence.new(RtsScenario.MAP[0].length(), RtsScenario.MAP.size())
	tactics = SquadTactics.new(side, level.search_depth, level.evaluation_noise, seed_value + 1)


## The economy's purchase and the squads' orders for this decision.
func decide(view: RtsSnapshot) -> Array[RtsCommand]:
	var started: int = Time.get_ticks_usec()
	_fill_queue(view)
	var given: Array[RtsCommand] = queue.commands(view)
	given.append_array(_mend(view, given))
	_record(FrameBudget.STRATEGY, Time.get_ticks_usec() - started)
	started = Time.get_ticks_usec()
	belief.update(view)
	given.append_array(_lead_the_army(view))
	_record(FrameBudget.TACTICS, Time.get_ticks_usec() - started)
	work = queue.work + squads.size()
	return given


## Below this share of its health a building is sent a worker to mend it.
const MEND_BELOW: float = 0.7
## No worker is sent while an enemy stands this near: it would die mending.
const MEND_SAFE: float = 8.0


# One worker to each hurt building of the side with no enemy in sight near
# it and nobody already mending it: the reflex a person has, by the order a
# person gives. A worker this decision already gave a job is left alone.
func _mend(view: RtsSnapshot, already: Array[RtsCommand]) -> Array[RtsCommand]:
	var given: Array[RtsCommand] = []
	var busy: Dictionary = {}
	for command: RtsCommand in already:
		for id: int in command.unit_ids:
			busy[id] = true
	for building: Dictionary in view.mine():
		var worker: Dictionary = _mender_for(view, building, busy) if _wants_mending(view, building) else {}
		if worker.is_empty():
			continue
		busy[worker["id"]] = true
		given.append(RtsCommand.repair([worker["id"]] as Array[int], building["id"]))
	return given


# Hurt, finished, nobody mending it already, and no enemy in sight near it.
static func _wants_mending(view: RtsSnapshot, building: Dictionary) -> bool:
	if not RtsKinds.is_building(building["kind"]) or not building["complete"]:
		return false
	if building["health"] >= int(RtsKinds.of(building["kind"], "health")) * MEND_BELOW:
		return false
	for unit: Dictionary in view.mine(RtsKinds.WORKER):
		if unit["order"] == RtsCommand.REPAIR and unit["target"] == building["id"]:
			return false
	for enemy: Dictionary in view.enemies():
		if (enemy["position"] as Vector2).distance_to(building["position"]) <= MEND_SAFE:
			return false
	return true


# The nearest worker not carrying anything and not already given a job.
static func _mender_for(view: RtsSnapshot, building: Dictionary, busy: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	for worker: Dictionary in view.mine(RtsKinds.WORKER):
		if busy.has(worker["id"]) or worker["carrying"] > 0 or worker["order"] == RtsCommand.BUILD:
			continue
		var near: float = (worker["position"] as Vector2).distance_to(building["position"])
		if best.is_empty() or near < (best["position"] as Vector2).distance_to(building["position"]):
			best = worker
	return best


## What tops the economy: a subclass wishes into `queue` here. The base
## class wishes nothing, so its side mines and never builds.
func _fill_queue(_view: RtsSnapshot) -> void:
	pass


## The wishes every side keeps under whatever tops it: a depot before the
## room runs out, workers up to a full home, and another barracks while ore
## piles up unspent.
func _reflexes(view: RtsSnapshot) -> void:
	var held: PackedStringArray = BuildOrder.facts(view)
	if BuildOrder.free_room(view) < 2 and view.supply_cap < RtsKinds.SUPPLY_LIMIT:
		queue.wish(RtsKinds.DEPOT, 95, "reflex: the room is nearly gone")
	else:
		queue.forget(RtsKinds.DEPOT)
	if not "workers_saturated" in held:
		queue.wish(RtsKinds.WORKER, 50, "reflex: the home is short of workers")
	else:
		queue.forget(RtsKinds.WORKER)
	var barracks: int = view.mine(RtsKinds.BARRACKS).size()
	if barracks > 0 and barracks < MOST_BARRACKS and view.resources[RtsKinds.ORE] >= FLOATING_ORE:
		queue.wish(RtsKinds.BARRACKS, 35, "reflex: ore piling up, another barracks")


## What the side is thinking, for the screen and `test/demo_overlays.gd`.
func overlay(view: RtsSnapshot) -> Dictionary:
	var listed: Array[Dictionary] = []
	for squad: Squad in squads:
		listed.append({"id": squad.id, "state": squad.machine.current, "size": squad.members.size(),
			"target": squad.target, "ratio": squad.ratio, "news": squad_news.get(squad.id, ""), "focus": squad.focus,
			"scores": squad.scores if squad.machine.current == Squad.ADVANCE else {}})
	return {"wishes": queue.wishes.duplicate(true), "waiting": queue.waiting_for(view), "squads": listed}


func _record(layer: String, microseconds: int) -> void:
	var times: PackedInt64Array = timings[layer]
	times.append(microseconds)
	timings[layer] = times


# Fighters into squads, squads updated, an advancing squad given the best
# region, and every squad's orders.
func _lead_the_army(view: RtsSnapshot) -> Array[RtsCommand]:
	_enlist(view)
	var given: Array[RtsCommand] = []
	for squad: Squad in squads:
		var arrow: String = squad.update(view)
		if arrow != "":
			squad_news[squad.id] = arrow
		if squad.machine.current == Squad.ADVANCE:
			squad.target = tactics.choose(squad, belief)
		given.append_array(squad.commands(view))
	squads.assign(squads.filter(func(squad: Squad) -> bool: return not squad.members.is_empty()))
	return given


# Every fighter in no squad joins the one still gathering, or a new one.
func _enlist(view: RtsSnapshot) -> void:
	var enlisted: Dictionary = {}
	for squad: Squad in squads:
		for member: int in squad.members:
			enlisted[member] = true
	for fighter: Dictionary in view.mine():
		if not RtsKinds.fights(fighter["kind"]) or enlisted.has(fighter["id"]):
			continue
		_forming().members.append(fighter["id"])


func _forming() -> Squad:
	for squad: Squad in squads:
		if squad.machine.current == Squad.GATHER and squad.members.size() < Squad.SIZE * 2:
			return squad
	if squads.size() >= MOST_SQUADS:
		return squads[squads.size() - 1]
	var fresh := Squad.new(_next_squad, side)
	_next_squad += 1
	squads.append(fresh)
	return fresh
