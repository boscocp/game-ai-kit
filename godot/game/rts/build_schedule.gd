## When each step of a build order can start, worked out by jumping from
## one moment a step becomes affordable to the next -- not by stepping the
## match tick by tick.
##
## Churchill and Buro's trick for StarCraft build orders (2011): income is a
## rate, so the time a price is met is arithmetic -- what is short, over what
## comes in a second -- and a schedule is one jump per step. A plan of six
## steps costs six jumps whatever the match's length. STRIPS chose the
## order; this says how long the order takes, which is the half a clock adds
## and what the screen shows beside each step.
##
## The rates are estimates, and the screen is honest about it: a worker
## brings `RtsKinds.LOAD` home every `ROUND_TRIP_TICKS`, a figure measured
## on this map's home deposits, not read off the world. A step whose
## resource nobody mines never comes, and says so.
##
## When not to use it: to decide. It times a plan; it never reorders one.
class_name BuildSchedule
extends RefCounted

## A worker's trip: `RtsKinds.GATHER_TICKS` at the deposit and about four
## cells each way at its speed. Measured on the home deposits of
## `RtsScenario`: 340 to 400 ticks, so 360.
const ROUND_TRIP_TICKS: int = 360
## Seconds standing for "never": what nobody mines cannot be paid for.
const NEVER: float = INF


## Each of `steps`, from `view` now: {step, starts, ready, waits} -- seconds
## from now until it can be bought and until what it buys stands, and what
## it waited on ("ore", "magma", a building, or "" for nothing).
static func of(steps: PackedStringArray, view: RtsSnapshot) -> Array[Dictionary]:
	var held: Dictionary = view.resources.duplicate()
	var rates: Dictionary = income(view)
	var standing: Dictionary = _standing_since(view)
	var now: float = 0.0
	var timed: Array[Dictionary] = []
	for step: String in steps:
		var what: String = BuildOrder.BUYS.get(step, "")
		if what == "":
			rates = _with_magma(rates, view)
			timed.append({"step": step, "starts": now, "ready": now, "waits": ""})
			continue
		var entry: Dictionary = _when(what, now, held, rates, standing)
		entry["step"] = step
		timed.append(entry)
		if entry["starts"] == NEVER:
			break
		now = entry["starts"]
		standing[what] = minf(standing.get(what, NEVER), entry["ready"])
	return timed


## What the side brings home a second, by resource, at its workers'
## present jobs.
static func income(view: RtsSnapshot) -> Dictionary:
	var yields: Dictionary = {}
	for deposit: Dictionary in view.deposits():
		yields[deposit["id"]] = RtsKinds.of(deposit["kind"], "yields")
	var rates: Dictionary = {}
	for resource: String in RtsKinds.RESOURCES:
		rates[resource] = 0.0
	for worker: Dictionary in view.mine(RtsKinds.WORKER):
		var resource: String = yields.get(worker["target"], "")
		if worker["order"] == RtsCommand.GATHER and resource != "":
			rates[resource] += _per_worker()
	return rates


# One step bought at the first moment from `now` that its price is met and
# the building it needs stands; advances `held` to that moment and pays.
static func _when(what: String, now: float, held: Dictionary, rates: Dictionary, standing: Dictionary) -> Dictionary:
	var start: float = now
	var waits: String = ""
	var needed: String = RtsKinds.of(what, "needs")
	if needed != "" and standing.get(needed, NEVER) > start:
		start = standing.get(needed, NEVER)
		waits = needed
	var price: Dictionary = RtsKinds.cost(what)
	# Each resource in turn: a wait for ore moves the moment magma is asked at.
	for resource: String in RtsKinds.RESOURCES:
		if start == NEVER:
			break
		var short: float = price[resource] - (held[resource] + rates[resource] * (start - now))
		if short > 0.0:
			start = NEVER if rates[resource] == 0.0 else start + short / rates[resource]
			waits = resource
	if start == NEVER:
		return {"starts": NEVER, "ready": NEVER, "waits": waits}
	for resource: String in RtsKinds.RESOURCES:
		held[resource] += rates[resource] * (start - now) - price[resource]
	var build_seconds: float = float(RtsKinds.of(what, "ticks")) / RtsWorld.TICKS_PER_SECOND
	return {"starts": start, "ready": start + build_seconds, "waits": waits}


# When each kind the side has will be standing complete, in seconds from now:
# 0 for one already up, its remaining build time for one going up.
static func _standing_since(view: RtsSnapshot) -> Dictionary:
	var standing: Dictionary = {}
	for unit: Dictionary in view.mine():
		var ready: float = 0.0
		if not unit["complete"]:
			var ticks_left: int = int(RtsKinds.of(unit["kind"], "ticks")) - int(unit["progress"])
			ready = float(ticks_left) / RtsWorld.TICKS_PER_SECOND
		standing[unit["kind"]] = minf(standing.get(unit["kind"], NEVER), ready)
	return standing


# `mine_magma` moves workers off ore and onto the vents: the rates after it.
static func _with_magma(rates: Dictionary, view: RtsSnapshot) -> Dictionary:
	var moved: float = minf(EconomyQueue.WORKERS_PER_VENT, rates[RtsKinds.ORE] / _per_worker())
	var after: Dictionary = rates.duplicate()
	if view.deposits(RtsKinds.MAGMA).is_empty():
		return after
	after[RtsKinds.ORE] -= moved * _per_worker()
	after[RtsKinds.MAGMA] += moved * _per_worker()
	return after


static func _per_worker() -> float:
	return float(RtsKinds.LOAD) * RtsWorld.TICKS_PER_SECOND / ROUND_TRIP_TICKS
