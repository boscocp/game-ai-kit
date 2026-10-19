## What a side may order, and what giving the order does.
##
## The never-cheat rule, in one place. Every refusal is a sentence a person
## could act on, and the order is checked whole before any of it is carried
## out, so a refused command changes nothing -- `test/rts_simulation.gd`
## checks the world's digest is untouched by each. Three of the refusals are
## the ones a cheating AI would trip: ordering the other side's units,
## spending money it does not have, and aiming at something it cannot see.
##
## When not to use it: rules that depend on more than the order and the
## world as it stands -- a cooldown on giving orders, say. Those belong to
## whoever gives them.
class_name RtsRules
extends RefCounted


## Why `side` may not give `order` in `world`, or "" when it may.
static func why_refused(world: RtsWorld, side: int, order: RtsCommand) -> String:
	if not order.kind in RtsCommand.KINDS:
		return "there is no order called %s" % order.kind
	if order.unit_ids.is_empty():
		return "an order needs at least one unit"
	for id: int in order.unit_ids:
		var given: RtsUnit = world.unit(id)
		if given == null:
			return "there is no unit %d" % id
		if given.side != side:
			return "unit %d is not yours" % id
		var unfit: String = _why_unfit(given, order)
		if unfit != "":
			return unfit
	match order.kind:
		RtsCommand.MOVE:
			return _why_move_refused(world, side, order.cell)
		RtsCommand.ATTACK, RtsCommand.GATHER:
			return _why_target_refused(world, side, order)
		RtsCommand.BUILD:
			return _why_build_refused(world, side, order)
	return _why_train_refused(world, side, order)


## Carry out an order `why_refused` has passed: hand the units their orders,
## and pay for what costs.
static func carry_out(world: RtsWorld, side: int, order: RtsCommand) -> void:
	if order.kind == RtsCommand.TRAIN:
		_pay(world, side, order.what)
		world.unit(order.unit_ids[0]).queue.append(order.what)
		return
	var target: int = order.target_id
	if order.kind == RtsCommand.BUILD:
		_pay(world, side, order.what)
		target = world.add_unit(order.what, side, order.cell, false).id
	for id: int in order.unit_ids:
		var given: RtsUnit = world.unit(id)
		given.order = order.kind
		given.goal = order.cell
		given.target_id = target
		given.progress = 0


# Whether this unit can take this kind of order at all.
static func _why_unfit(given: RtsUnit, order: RtsCommand) -> String:
	var building: bool = RtsKinds.is_building(given.kind)
	if order.kind == RtsCommand.TRAIN:
		return "" if building else "unit %d is a %s, which trains nothing" % [given.id, given.kind]
	if building:
		return "unit %d is a %s and cannot %s" % [given.id, given.kind, order.kind]
	if order.kind in [RtsCommand.GATHER, RtsCommand.BUILD] and given.kind != RtsKinds.WORKER:
		return "only a worker can %s, and unit %d is a %s" % [order.kind, given.id, given.kind]
	return ""


# A blocked cell is refused only when the side can see what blocks it: a
# refusal about a cell in the fog would say the enemy built there. A move to
# one is taken, and ends where the building stops it, as a player's would.
static func _why_move_refused(world: RtsWorld, side: int, cell: Vector2i) -> String:
	if not world.graph.contains(cell):
		return "%s is off the board" % cell
	if world.graph.is_blocked(cell) and world.visible_to(side, Vector2(cell) + Vector2(0.5, 0.5)):
		return "nobody can stand on %s" % cell
	return ""


static func _why_target_refused(world: RtsWorld, side: int, order: RtsCommand) -> String:
	# Gone and unseen get one answer: two would tell a side which of the ids
	# it cannot see are still alive.
	var target: RtsUnit = world.unit(order.target_id)
	if target == null or not world.visible_to(side, target.position):
		return "unit %d is not in sight" % order.target_id
	if order.kind == RtsCommand.GATHER:
		return "" if target.kind == RtsKinds.MINE else "unit %d is not a mine" % target.id
	if target.side == side or target.side == RtsWorld.NEUTRAL:
		return "unit %d is not an enemy" % target.id
	return ""


static func _why_build_refused(world: RtsWorld, side: int, order: RtsCommand) -> String:
	if order.unit_ids.size() != 1:
		return "one worker builds a building"
	if not RtsKinds.TABLE.has(order.what) or not RtsKinds.is_building(order.what) \
			or order.what == RtsKinds.MINE:
		return "%s is not something a worker builds" % order.what
	# Sight first: "not free" about a cell nobody can see would say who stands there.
	if not world.visible_to(side, Vector2(order.cell) + Vector2(0.5, 0.5)):
		return "%s is not in sight" % order.cell
	if not world.is_free(order.cell):
		return "%s is not free to build on" % order.cell
	return _why_unaffordable(world, side, order.what)


static func _why_train_refused(world: RtsWorld, side: int, order: RtsCommand) -> String:
	if order.unit_ids.size() != 1:
		return "one building trains at a time"
	var producer: RtsUnit = world.unit(order.unit_ids[0])
	if not producer.complete:
		return "unit %d is still being built" % producer.id
	if not order.what in RtsKinds.of(producer.kind, "trains"):
		return "a %s does not train a %s" % [producer.kind, order.what]
	if producer.queue.size() >= RtsKinds.QUEUE_LIMIT:
		return "unit %d already has %d in its queue" % [producer.id, RtsKinds.QUEUE_LIMIT]
	return _why_unaffordable(world, side, order.what)


static func _why_unaffordable(world: RtsWorld, side: int, kind: String) -> String:
	var cost: int = RtsKinds.of(kind, "cost")
	var held: int = world.resources.get(side, 0)
	return "" if held >= cost else "a %s costs %d and you have %d" % [kind, cost, held]


static func _pay(world: RtsWorld, side: int, kind: String) -> void:
	world.resources[side] = world.resources.get(side, 0) - RtsKinds.of(kind, "cost")
