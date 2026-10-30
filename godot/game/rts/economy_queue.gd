## The economy as a priority queue: what to build or train next, dearest
## wish first, and the workers kept busy underneath it.
##
## What shipped RTS economies are. Age of Empires II's AI scripts, Supreme
## Commander's and 0 A.D.'s all keep a list of wanted things with a priority
## each, and spend on the top of it (ADR 0010, point 2). The one rule that
## makes it a queue and not a shopping list: **the top wish waits for its
## price and nothing below it is bought meanwhile**. Without that, a cheap
## worker every few seconds would starve the barracks forever.
##
## Who fills the queue is not this class's business. `QueueSide` fills it
## from fixed rules -- the baseline; `RtsCommander` fills it from a plan.
## Under both, the same two reflexes run every decision: an idle worker goes
## to a deposit, and a share of workers goes to magma once magma is wanted.
##
## When not to use it: an economy with no contention, where everything
## wanted can be had at once. Then a list in any order does.
class_name EconomyQueue
extends RefCounted

## Workers wanted on each vent once magma is wanted, and on each base's ore.
const WORKERS_PER_VENT: int = 3
const WORKERS_PER_BASE: int = 8
## Purchases one decision may make: enough to keep three barracks busy.
const PURCHASES_PER_DECISION: int = 3
## How far from a base a deposit may be and still be mined from it.
const DEPOSIT_REACH: float = 9.0

## Every wish, dearest first: {what, priority, why}. `why` is shown on the
## screen beside it -- which rule or which step of the plan asked.
var wishes: Array[Dictionary] = []
## True once magma is wanted: workers are then split onto the vents.
var magma_wanted: bool = false
## The wish bought on the last decision, for the screen; {} for none.
var last_bought: Dictionary = {}
## Units weighed on the last decision: what `RtsController.work` reports.
var work: int = 0
## Where the last building it tried to place was to go: what the screen
## marks. Kept rather than asked again, because choosing a site rolls the
## side's dice, and a screen that rolled them would change the game.
var planned_site: Vector2i = Vector2i(-1, -1)

var _side: int
var _dice := RandomNumberGenerator.new()


## A queue for `side`, its choices of building site drawn from `seed_value`.
func _init(side: int, seed_value: int) -> void:
	_side = side
	_dice.seed = seed_value


## Wish for `what` at `priority`, said to be because of `why`, a
## `Sentence`: its English key and values, worded where it is shown (T80). A
## wish for the same thing replaces the old one, so asking every decision is
## safe.
func wish(what: String, priority: int, why: Array) -> void:
	forget(what)
	var index: int = 0
	while index < wishes.size() and wishes[index]["priority"] >= priority:
		index += 1
	wishes.insert(index, {"what": what, "priority": priority, "why": why})


## Drop any wish for `what`.
func forget(what: String) -> void:
	for index: int in range(wishes.size() - 1, -1, -1):
		if wishes[index]["what"] == what:
			wishes.remove_at(index)


## This decision's commands: wishes bought from the top while the top can
## be had, up to `PURCHASES_PER_DECISION`, and every idle worker put to
## work. A bought wish leaves the queue; the first that cannot be had stops
## the buying, so nothing below it spends what it is saving for.
func commands(view: RtsSnapshot) -> Array[RtsCommand]:
	work = 0
	last_bought = {}
	var given: Array[RtsCommand] = []
	var funds: Dictionary = view.resources.duplicate()
	while not wishes.is_empty() and given.size() < PURCHASES_PER_DECISION:
		var what: String = wishes[0]["what"]
		var bought: RtsCommand = _buy(view, what, funds, given)
		if bought == null:
			break
		given.append(bought)
		if bought.kind == RtsCommand.MOVE:
			break
		last_bought = wishes.pop_front()
		for resource: String in RtsKinds.RESOURCES:
			funds[resource] -= RtsKinds.cost(what)[resource]
	given.append_array(_put_workers_to_work(view, given))
	return given


## The top wish and why it waits, for the screen, as a `Sentence`: empty
## when the queue is.
func waiting_for(view: RtsSnapshot) -> Array:
	if wishes.is_empty():
		return []
	var top: String = wishes[0]["what"]
	if not view.can_pay(RtsKinds.cost(top)):
		return Sentence.of("{kind}: saving up", {kind = top})  # shown through tr()
	return Sentence.of("{kind}: {why}", {kind = top, why = wishes[0]["why"]})  # shown through tr()


# The command that buys `what` now, or null when it cannot be had yet --
# the price, no producer free, no worker, no site. A site in the fog cannot
# be built on (the rules refuse it), so the builder is walked there first:
# a move, and the wish stays at the top until the site is in sight.
# `funds` is what is left after this decision's earlier purchases, and
# `already` those purchases, so two are never made from one producer, one
# worker or one coin.
func _buy(view: RtsSnapshot, what: String, funds: Dictionary, already: Array[RtsCommand]) -> RtsCommand:
	for resource: String in RtsKinds.RESOURCES:
		if funds[resource] < RtsKinds.cost(what)[resource]:
			return null
	if not _has_what_it_needs(view, what):
		return null
	if RtsKinds.is_building(what):
		return _build(view, what, already)
	var supply: int = int(RtsKinds.of(what, "supply"))
	for command: RtsCommand in already:
		supply += int(RtsKinds.of(command.what, "supply")) if command.kind == RtsCommand.TRAIN else 0
	if view.supply_cap - view.supply_used < supply:
		return null
	var used: Dictionary = _units_in(already)
	for producer: Dictionary in view.mine():
		work += 1
		if _free_to_train(producer, what) and not used.has(producer["id"]):
			return RtsCommand.train(producer["id"], what)
	return null


