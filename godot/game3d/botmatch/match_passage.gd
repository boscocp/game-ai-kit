## A bot blocked by a body in the bot match, deciding how to get past it by
## `PassageChoice`: the facts measured here, the choice carried out here.
##
## The facts: how far the body must still move and how fast it moves off;
## the extra walk of a detour round the bodies near, an A* over
## `CrowdedWalk`; whether it is a teammate, and whether it refused lately;
## and how much less the next best spot the bot weighed is worth. Asking is
## a request the teammate answers by its own weighing (`PassageChoice.answer`):
## what being let by saves the asker against what moving costs itself now.
class_name MatchPassage
extends RefCounted


## `bot`, blocked going `step`, weighs its ways on and takes one.
static func decide(world: BotMatch, bot: MatchBot, step: Vector2) -> void:
	var blocker: MatchBot = _blocker(world, bot, step)
	if blocker == null:
		return
	var target: Vector2i = bot.path[-1] if not bot.path.is_empty() else BotArena.cell_of(bot.goal)
	var closed: Array[Vector2i] = _closed_cells(world, bot, target)
	var detour: Array[Vector2i] = world.detour(bot, target, closed)
	# A "way round" whose first step is the step that is blocked is no way
	# round: a body inside the bot's own cell closes nothing the grid sees.
	if not detour.is_empty() and not bot.path.is_empty() and detour[0] == bot.path[0]:
		detour = []
	var facts: PassageChoice.Facts = _facts(world, bot, blocker, step, detour)
	var choice: PassageChoice.Choice = PassageChoice.choose(facts)
	bot.last_passage = {"blocker": blocker.id, "costs": choice.costs, "chosen": choice.chosen, "answer": ""}
	match choice.chosen:
		PassageChoice.DETOUR:
			bot.path = detour
		PassageChoice.ASK:
			_ask(world, bot, blocker, choice)
		PassageChoice.OTHER_SPOT:
			_take_the_next_spot(world, bot)


# The body the step runs into: the nearest living one it would touch, and
# of two as near, a teammate -- the one it may ask -- rather than the lower
# id, which is blue's whichever side asks.
static func _blocker(world: BotMatch, bot: MatchBot, step: Vector2) -> MatchBot:
	var found: MatchBot = null
	var touching: float = world.rules.body_radius * 2.0
	for other: MatchBot in world.bots:
		var near: bool = other != bot and other.alive() and other.position.distance_to(bot.position + step) < touching
		if near and (found == null or _nearer_blocker(bot, other, found)):
			found = other
	return found


static func _nearer_blocker(bot: MatchBot, other: MatchBot, found: MatchBot) -> bool:
	var apart: float = snappedf(other.position.distance_to(bot.position), 1e-6)
	var found_apart: float = snappedf(found.position.distance_to(bot.position), 1e-6)
	return apart < found_apart or (apart == found_apart and other.team == bot.team and found.team != bot.team)


# The cells a body within reach leaves no room in -- their middle nearer it
# than two radii and half a cell -- the bot's own and its target's left open.
static func _closed_cells(world: BotMatch, bot: MatchBot, target: Vector2i) -> Array[Vector2i]:
	var open_cells: Array[Vector2i] = [BotArena.cell_of(bot.position), target]
	var reach: float = world.rules.body_radius * 2.0 + 0.5
	var closed: Array[Vector2i] = []
	var reached: float = world.rules.passage_body_reach
	var near: Array = world.bots.filter(func(other: MatchBot) -> bool:
		return other != bot and other.alive() and other.position.distance_to(bot.position) <= reached)
	for other: MatchBot in near:
		var round: Array[Vector2i] = _cells_round(other.position, reach)
		closed.append_array(round.filter(func(cell: Vector2i) -> bool: return not open_cells.has(cell) and not closed.has(cell)))
	return closed


# The cells whose middle is within `reach` of `place`.
static func _cells_round(place: Vector2, reach: float) -> Array[Vector2i]:
	var middle: Vector2i = BotArena.cell_of(place)
	var found: Array[Vector2i] = []
	for index: int in range(25):
		var cell: Vector2i = middle + Vector2i(index % 5 - 2, index / 5 - 2)
		if BotArena.centre_of(cell).distance_to(place) < reach:
			found.append(cell)
	return found


static func _facts(world: BotMatch, bot: MatchBot, blocker: MatchBot, step: Vector2,
		detour: Array[Vector2i]) -> PassageChoice.Facts:
	var rules: MatchRules = world.rules
	var facts := PassageChoice.Facts.new()
	var away: Vector2 = (blocker.position - bot.position).normalized()
	facts.gap = maxf(rules.body_radius * 2.0 - blocker.position.distance_to(bot.position + step), 0.0)
	facts.leaving_speed = maxf(blocker.velocity.dot(away), 0.0)
	facts.detour_metres = INF if detour.is_empty() else maxf(float(detour.size() - bot.path.size()), 0.0)
	facts.speed = MatchActions.speed_of(world, bot)
	facts.teammate = blocker.team == bot.team
	facts.refused = world.time - float(bot.refused_by.get(blocker.id, -INF)) < rules.passage_refusal_memory
	facts.ask_seconds = rules.passage_ask_seconds
	facts.spot_loss = _next_spot_loss(world, bot)
	facts.points_a_second = rules.passage_points_a_second
	return facts


