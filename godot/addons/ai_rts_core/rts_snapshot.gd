## One side's view of the match at one tick, frozen: everything an AI is
## ever shown, and what anything that searches reads.
##
## Its own units, whole; anybody else's only while one of its units can see
## them; its own funds and nobody else's. Every value is copied into plain
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
## This side's funds.
var resources: int
## What this side can see, each unit as a read-only dictionary: id, side,
## kind, position, health, order, complete, carrying and queued (how many
## its queue holds). Sorted by id.
var units: Array[Dictionary] = []
## The board as it is, buildings blocking their cells: a copy.
var graph: GridGraph


## What `world` shows `viewer` now.
static func of(world: RtsWorld, viewer: int) -> RtsSnapshot:
	var view := RtsSnapshot.new()
	view.side = viewer
	view.tick = world.tick
	view.resources = world.resources.get(viewer, 0)
	view.graph = world.graph.duplicate_graph()
	for unit: RtsUnit in world.units():
		if unit.side == viewer or world.visible_to(viewer, unit.position):
			view.units.append(_frozen(unit))
	view.units.make_read_only()
	return view


## This side's own units, or only those of `kind` when one is named.
func mine(kind: String = "") -> Array[Dictionary]:
	return _where(func(unit: Dictionary) -> bool:
		return unit["side"] == side and (kind == "" or unit["kind"] == kind))


## The other sides' units this side can see, mines not counted.
func enemies() -> Array[Dictionary]:
	return _where(func(unit: Dictionary) -> bool:
		return unit["side"] != side and unit["side"] != RtsWorld.NEUTRAL)


## The mines this side can see.
func mines() -> Array[Dictionary]:
	return _where(func(unit: Dictionary) -> bool: return unit["kind"] == RtsKinds.MINE)


# `filter` hands back an untyped Array, and returning that as a typed one is
# a script error that aborts the caller and nothing else; `assign` converts.
func _where(test: Callable) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	found.assign(units.filter(test))
	return found


static func _frozen(unit: RtsUnit) -> Dictionary:
	var values: Dictionary = {"id": unit.id, "side": unit.side, "kind": unit.kind,
		"position": unit.position, "health": unit.health, "order": unit.order,
		"complete": unit.complete, "carrying": unit.carrying, "queued": unit.queue.size()}
	values.make_read_only()
	return values
