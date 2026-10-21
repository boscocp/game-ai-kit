## A bot's shot in the bot match, aimed by `AimChoice`: the target's body
## as the technique's zones, what the shooter can see of each, and where
## the shot lands.
##
## The zones are the rules' (`MatchRules.zone_at`), laid out as the shooter
## faces the target: head, torso, arms and legs, the last two worth a limb's
## damage each. A zone is exposed when the line from the shooter's eyes to
## the point a shot at it is aimed is clear -- so low cover hides the legs,
## and a crouch behind it the torso too, which is what partial cover is
## worth here. The spread is the distance times the tangent of the team's
## aim error.
class_name MatchAim
extends RefCounted

## The zones, in the order `AimChoice` weighs them, and the damage each is.
const ZONES: Array[String] = ["head", "torso", "arms", "legs"]
const DAMAGE_ZONE: Dictionary = {
	"head": MatchRules.HEAD, "torso": MatchRules.TORSO, "arms": MatchRules.LIMB, "legs": MatchRules.LIMB,
}
## How far out from the middle a shot at an arm is aimed: between the
## torso's edge and the body's.
const ARM_AIM_SHARE: float = 0.5


## What `shooter` decides to aim at on `target`, and the chances it is
## weighing: the zones, the choice, and the zone aimed at. A team that does
## not aim by worth -- the planted always-head bot -- aims at the head.
static func aim(world: BotMatch, shooter: MatchBot, target: MatchBot) -> Array:
	var zones: Array[AimChoice.Zone] = zones_of(world, shooter, target)
	var eyes: Vector3 = MatchActions.eyes_of(world, shooter)
	var distance: float = eyes.distance_to(world.arena.above(target.position, world.rules.chest_height))
	var spread: float = distance * tan(maxf(world.teams[shooter.team].aim_error, 1e-4))
	var choice: AimChoice.Choice = AimChoice.choose(zones, spread)
	var aimed: int = choice.aimed if choice.aimed != -1 else 1
	if not world.teams[shooter.team].aims_by_worth:
		aimed = 0
	choice.chances = AimChoice.chances_from(zones[aimed].aim, spread, zones)
	return [zones, choice, aimed]


## The target's four zones as `shooter` sees them: across and up from its
## feet, each with its exposure from the shooter's eyes.
static func zones_of(world: BotMatch, shooter: MatchBot, target: MatchBot) -> Array[AimChoice.Zone]:
	var eyes: Vector3 = MatchActions.eyes_of(world, shooter)
	var zones: Array[AimChoice.Zone] = _body(world.rules, target.crouched)
	for zone: AimChoice.Zone in zones:
		var seen: bool = world.arena.clear_line(eyes, point_of(world, shooter, target, zone.aim))
		zone.exposure = 1.0 if seen else 0.0
	return zones


# The rules' zones laid out as rectangles, for a body crouched or not: the
# head over the torso, an arm either side of it, the legs below.
static func _body(rules: MatchRules, crouched: bool) -> Array[AimChoice.Zone]:
	var shrink: float = rules.crouched_body_height / rules.body_height if crouched else 1.0
	var head_from: float = rules.head_from * shrink
	var torso_from: float = rules.torso_from * shrink
	var top: float = rules.body_height * shrink
	var chest: float = (torso_from + head_from) / 2.0
	var arm_width: float = rules.body_half_width - rules.torso_half_width
	var torso_height: float = head_from - torso_from
	var head := Rect2(-rules.head_half_width, head_from, rules.head_half_width * 2.0, top - head_from)
	var torso := Rect2(-rules.torso_half_width, torso_from, rules.torso_half_width * 2.0, torso_height)
	var left_arm := Rect2(-rules.body_half_width, torso_from, arm_width, torso_height)
	var right_arm := Rect2(rules.torso_half_width, torso_from, arm_width, torso_height)
	var legs := Rect2(-rules.body_half_width, 0.0, rules.body_half_width * 2.0, torso_from)
	var arm_aim := Vector2(rules.torso_half_width + arm_width * ARM_AIM_SHARE, chest)
	return [
		_zone(rules, "head", Vector2(0.0, (head_from + top) / 2.0), [head]),
		_zone(rules, "torso", Vector2(0.0, chest), [torso]),
		_zone(rules, "arms", arm_aim, [left_arm, right_arm]),
		_zone(rules, "legs", Vector2(0.0, torso_from / 2.0), [legs]),
	]


static func _zone(rules: MatchRules, name: String, at: Vector2, rects: Array[Rect2]) -> AimChoice.Zone:
	var zone := AimChoice.Zone.new()
	zone.name = name
	zone.multiplier = _multiplier(rules, DAMAGE_ZONE[name])
	zone.aim = at
	zone.rects = rects
	return zone


## The point in the world `at` names on `target`, across and up from its
## feet, as `shooter` faces it.
static func point_of(world: BotMatch, shooter: MatchBot, target: MatchBot, at: Vector2) -> Vector3:
	var across: Vector2 = (target.position - shooter.position).normalized().orthogonal()
	var feet: Vector3 = world.arena.above(target.position, 0.0)
	return feet + Vector3(across.x * at.x, at.y, across.y * at.x)


static func _multiplier(rules: MatchRules, zone: String) -> float:
	return {MatchRules.HEAD: rules.head_multiplier, MatchRules.TORSO: rules.torso_multiplier}.get(zone, rules.limb_multiplier)
