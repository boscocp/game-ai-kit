## What the fight is deciding with, as data: the overlay draws it and a
## test reads it (invariant 13).
##
## - per token kind: the pool, who holds it, who is queued in the order
##   they would be served, and the reissue timer with its multiplier;
## - the three rings and each claim on them;
## - each minion: its state, its ring and point, whether it holds a token;
## - the boss: its phase, what it does, its attack and the telegraph bar;
## - the director (T158): its state, what the next wave waits for and when,
##   who stands, and the level with every number it sets.
##
## An empty list is never handed over: "none" says there is nothing, so a
## reader -- and `demo_overlays.gd` -- can tell nothing from missing.
class_name BossFightShown
extends RefCounted

const NONE: String = "none"  # shown through tr()


## The whole overlay for `fight`, now.
static func overlay(fight: BossFight) -> Dictionary:
	return {"time": fight.time, "player_state": fight.player_state(), "health": fight.player.health,
		"locked": _or_none(fight.player.locked), "outcome": _or_none(fight.outcome),
		"tokens": {BossMinion.MELEE: tokens(fight, BossMinion.MELEE), BossMinion.RANGED: tokens(fight, BossMinion.RANGED)},
		"rings": rings(fight), "minions": minions(fight), "boss": boss(fight), "director": director(fight),
		"difficulty": difficulty(fight)}


## One kind's pool: its size, who holds and who waits, and the timer --
## the base delay, the factor the player's state set at the last grant, and
## the seconds left.
static func tokens(fight: BossFight, kind: String) -> Dictionary:
	var state: String = fight.last_grant.get(kind, {}).get("state", fight.player_state())
	if kind == BossMinion.RANGED and fight.holding_fire():
		state = BossFightRules.PRESSED
	var base: float = fight.tokens.delay_for(kind, BossFightRules.FREE)
	return {"pool": fight.tokens.free_tokens(kind) + fight.tokens.held(kind), "free": fight.tokens.free_tokens(kind),
		"holders": _listed(fight.tokens.holders(kind)), "queue": _listed(fight.tokens.waiting(kind)),
		"delay": base, "factor": fight.tokens.delay_for(kind, state) / base if base > 0.0 else 1.0,
		"next_in": fight.next_grant_in(kind), "set_while": state}


## Each ring: its name, how many points, and every claim as "who (point)".
static func rings(fight: BossFight) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for ring: EngagementRings.Ring in fight.rings.config.rings:
		found.append({"ring": ring.name, "radius": ring.radius, "points": ring.count,
			"claims": _listed(_claims_on(fight, ring.name))})
	return found


## Each minion: its state, ring and point, and whether it holds a token.
static func minions(fight: BossFight) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for minion: BossMinion in fight.minions:
		var point_name: String = fight.rings.points[minion.point].id if minion.point >= 0 else NONE
		found.append({"id": minion.id, "kind": minion.kind, "state": minion.state, "ring": minion.ring,
			"point": point_name, "token": minion.holds_token(fight.tokens), "health": minion.health})
	return found


## The boss's decision: `BossBrain.shown()` with every empty word "none".
static func boss(fight: BossFight) -> Dictionary:
	var seen: Dictionary = fight.boss.shown(fight.time)
	var trail: PackedStringArray = []
	for step: Variant in seen.get("trail", []):
		trail.append(str(step))
	return {"phase": _or_none(seen["phase"]), "state": _or_none(seen["state"]), "attack": _or_none(seen["attack"]),
		"telegraph": seen["telegraph"], "health": fight.boss.health, "scored": seen["reasons"].size(),
		"trail": _listed(trail)}


## Who brings the minions: the director's state and since when, what the
## next wave waits for and in how many seconds (-1 when it waits on
## something else), the waves so far, and how many of each kind stand.
static func director(fight: BossFight) -> Dictionary:
	var pacing: BossDirector = fight.director
	return {"pacing": pacing.state, "since": pacing.since, "waits_for": pacing.waits_for(),
		"next_wave_in": pacing.next_wave_in(), "waves": pacing.waves,
		"standing": {BossMinion.MELEE: fight.alive_of(BossMinion.MELEE), BossMinion.RANGED: fight.alive_of(BossMinion.RANGED)}}


## The level and every number it set, as the fight runs with them: nothing
## the level gives the boss's side is hidden.
static func difficulty(fight: BossFight) -> Dictionary:
	var shown: Dictionary = {"level": _or_none(fight.rules.level), "telegraph_scale": fight.rules.telegraph_scale,
		"minimum_telegraph": fight.table.minimum_telegraph}
	for kind: String in [BossMinion.MELEE, BossMinion.RANGED]:
		shown[kind] = {"pool": fight.tokens.free_tokens(kind) + fight.tokens.held(kind),
			"delay": fight.tokens.delay_for(kind, BossFightRules.FREE), "wave": fight.rules.wave.get(kind, 0),
			"cap": fight.rules.wave_cap.get(kind, 0)}
	return shown


# Every claim on the ring `ring_name`, as "who (point)".
static func _claims_on(fight: BossFight, ring_name: String) -> PackedStringArray:
	var claims := PackedStringArray()
	for point: EngagementRings.Point in fight.rings.points:
		if point.ring == ring_name and point.claimed_by != -1:
			claims.append("%s (%s)" % [_minion_name(fight, point.claimed_by), point.id])
	return claims


static func _minion_name(fight: BossFight, number: int) -> String:
	for minion: BossMinion in fight.minions:
		if minion.number == number:
			return minion.id
	return str(number)


static func _listed(names: PackedStringArray) -> PackedStringArray:
	return names if not names.is_empty() else PackedStringArray([NONE])


static func _or_none(text: String) -> String:
	return text if text != "" else NONE
