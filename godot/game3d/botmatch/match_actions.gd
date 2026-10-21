## How a bot carries out what it chose, within the rules: a
## limited speed and turn rate, a sprint that forbids a shot, a fire
## interval, a magazine, a reload, and a shot that lands by the team's aim
## error. The same body for every bot.
##
## A bot's shot is hitscan, aimed by `MatchAim`: at the zone of the target
## worth the most damage, given the spread its aim error makes at that
## distance and what of each zone it can see. It lands by those chances on
## the zone aimed at, or a neighbour, or nothing. So a nearer target, or a
## steadier hand, is hit more often; and a target behind low cover shows no
## legs -- partial cover is the Killzone weight's reason, and here it is
## the rule that makes it worth 40.
##
## A bot walks its path cell by cell, and a body in the way is stepped
## round by `_best_step` or, blocked, weighed by `PassageChoice`. Not by
## `ai_steering`, asked for T67 and measured against this map: its avoid
## swerves from round obstacles only -- "not walls, corridors", its own
## header says, and the passages here are doors and corridors between
## boxes; and head-on it turns to the vehicle's left, a fixed side: north
## for a bot going east, south for one going west, which is the very fault
## that bent the yards' mirror 9 to 1 in T66. Its arrive slows a vehicle
## into its target, and a bot here already stops on its goal at its walking
## pace, with no overshoot to damp. Its vehicles have inertia, and a bot's
## turn rate is a knob of the honest bot, not a force.
class_name MatchActions
extends RefCounted

## How many path cells ahead a bot looks for one it can walk to straight.
const LOOK_AHEAD: int = 6
## A bot shooting walks at this share of its speed.
const SHOOTING_PACE: float = 0.5
## How far beside its target a bot's missed shot is drawn.
const MISS_DRAWN: float = 0.7


## Carry out `bot.action` for `delta` seconds.
static func act(world: BotMatch, bot: MatchBot, delta: float) -> void:
	bot.fire_cooldown = maxf(0.0, bot.fire_cooldown - delta)
	if bot.respawn_left > 0.0:
		bot.respawn_left -= delta
		if bot.respawn_left <= 0.0:
			world.respawn(bot)
		return
	# A reload the bot chose not to carry on is lost, as a magazine pulled
	# half way: its weighing found something better to do.
	if bot.reload_left > 0.0 and bot.action != MatchBot.RELOAD and bot.action != MatchBot.PLAYED:
		bot.reload_left = 0.0
	match bot.action:
		MatchBot.RELOAD:
			_reload(world, bot, delta)
		MatchBot.SHOOT:
			_shoot(world, bot, delta)
		MatchBot.MOVE, MatchBot.FALL_BACK:
			_walk(world, bot, delta)
		MatchBot.LOOK:
			_look(world, bot, delta)
		MatchBot.PLAYED:
			_played(world, bot, delta)


# Turn towards the shot it heard, where it stands.
static func _look(world: BotMatch, bot: MatchBot, delta: float) -> void:
	if bot.look_at != Vector2.INF:
		bot.turn_to(bot.look_at, world.teams[bot.team].turn_rate, delta)


## Fire one shot from `shooter` at `target`, by the rules: counted, checked
## against the line as it is at this moment -- not the sight table, which
## is up to a decision old -- and landing where its aim and spread put it.
static func fire(world: BotMatch, shooter: MatchBot, target: MatchBot) -> void:
	var stats: MatchStats = world.stats[shooter.team]
	stats.shots += 1
	stats.shots_sprinting += 1 if shooter.sprinting else 0
	if not world.sees(shooter, target):
		stats.shots_unseen += 1
	shooter.ammo -= 1
	shooter.fire_cooldown = world.rules.fire_interval
	var aimed: Array = MatchAim.aim(world, shooter, target)
	var zones: Array[AimChoice.Zone] = aimed[0]
	var choice: AimChoice.Choice = aimed[1]
	shooter.aim_zone = MatchAim.DAMAGE_ZONE[zones[aimed[2]].name]
	shooter.last_aim = [target.id, MatchAim.ZONES, choice.own_chances, choice.expected, aimed[2]]
	var landed: int = AimChoice.land(choice.chances, world.random.randf())
	var hit: bool = landed != -1
	var zone: String = MatchAim.DAMAGE_ZONE[zones[landed].name] if hit else MatchRules.NONE
	world.record_shot(shooter, target.id, hit, _bot_shot_end(world, shooter, target, zone), zone)
	if hit and target.alive():
		land(world, shooter, target, zone)


