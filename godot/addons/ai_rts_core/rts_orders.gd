## What one unit does in one tick, given the order it carries.
##
## Every order is a little state machine read off the unit's own fields --
## walk until in reach, then work until done -- run once a tick by
## `RtsWorld.step` for every unit in id order. Walking reads the flow field
## to the goal: the arrow under the unit's feet, followed from cell centre to
## cell centre at the unit's speed. Units pass through each other: steering
## round one another is T22's lesson (`ai_steering`), not this core's.
##
## A soldier with no order looks for the nearest enemy it can see and goes
## for it -- not every tick, but every `LOOK_EVERY` ticks, each soldier on its
## own tick of the cycle, so the questions are spread evenly. Measured in T19:
## 200 idle soldiers asking every tick cost about 7 ms, more than the whole
## simulation's share. Six looks a second is still quicker than a person.
##
## When not to use it: units that need to plan more than one step of their
## own. That is a controller's job, through `RtsCommand`.
class_name RtsOrders
extends RefCounted

## How close counts as standing on a move order's goal.
const ARRIVED: float = 0.05
## Within this many cells, with nothing blocked on the straight line, a unit
## walks straight at its goal rather than asking for a field. A chase would
## otherwise start a new field every time the quarry stepped into a new cell.
const STRAIGHT: float = 4.0
## Ticks between two looks round by an idle soldier.
const LOOK_EVERY: int = 10


## Let `unit` act on its order for one tick.
static func act(world: RtsWorld, unit: RtsUnit) -> void:
	if unit.health <= 0:
		return
	unit.cooldown = maxi(unit.cooldown - 1, 0)
	match unit.order:
		RtsCommand.MOVE:
			_move(world, unit)
		RtsCommand.ATTACK:
			_attack(world, unit)
		RtsCommand.GATHER:
			_gather(world, unit)
		RtsCommand.BUILD:
			_build(world, unit)
		_:
			_idle(world, unit)


## The nearest enemy `unit` can see, ties to the lowest id; null for none.
static func nearest_enemy(world: RtsWorld, unit: RtsUnit) -> RtsUnit:
	var best: RtsUnit = null
	var sight: float = RtsKinds.of(unit.kind, "sight")
	for id: int in world.spatial.near(unit.position, sight):
		var other: RtsUnit = world.unit(id)
		if other.side == unit.side or other.side == RtsWorld.NEUTRAL or other.health <= 0:
			continue
		if best == null or other.position.distance_to(unit.position) < best.position.distance_to(unit.position):
			best = other
	return best


# Walk towards `goal`'s cell until within `reach` of `point`. True on
# arriving. While the field to it is still being settled the unit waits; when
# there is no way there at all it gives the order up.
static func _walk(world: RtsWorld, unit: RtsUnit, goal: Vector2i, point: Vector2, reach: float) -> bool:
	if unit.position.distance_to(point) <= reach:
		return true
	var stride: float = float(RtsKinds.of(unit.kind, "speed")) / RtsWorld.TICKS_PER_SECOND
	if unit.position.distance_to(point) <= STRAIGHT and _line_is_clear(world, unit.position, point, goal):
		world.place(unit, unit.position.move_toward(point, stride))
		return false
	var field: FlowField = world.field_to(goal)
	if not field.complete:
		return false
	var here: Vector2i = unit.cell()
	if field.distance_at(here) == FlowField.UNREACHABLE:
		unit.order = RtsUnit.IDLE
		return false
	var direction: Vector2i = field.direction_at(here)
	var waypoint: Vector2 = point if direction == Vector2i.ZERO else Vector2(here + direction) + Vector2(0.5, 0.5)
	world.place(unit, unit.position.move_toward(waypoint, stride))
	return false


# True when every cell the straight line from `from` to `to` crosses, sampled
# every quarter cell, may be walked -- the goal's own cell excepted, since a
# building or a mine there is what the unit is walking up to.
static func _line_is_clear(world: RtsWorld, from: Vector2, to: Vector2, goal: Vector2i) -> bool:
	var samples: int = ceili(from.distance_to(to) * 4.0)
	for sample: int in range(1, samples + 1):
		var cell := Vector2i(from.lerp(to, float(sample) / samples).floor())
		if cell != goal and world.graph.is_blocked(cell):
			return false
	return true


