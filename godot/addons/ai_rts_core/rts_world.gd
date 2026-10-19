## A real-time match's whole state, changed in place, one fixed tick at a time.
##
## `ai_core`'s `BoardState` answers every move with a new board. That is what
## lets a search try a thousand moves, and it cost 50 ms to move 200 units one
## cell each, measured in T19 -- three whole frames. So this core mutates:
## a tick moves every unit a little, and nothing is copied. What searches get
## instead is a frozen copy, `RtsSnapshot`, which is also the only thing an AI
## is ever shown. The game mutates; the planner reads a snapshot.
##
## Three promises, each held by `test/rts_simulation.gd`:
##   * deterministic: a fixed tick, every random number from the seed, nothing
##     read from the clock or the screen -- one seed and one list of commands
##     always end in the same `digest()`;
##   * one way in: `command()`, which refuses what a side may not do, so a
##     person and an AI are held to the same rules;
##   * fog: `visible_to()` is what a side can see, and snapshots obey it.
##
## When not to use it: anything turn-based, or anything that searches over
## moves. Use `ai_core`, which is built for exactly that (ADR 0019).
class_name RtsWorld
extends RefCounted

const TICKS_PER_SECOND: int = 60
## The side of whatever belongs to nobody: the mines.
const NEUTRAL: int = -1
## Cells of flow field settled per tick, across every field being built: the
## flow-field layer's share of the frame, in work rather than milliseconds, so
## the same match settles the same cells on any machine. `FrameBudget` holds
## the milliseconds this costs to its share: measured in T19 at about 2.4 us a
## cell, so 512 is some 1.2 ms, and a 64 x 64 field takes eight ticks.
const FIELD_CELLS_PER_TICK: int = 512
## A field nobody has asked for in this many ticks is dropped: one second.
const FIELD_KEPT_FOR: int = TICKS_PER_SECOND

var graph: GridGraph
var tick: int = 0
## What each side has to spend, by side.
var resources: Dictionary = {}
## Who stands where, for every question about who is near.
var spatial := SpatialHash.new()
## Every random number in the match comes from here, seeded once.
var rng := RandomNumberGenerator.new()
## Flow fields started since the world was made: the price of the questions
## "how do I get there", paid once per goal rather than once per unit.
var fields_started: int = 0
## What each side's workers have carried home, by side: income, kept apart
## from `resources` so spending cannot hide it.
var delivered: Dictionary = {}
## Buildings each side has finished raising, by side: kept because a
## building raised and then lost leaves no other trace.
var raised: Dictionary = {}

var _units: Dictionary = {}
var _next_id: int = 1
var _fields: Dictionary = {}
# The tick each field was last asked for.
var _asked: Dictionary = {}
# The cost a building's cell had before the building blocked it.
var _covered: Dictionary = {}


## A world on a copy of `board`, its dice seeded with `match_seed`, and
## nobody in it.
func _init(board: GridGraph, match_seed: int) -> void:
	graph = board.duplicate_graph()
	rng.seed = match_seed


## Put a `kind` of `side` in the middle of `cell`. A building blocks its cell;
## one not `complete` starts at 1 health and is raised by a worker.
func add_unit(kind: String, side: int, cell: Vector2i, complete: bool = true) -> RtsUnit:
	var health: int = RtsKinds.of(kind, "health") if complete else 1
	var unit := RtsUnit.new(_next_id, side, kind, Vector2(cell) + Vector2(0.5, 0.5), health)
	unit.complete = complete
	_next_id += 1
	_units[unit.id] = unit
	spatial.place(unit.id, unit.position)
	if RtsKinds.is_building(kind):
		_covered[cell] = graph.cost_at(cell)
		graph.block(cell)
		_fields.clear()
		_asked.clear()
	return unit


## The unit with this id, or null when there is none -- or it has died.
func unit(id: int) -> RtsUnit:
	return _units.get(id)


## Every unit, in id order: the order a tick acts in, so two runs agree.
func units() -> Array[RtsUnit]:
	var listed: Array[RtsUnit] = []
	listed.assign(_units.values())
	return listed


## Move `moving` to `to`, keeping the spatial hash in step. The one way
## anything changes a position, so the hash cannot fall behind.
func place(moving: RtsUnit, to: Vector2) -> void:
	moving.position = to
	spatial.place(moving.id, to)


## A flow field to `goal`, from the cache when one is there. A new one starts
## empty; `step` settles it, and it may take more than one tick to complete.
func field_to(goal: Vector2i) -> FlowField:
	if not _fields.has(goal):
		_fields[goal] = FlowField.new(graph, goal)
		fields_started += 1
	_asked[goal] = tick
	return _fields[goal]


