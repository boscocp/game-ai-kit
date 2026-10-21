## A capture-and-hold match between two teams of bots, as a simulation with
## no physics engine in it: it steps a fixed time, looks, decides, moves,
## shoots, captures and scores, and runs headless at many times real speed.
## The 3D scene draws one of these; `botmatch_effects.gd` runs hundreds.
##
## Every step, in order: every `decision_interval`, the sight table is built
## (who sees whom, by `BotArena.clear_line`), each team remembers what its
## bots saw and thinks (`TeamTactics`), and every bot runs its priority list
## (`MatchBot.decide`). Then every bot acts on what it chose, points are
## captured, and the score grows by each point held. One random generator,
## seeded, and bots always taken in id order: the same seed is the same match.
##
## What it counts -- points held, deaths, points lost, bots bunched in one
## spot, and every shot with whether its target was in the shooter's sight
## row -- is what the effects test reads. A shot at a target not in the row
## is counted, never prevented, so a cheating bot is caught rather than
## silently stopped.
class_name BotMatch
extends RefCounted

const BLUE: int = 0
const RED: int = 1
const TEAM_NAMES: Array[String] = ["blue", "red"]
const BOTS_A_SIDE: int = 6
## Three squads of two: six bots over three points, so a commander that
## sends one squad to each objective can cover the map. With two squads of
## three, both sides' commanders sent everyone to the two nearest points and
## left the third to whoever wandered there alone.
const PER_SQUAD: int = 2
## A bot sees ahead within this half-angle, and all round within NEAR.
const VIEW_HALF_ANGLE: float = deg_to_rad(60.0)
const NEAR: float = 3.0
## Two bots holding cover spots this close count as bunched.
const BUNCHED: float = 1.0
## The places around a point a bot attacking it may stand on.
const ON_POINT: float = 1.5
## How many shots the view is kept for.
const SHOTS_KEPT: int = 48

var rules: MatchRules
var arena: BotArena
var teams: Array[MatchTeam] = []
var bots: Array[MatchBot] = []
var time: float = 0.0
var random := RandomNumberGenerator.new()
## Each point's owner (-1 nobody), and its progress, -1 red to +1 blue.
var point_owner: PackedInt32Array = PackedInt32Array()
var point_progress: PackedFloat64Array = PackedFloat64Array()
var score: PackedFloat64Array = PackedFloat64Array([0.0, 0.0])
## The sight table: bot id -> the enemy ids it sees now.
var sight: Dictionary = {}
## Each squad's last confidence, by team, for the view.
var squad_confidence: Array[Dictionary] = [{}, {}]
## What the effects test reads, by team.
var stats: Array[MatchStats] = [MatchStats.new(), MatchStats.new()]
## The last shots, newest last: [time, shooter, target (-1: none), hit,
## from, to] -- the two ends in 3D, for the view's tracers.
var recent_shots: Array[Array] = []
## Every shot fired since the match began, for the view to hear the new ones.
var shots_fired: int = 0
## Cover spots, then the places on each point.
var _places: Array[Vector2] = []
var _place_ids: Array[String] = []
var _cover_count: int = 0
var _next_decision: float = 0.0
var _search := AStarSearch.new()


## A new match. `blue` and `red` are the two teams, made by the caller with
## their switches and knobs; this gives them their bots and squads.
func _init(seed_value: int, blue: MatchTeam, red: MatchTeam, match_rules: MatchRules = null,
		match_arena: BotArena = null) -> void:
	random.seed = seed_value
	rules = match_rules if match_rules != null else MatchRules.new()
	arena = match_arena if match_arena != null else BotArena.new(rules.body_radius)
	teams = [blue, red]
	_build_places()
	for point: Vector2 in arena.point_places:
		point_owner.append(-1)
		point_progress.append(0.0)
	for side: int in [BLUE, RED]:
		var ids: Array[int] = []
		for place_in_team: int in range(BOTS_A_SIDE):
			ids.append(_add_bot(side, place_in_team))
		teams[side].form_squads(ids, PER_SQUAD)


## Whether the match is over: a score at the limit, or the time.
func over() -> bool:
	return score[BLUE] >= rules.score_limit or score[RED] >= rules.score_limit or time >= rules.time_limit