# How many points less the next best spot the bot weighed is worth than the
# one it holds; INF when it weighed no other it may take.
static func _next_spot_loss(world: BotMatch, bot: MatchBot) -> float:
	var next: Array = _next_spot(world, bot)
	return INF if next.is_empty() else float(next[1])


# The next best spot of the bot's last position query, kept and not its
# own: [place index, points less than its own], or [] when there is none.
static func _next_spot(world: BotMatch, bot: MatchBot) -> Array:
	var team: MatchTeam = world.teams[bot.team]
	if not team.last_choice.has(bot.id) or bot.spot == -1:
		return []
	var choice: TacticalPositions.Choice = team.last_choice[bot.id][0]
	var places: Array = team.last_choice[bot.id][1]
	var own: int = places.find(bot.spot)
	var best: int = -1
	for index: int in range(places.size()):
		var kept: bool = choice.statuses[index] == TacticalPositions.KEPT and index != own
		if kept and (best == -1 or choice.scores[index] > choice.scores[best]):
			best = index
	if best == -1 or own == -1:
		return []
	return [places[best], maxf(choice.scores[own] - choice.scores[best], 0.0)]


static func _take_the_next_spot(world: BotMatch, bot: MatchBot) -> void:
	var next: Array = _next_spot(world, bot)
	if next.is_empty():
		return
	world.teams[bot.team].claim(bot.id, next[0])
	world.send(bot, world.place_position(next[0]), next[0])
	bot.chose_at = world.time


# The request: what being let by saves the asker -- its next cheapest way
# less asking -- sent to the teammate, which weighs it against its own cost.
static func _ask(world: BotMatch, bot: MatchBot, blocker: MatchBot, choice: PassageChoice.Choice) -> void:
	var request: PassageChoice.Request = request_to(world, blocker, bot)
	var others: PackedFloat64Array = choice.costs.duplicate()
	var asked: int = PassageChoice.WAYS.find(PassageChoice.ASK)
	others.remove_at(asked)
	var next_best: float = others[0]
	for cost: float in others:
		next_best = minf(next_best, cost)
	request.saves = next_best - choice.costs[asked]
	var reply: PassageChoice.Answer = PassageChoice.answer(request, prices_of(world.rules))
	bot.last_passage["answer"] = "granted" if reply.granted else "refused"
	bot.last_passage["saves"] = request.saves
	bot.last_passage["their_cost"] = reply.cost
	if not reply.granted:
		bot.refused_by[blocker.id] = world.time
		return
	var aside: Vector2 = _aside(world, bot, blocker)
	if aside != Vector2.INF:
		world.send(blocker, aside, blocker.spot)
	blocker.chose_at = world.time


## What the teammate `asked` knows of itself, as a request's facts, with
## `asker` the bot it would step aside for.
static func request_to(world: BotMatch, asked: MatchBot, asker: MatchBot) -> PassageChoice.Request:
	var request := PassageChoice.Request.new()
	request.enemies_in_sight = (world.sight.get(asked.id, []) as Array).size()
	request.shooting = asked.action == MatchBot.SHOOT
	request.reloading = asked.reload_left > 0.0
	request.covering_a_retreat = TeamTactics.covering_a_retreat(world, world.teams[asked.team], asked)
	request.driven_by_a_person = asked.controlled
	request.room_to_step = _aside(world, asker, asked) != Vector2.INF
	return request


## The rules' prices for stepping aside, as the technique takes them.
static func prices_of(rules: MatchRules) -> PassageChoice.Prices:
	var prices := PassageChoice.Prices.new()
	prices.step_seconds = rules.make_way_step_seconds
	prices.per_enemy_seen = rules.make_way_per_enemy
	prices.shooting = rules.make_way_shooting
	prices.reloading = rules.make_way_reloading
	prices.covering_a_retreat = rules.make_way_covering
	return prices


# Where `asked` steps aside to: of a step away from the asker and a step to
# either side of that, the free one furthest from the asker, and of two as
# far -- either side, when straight away is blocked -- the one further
# south, which the mirror across x keeps; INF when none is free. Not by an
# order of turns: "+90 first" sent blue's teammate north and red's south.
static func _aside(world: BotMatch, asker: MatchBot, asked: MatchBot) -> Vector2:
	var away: Vector2 = (asked.position - asker.position).normalized()
	var best: Vector2 = Vector2.INF
	var best_score := Vector2(INF, INF)
	for turn: float in [0.0, PI / 2.0, -PI / 2.0]:
		var to: Vector2 = asked.position + away.rotated(turn) * world.rules.passage_step_aside
		var score := Vector2(-snappedf(to.distance_to(asker.position), 1e-6), -snappedf(to.y, 1e-6))
		if _free_for(world, asked, to) and score < best_score:
			best_score = score
			best = to
	return best


static func _free_for(world: BotMatch, bot: MatchBot, to: Vector2) -> bool:
	return world.arena.can_step(bot.position, to, world.rules.body_radius) and MatchActions.clear_of_bodies(world, bot, to)