# Complete, able to train it, nothing queued -- and, for a tower, not armed
# already: the rules refuse a second arm, and asking would hold the queue.
static func _free_to_train(producer: Dictionary, what: String) -> bool:
	return producer["complete"] and what in RtsKinds.of(producer["kind"], "trains") and producer["queued"] == 0 \
		and not producer["armed"]


static func _units_in(commands_given: Array[RtsCommand]) -> Dictionary:
	var used: Dictionary = {}
	for command: RtsCommand in commands_given:
		for id: int in command.unit_ids:
			used[id] = true
	return used


# The rules would refuse a lab before a barracks stands complete; the queue
# waits instead of giving an order it knows will be refused.
static func _has_what_it_needs(view: RtsSnapshot, what: String) -> bool:
	var needed: String = RtsKinds.of(what, "needs")
	if needed == "":
		return true
	for unit: Dictionary in view.mine(needed):
		if unit["complete"]:
			return true
	return false


func _build(view: RtsSnapshot, what: String, already: Array[RtsCommand]) -> RtsCommand:
	var site: Vector2i = site_for(view, what)
	planned_site = site
	if site == Vector2i(-1, -1):
		return null
	var builder: Dictionary = _walking_to(view, site)
	if builder.is_empty():
		builder = _free_worker(view, _units_in(already))
	if builder.is_empty():
		return null
	if _in_sight(view, site):
		return RtsCommand.build(builder["id"], what, site)
	if builder["order"] == RtsCommand.MOVE and builder["goal"] == site:
		return null
	return RtsCommand.move([builder["id"]] as Array[int], site)


# The worker already sent towards `site`, so one walk is not begun twice.
func _walking_to(view: RtsSnapshot, site: Vector2i) -> Dictionary:
	for worker: Dictionary in view.mine(RtsKinds.WORKER):
		if worker["order"] == RtsCommand.MOVE and worker["goal"] == site:
			return worker
	return {}


static func _in_sight(view: RtsSnapshot, cell: Vector2i) -> bool:
	var middle: Vector2 = Vector2(cell) + Vector2(0.5, 0.5)
	for unit: Dictionary in view.mine():
		if (unit["position"] as Vector2).distance_to(middle) <= RtsKinds.sight(unit["kind"], unit["complete"]):
			return true
	return false


## Where `what` would go: a base on the side's untaken expansion, anything
## else on open ground round its first base, a ring at a time. (-1, -1) when
## nowhere is free.
func site_for(view: RtsSnapshot, what: String) -> Vector2i:
	if what == RtsKinds.BASE:
		return _expansion_site(view)
	var taken: Dictionary = _cells_in_use(view)
	for ring: int in range(3, 8):
		var site: Vector2i = _site_on_ring(view, ring, taken)
		if site != Vector2i(-1, -1):
			return site
	return Vector2i(-1, -1)


# A fit cell `ring` steps from home, the search started at a cell the dice
# choose so buildings spread round the base rather than piling on one side.
func _site_on_ring(view: RtsSnapshot, ring: int, taken: Dictionary) -> Vector2i:
	var cells: Array[Vector2i] = _ring_cells(RtsScenario.home(_side), ring)
	var start: int = _dice.randi_range(0, cells.size() - 1)
	for offset: int in range(cells.size()):
		var cell: Vector2i = cells[(start + offset) % cells.size()]
		work += 1
		if _fit_to_build_on(view, cell, taken):
			return cell
	return Vector2i(-1, -1)


# Open, unblocked, nobody standing there, and a way round it kept.
static func _fit_to_build_on(view: RtsSnapshot, cell: Vector2i, taken: Dictionary) -> bool:
	if not view.graph.contains(cell) or view.graph.is_blocked(cell) or taken.has(cell):
		return false
	return _keeps_a_way_round(view, cell)


# Its own expansion's cell, when no base of anybody's stands near it.
func _expansion_site(view: RtsSnapshot) -> Vector2i:
	var region: String = "west expansion" if _side == RtsScenario.WEST else "east expansion"  # not shown: an identifier
	var cell: Vector2i = RtsScenario.REGIONS[region]["cell"]
	for unit: Dictionary in view.units:
		if unit["kind"] == RtsKinds.BASE and (unit["position"] as Vector2).distance_to(Vector2(cell)) < 4.0:
			return Vector2i(-1, -1)
	return cell


