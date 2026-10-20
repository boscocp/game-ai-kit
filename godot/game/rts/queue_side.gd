## The baseline: an RTS side whose economy is fixed rules over a priority
## queue, the way Age of Empires II's scripts and 0 A.D.'s AI are written.
##
## Each rule looks at the snapshot and, when it fires, wishes for one thing
## at one priority: a barracks if there is none, magma once there is one, a
## lab after three minutes, the expansion once the home is full, and
## fighters in turn, whichever of the three it has fewest of. No rule knows
## why another fires, and none looks further than the next purchase -- so
## it never saves for the lab while the barracks is wanted, and it builds
## mortars whether or not the enemy has a shield to beat.
##
## ADR 0010 makes it the bar: "a commander that does not beat the queues
## alone has not earned its cost", and `test/rts/rts_match.gd` measures it.
##
## When not to use it: as the strong side. It is the floor every other side
## is measured from.
class_name QueueSide
extends RtsSide

## When the lab is wanted, and when the expansion may be: in seconds.
const LAB_AFTER_SECONDS: int = 180
const EXPAND_AFTER_SECONDS: int = 300


func _fill_queue(view: RtsSnapshot) -> void:
	_reflexes(view)
	wish_by_rules(queue, view)


## The rules, wished into `queue` for the side `view` belongs to. Static, so
## a commander told to plan nothing (horizon 0, `RtsLevels`' easy) plays its
## economy by exactly these.
static func wish_by_rules(queue: EconomyQueue, view: RtsSnapshot) -> void:
	var have: Dictionary = _have(view)
	var seconds: float = float(view.tick) / RtsWorld.TICKS_PER_SECOND
	if have.get(RtsKinds.BARRACKS, 0) == 0:
		queue.wish(RtsKinds.BARRACKS, 70, "rule: no barracks")
		return
	queue.magma_wanted = true
	if have.get(RtsKinds.LAB, 0) == 0 and seconds >= LAB_AFTER_SECONDS:
		queue.wish(RtsKinds.LAB, 45, "rule: three minutes in, no lab")
	if have.get(RtsKinds.BASE, 0) < 2 and seconds >= EXPAND_AFTER_SECONDS \
			and have.get(RtsKinds.WORKER, 0) >= EconomyQueue.WORKERS_PER_BASE:
		queue.wish(RtsKinds.BASE, 60, "rule: a full home, five minutes in")
	var fewest: String = _fewest_fighter(view, have)
	for kind: String in RtsKinds.FIGHTERS:
		if kind != fewest:
			queue.forget(kind)
	queue.wish(fewest, 30, "rule: fewest %ss" % fewest)


# The fighter it has fewest of, among those it can train now -- runners
# first on a tie, since they cost no magma.
static func _fewest_fighter(view: RtsSnapshot, have: Dictionary) -> String:
	var fewest: String = RtsKinds.RUNNER
	for kind: String in RtsKinds.FIGHTERS:
		if _can_have(view, have, kind) and have.get(kind, 0) < have.get(fewest, 0):
			fewest = kind
	return fewest


# Whether `kind` can be trained at all now: what it needs stands, and any
# magma it costs is held or coming in.
static func _can_have(view: RtsSnapshot, have: Dictionary, kind: String) -> bool:
	var needed: String = RtsKinds.of(kind, "needs")
	if needed != "" and have.get(needed, 0) == 0:
		return false
	if RtsKinds.cost(kind)[RtsKinds.MAGMA] == 0 or view.resources[RtsKinds.MAGMA] > 0:
		return true
	return BuildSchedule.income(view)[RtsKinds.MAGMA] > 0.0


# Own units by kind, queued ones counted.
static func _have(view: RtsSnapshot) -> Dictionary:
	var have: Dictionary = {}
	for unit: Dictionary in view.mine():
		have[unit["kind"]] = have.get(unit["kind"], 0) + 1
		for queued: String in unit["queue"]:
			have[queued] = have.get(queued, 0) + 1
	return have
