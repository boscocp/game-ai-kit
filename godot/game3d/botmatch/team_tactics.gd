## Where a team's three techniques are asked, once per decision: the
## commander over the influence map, each squad's confidence, the waves its
## fall-backs keep to, and each bot's position among the spots.
##
## Since T65 no threshold sends a squad back: confidence is what a squad
## perceives of the fight -- it decides whether the squad steps onto a
## point to take it -- and falling back is each bot's own errand, weighed
## (`FallBackFacts`). The waves are the coordination: a squad's member falls
## back only while another covers it.
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
		_update_confidence(world, team, index)
	world.supply.think(world, team)
	for index: int in range(team.squads.size()):
		_keep_to_waves(world, team, index, now)
	for bot_id: int in team.members:
		var bot: MatchBot = world.bots[bot_id]
		if bot.controlled:
			_claim_where_standing(world, team, bot)
		elif bot.errand != MatchSupply.NO_ERRAND:
			_run_errand(world, team, bot)
		elif _due_a_choice(world, team, bot, now):
			choose_spot(world, team, bot, now)


# A bot on an errand gives up its spot and heads for the errand's place --
# hiding or falling back, it claims the place it goes to, so two do not
# share it; back from it, it chooses a spot at once.
static func _run_errand(world: BotMatch, team: MatchTeam, bot: MatchBot) -> void:
	var spot: int = -1
	if bot.errand == MatchSupply.HIDE:
		spot = bot.hide_spot
	elif bot.errand == MatchSupply.FALL_BACK:
		spot = bot.fall_back_spot
	# A teammate took the place since this bot found it -- the places are
	# found before anyone claims, and kept a second: it stays at its post
	# this decision and looks again. Claiming over it stacked two bodies on
	# one spot (wave 97, measured: 366 s bunched with claims on).
	var taken: bool = spot != -1 and int(team.claims.get(spot, bot.id)) != bot.id
	if taken and team.use_claims:
		bot.errand = MatchSupply.NO_ERRAND
		bot.hide_asked_at = -INF
		bot.fall_back_asked_at = -INF
		return
	team.claim(bot.id, spot)
	bot.chose_at = -INF
	world.send(bot, MatchSupply.errand_place(world, bot), spot)


# A person's bot claims the place it stands on, if it stands on one, so its
# teammates leave it there -- the same courtesy they give each other.
static func _claim_where_standing(world: BotMatch, team: MatchTeam, bot: MatchBot) -> void:
	var standing: Array[int] = world.places_near(bot.position, CLAIM_REACH)
	bot.spot = standing[0] if not standing.is_empty() else -1
	team.claim(bot.id, bot.spot)


# Alive, its last choice older than the rules' interval, and not covering a
# fall-back -- a covering bot stays where it is and shoots.
static func _due_a_choice(world: BotMatch, team: MatchTeam, bot: MatchBot, now: float) -> bool:
	var due: bool = bot.alive() and now - bot.chose_at >= world.rules.position_interval
	return due and not covering_a_retreat(world, team, bot)


## Whether `bot` is falling back now: on the errand, which the waves left
## it -- in the moving wave of its squad.
static func moving_in_retreat(_world: BotMatch, _team: MatchTeam, bot: MatchBot) -> bool:
	return bot.alive() and bot.errand == MatchSupply.FALL_BACK


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


# The squad's confidence, as Days Gone's squads keep it, and from it whether
# it attacks or holds. Never retreat: that is each bot's to weigh (T65).
static func _update_confidence(world: BotMatch, team: MatchTeam, index: int) -> void:
	var now: float = world.time
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
	var value: float = SquadConfidence.confidence(facts, SquadConfidence.Thresholds.new())
	var before: String = team.squad_states[index]
	team.squad_states[index] = SquadConfidence.next_state(before, value, SquadConfidence.Thresholds.new(), false)
	world.squad_confidence[team.side][index] = value


# A member falls back only while another covers it. When every living
# member of a squad of two or more weighed falling back, the waves split
# them: one half keeps the errand and moves, the other stays and shoots,
# and they swap when the movers arrived or the rules' wave time ran out.
# A planted team that retreats in one wave lets them all go at once.
static func _keep_to_waves(world: BotMatch, team: MatchTeam, index: int, now: float) -> void:
	var living: Array[int] = []
	for bot_id: int in team.squads[index]:
		if world.bots[bot_id].alive():
			living.append(bot_id)
	var wanting: Array[int] = living.filter(func(bot_id: int) -> bool:
		return world.bots[bot_id].errand == MatchSupply.FALL_BACK)
	var all_want: bool = living.size() >= 2 and wanting.size() == living.size()
	if not all_want or team.retreat_in_one_wave:
		team.wave_started[index] = -INF
		return
	var split: SquadConfidence.Waves = SquadConfidence.waves(living, team.squad_phases[index])
	var all_there: bool = split.moving.all(func(bot_id: int) -> bool: return world.bots[bot_id].arrived())
	var timed_out: bool = now - team.wave_started[index] > world.rules.wave_timeout
	if team.wave_started[index] == -INF:
		team.wave_started[index] = now
	elif all_there or timed_out:
		team.squad_phases[index] += 1
		team.wave_started[index] = now
		split = SquadConfidence.waves(living, team.squad_phases[index])
	for bot_id: int in split.covering:
		world.bots[bot_id].errand = MatchSupply.NO_ERRAND


## Whether `bot` covers a fall-back: alive, staying, while a member of its
## squad falls back. It stays where it is and shoots.
static func covering_a_retreat(world: BotMatch, team: MatchTeam, bot: MatchBot) -> bool:
	if not bot.alive() or moving_in_retreat(world, team, bot):
		return false
	for bot_id: int in team.squads[team.squad_of(bot.id)]:
		if moving_in_retreat(world, team, world.bots[bot_id]):
			return true
	return false


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


## Where `bot` should be: [centre, radius]. A squad attacking stands on
## its point, one holding stands in cover near it. (A bot falling back is
## on an errand, sent to its place by `_run_errand`.)
static func area_of(world: BotMatch, team: MatchTeam, bot: MatchBot) -> Array:
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
