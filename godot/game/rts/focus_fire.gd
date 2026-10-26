## Whom a squad in a fight strikes: every enemy in sight scored, and the
## best one struck by all of them at once.
##
## The rule StarCraft bots and their players share: kill first what hurts
## most and dies quickest. An enemy's score is
##
##     (threat + PASSIVE) / time to kill it / (1 + distance / NEAR_SCALE)
##
## where **threat** is the damage a second it deals this squad, **time to
## kill** is its health left over the damage a second this squad deals it --
## so the counter table counts twice: the squad kills what it beats faster,
## and what beats the squad threatens more -- and **PASSIVE** is a little
## worth for what does not fight, so a worker or a building is struck only
## when nothing armed is near. A mortar's squad breaks buildings quickly and
## so goes for them sooner; nobody had to write that down.
##
## Utility again, as `SquadTactics` is for regions: one number per option,
## the best taken, the numbers kept for the screen. It reads the snapshot
## only: what the squad can see, as a player would.
##
## When not to use it: a fight of one against one. There is nobody else to
## choose.
class_name FocusFire
extends RefCounted

## What an unarmed enemy is worth, in damage a second: less than anything
## armed, more than nothing.
const PASSIVE: float = 0.5
## Distance, in cells, at which an enemy's score halves.
const NEAR_SCALE: float = 4.0
## Why an enemy scored as it did: plain, beaten by the squad, unarmed, both.
const WHY: Array[String] = [  # shown through tr()
	"{health} hp, {seconds} s to kill",
	"we beat it, {health} hp, {seconds} s to kill",
	"unarmed, {health} hp, {seconds} s to kill",
	"we beat it, unarmed, {health} hp, {seconds} s to kill",
]


## Every enemy within `reach` of the squad's middle, scored, best first:
## [{id, kind, score, why}].
static func scores(view: RtsSnapshot, members: Array[Dictionary], centre: Vector2, reach: float) -> Array[Dictionary]:
	var scored: Array[Dictionary] = []
	for enemy: Dictionary in view.enemies():
		var distance: float = (enemy["position"] as Vector2).distance_to(centre)
		if distance > reach or members.is_empty():
			continue
		var dealt: float = _damage_a_second(members, enemy["kind"])
		var threat: float = _threat(enemy["kind"], members)
		var to_kill: float = float(enemy["health"]) / maxf(dealt, 0.01)
		var score: float = (threat + PASSIVE) / to_kill / (1.0 + distance / NEAR_SCALE)
		scored.append({"id": enemy["id"], "kind": enemy["kind"], "score": score,
			"why": _why(enemy, members, threat, to_kill)})
	scored.sort_custom(func(one: Dictionary, other: Dictionary) -> bool: return one["score"] > other["score"])
	return scored


## The damage a second `members` deal a `kind` together.
static func _damage_a_second(members: Array[Dictionary], kind: String) -> float:
	var total: float = 0.0
	for member: Dictionary in members:
		var cooldown: float = maxf(float(RtsKinds.of(member["kind"], "cooldown")), 1.0) / RtsWorld.TICKS_PER_SECOND
		total += RtsKinds.blow(member["kind"], kind) / cooldown
	return total


# The damage a second one `kind` deals this squad, by the members it would
# strike, averaged; 0 for what does not fight.
static func _threat(kind: String, members: Array[Dictionary]) -> float:
	if not RtsKinds.fights(kind):
		return 0.0
	var cooldown: float = float(RtsKinds.of(kind, "cooldown")) / RtsWorld.TICKS_PER_SECOND
	var total: float = 0.0
	for member: Dictionary in members:
		total += RtsKinds.blow(kind, member["kind"]) / cooldown
	return total / members.size()


# A few words a person can check, as a `Sentence`: does the squad beat it,
# does it beat the squad, how much is left of it. One key each way, so no
# clause is glued to another (T80).
static func _why(enemy: Dictionary, members: Array[Dictionary], threat: float, to_kill: float) -> Array:
	var beaten: bool = members.any(func(member: Dictionary) -> bool:
		return enemy["kind"] in RtsKinds.of(member["kind"], "beats"))
	var key: String = WHY[(1 if beaten else 0) + (2 if threat == 0.0 else 0)]
	return Sentence.of(key, {health = enemy["health"], seconds = "%.0f" % to_kill})
