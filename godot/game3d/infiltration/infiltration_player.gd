## The person sneaking in: where they are, how they hold their body, how
## fast they move and what noise that makes.
##
## Walking and sprinting are the bot match's (T66); crouching and lying
## prone are rows of `rules.json`, each with its speed, its noise -- a T69
## event, heard along the level like any other -- and the heights of the
## three body points a guard's eye may see. Sprinting is only upright. The
## same body is driven by a person in the demo and by a script in the
## properties: both hand it a `PlayerIntent` a step.
##
## When not to use it: as a guard. Guards are agents that decide; this only
## does what it is told.
class_name InfiltrationPlayer
extends RefCounted

var position: Vector2 = Vector2.ZERO
## Radians, 0 along +x, turning towards +z.
var facing: float = 0.0
var stance: String = "standing"
var sprinting: bool = false
var health: float = 100.0
## How far it moved in the last step, in metres.
var moved: float = 0.0
## When it may next make a noise for its steps.
var noise_ready_at: float = 0.0


func _init(start: Vector2, rules: InfiltrationRules) -> void:
	position = start
	health = float(rules.player["health"])


## True while it can still move.
func alive() -> bool:
	return health > 0.0


## Move by `intent` for `seconds`: its stance taken, then a step at that
## stance's speed -- or the sprint's, upright -- along the floor; a step
## into a wall slides along it, as a body would.
func move(intent: PlayerIntent, level: InfiltrationLevel, rules: InfiltrationRules, seconds: float) -> void:
	stance = intent.stance if rules.stances.has(intent.stance) else stance
	sprinting = intent.sprint and stance == "standing"
	var speed: float = float(rules.player["sprint_speed"]) if sprinting else float(rules.stances[stance]["speed"])
	var wanted: Vector2 = intent.direction.limit_length(1.0) * speed * seconds
	var before: Vector2 = position
	for attempt: Vector2 in [wanted, Vector2(wanted.x, 0.0), Vector2(0.0, wanted.y)]:
		if attempt != Vector2.ZERO and level.arena.walkable(position, position + attempt):
			position += attempt
			break
	moved = position.distance_to(before)
	if moved > 0.0:
		facing = (position - before).angle()


## The noise its steps make this step, by event kind, or "" when none: its
## stance's, or the sprint's, at most once each `noise_every` seconds.
func step_noise(rules: InfiltrationRules, now: float) -> String:
	if moved <= 0.0 or now < noise_ready_at:
		return ""
	noise_ready_at = now + float(rules.player["noise_every"])
	return str(rules.player["sprint_noise"]) if sprinting else str(rules.stances[stance]["noise"])


## How fast it is moving, from 0 still to 1 at a walk or faster: what a
## guard's eye reads as motion.
func motion(rules: InfiltrationRules, seconds: float) -> float:
	return clampf(moved / (float(rules.stances["standing"]["speed"]) * seconds), 0.0, 1.0)
