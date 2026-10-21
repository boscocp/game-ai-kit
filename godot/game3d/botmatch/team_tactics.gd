## Where a team's three techniques are asked, once per decision: the
## commander over the influence map, each squad's confidence and waves, and
## each bot's position among the spots.
##
## Each technique is ai_teamwork's, and reads facts. This file builds those
## facts from the match -- the team's memory of the enemy, its own bots, the
## arena's sight lines -- and writes the answers back as orders and goals.
## So it is the snapshot of ADR 0018: everything a technique decides on
## passes through here, and nothing else is read.
class_name TeamTactics
extends RefCounted

## A spot's facts are asked of at most this many other threats besides the
## main one: enough to see a cross-fire, and the rays stay bounded.
const OTHER_THREATS: int = 2
## Candidates are spots this far beyond the area too, so the view can show
## why they were dropped.
const AREA_MARGIN: float = 4.0
## A person's bot this near a place claims it.
const CLAIM_REACH: float = 1.0


## Everything `team` decides at `now`, in order.
static func think(world: BotMatch, team: MatchTeam, now: float) -> void:
	team.forget(now, world.rules.remembered_for)
	team.influence = _influence(world, team)
	_give_orders(world, team)
	for index: int in range(team.squads.size()):
		_update_confidence(world, team, index, now)
	for bot_id: int in team.members:
		var bot: MatchBot = world.bots[bot_id]
		if bot.controlled:
			_claim_where_standing(world, team, bot)
		elif _due_a_choice(world, team, bot, now):
			choose_spot(world, team, bot, now)


# A person's bot claims the place it stands on, if it stands on one, so its
# teammates leave it there -- the same courtesy they give each other.
static func _claim_where_standing(world: BotMatch, team: MatchTeam, bot: MatchBot) -> void:
	var standing: Array[int] = world.places_near(bot.position, CLAIM_REACH)
	bot.spot = standing[0] if not standing.is_empty() else -1
	team.claim(bot.id, bot.spot)


# Alive, its last choice older than the rules' interval, and not covering a
# retreat -- a covering bot stays where it is and shoots.
static func _due_a_choice(world: BotMatch, team: MatchTeam, bot: MatchBot, now: float) -> bool:
	var due: bool = bot.alive() and now - bot.chose_at >= world.rules.position_interval
	return due and not _covering_a_retreat(world, team, bot)


## Whether `bot` is in the moving wave of its squad's retreat.
static func moving_in_retreat(world: BotMatch, team: MatchTeam, bot: MatchBot) -> bool:
	var index: int = team.squad_of(bot.id)
	if team.squad_states[index] != SquadConfidence.RETREAT:
		return false
	return bot.id in _waves(world, team, index).moving


# --- the commander ---------------------------------------------------------


static func _influence(world: BotMatch, team: MatchTeam) -> TeamInfluence:
	var map := TeamInfluence.new(int(world.arena.width / 2), int(world.arena.depth / 2), 2.0,
			Vector2.ZERO, 10.0)
	for bot_id: int in team.members:
		var bot: MatchBot = world.bots[bot_id]
		if bot.alive():
			map.add_source(bot.position, float(bot.health) / world.rules.health)
	for place: Vector2 in team.known_enemies():
		map.add_source(place, -1.0)
	return map


# Every bot's point and mode: by squad from the commander, or each bot to its
# own nearest point when the commander is off.
static func _give_orders(world: BotMatch, team: MatchTeam) -> void:
	var objectives: Array[TeamCommander.Objective] = _objectives(world, team)
	if team.use_commander:
		team.squad_orders = TeamCommander.assign(_reports(world, team), objectives, TeamCommander.Weights.new())
	for bot_id: int in team.members:
		var point_id: String = _order_for(world, team, bot_id, objectives)
		var point: int = world.arena.point_ids.find(point_id)
		team.bot_points[bot_id] = point
		team.bot_modes[bot_id] = _mode_for(world, team, bot_id, point)


# On a point of ours, hold it. On one to take, only a squad whose confidence
# says attack steps onto it; a squad that only holds takes cover near it and
# contests it by fire. So the attack state decides where the bots stand.
static func _mode_for(world: BotMatch, team: MatchTeam, bot_id: int, point: int) -> String:
	if world.point_owner[point] == team.side:
		return MatchTeam.HOLD
	var confident: bool = team.squad_states[team.squad_of(bot_id)] == SquadConfidence.ATTACK
	return MatchTeam.ATTACK if confident else MatchTeam.HOLD


