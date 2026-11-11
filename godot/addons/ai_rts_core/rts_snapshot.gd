## One side's view of the match at one tick, frozen: everything an AI is
## ever shown, and what anything that searches reads.
##
## Its own units, whole; anybody else's only while one of its units can see
## them, and then only what a player would see -- kind, place, health, not
## its orders or its queue; its own funds and room and nobody else's; and the board
## with only the buildings it can see on it, since a blocked cell in fog
## would say where the enemy built. Every value is copied into plain
## dictionaries and arrays and then made read-only, so a snapshot holds no
## reference to the world: an AI that writes to one gets an engine error, and
## an AI that keeps one sees the past, never the present.
##
## It costs a copy of what the side can see, once per decision -- not per
## tick, and not per search node. A planner that wants to try moves on it
## builds its own small state from it, as `ai_planning` does from a board.
##
## When not to use it: inside the world's own tick, which has the real thing.
class_name RtsSnapshot
extends RefCounted

## Whose view this is.
var side: int
var tick: int
## This side's funds, by resource: a read-only copy.
var resources: Dictionary = {}
## The room its units take, and the room its buildings give.
var supply_used: int = 0
var supply_cap: int = 0
## What this side can see, each unit as a read-only dictionary: id, side,
## kind, position, health, complete and armed -- a gun on a tower is in
## plain sight; and for its own units also order,
## its target and goal, carrying and carried, progress, and its queue (and
## queued, how many that is). Sorted by id.
var units: Array[Dictionary] = []
## The board as it is, buildings blocking their cells: a copy.
var graph: GakGridGraph


## What `world` shows `viewer` now.
static func of(world: RtsWorld, viewer: int) -> RtsSnapshot:
	var view: RtsSnapshot = new()
	view.side = viewer
	view.tick = world.tick
	view.resources = world.funds(viewer).duplicate()
	view.resources.make_read_only()
	view.supply_used = world.supply_used(viewer)
	view.supply_cap = world.supply_cap(viewer)
	view.graph = world.graph.duplicate_graph()
	for unit: RtsUnit in world.units():
		var seen: bool = unit.side == viewer or world.visible_to(viewer, unit.position)
		if seen:
			view.units.append(_frozen(unit, unit.side == viewer))
		elif RtsKinds.is_building(unit.kind):
			view.graph.set_cost(unit.cell(), world.bare_cost(unit.cell()))
	view.units.make_read_only()
	return view


## This side's own units, or only those of `kind` when one is named.
func mine(kind: String = "") -> Array[Dictionary]:
	return _where(func(unit: Dictionary) -> bool:
		return unit["side"] == side and (kind == "" or unit["kind"] == kind))


## The other sides' units this side can see, deposits not counted.
func enemies() -> Array[Dictionary]:
	return _where(func(unit: Dictionary) -> bool:
		return unit["side"] != side and unit["side"] != RtsWorld.NEUTRAL)


## The deposits this side can see, of `resource` only when one is named.
func deposits(resource: String = "") -> Array[Dictionary]:
	return _where(func(unit: Dictionary) -> bool:
		return RtsKinds.is_deposit(unit["kind"]) and (resource == "" or RtsKinds.of(unit["kind"], "yields") == resource))


## True when `amount` of each resource in `price` is held: what a decision
## asks before it orders something the rules would refuse.
func can_pay(price: Dictionary) -> bool:
	for resource: String in price:
		if resources.get(resource, 0) < price[resource]:
			return false
	return true


# `filter` hands back an untyped Array, and returning that as a typed one is
# a script error that aborts the caller and nothing else; `assign` converts.
func _where(test: Callable) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	found.assign(units.filter(test))
	return found


static func _frozen(unit: RtsUnit, own: bool) -> Dictionary:
	var values: Dictionary = {"id": unit.id, "side": unit.side, "kind": unit.kind,
		"position": unit.position, "health": unit.health, "complete": unit.complete,
		"armed": unit.armed}
	if own:
		values.merge({"order": unit.order, "carrying": unit.carrying, "carried": unit.carried,
			"queued": unit.queue.size(), "queue": unit.queue.duplicate(), "target": unit.target_id,
			"goal": unit.goal, "progress": unit.progress})
	values.make_read_only()
	return values
