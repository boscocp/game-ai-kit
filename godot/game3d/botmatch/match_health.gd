## Health that comes back (T68, the owner's ask): after the rules' delay
## without a hit, a bot's health returns a little each step, as in the
## shooters people know -- Halo's shields, Call of Duty's health (the
## sources are in `docs/concepts/shooter-ai.md`). The person's bot comes
## back by the same rule: it is the same body.
##
## Health is a whole number and a step gives back a fraction of a point, so
## what is not yet a point is carried to the next step, and a hit throws it
## away with the clock. Constant time a bot a step.
##
## Whether to break off and hide while it comes back is weighed, not a
## threshold. Health comes back while a bot stays, too, unless it is hit:
## so what breaking off gains is the hit it avoids, and `exposure` measures
## that from what the bot perceives -- 1 under fire lately, else the share
## of the enemies its team knows of with a line to its body now. And
## `hide_facts` measures what `ErrandChoice` weighs hiding by -- the
## nearest place hidden from every enemy the team knows of, asked of
## `TacticalPositions`, how long the walk there and the wait for the health
## would take -- beside going home to be healed whole and staying to fight.
## A query over the places near the bot, two rays each per known enemy.
##
## When not to use it: a game whose healing is a pickup or a medic -- then
## health only comes back by an errand, and this file has nothing to do.
class_name MatchHealth
extends RefCounted

## The planted rule's fixed threshold: a team that always breaks off below
## this much health, whatever it costs (`MatchTeam.heal_rule`).
const ALWAYS_BELOW: int = 50


## Give `bot` back what `delta` seconds of regeneration is worth, if its
## last hit is older than the rules' delay; never past the rules' cap nor
## its whole health. What it gained, in points, for the counts.
static func regenerate(rules: MatchRules, bot: MatchBot, now: float, delta: float) -> int:
	var cap: int = mini(rules.regeneration_to, rules.health)
	if now - bot.hurt_at < rules.regeneration_delay or bot.health >= cap:
		bot.regeneration_carry = 0.0
		return 0
	bot.regeneration_carry += rules.regeneration_rate * delta
	var whole: int = floori(bot.regeneration_carry)
	bot.regeneration_carry -= whole
	var gained: int = mini(whole, cap - bot.health)
	bot.health += gained
	return gained


## Seconds until `bot` begins to come back, at `now`: 0 once it has begun.
static func delay_left(rules: MatchRules, bot: MatchBot, now: float) -> float:
	return maxf(0.0, rules.regeneration_delay - (now - bot.hurt_at))


## What hiding to heal is weighed on, for `bot` of `team`, and where it
## would hide: [ErrandChoice.Hide, the place's index, its position]. With
## no enemy known, or nothing to come back, there is nothing to hide from
## or for: unavailable -- it regenerates where it stands.
##
## The place is only looked for when hiding could win. Cover at its feet is
## the best case -- no walk, the whole wait -- and a weighing team whose best
## case scores no more than zero would never hide, so it is shown that
## best case, with no place, rather than spend the rays: measured, asking
## every hurt bot every decision made a match four times slower. And the
## place found is kept for the rules' `position_interval`, as a fighting
## spot is -- unless the enemies its team knows of change, when it is
## asked again: a place hidden from the old set may not be from the new.
static func hide_facts(world: BotMatch, team: MatchTeam, bot: MatchBot) -> Array:
	var rules: MatchRules = world.rules
	var facts := ErrandChoice.Hide.new()
	var missing: int = mini(rules.regeneration_to, rules.health) - bot.health
	var threats: Array[Vector2] = nearest_first(bot.position, team.known_enemies())
	if missing <= 0 or threats.is_empty() or team.heal_rule == MatchSupply.NEVER:
		return [facts, -1, Vector2.INF]
	facts.available = true
	facts.hurt = float(missing) / rules.health
	facts.exposure = exposure(world, team, bot)
	facts.wait_seconds = delay_left(rules, bot, world.time) + missing / rules.regeneration_rate
	facts.attacking = team.bot_modes.get(bot.id, MatchTeam.HOLD) == MatchTeam.ATTACK
	var best_case: float = ErrandChoice.weigh_hide(facts, MatchSupply.weights_of(rules))[3]
	if best_case <= 0.0 and team.heal_rule == MatchSupply.WEIGH:
		# Asked again as soon as it could win: no place is remembered.
		bot.hide_asked_at = -INF
		return [facts, -1, Vector2.INF]
	var place: int = bot.hide_spot
	var known: Array = known_ids(team)
	if world.time - bot.hide_asked_at >= rules.position_interval or known != bot.hide_asked_for:
		place = hiding_place(world, team, bot, threats)
		bot.hide_asked_at = world.time
		bot.hide_asked_for = known
	if place == -1:
		return [ErrandChoice.Hide.new(), -1, Vector2.INF]
	var at: Vector2 = world.place_position(place)
	facts.walk_seconds = bot.position.distance_to(at) / rules.speed
	var still_delayed: float = maxf(0.0, delay_left(rules, bot, world.time) - facts.walk_seconds)
	facts.wait_seconds = still_delayed + missing / rules.regeneration_rate
	return [facts, place, at]