## A hit on `target` in `zone`: its damage, counted for the shooter's team.
static func land(world: BotMatch, shooter: MatchBot, target: MatchBot, zone: String) -> void:
	var stats: MatchStats = world.stats[shooter.team]
	var damage: int = world.rules.damage_in(zone)
	if shooter.weapon == MatchSupply.POWER:
		damage = roundi(damage * world.rules.power_damage_multiplier)
	stats.hits += 1
	stats.damage += damage
	stats.zone_hits[zone] = int(stats.zone_hits.get(zone, 0)) + 1
	target.health -= damage
	target.last_hit_by = shooter.id


# Where a bot's shot is drawn ending: the middle of the zone it struck; when
# it missed, past the zone it aimed at to one side, alternating with each
# shot -- drawn only, so it uses no random number and changes no match.
static func _bot_shot_end(world: BotMatch, shooter: MatchBot, target: MatchBot, struck: String) -> Vector3:
	var zone: String = struck if struck != MatchRules.NONE else shooter.aim_zone
	var chest: Vector3 = world.arena.above(target.position, zone_middle(world.rules, zone, target.crouched))
	if struck != MatchRules.NONE:
		return chest
	var across: Vector2 = (target.position - shooter.position).normalized().orthogonal()
	var side: float = MISS_DRAWN * (1.0 if world.stats[shooter.team].shots % 2 == 0 else -1.0)
	return chest + Vector3(across.x * side, 0.3, across.y * side)


## How high above the feet the middle of `zone` is, crouched or not.
static func zone_middle(rules: MatchRules, zone: String, crouched: bool) -> float:
	var shrink: float = rules.crouched_body_height / rules.body_height if crouched else 1.0
	var middles: Dictionary = {
		MatchRules.HEAD: (rules.head_from + rules.body_height) / 2.0,
		MatchRules.TORSO: (rules.torso_from + rules.head_from) / 2.0,
		MatchRules.LIMB: rules.torso_from / 2.0,
	}
	return float(middles.get(zone, rules.chest_height)) * shrink


## The person's shot, as in a first-person shooter: a ray from their eyes
## along where they look, yaw and pitch. It strikes the first enemy whose
## body it passes through -- in one of its zones where the ray comes
## nearest, standing or crouched -- unless a box, or the ground, comes
## first. A platform is a box. The zone is the damage: head, torso, limb. The person's own aim is the aim error.
static func fire_aimed(world: BotMatch, shooter: MatchBot) -> void:
	shooter.ammo -= 1
	shooter.fire_cooldown = world.rules.fire_interval
	world.stats[shooter.team].shots += 1
	world.stats[shooter.team].shots_sprinting += 1 if shooter.sprinting else 0
	var eyes: Vector3 = eyes_of(world, shooter)
	var look: Vector3 = look_of(shooter)
	var far: Vector3 = eyes + look * world.rules.max_range
	var reach: float = world.arena.first_block(eyes, far) * world.rules.max_range
	# Aimed down, the ground stops it too.
	if look.y < 0.0:
		reach = minf(reach, eyes.y / -look.y)
	var struck: MatchBot = null
	var zone: String = MatchRules.NONE
	for other: MatchBot in world.bots:
		var crossing: Array = _crossing(world, eyes, look, other)
		if other.team != shooter.team and other.alive() and float(crossing[0]) < reach:
			reach = crossing[0]
			zone = crossing[1]
			struck = other
	world.record_shot(shooter, struck.id if struck != null else -1, struck != null, eyes + look * reach, zone)
	if struck != null:
		land(world, shooter, struck, zone)


## Where a bot's eyes are: above the floor it stands on, lower when it
## crouches.
static func eyes_of(world: BotMatch, bot: MatchBot) -> Vector3:
	var height: float = world.rules.eye_height - (world.rules.body_height - world.rules.crouched_body_height) * float(bot.crouched)
	return world.arena.above(bot.position, height)


## Where a shot towards `to` leaves the gun: in front of the eyes, a little
## right and below, as a rifle held at the shoulder. Drawn only; the shot
## itself is the eyes' ray.
static func muzzle_of(world: BotMatch, bot: MatchBot, to: Vector3) -> Vector3:
	var eyes: Vector3 = eyes_of(world, bot)
	var ahead: Vector3 = (to - eyes).normalized()
	var right: Vector3 = ahead.cross(Vector3.UP).normalized() if absf(ahead.y) < 0.99 else Vector3.RIGHT
	# The end of the viewmodel's barrel (`Viewmodel.REST` and its barrel).
	return eyes + ahead * 0.9 + right * 0.22 - Vector3.UP * 0.185


## The unit direction a bot looks along, from its facing and pitch.
static func look_of(bot: MatchBot) -> Vector3:
	return Vector3(cos(bot.pitch) * cos(bot.facing), sin(bot.pitch), cos(bot.pitch) * sin(bot.facing))