## One step of `rules.step` seconds.
func step() -> void:
	if time >= _next_decision:
		_decide()
		_next_decision += rules.decision_interval
	for bot: MatchBot in bots:
		MatchActions.act(self, bot, rules.step)
	_keep_bodies_apart()
	for bot: MatchBot in bots:
		if bot.alive() and bot.health <= 0:
			killed(bot, bot.last_hit_by)
	_capture(rules.step)
	_count(rules.step)
	time += rules.step


# Look, let each team think, and let each bot run its list.
func _decide() -> void:
	_look()
	for team: MatchTeam in teams:
		TeamTactics.think(self, team, time)
	var places: Dictionary = _positions()
	for bot: MatchBot in bots:
		var team: MatchTeam = teams[bot.team]
		var retreating: bool = TeamTactics.moving_in_retreat(self, team, bot)
		var row: Array[int] = sight.get(bot.id, [] as Array[int])
		bot.decide(time, row, places, team.reaction, retreating)
		bot.choose_pace(row, rules.sprint_from)
	for team: MatchTeam in teams:
		_count_retreats(team)


# For each squad of two or more living that is retreating: one decision
# counted, and one more if nobody is left covering.
func _count_retreats(team: MatchTeam) -> void:
	for index: int in range(team.squads.size()):
		var living: Array = team.squads[index].filter(func(bot_id: int) -> bool: return bots[bot_id].alive())
		if team.squad_states[index] != SquadConfidence.RETREAT or living.size() < 2:
			continue
		stats[team.side].retreat_decisions += 1
		var covering: bool = living.any(func(bot_id: int) -> bool: return bots[bot_id].action != MatchBot.FALL_BACK)
		stats[team.side].retreats_uncovered += 0 if covering else 1


## Step until the match is over.
func play_out() -> void:
	while not over():
		step()


## Send `bot` towards `goal`, holding place `place` (-1: none), by A* over
## the walk grid and its heights (`ArenaWalk`). The path is only searched again when the goal moves.
func send(bot: MatchBot, goal: Vector2, place: int) -> void:
	bot.spot = place
	if goal.distance_to(bot.goal) < 0.01 and not bot.path.is_empty():
		return
	bot.goal = goal
	bot.path = _path_for(bot.team, BotArena.cell_of(bot.position), BotArena.cell_of(goal))