# A building in a doorway walls a base in. A cell is fit when its four
# neighbours are open, so two buildings never touch and a gap stays round each.
static func _keeps_a_way_round(view: RtsSnapshot, cell: Vector2i) -> bool:
	for direction: Vector2i in GakGridGraph.DIRECTIONS:
		var beside: Vector2i = cell + direction
		if not view.graph.contains(beside) or view.graph.is_blocked(beside):
			return false
	return true


func _cells_in_use(view: RtsSnapshot) -> Dictionary:
	var taken: Dictionary = {}
	for unit: Dictionary in view.units:
		taken[Vector2i((unit["position"] as Vector2).floor())] = true
	return taken


# The cells exactly `ring` steps from `centre`, a row at a time, top first.
static func _ring_cells(centre: Vector2i, ring: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var across: int = 2 * ring + 1
	for index: int in range(across * across):
		var offset := Vector2i(index % across - ring, index / across - ring)
		if maxi(absi(offset.x), absi(offset.y)) == ring:
			cells.append(centre + offset)
	return cells


# A worker to take off mining: an idle one first, else one carrying nothing
# on its way to ore. Never one already building.
func _free_worker(view: RtsSnapshot, taken: Dictionary) -> Dictionary:
	var fallback: Dictionary = {}
	for worker: Dictionary in view.mine(RtsKinds.WORKER):
		work += 1
		if taken.has(worker["id"]):
			continue
		if worker["order"] == RtsUnit.IDLE:
			return worker
		if fallback.is_empty() and worker["order"] == RtsCommand.GATHER and worker["carrying"] == 0:
			fallback = worker
	return fallback


# Every idle worker -- except one just given a building -- to the deposit
# that most wants a worker: magma while its vents are short and magma is
# wanted, else the ore nearest a base. While the vents are short, a worker
# on ore with empty hands is moved too: at the start nobody is idle, and
# waiting for an idle one would wait forever.
func _put_workers_to_work(view: RtsSnapshot, already: Array[RtsCommand]) -> Array[RtsCommand]:
	var busy: Dictionary = {}
	for command: RtsCommand in already:
		for id: int in command.unit_ids:
			busy[id] = true
	var on_magma: int = _gatherers_of(view, RtsKinds.MAGMA)
	var magma_short: int = WORKERS_PER_VENT * _home_deposits(view, RtsKinds.MAGMA).size() - on_magma
	if not magma_wanted:
		magma_short = 0
	var given: Array[RtsCommand] = []
	for worker: Dictionary in view.mine(RtsKinds.WORKER):
		work += 1
		if busy.has(worker["id"]):
			continue
		var idle: bool = worker["order"] == RtsUnit.IDLE
		if not idle and not (magma_short > 0 and _mining_ore_empty_handed(view, worker)):
			continue
		var resource: String = RtsKinds.MAGMA if magma_short > 0 else RtsKinds.ORE
		var deposit: Dictionary = _nearest_home_deposit(view, worker["position"], resource)
		if deposit.is_empty():
			deposit = _nearest_home_deposit(view, worker["position"], RtsKinds.ORE)
		if deposit.is_empty() or deposit["id"] == worker["target"]:
			continue
		if resource == RtsKinds.MAGMA:
			magma_short -= 1
		given.append(RtsCommand.gather([worker["id"]] as Array[int], deposit["id"]))
	return given


static func _mining_ore_empty_handed(view: RtsSnapshot, worker: Dictionary) -> bool:
	if worker["order"] != RtsCommand.GATHER or worker["carrying"] > 0:
		return false
	for deposit: Dictionary in view.deposits(RtsKinds.ORE):
		if deposit["id"] == worker["target"]:
			return true
	return false


## How many of the side's workers are gathering `resource` now.
func _gatherers_of(view: RtsSnapshot, resource: String) -> int:
	var deposit_yields: Dictionary = {}
	for deposit: Dictionary in view.deposits():
		deposit_yields[deposit["id"]] = RtsKinds.of(deposit["kind"], "yields")
	var count: int = 0
	for worker: Dictionary in view.mine(RtsKinds.WORKER):
		if worker["order"] == RtsCommand.GATHER and deposit_yields.get(worker["target"], "") == resource:
			count += 1
	return count


# The deposits of `resource` within reach of one of the side's bases.
func _home_deposits(view: RtsSnapshot, resource: String) -> Array[Dictionary]:
	var near: Array[Dictionary] = []
	for deposit: Dictionary in view.deposits(resource):
		if _a_base_near(view, deposit["position"]):
			near.append(deposit)
	return near


static func _a_base_near(view: RtsSnapshot, point: Vector2) -> bool:
	for base: Dictionary in view.mine(RtsKinds.BASE):
		if base["complete"] and (base["position"] as Vector2).distance_to(point) <= DEPOSIT_REACH:
			return true
	return false


func _nearest_home_deposit(view: RtsSnapshot, from: Vector2, resource: String) -> Dictionary:
	var best: Dictionary = {}
	for deposit: Dictionary in _home_deposits(view, resource):
		if best.is_empty() or from.distance_to(deposit["position"]) < from.distance_to(best["position"]):
			best = deposit
	return best
