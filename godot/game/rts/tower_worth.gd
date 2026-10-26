## Whether arming a tower is worth its price now: the part of a raid at home
## the gun would kill before help comes, priced, against what the gun costs.
##
## The commander's one weighed purchase outside the plan's chain (T56). Every
## term is something the side perceives or can work out, and each moves the
## answer the way a player's would:
##
##     saved = raid worth x min(1, gun damage a second x gun seconds / raid health)
##     gun seconds = help seconds - seconds until the gun is ready
##
## **The raid** is the enemy fighters `RtsInfluence` remembers near home, each
## weighed by how much it is still trusted -- a raid lost from sight counts
## less every second, and a single scout is worth little. **Help** is the
## first moment its own fighters walking home would match the raid, or, if
## all of them together would not, a fresh squad trained at one barracks: the
## other way to spend the same ore. **The gun is ready** when `BuildSchedule`
## says the arm step stands -- a tower first if there is none, and the wait
## for magma. The arm is bought when `saved` is more than its price.
##
## It counts one raid only. A gun lasts and the next raid meets it too, so
## this undervalues the arm; it is the cautious half, and the measured one.
##
## When not to use it: a side that holds its home with its army. Then help is
## already there, and the answer is always no.
class_name TowerWorth
extends RefCounted

## How near its home a remembered enemy fighter counts as raiding it, in cells.
const RAID_REACH: float = 10.0


## The weighing for the side `view` belongs to, given its `belief`:
## {raid (worth), raid_health, help, ready (seconds), saved, price, worth_it}.
static func weigh(view: RtsSnapshot, belief: RtsInfluence) -> Dictionary:
	var home: Vector2i = RtsScenario.home(view.side)
	var raid: float = 0.0
	var raid_health: float = 0.0
	for fighter: Dictionary in belief.fighters_near(home, RAID_REACH, view.tick):
		raid += RtsInfluence.strength(fighter["kind"], fighter["health"]) * fighter["trust"]
		raid_health += float(fighter["health"]) * fighter["trust"]
	var price: int = 0
	for resource: String in RtsKinds.RESOURCES:
		price += RtsKinds.cost(RtsKinds.ARM)[resource]
	var weighed: Dictionary = {"raid": raid, "raid_health": raid_health, "help": help_seconds(view, raid),
		"ready": gun_ready_in(view), "saved": 0.0, "price": price, "worth_it": false}
	var gun_seconds: float = maxf(weighed["help"] - weighed["ready"], 0.0)
	if raid_health > 0.0 and gun_seconds > 0.0:
		weighed["saved"] = raid * minf(gun_damage_per_second() * gun_seconds / raid_health, 1.0)
	weighed["worth_it"] = weighed["saved"] > price
	return weighed


## Seconds until the side's own fighters walking home would match `raid` in
## strength, nearest first; a fresh squad's training time if they never would,
## or if that is sooner. 0 when the raid is matched already.
static func help_seconds(view: RtsSnapshot, raid: float) -> float:
	if raid <= 0.0:
		return 0.0
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


## Seconds until an armed tower would stand: 0 with one armed or arming --
## nothing more to buy -- else when `BuildSchedule` says the arm is done.
static func gun_ready_in(view: RtsSnapshot) -> float:
	for tower: Dictionary in view.mine(RtsKinds.TOWER):
		if tower["armed"] or RtsKinds.ARM in tower["queue"]:
			return 0.0
	var steps := PackedStringArray(["arm_tower"])
	if view.mine(RtsKinds.TOWER).is_empty():
		steps.insert(0, "build_tower")
	var timed: Array[Dictionary] = BuildSchedule.of(steps, view)
	return timed[-1]["ready"]


## The armed tower's damage a second against a fighter it does not beat,
## the dice taken at their middle.
static func gun_damage_per_second() -> float:
	var blow: float = float(RtsKinds.of(RtsKinds.ARM, "damage")) + 1.0
	return blow * RtsWorld.TICKS_PER_SECOND / float(RtsKinds.of(RtsKinds.ARM, "cooldown"))