static func _order_for(world: BotMatch, team: MatchTeam, bot_id: int,
		objectives: Array[TeamCommander.Objective]) -> String:
	var squad_key: String = "squad%d" % team.squad_of(bot_id)
	if team.use_commander and team.squad_orders.has(squad_key):
		return team.squad_orders[squad_key]
	var alone := TeamCommander.SquadReport.new()
	alone.id = "bot%d" % bot_id
	alone.position = world.bots[bot_id].position
	var single: Array[TeamCommander.SquadReport] = [alone]
	return TeamCommander.nearest(single, objectives)[alone.id]


static func _objectives(world: BotMatch, team: MatchTeam) -> Array[TeamCommander.Objective]:
	var objectives: Array[TeamCommander.Objective] = []
	for index: int in range(world.arena.point_ids.size()):
		var objective := TeamCommander.Objective.new()
		objective.id = world.arena.point_ids[index]
		objective.position = world.arena.point_places[index]
		var owner: int = world.point_owner[index]
		objective.held_by = TeamCommander.NOBODY if owner == -1 else (TeamCommander.US if owner == team.side else TeamCommander.THEM)
		objective.ideal = team.bots_per_point
		objective.influence = team.influence.value_at(objective.position)
		objectives.append(objective)
	return objectives


# Each squad with someone alive in it, at its living members' centre.
static func _reports(world: BotMatch, team: MatchTeam) -> Array[TeamCommander.SquadReport]:
	var reports: Array[TeamCommander.SquadReport] = []
	for index: int in range(team.squads.size()):
		var living: Array[Vector2] = _living_places(world, team.squads[index])
		if living.is_empty():
			continue
		var report := TeamCommander.SquadReport.new()
		report.id = "squad%d" % index
		report.position = _centre(living)
		report.size = living.size()
		reports.append(report)
	return reports


# --- confidence and the waves ----------------------------------------------


static func _update_confidence(world: BotMatch, team: MatchTeam, index: int, now: float) -> void:
	var living: Array[Vector2] = _living_places(world, team.squads[index])
	var facts := SquadConfidence.Facts.new()
	for bot_id: int in team.squads[index]:
		if world.bots[bot_id].alive():
			facts.friendly_strength += float(world.bots[bot_id].health) / world.rules.health
	var centre: Vector2 = _centre(living) if not living.is_empty() else Vector2.ZERO
	for place: Vector2 in team.known_enemies(now, world.rules.confidence_memory):
		if place.distance_to(centre) <= world.rules.squad_sight_radius:
			facts.enemy_strength += 1.0
	facts.kills = team.kills[index].size()
	facts.losses = team.losses[index].size()
	var thresholds: SquadConfidence.Thresholds = thresholds_of(world.rules)
	var value: float = SquadConfidence.confidence(facts, thresholds)
	var before: String = team.squad_states[index]
	team.squad_states[index] = SquadConfidence.next_state(before, value, thresholds, team.may_retreat)
	world.squad_confidence[team.side][index] = value
	if team.squad_states[index] == SquadConfidence.RETREAT:
		_advance_waves(world, team, index, now, before != SquadConfidence.RETREAT)


## The confidence thresholds the match plays with: the technique's, with
## the rules' retreat and recovery.
static func thresholds_of(rules: MatchRules) -> SquadConfidence.Thresholds:
	var thresholds := SquadConfidence.Thresholds.new()
	thresholds.retreat_at = rules.retreat_at
	thresholds.recover_at = rules.recover_at
	return thresholds


# A new retreat starts at phase 0; a wave ends when its movers arrived or
# its time ran out, and the next wave's movers choose a spot at once.
static func _advance_waves(world: BotMatch, team: MatchTeam, index: int, now: float, starting: bool) -> void:
	var moving: Array[int] = _waves(world, team, index).moving
	var all_there: bool = moving.all(func(bot_id: int) -> bool: return world.bots[bot_id].arrived())
	if starting or all_there or now - team.wave_started[index] > world.rules.wave_timeout:
		if not starting:
			team.squad_phases[index] += 1
		team.wave_started[index] = now
		for bot_id: int in _waves(world, team, index).moving:
			world.bots[bot_id].chose_at = -INF


