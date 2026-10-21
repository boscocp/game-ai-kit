## A bot's senses in the bot match, through `ai_perception`: its eyes are a
## `VisionCone` in the open, the line asked of the arena's boxes, and its
## ears are `Hearing`, every enemy shot a noise. What they give, with its
## body and its orders, is the one record a decision reads (`MatchPercepts`).
##
## The cone is the match's: 40 m ahead within 60 degrees either side, and
## all round within 3 m. The line runs from its eyes to the target's body,
## crouched or standing, each above the floor it stands on -- exact against
## the boxes, which the addon's grid line of sight is not: that one is all
## or nothing cell by cell, and knows no height. A shot is heard by the
## enemy within `shot_heard_metres`, louder nearer, through walls, as
## `Hearing` says sound goes; cell by cell, and a cell is a metre here.
class_name MatchSenses
extends RefCounted

## A bot sees ahead within this half-angle, and all round within NEAR.
const VIEW_HALF_ANGLE_DEGREES: float = 60.0
const NEAR: float = 3.0


## The eyes every bot of the match has, by the rules' range.
static func cone_of(rules: MatchRules) -> VisionCone:
	var cone := VisionCone.new(rules.max_range, VIEW_HALF_ANGLE_DEGREES)
	cone.all_round_within = NEAR
	return cone


## Whether `looker` sees `target` now, through `cone`.
static func sees(world: BotMatch, cone: VisionCone, looker: MatchBot, target: MatchBot) -> bool:
	var height: float = world.rules.crouched_height if target.crouched else world.rules.chest_height
	var eyes: Vector3 = world.arena.above(looker.position, world.rules.eye_height)
	var body: Vector3 = world.arena.above(target.position, height)
	var line: Callable = func() -> bool: return world.arena.clear_line(eyes, body)
	return cone.sees_in_the_open(looker.position, looker.facing, target.position, line)


## Everything `bot` perceives at this decision: its row of the sight table,
## the loudest enemy shot it heard, its body and its orders.
static func perceive(world: BotMatch, bot: MatchBot, moving_in_retreat: bool) -> MatchPercepts:
	var capacity: int = world.rules.power_rounds if bot.weapon == MatchSupply.POWER else world.rules.magazine
	var percepts: MatchPercepts = MatchPercepts.of_body(bot, world.time, capacity, moving_in_retreat)
	if not bot.alive():
		return percepts
	percepts.in_sight = world.sight.get(bot.id, [] as Array[int])
	for enemy: int in percepts.in_sight:
		percepts.enemy_places[enemy] = world.bots[enemy].position
		percepts.shot_worth[enemy] = shot_worth(world, bot, world.bots[enemy])
	_hear(world, bot, percepts)
	return percepts


## What a shot by `shooter` at `target` is worth now, 0 to 1: the damage
## its aim expects, over the most a shot can do -- the zone worth most, hit
## for sure.
static func shot_worth(world: BotMatch, shooter: MatchBot, target: MatchBot) -> float:
	var aimed: Array = MatchAim.aim(world, shooter, target)
	var most: float = 0.0
	for zone: AimChoice.Zone in aimed[0]:
		most = maxf(most, zone.multiplier)
	var choice: AimChoice.Choice = aimed[1]
	return choice.expected[aimed[2]] / most if most > 0.0 else 0.0


# The loudest of the enemy shots fired since the last decision, by
# `Hearing`; a shot by its own side is no news.
static func _hear(world: BotMatch, bot: MatchBot, percepts: MatchPercepts) -> void:
	var here: Vector2i = BotArena.cell_of(bot.position)
	for noise: Array in world.noises:
		if int(noise[0]) == bot.team:
			continue
		var loudness: float = Hearing.loudness_at(here, BotArena.cell_of(noise[1]), world.rules.shot_heard_metres)
		if loudness > percepts.heard:
			percepts.heard = loudness
			percepts.heard_from = noise[1]
