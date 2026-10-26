## What falling back is weighed on (T65), measured from what a bot
## perceives, for `ErrandChoice.weigh_fall_back` -- and where it would go.
##
## Where: cover near its squad's point, not towards its spawn. Every source
## the T65 reading opened falls back at the objective and only to cover
## (F.E.A.R.: "run away if he can find a path to safety, or hunker down"),
## so the place is T68's hiding query -- the nearest place no enemy its team
## knows of sees it crouched on -- asked within the rules' `hide_metres` of
## the point. With none, it holds where it is: staying at its post is
## holding, and there is nothing to weigh.
##
## What: the health that would come back priced by its exposure, as
## hiding's; the death it would avoid -- the chance of dying soon where it
## stands, by its health and exposure, less the chance in cover, both read
## from the table the effects gate measured (`rules.json`'s `dying`), times
## what a death costs in seconds, the wait to come back and the walk back
## to the point; each second away; and the point it would give up -- the
## seconds until the enemy owns it -- when it is the last of its team
## within the area radius of its point, with an enemy known near.
##
## A query over the places near the point, two rays each per known enemy,
## asked only when falling back could win, and kept as a hiding place is.
## When not to use it: a bot with no squad's point to fall back to.
class_name FallBackFacts
extends RefCounted


## [ErrandChoice.FallBack, the place's index, its position] for `bot` of
## `team`; unavailable when its team does not fall back, it knows of no
## enemy, or nothing is to be gained -- unseen and unhit, it heals and is as
## safe where it stands.
static func build(world: BotMatch, team: MatchTeam, bot: MatchBot) -> Array:
	var rules: MatchRules = world.rules
	var facts := ErrandChoice.FallBack.new()
	var enemies: Array[Vector2] = team.known_enemies()
	if not team.may_retreat or enemies.is_empty() or not team.bot_points.has(bot.id):
		return [facts, -1, Vector2.INF]
	facts.exposure = MatchHealth.exposure(world, team, bot)
	if facts.exposure <= 0.0:
		return [facts, -1, Vector2.INF]
	var point: int = team.bot_points[bot.id]
	_measure(world, team, bot, point, facts)
	var best_case: float = ErrandChoice.weigh_fall_back(facts, MatchSupply.weights_of(rules, team))[3]
	if best_case <= 0.0:
		# Shown at its best -- cover at its feet -- and asked again as soon
		# as it could win, as hiding is.
		bot.fall_back_asked_at = -INF
		return [facts, -1, Vector2.INF]
	var place: int = _place(world, team, bot, point, enemies)
	if place == -1:
		return [ErrandChoice.FallBack.new(), -1, Vector2.INF]
	var at: Vector2 = world.place_position(place)
	facts.walk_seconds = bot.position.distance_to(at) / rules.speed
	var missing: int = mini(rules.regeneration_to, rules.health) - bot.health
	var still_delayed: float = maxf(0.0, MatchHealth.delay_left(rules, bot, world.time) - facts.walk_seconds)
	facts.wait_seconds = still_delayed + missing / rules.regeneration_rate if missing > 0 else 0.0
	return [facts, place, at]


# Everything but the walk, which needs the place: the cover at its feet.
static func _measure(world: BotMatch, team: MatchTeam, bot: MatchBot, point: int,
		facts: ErrandChoice.FallBack) -> void:
	var rules: MatchRules = world.rules
	var missing: int = maxi(0, mini(rules.regeneration_to, rules.health) - bot.health)
	var share: float = float(bot.health) / rules.health
	facts.available = true
	facts.hurt = float(missing) / rules.health
	facts.dying_here = chance_of_dying(rules, share, facts.exposure)
	facts.dying_there = chance_of_dying(rules, share, 0.0)
	var point_place: Vector2 = world.arena.point_places[point]
	# A point no walk reaches from the base has no walk back to price.
	var back: float = world.supply.walk_from_base(world, bot.team, point_place)
	facts.death_seconds = rules.respawn_wait(world.time) + (back if back < MatchSupply.UNREACHED else 0.0)
	facts.wait_seconds = MatchHealth.delay_left(rules, bot, world.time) + missing / rules.regeneration_rate if missing > 0 else 0.0
	facts.point_seconds = point_given_up(world, team, bot, point)


## The measured chance that a bot with `health_share` of its health and
## `exposure` dies within the table's seconds: `rules.json`'s `dying`, by
## the bands `MatchFallBacks` counted it in. 0 with no table.
static func chance_of_dying(rules: MatchRules, health_share: float, exposure: float) -> float:
	var chances: Array = rules.dying.get("chances", [])
	if chances.is_empty():
		return 0.0
	var band: int = MatchFallBacks.band(health_share, exposure)
	return float(chances[band / MatchFallBacks.EXPOSURE_BANDS][band % MatchFallBacks.EXPOSURE_BANDS])


## Seconds until the enemy would own `point` if `bot` left it: from the
## point's progress, its whole capture time to neutral and as much again --
## 8 s from a point held. Nothing unless it is the last of its team within
## the area radius, not falling back, and an enemy is known within the
## rules' squad sight radius of the point: then it gives nothing up.
static func point_given_up(world: BotMatch, team: MatchTeam, bot: MatchBot, point: int) -> float:
	var rules: MatchRules = world.rules
	var place: Vector2 = world.arena.point_places[point]
	if bot.position.distance_to(place) > rules.area_radius:
		return 0.0
	for other_id: int in team.members:
		var other: MatchBot = world.bots[other_id]
		var stays: bool = other.alive() and other.errand != ErrandChoice.FALL_BACK
		if other_id != bot.id and stays and other.position.distance_to(place) <= rules.area_radius:
			return 0.0
	var enemy_near: bool = team.known_enemies().any(func(enemy: Vector2) -> bool:
		return enemy.distance_to(place) <= rules.squad_sight_radius)
	if not enemy_near:
		return 0.0
	var ours: float = world.point_progress[point] * (1.0 if team.side == BotMatch.BLUE else -1.0)
	return (ours + 1.0) * rules.capture_time


# The place near its squad's point, kept for the rules' position interval
# unless the enemies its team knows of change, as a hiding place is.
static func _place(world: BotMatch, team: MatchTeam, bot: MatchBot, point: int, enemies: Array[Vector2]) -> int:
	var known: Array = MatchHealth.known_ids(team)
	var stale: bool = world.time - bot.fall_back_asked_at >= world.rules.position_interval
	if not stale and known == bot.fall_back_asked_for:
		return bot.fall_back_spot
	bot.fall_back_asked_at = world.time
	bot.fall_back_asked_for = known
	var threats: Array[Vector2] = MatchHealth.nearest_first(bot.position, enemies)
	return MatchHealth.hiding_place(world, team, bot, threats, world.arena.point_places[point])