# A* breaks ties by a fixed order of neighbours -- north, east, south, west
# -- so a path east is not the mirror of a path west, and on a mirrored
# arena one side walked different, longer-looking routes: measured, blue
# won a mirror match 10-0 while the order held. The arena is its own mirror
# across x = 24, so red's path is searched in the mirror and mirrored back,
# and both sides walk each other's mirror image exactly.
func _path_for(side: int, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if side == BLUE:
		return _search.search(arena.walk_graph, from, to).path
	var path: Array[Vector2i] = _search.search(arena.walk_graph, _mirrored(from), _mirrored(to)).path
	var back: Array[Vector2i] = []
	for cell: Vector2i in path:
		back.append(_mirrored(cell))
	return back


func _mirrored(cell: Vector2i) -> Vector2i:
	return Vector2i(int(arena.width) - 1 - cell.x, cell.y)


## A place's floor position, by index: cover spots first, then the places
## on the points.
func place_position(place: int) -> Vector2:
	return _places[place]


## A place's id, as the view and the overlay name it.
func place_id(place: int) -> String:
	return _place_ids[place]


## Whether a place is a cover spot, not one of the places on a point.
func is_cover(place: int) -> bool:
	return place >= 0 and place < _cover_count


## Every place within `radius` of `centre`, in index order.
func places_near(centre: Vector2, radius: float) -> Array[int]:
	var near: Array[int] = []
	for index: int in range(_places.size()):
		if _places[index].distance_to(centre) <= radius:
			near.append(index)
	return near


## Whether `looker` sees `target` now: in range, ahead of it or near, and a
## clear line from its eyes to the target's body, crouched or standing --
## each above the floor it stands on.
func sees(looker: MatchBot, target: MatchBot) -> bool:
	var offset: Vector2 = target.position - looker.position
	var distance: float = offset.length()
	if distance > rules.max_range:
		return false
	if distance > NEAR and absf(wrapf(offset.angle() - looker.facing, -PI, PI)) > VIEW_HALF_ANGLE:
		return false
	var height: float = rules.crouched_height if target.crouched else rules.chest_height
	var eyes: Vector3 = arena.above(looker.position, rules.eye_height)
	return arena.clear_line(eyes, arena.above(target.position, height))


## Note a shot for the view: who, at whom, whether it hit, and where it went.
func record_shot(shooter: MatchBot, target: int, hit: bool, to: Vector3) -> void:
	recent_shots.append([time, shooter.id, target, hit, MatchActions.muzzle_of(self, shooter, to), to])
	shots_fired += 1
	if recent_shots.size() > SHOTS_KEPT:
		recent_shots.pop_front()
	if hit:
		bots[target].hurt_at = time


## A bot was killed by `killer` (-1: nobody); count it on both sides.
func killed(victim: MatchBot, killer: int) -> void:
	victim.respawn_left = rules.respawn_time
	teams[victim.team].claim(victim.id, -1)
	# A body seen falling is not a threat any more.
	teams[1 - victim.team].remembered.erase(victim.id)
	stats[victim.team].deaths += 1
	teams[victim.team].losses[teams[victim.team].squad_of(victim.id)].append(time)
	if killer != -1:
		var shooter_team: MatchTeam = teams[bots[killer].team]
		shooter_team.kills[shooter_team.squad_of(killer)].append(time)
		stats[bots[killer].team].kills += 1


## Put `replacement` in the place of bot `bot_id` -- same id, side and
## spawn -- before the match starts. How a test plants a bot of its own.
func replace_bot(bot_id: int, replacement: MatchBot) -> void:
	var original: MatchBot = bots[bot_id]
	replacement.id = original.id
	replacement.team = original.team
	replacement.place_in_team = original.place_in_team
	bots[bot_id] = replacement
	respawn(replacement)


## Put a bot back at its spawn, whole.
func respawn(bot: MatchBot) -> void:
	var spawns: Array = arena.spawns[TEAM_NAMES[bot.team]]
	bot.position = spawns[bot.place_in_team % spawns.size()]
	bot.facing = 0.0 if bot.team == BLUE else PI
	bot.health = rules.health
	bot.ammo = rules.magazine
	bot.reload_below = rules.reload_below
	bot.reload_left = 0.0
	bot.respawn_left = 0.0
	bot.spot = -1
	bot.path.clear()
	bot.goal = bot.position
	bot.chose_at = -INF
	bot.seen_since.clear()
	bot.last_hit_by = -1


func _add_bot(side: int, place_in_team: int) -> int:
	var bot := MatchBot.new()
	bot.id = bots.size()
	bot.team = side
	bot.place_in_team = place_in_team
	bots.append(bot)
	respawn(bot)
	return bot.id


func _build_places() -> void:
	for spot: BotArena.Spot in arena.spots:
		_places.append(spot.position)
		_place_ids.append(spot.id)
	_cover_count = _places.size()
	for index: int in range(arena.point_ids.size()):
		for corner: int in range(4):
			_add_point_place(index, corner)


# One of the four places around a point, if a bot can stand there.
func _add_point_place(index: int, corner: int) -> void:
	var place: Vector2 = arena.point_places[index] + Vector2.RIGHT.rotated(corner * PI / 2.0) * ON_POINT
	if arena.can_stand(place, rules.body_radius):
		_places.append(place)
		_place_ids.append("%s%d" % [arena.point_ids[index], corner])


# The sight table, and what each team remembers from it.
func _look() -> void:
	sight.clear()
	for looker: MatchBot in bots:
		var row: Array[int] = _row_of(looker)
		for target: int in row:
			teams[looker.team].remember(target, bots[target].position, time)
		sight[looker.id] = row
		looker.see(time, row)


# The enemies `looker` sees now; nobody, when it is dead.
func _row_of(looker: MatchBot) -> Array[int]:
	var row: Array[int] = []
	if not looker.alive():
		return row
	for target: MatchBot in bots:
		if target.team != looker.team and target.alive() and sees(looker, target):
			row.append(target.id)
	return row


func _positions() -> Dictionary:
	var places: Dictionary = {}
	for bot: MatchBot in bots:
		places[bot.id] = bot.position
	return places


# Each point: the side alone on it moves its progress, a full bar owns it,
# and crossing the middle leaves it nobody's.
func _capture(delta: float) -> void:
	for index: int in range(point_owner.size()):
		var present: PackedInt32Array = _present(arena.point_places[index])
		if (present[BLUE] > 0) == (present[RED] > 0):
			continue
		var towards: float = 1.0 if present[BLUE] > 0 else -1.0
		point_progress[index] = clampf(point_progress[index] + towards * delta / rules.capture_time, -1.0, 1.0)
		_change_owner(index)


func _change_owner(index: int) -> void:
	var now: float = point_progress[index]
	var owner: int = point_owner[index]
	var neutralised: bool = (owner == BLUE and now <= 0.0) or (owner == RED and now >= 0.0)
	if neutralised:
		stats[owner].points_lost += 1
		point_owner[index] = -1
	if absf(now) >= 1.0:
		point_owner[index] = BLUE if now > 0.0 else RED


# How many distinct points the living bots of `side` are ordered to.
func _points_ordered(side: int) -> int:
	var ordered: Dictionary = {}
	for bot: MatchBot in bots:
		if bot.team == side and bot.alive() and teams[side].bot_points.has(bot.id):
			ordered[teams[side].bot_points[bot.id]] = true
	return ordered.size()


# How many points have a living bot of `side` within the area radius.
func _points_covered(side: int) -> int:
	var covered: int = 0
	for place: Vector2 in arena.point_places:
		var near: bool = bots.any(func(bot: MatchBot) -> bool:
			return bot.team == side and bot.alive() and bot.position.distance_to(place) <= rules.area_radius)
		covered += 1 if near else 0
	return covered


# Two bodies closer than two radii are pushed apart, half each, where each
# can stand. Without it every bot of a team could share the one best spot,
# and bunching would cost nothing -- the reason claims exist would be gone.
func _keep_bodies_apart() -> void:
	var touching: float = rules.body_radius * 2.0
	for first: int in range(bots.size()):
		for second: int in range(first + 1, bots.size()):
			_push_apart(bots[first], bots[second], touching)


func _push_apart(one: MatchBot, other: MatchBot, touching: float) -> void:
	if not one.alive() or not other.alive():
		return
	var offset: Vector2 = other.position - one.position
	var distance: float = offset.length()
	if distance >= touching:
		return
	# Exactly on top of each other: apart along the lower id's facing.
	var away: Vector2 = offset / distance if distance > 1e-6 else Vector2.RIGHT.rotated(one.facing)
	var shove: Vector2 = away * (touching - distance) / 2.0
	if arena.can_step(other.position, other.position + shove, rules.body_radius):
		other.position += shove
	if arena.can_step(one.position, one.position - shove, rules.body_radius):
		one.position -= shove


func _present(place: Vector2) -> PackedInt32Array:
	var present := PackedInt32Array([0, 0])
	for bot: MatchBot in bots:
		if bot.alive() and bot.position.distance_to(place) <= rules.capture_radius:
			present[bot.team] += 1
	return present


func _count(delta: float) -> void:
	for owner: int in point_owner:
		if owner != -1:
			score[owner] += delta
			stats[owner].point_seconds += delta
	for side: int in [BLUE, RED]:
		stats[side].bunched_seconds += delta * _bunched_pairs(side)
		stats[side].point_coverage += delta * _points_covered(side)
		stats[side].order_spread += delta * _points_ordered(side)
	for bot: MatchBot in bots:
		stats[bot.team].sprint_seconds += delta if bot.alive() and bot.sprinting else 0.0


# Pairs of one team's bots in cover within BUNCHED metres of each other: each
# holding a cover spot and standing within BUNCHED of it. Not "arrived": two
# bodies cannot both stand on one spot, so the second is pushed off it.
func _bunched_pairs(side: int) -> int:
	var holding: Array[Vector2] = []
	for bot: MatchBot in bots:
		var in_cover: bool = is_cover(bot.spot) and bot.position.distance_to(_places[bot.spot]) <= BUNCHED
		if bot.team == side and bot.alive() and in_cover:
			holding.append(bot.position)
	var pairs: int = 0
	for first: int in range(holding.size()):
		for second: int in range(first + 1, holding.size()):
			pairs += 1 if holding[first].distance_to(holding[second]) <= BUNCHED else 0
	return pairs