# Where the look passes `other`'s body: [how far along the ray, the zone],
# or [INF, NONE]. Taken where the ray comes nearest the body's middle, from
# above: how far across it passes then, and how high above its feet.
static func _crossing(world: BotMatch, eyes: Vector3, look: Vector3, other: MatchBot) -> Array:
	var missed: Array = [INF, MatchRules.NONE]
	var flat := Vector2(look.x, look.z)
	if flat.length() < 1e-6:
		return missed
	var offset: Vector2 = other.position - Vector2(eyes.x, eyes.z)
	var along_flat: float = offset.dot(flat.normalized())
	if along_flat <= 0.0:
		return missed
	var along: float = along_flat / flat.length()
	var height: float = eyes.y + look.y * along - world.arena.floor_at(other.position)
	var zone: String = world.rules.zone_at(height, offset.cross(flat.normalized()), other.crouched)
	return missed if zone == MatchRules.NONE else [along, zone]


## How fast a bot walks now: its sprint, its walk, or half that crouched.
static func speed_of(world: BotMatch, bot: MatchBot) -> float:
	if bot.sprinting:
		return world.rules.sprint_speed
	return world.rules.speed * (0.5 if bot.crouched else 1.0)


# The person's bot: walk where they push, blocked by the boxes and by any
# rise higher than a step, as a bot is -- reloading too; slower crouched,
# faster sprinting, and fire while the trigger is held and they are not
# sprinting.
static func _played(world: BotMatch, bot: MatchBot, delta: float) -> void:
	# Every step, not every decision: a key answers at once.
	bot.choose_pace([] as Array[int], world.rules.sprint_from)
	var stride: Vector2 = bot.wants_to_walk.limit_length(1.0) * speed_of(world, bot) * delta
	for step: Vector2 in [stride, Vector2(stride.x, 0.0), Vector2(0.0, stride.y)]:
		var next: Vector2 = bot.position + step
		if world.arena.can_step(bot.position, next, world.rules.body_radius) and clear_of_bodies(world, bot, next):
			bot.position = next
			break
	# A reload is the person's to start, with R (the owner's ask): an empty
	# magazine clicks, it does not reload by itself.
	if bot.reload_left > 0.0:
		_reload(world, bot, delta)
	elif bot.wants_to_fire and bot.ammo > 0 and bot.fire_cooldown <= 0.0 and not bot.sprinting:
		fire_aimed(world, bot)


# A reload takes from the reserve what the magazine lacks, and no more than
# there is; with nothing in reserve, or a full magazine, there is nothing to
# reload. That last is not tidiness: a bot's action stays RELOAD until its
# next decision, and a reload that had just finished began again in that
# gap, so every reload took two.
static func _reload(world: BotMatch, bot: MatchBot, delta: float) -> void:
	var nothing_to_do: bool = bot.reserve <= 0 or bot.ammo >= world.rules.magazine
	if bot.reload_left <= 0.0 and nothing_to_do:
		bot.reload_left = 0.0
		return
	if bot.reload_left <= 0.0:
		bot.reload_left = world.rules.reload_time
	bot.reload_left -= delta
	if bot.reload_left <= 0.0:
		bot.reload_left = 0.0
		var taken: int = mini(world.rules.magazine - bot.ammo, bot.reserve)
		bot.ammo += taken
		bot.reserve -= taken


# A bot shooting still closes on its goal, at half speed, facing its target:
# bots that stop to fire at every enemy never reach a point.
static func _shoot(world: BotMatch, bot: MatchBot, delta: float) -> void:
	var target: MatchBot = world.bots[bot.target]
	if not bot.arrived():
		_step_towards(world, bot, delta * SHOOTING_PACE)
	var facing: bool = bot.turn_to(target.position, world.teams[bot.team].turn_rate, delta)
	# The table said it could see the target when it decided; a target that
	# has stepped behind a box since is not shot through it.
	var still_seen: bool = world.sees(bot, target) or not bot.checks_its_line
	var ready: bool = bot.fire_cooldown <= 0.0 and bot.ammo > 0 and not bot.sprinting
	if facing and still_seen and ready and target.alive():
		fire(world, bot, target)


# Along the path: towards the farthest of the next few cells it can walk to
# straight, then the goal itself, facing the way it goes.
static func _walk(world: BotMatch, bot: MatchBot, delta: float) -> void:
	var towards: Vector2 = _step_towards(world, bot, delta)
	if towards.distance_to(bot.position) > 0.01:
		bot.turn_to(towards, world.teams[bot.team].turn_rate, delta)