## How exposed `bot` is where it stands, 0 to 1, from what it perceives:
## 1 when it was hit within the rules' `confidence_memory` -- under fire,
## whoever fired -- else the share of the enemies its team knows of whose
## eyes, where they were seen, have a clear line to its body; 0 when it
## knows of none. What staying would cost it: the hit that resets its
## clock. A ray per known enemy.
static func exposure(world: BotMatch, team: MatchTeam, bot: MatchBot) -> float:
	var rules: MatchRules = world.rules
	if world.time - bot.hurt_at <= rules.confidence_memory:
		return 1.0
	var enemies: Array[Vector2] = team.known_enemies()
	if enemies.is_empty():
		return 0.0
	var height: float = rules.crouched_height if bot.crouched else rules.chest_height
	var body: Vector3 = world.arena.above(bot.position, height)
	var seeing: int = 0
	for enemy: Vector2 in enemies:
		seeing += 1 if world.arena.clear_line(world.arena.above(enemy, rules.eye_height), body) else 0
	return float(seeing) / enemies.size()


## The ids of the enemies `team` knows of, in order: a hiding place found
## for one set is asked again when it changes, not kept for a second.
static func known_ids(team: MatchTeam) -> Array:
	var ids: Array = team.remembered.keys()
	ids.sort()
	return ids


## The nearest place to `bot` within the rules' `hide_metres` of `centre`
## -- the bot itself, or, falling back (T65), its squad's point -- that no
## enemy in `threats` would see it crouched on and nobody else of its team
## holds: `TacticalPositions` asked to hide, nearness alone ranking. -1:
## none.
static func hiding_place(world: BotMatch, team: MatchTeam, bot: MatchBot, threats: Array[Vector2],
		centre: Vector2 = Vector2.INF) -> int:
	var around: Vector2 = bot.position if centre == Vector2.INF else centre
	var area: Array = [around, world.rules.hide_metres]
	var nearby: Array[int] = world.places_near(around, world.rules.hide_metres)
	var candidates: Array[TacticalPositions.Candidate] = []
	for place: int in nearby:
		candidates.append(SpotFacts.build(world, team, bot, place, area, threats))
	# As far as the furthest place in the area can be from the bot.
	var reach: float = world.rules.hide_metres + bot.position.distance_to(around)
	var choice: TacticalPositions.Choice = TacticalPositions.choose(bot.id, candidates, _hiding_weights(reach),
			true, team.use_claims)
	return nearby[choice.chosen] if choice.chosen != -1 else -1


# The query's weights to hide, not to fight: every threat term at zero, so
# nearness alone ranks what no threat sees, out to `reach` metres.
static func _hiding_weights(reach: float) -> TacticalPositions.Weights:
	var weights := TacticalPositions.Weights.new()
	weights.partial_cover = 0.0
	weights.line_of_fire = 0.0
	weights.other_cover = 0.0
	weights.preferred_range = 0.0
	weights.max_travel = reach
	weights.cover_from_all = true
	return weights


## `enemies`, the nearest to `place` first.
static func nearest_first(place: Vector2, enemies: Array[Vector2]) -> Array[Vector2]:
	var sorted: Array[Vector2] = enemies.duplicate()
	sorted.sort_custom(func(one: Vector2, other: Vector2) -> bool:
		return place.distance_squared_to(one) < place.distance_squared_to(other))
	return sorted