static func _waves(world: BotMatch, team: MatchTeam, index: int) -> SquadConfidence.Waves:
	var living: Array[int] = []
	for bot_id: int in team.squads[index]:
		if world.bots[bot_id].alive():
			living.append(bot_id)
	if team.retreat_in_one_wave:
		var everyone := SquadConfidence.Waves.new()
		everyone.moving = living
		return everyone
	return SquadConfidence.waves(living, team.squad_phases[index])


static func _covering_a_retreat(world: BotMatch, team: MatchTeam, bot: MatchBot) -> bool:
	var index: int = team.squad_of(bot.id)
	return team.squad_states[index] == SquadConfidence.RETREAT and not moving_in_retreat(world, team, bot)


# --- where to stand --------------------------------------------------------


## Choose `bot`'s spot: build each candidate's facts from the team's memory
## and the arena's sight lines, ask `TacticalPositions`, keep the current
## spot unless the best beats it by the rules' stay margin, and claim it.
static func choose_spot(world: BotMatch, team: MatchTeam, bot: MatchBot, now: float) -> void:
	bot.chose_at = now
	var area: Array = area_of(world, team, bot)
	var nearby: Array[int] = world.places_near(area[0], float(area[1]) + AREA_MARGIN)
	var threats: Array[Vector2] = _threats_for(bot.position, team.known_enemies())
	var candidates: Array[TacticalPositions.Candidate] = []
	for place: int in nearby:
		candidates.append(SpotFacts.build(world, team, bot, place, area, threats))
	var choice: TacticalPositions.Choice = TacticalPositions.choose(bot.id, candidates,
			TacticalPositions.Weights.new(), not threats.is_empty(), team.use_claims)
	team.last_choice[bot.id] = [choice, nearby]
	var picked: int = _stay_or_move(world, bot, choice, nearby)
	team.claim(bot.id, picked)
	world.send(bot, world.place_position(picked) if picked != -1 else area[0], picked)


## Where `bot` should be: [centre, radius]. A retreat's movers fall back
## towards their spawn; a squad attacking stands on its point, one holding
## stands in cover near it.
static func area_of(world: BotMatch, team: MatchTeam, bot: MatchBot) -> Array:
	if moving_in_retreat(world, team, bot):
		var squad_places: Array[Vector2] = _living_places(world, team.squads[team.squad_of(bot.id)])
		var centre: Vector2 = _centre(squad_places)
		var home: Vector2 = _centre(world.arena.spawns[team.name])
		return [centre + (home - centre).normalized() * world.rules.fallback_metres, world.rules.area_radius]
	var point: Vector2 = world.arena.point_places[team.bot_points[bot.id]]
	var attacking: bool = team.bot_modes[bot.id] == MatchTeam.ATTACK
	return [point, world.rules.attack_radius if attacking else world.rules.area_radius]


static func _stay_or_move(world: BotMatch, bot: MatchBot, choice: TacticalPositions.Choice,
		nearby: Array[int]) -> int:
	if choice.chosen == -1:
		return -1
	var current: int = nearby.find(bot.spot)
	var keeps: bool = current != -1 and choice.statuses[current] == TacticalPositions.KEPT
	if keeps and choice.scores[current] + world.rules.stay_margin >= choice.scores[choice.chosen]:
		return bot.spot
	return nearby[choice.chosen]


# The nearest known enemy first, then the next OTHER_THREATS.
static func _threats_for(place: Vector2, enemies: Array[Vector2]) -> Array[Vector2]:
	var sorted: Array[Vector2] = enemies.duplicate()
	sorted.sort_custom(func(one: Vector2, other: Vector2) -> bool:
		return place.distance_squared_to(one) < place.distance_squared_to(other))
	return sorted.slice(0, OTHER_THREATS + 1)


static func _living_places(world: BotMatch, squad: Array) -> Array[Vector2]:
	var places: Array[Vector2] = []
	for bot_id: int in squad:
		if world.bots[bot_id].alive():
			places.append(world.bots[bot_id].position)
	return places


static func _centre(places: Array) -> Vector2:
	var total := Vector2.ZERO
	for place: Vector2 in places:
		total += place
	return total / maxf(places.size(), 1)
