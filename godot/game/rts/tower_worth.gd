## Whether arming a tower is worth its price now: the enemy worth the gun
## would kill before help comes, against what the gun costs.
##
## The commander's one weighed purchase outside the plan's chain (T56): when
## it is worth it, the commander wishes the tower and its arm straight into
## the queue above the plan, so the time weighed here is the time it is
## bought in. Every term is something the side perceives or works out:
##
##     killed = raid worth x min(1, gun damage a second x gun seconds / raid health)
##     gun seconds = help seconds - seconds until the gun is ready
##
## **The raid** is the enemy fighters `RtsInfluence` remembers within the
## gun's reach of the tower that would shoot -- its own tower, or its home
## when it has none yet, since towers go up a few cells round it -- each
## weighed by how much it is still trusted: a raid lost from sight counts
## less every second, and a single scout is worth little. **Help** is the
## first moment its own fighters walking home would match the raid, or, if
## all of them together would not, a fresh squad trained at one barracks:
## the other way to spend the same ore. **The gun is ready** when
## `BuildSchedule` says the arm step stands -- a tower first if there is
## none, and the wait for magma. The arm is worth it when `killed` is more
## than its price.
##
## It counts one raid only. A gun lasts and the next raid meets it too, so
## this undervalues the arm; it is the cautious half, and the measured one.
## The belief it reads is the one the side's last decision built.
##
## When not to use it: a side that holds its home with its army. Then help is
## already there, and the answer is always no.
class_name TowerWorth
extends RefCounted


## The weighing for the side `view` belongs to, given its `belief`:
## {bought, raid (worth), raid_health, help, ready (seconds), killed, price,
## worth_it}. `bought` when a tower is armed or arming already: nothing is
## left to weigh, and `worth_it` is false.
static func weigh(view: RtsSnapshot, belief: RtsInfluence) -> Dictionary:
	var weighed: Dictionary = {"bought": _bought(view), "raid": 0.0, "raid_health": 0.0, "help": 0.0,
		"ready": 0.0, "killed": 0.0, "price": price(), "worth_it": false}
	if weighed["bought"]:
		return weighed
	var reach: float = RtsKinds.of(RtsKinds.ARM, "reach")
	for fighter: Dictionary in belief.fighters_near(Vector2i(gun_at(view).floor()), reach, view.tick):
		weighed["raid"] += RtsInfluence.strength(fighter["kind"], fighter["health"]) * fighter["trust"]
		weighed["raid_health"] += float(fighter["health"]) * fighter["trust"]
	if weighed["raid"] <= 0.0:
		return weighed
	weighed["help"] = help_seconds(view, weighed["raid"])
	weighed["ready"] = gun_ready_in(view)
	var gun_seconds: float = maxf(weighed["help"] - weighed["ready"], 0.0)
	var share: float = minf(gun_damage_per_second() * gun_seconds / weighed["raid_health"], 1.0)
	weighed["killed"] = weighed["raid"] * share
	weighed["worth_it"] = weighed["killed"] > weighed["price"]
	return weighed


## The arm's price, both resources counted alike.
static func price() -> int:
	var total: int = 0
	for resource: String in RtsKinds.RESOURCES:
		total += RtsKinds.cost(RtsKinds.ARM)[resource]
	return total


## Where the gun would stand: the side's first tower, standing or going up;
## its home's cell when it has none, since a tower is sited a few cells
## round it.
static func gun_at(view: RtsSnapshot) -> Vector2:
	var towers: Array[Dictionary] = view.mine(RtsKinds.TOWER)
	if towers.is_empty():
		return Vector2(RtsScenario.home(view.side)) + Vector2(0.5, 0.5)
	return towers[0]["position"]


## Seconds until the side's own fighters walking home would match `raid` in
## strength, nearest first; a fresh squad's training time if they never would,
## or if that is sooner. 0 when the raid is matched already.
static func help_seconds(view: RtsSnapshot, raid: float) -> float:
	var home := Vector2(RtsScenario.home(view.side))
	var walkers: Array[Dictionary] = []
	for fighter: Dictionary in view.mine():
		if RtsKinds.fights(fighter["kind"]):
			var seconds: float = (fighter["position"] as Vector2).distance_to(home) / float(RtsKinds.of(fighter["kind"], "speed"))
			walkers.append({"seconds": seconds, "strength": RtsInfluence.strength(fighter["kind"], fighter["health"])})
	walkers.sort_custom(func(one: Dictionary, other: Dictionary) -> bool: return one["seconds"] < other["seconds"])
	var squad_seconds: float = float(RtsKinds.of(RtsKinds.RUNNER, "ticks")) * BuildOrder.SQUAD / RtsWorld.TICKS_PER_SECOND
	var gathered: float = 0.0
	for walker: Dictionary in walkers:
		if walker["seconds"] >= squad_seconds:
			break
		gathered += walker["strength"]
		if gathered >= raid:
			return walker["seconds"]
	return squad_seconds


## Seconds until an armed tower would stand, if the tower and its arm are
## wished now at the top of the queue: what `BuildSchedule` says of the
## steps still to buy. `BuildSchedule.NEVER` when the magma never comes.
static func gun_ready_in(view: RtsSnapshot) -> float:
	var steps := PackedStringArray(["arm_tower"])
	if view.mine(RtsKinds.TOWER).is_empty():
		steps.insert(0, "build_tower")
	var timed: Array[Dictionary] = BuildSchedule.of(steps, view)
	return timed[-1]["ready"]


## The armed tower's damage a second against a fighter it does not beat, the
## dice taken at their middle. It fires on its own looks, every
## `RtsOrders.LOOK_EVERY` ticks, so a cooldown of 45 is a shot every 50.
static func gun_damage_per_second() -> float:
	var blow: float = float(RtsKinds.of(RtsKinds.ARM, "damage")) + 1.0
	var cooldown: int = int(RtsKinds.of(RtsKinds.ARM, "cooldown"))
	var between: int = ceili(float(cooldown) / RtsOrders.LOOK_EVERY) * RtsOrders.LOOK_EVERY
	return blow * RtsWorld.TICKS_PER_SECOND / float(between)


static func _bought(view: RtsSnapshot) -> bool:
	for tower: Dictionary in view.mine(RtsKinds.TOWER):
		if tower["armed"] or RtsKinds.ARM in tower["queue"]:
			return true
	return false