static func _move(world: RtsWorld, unit: RtsUnit) -> void:
	if _walk(world, unit, unit.goal, Vector2(unit.goal) + Vector2(0.5, 0.5), ARRIVED):
		unit.order = RtsUnit.IDLE


static func _idle(world: RtsWorld, unit: RtsUnit) -> void:
	if RtsKinds.is_building(unit.kind):
		_train(world, unit)
	elif unit.kind == RtsKinds.SOLDIER and (world.tick + unit.id) % LOOK_EVERY == 0:
		var enemy: RtsUnit = nearest_enemy(world, unit)
		if enemy != null:
			unit.order = RtsCommand.ATTACK
			unit.target_id = enemy.id


static func _attack(world: RtsWorld, unit: RtsUnit) -> void:
	var target: RtsUnit = world.unit(unit.target_id)
	if target == null or target.health <= 0:
		unit.order = RtsUnit.IDLE
		return
	var reach: float = RtsKinds.of(unit.kind, "reach")
	if not _walk(world, unit, target.cell(), target.position, reach):
		return
	if unit.cooldown == 0:
		# The one random number in a fight: a little spread on every blow, drawn
		# from the match's own dice so a replay strikes the same.
		target.health -= int(RtsKinds.of(unit.kind, "damage")) + world.rng.randi_range(0, 2)
		unit.cooldown = RtsKinds.of(unit.kind, "cooldown")


static func _gather(world: RtsWorld, unit: RtsUnit) -> void:
	var mine: RtsUnit = world.unit(unit.target_id)
	if unit.carrying > 0 or mine == null or mine.health <= 0:
		_deliver(world, unit, mine != null and mine.health > 0)
		return
	if not _walk(world, unit, mine.cell(), mine.position, RtsKinds.USE_REACH):
		return
	unit.progress += 1
	if unit.progress >= RtsKinds.GATHER_TICKS:
		unit.carrying = mini(RtsKinds.LOAD, mine.health)
		mine.health -= unit.carrying
		unit.progress = 0


# Carry the load to the nearest base. With the mine gone and nothing to
# carry, or no base to carry to, the order is over.
static func _deliver(world: RtsWorld, unit: RtsUnit, mine_left: bool) -> void:
	var base: RtsUnit = world.nearest(unit.position, unit.side, RtsKinds.BASE)
	if base == null or (unit.carrying == 0 and not mine_left):
		unit.order = RtsUnit.IDLE
		return
	if _walk(world, unit, base.cell(), base.position, RtsKinds.USE_REACH):
		world.resources[unit.side] = world.resources.get(unit.side, 0) + unit.carrying
		unit.carrying = 0


static func _build(world: RtsWorld, unit: RtsUnit) -> void:
	var site: RtsUnit = world.unit(unit.target_id)
	if site == null or site.complete:
		unit.order = RtsUnit.IDLE
		return
	if not _walk(world, unit, site.cell(), site.position, RtsKinds.USE_REACH):
		return
	var needed: int = RtsKinds.of(site.kind, "ticks")
	var full: int = RtsKinds.of(site.kind, "health")
	site.progress += 1
	site.health = maxi(1, full * site.progress / needed)
	if site.progress >= needed:
		site.complete = true
		site.health = full
		site.progress = 0
		unit.order = RtsUnit.IDLE


# A building works through its queue: the first in it trains, and when it is
# ready steps out into the nearest free cell -- or waits, ready, until one is.
static func _train(world: RtsWorld, building: RtsUnit) -> void:
	if not building.complete or building.queue.is_empty():
		return
	building.progress = mini(building.progress + 1, RtsKinds.of(building.queue[0], "ticks"))
	if building.progress < RtsKinds.of(building.queue[0], "ticks"):
		return
	var cell: Vector2i = world.free_cell_near(building.cell())
	if cell == building.cell():
		return
	world.add_unit(building.queue.pop_front(), building.side, cell)
	building.progress = 0