# Of the step a bot wants and the same step turned 45 and 90 degrees either
# way, the free one that leaves it nearest `towards`, and of equals the one
# furthest from any body, and of exact equals -- a body square on the line
# of the step -- the one further south, which the mirror across x keeps;
# INF when none is free. Chosen by where each step leaves it, not by an
# order of turns: a fixed "left first" turned blue south and red north round
# the same body, and blue won the yards' mirror 9 to 1. On an open floor
# the straight step is nearest, so nothing changes.
static func _best_step(world: BotMatch, bot: MatchBot, step: Vector2, towards: Vector2) -> Vector2:
	var best: Vector2 = Vector2.INF
	var best_score := Vector3(INF, INF, INF)
	for tried: Vector2 in _around(step):
		var at: Vector2 = bot.position + tried
		if not world.arena.walkable(bot.position, at) or not clear_of_bodies(world, bot, at):
			continue
		var score: Vector3 = _step_score(world, bot, at, towards, tried)
		if score < best_score:
			best_score = score
			best = tried
	return best


# What a step is ranked by, least first: how far it leaves the bot from
# `towards`, how near a body, and how far north.
static func _step_score(world: BotMatch, bot: MatchBot, at: Vector2, towards: Vector2, tried: Vector2) -> Vector3:
	return Vector3(snappedf(at.distance_to(towards), 1e-6), snappedf(-_clearance(world, bot, at), 1e-6), -snappedf(tried.y, 1e-6))


# How far `at` is from the nearest living body but `bot`'s own.
static func _clearance(world: BotMatch, bot: MatchBot, at: Vector2) -> float:
	var nearest: float = INF
	for other: MatchBot in world.bots:
		if other != bot and other.alive():
			nearest = minf(nearest, at.distance_to(other.position))
	return nearest


# The step a bot wants, and the same step turned 45 and 90 degrees either
# way: a body in the way is walked round, not waited behind.
static func _around(step: Vector2) -> Array[Vector2]:
	var tried: Array[Vector2] = [step]
	for turn: float in [PI / 4.0, -PI / 4.0, PI / 2.0, -PI / 2.0]:
		tried.append(step.rotated(turn))
	return tried


## Whether `bot` may step to `next` for the other bodies: nobody living,
## friend or enemy, ends up nearer than two radii -- unless it was already
## that near and the step takes it further off, so two bodies that start
## inside each other (a respawn on a spot someone stands on) can part.
## Nobody walks through anybody (the owner's ask).
static func clear_of_bodies(world: BotMatch, bot: MatchBot, next: Vector2) -> bool:
	var touching: float = world.rules.body_radius * 2.0
	for other: MatchBot in world.bots:
		if other == bot or not other.alive():
			continue
		var after: float = next.distance_to(other.position)
		if after < touching and after < bot.position.distance_to(other.position) - 1e-6:
			return false
	return true


# Move `delta` seconds' worth along the path, sliding along a body in the
# way; blocked, it decides how to get past; the waypoint it moved towards.
static func _step_towards(world: BotMatch, bot: MatchBot, delta: float) -> Vector2:
	var towards: Vector2 = _next_waypoint(world, bot)
	var offset: Vector2 = towards - bot.position
	var stride: float = speed_of(world, bot) * delta
	var step: Vector2 = offset if offset.length() <= stride else offset.normalized() * stride
	var chosen: Vector2 = _best_step(world, bot, step, towards)
	var moved: bool = chosen != Vector2.INF
	if moved:
		bot.position += chosen
	# Blocked for its patience, it weighs the ways past (`MatchPassage`), and
	# is patient again after; moving, it never was.
	bot.blocked_for = 0.0 if moved else bot.blocked_for + delta
	if bot.blocked_for >= world.rules.passage_patience:
		bot.blocked_for = 0.0
		MatchPassage.decide(world, bot, step)
	# Everything up to the cell it stands in is behind it, wherever in the path
	# that cell is: a bot cutting a corner skips cells, and one that only
	# dropped the first never moved past it, looking at the same few ahead.
	var here: int = bot.path.find(BotArena.cell_of(bot.position))
	if here != -1:
		bot.path = bot.path.slice(here + 1)
	return towards


static func _next_waypoint(world: BotMatch, bot: MatchBot) -> Vector2:
	if bot.path.size() <= 1 or world.arena.walkable(bot.position, bot.goal):
		return bot.goal
	var best: Vector2 = BotArena.centre_of(bot.path[0])
	for index: int in range(1, mini(LOOK_AHEAD, bot.path.size())):
		var centre: Vector2 = BotArena.centre_of(bot.path[index])
		if not world.arena.walkable(bot.position, centre):
			break
		best = centre
	return best