## True when some unit of `side` has `position` within its sight.
func visible_to(side: int, position: Vector2) -> bool:
	for id: int in spatial.near(position, RtsKinds.LONGEST_SIGHT):
		var watcher: RtsUnit = _units[id]
		if watcher.side == side and watcher.position.distance_to(position) <= RtsKinds.of(watcher.kind, "sight"):
			return true
	return false


## Give `side`'s `order`, or say why not. "" means it was given: the units
## have their orders, and whatever it costs is paid.
func command(side: int, order: RtsCommand) -> String:
	var refusal: String = RtsRules.why_refused(self, side, order)
	if refusal == "":
		RtsRules.carry_out(self, side, order)
	return refusal


## One tick: settle flow fields up to their share, let every unit act on its
## order, and bury the dead. `budget`, when given, times the two layers; it
## never changes what they do.
func step(budget: FrameBudget = null) -> void:
	var started: int = Time.get_ticks_usec()
	_settle_fields()
	if budget != null:
		budget.record(FrameBudget.FLOW_FIELDS, Time.get_ticks_usec() - started)
	started = Time.get_ticks_usec()
	for acting: RtsUnit in units():
		RtsOrders.act(self, acting)
	_bury_the_dead()
	_forget_old_fields()
	tick += 1
	if budget != null:
		budget.record(FrameBudget.SIMULATION, Time.get_ticks_usec() - started)


## The match's state as one hash: the tick, the dice, every side's funds and
## every unit. Two worlds are the same match when their digests are equal --
## never `==` on the objects, which only asks whether they are one object.
func digest() -> String:
	var sides: Array = resources.keys()
	sides.sort()
	var values: Array = [tick, rng.state]
	for side: Variant in sides:
		values.append([side, resources[side]])
	for listed: RtsUnit in units():
		values.append(listed.state())
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(values))
	return context.finish().hex_encode()


## The nearest complete `kind` of `side` to `from`, ties to the lowest id;
## null when there is none. A scan: it is asked when a worker turns for home,
## not every tick.
func nearest(from: Vector2, side: int, kind: String) -> RtsUnit:
	var best: RtsUnit = null
	for candidate: RtsUnit in units():
		if candidate.side != side or candidate.kind != kind or not candidate.complete:
			continue
		if best == null or candidate.position.distance_to(from) < best.position.distance_to(from):
			best = candidate
	return best


## The first free cell round `centre`, nearest ring first; `centre` itself
## when nothing is free within three cells. Free: on the board, not blocked,
## and nobody standing in it.
func free_cell_near(centre: Vector2i) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for ring: int in range(1, 4):
		candidates.append_array(_ring(centre, ring))
	for cell: Vector2i in candidates:
		if is_free(cell):
			return cell
	return centre


## True when a unit may stand in `cell`: on the board, not blocked, and
## nobody's position falls inside it -- corners included, so a building is
## never raised over a unit standing near its edge.
func is_free(cell: Vector2i) -> bool:
	if not graph.contains(cell) or graph.is_blocked(cell):
		return false
	# 0.71 reaches the cell's corners from its centre.
	for id: int in spatial.near(Vector2(cell) + Vector2(0.5, 0.5), 0.71):
		if _units[id].cell() == cell:
			return false
	return true


## What `cell` costs to cross with every building taken away: the board as
## a side that has seen none of them would draw it.
func bare_cost(cell: Vector2i) -> int:
	return _covered.get(cell, graph.cost_at(cell))


# The cells exactly `ring` steps from `centre`, a row at a time, top first.
static func _ring(centre: Vector2i, ring: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var across: int = 2 * ring + 1
	for index: int in range(across * across):
		var offset := Vector2i(index % across - ring, index / across - ring)
		if maxi(absi(offset.x), absi(offset.y)) == ring:
			cells.append(centre + offset)
	return cells


func _settle_fields() -> void:
	var left: int = FIELD_CELLS_PER_TICK
	for field: FlowField in _fields.values():
		if left <= 0:
			return
		if field.complete:
			continue
		var before: int = field.work
		field.settle(left)
		left -= field.work - before


func _forget_old_fields() -> void:
	for goal: Vector2i in _fields.keys():
		if _asked.get(goal, tick) < tick - FIELD_KEPT_FOR:
			_fields.erase(goal)
			_asked.erase(goal)


func _bury_the_dead() -> void:
	for listed: RtsUnit in units():
		if listed.health > 0:
			continue
		_units.erase(listed.id)
		spatial.remove(listed.id)
		if RtsKinds.is_building(listed.kind):
			graph.set_cost(listed.cell(), _covered.get(listed.cell(), GridGraph.DEFAULT_COST))
			_covered.erase(listed.cell())
			_fields.clear()
			_asked.clear()
