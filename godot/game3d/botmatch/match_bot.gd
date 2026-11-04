## One bot of the match: its body, what it knows, and how it decides --
## AIMA's agent, percepts in and an action out [Russell and Norvig, ch. 2].
##
## Each decision it reads one record, `MatchPercepts` -- what its cone and
## its ears gave it, its body and its orders -- turns it into a handful of
## numbers (`numbers_of`), and weighs every action it has at once by
## `ActionChoice`: reload, fall back, shoot, move, look towards a shot it
## heard, hold. Each action's weight and considerations are data
## (`actions.json`), not an order of `if`s: a nearer enemy, an emptier
## magazine, a louder shot each move the choice by degrees, and the view
## shows every score. Whom it would shoot is the enemy in sight, reacted to,
## that a shot is worth the most damage at (`AimChoice`, through the
## percepts).
##
## Then, from the same numbers and what it chose, it weighs how to hold its
## body -- stand, or crouch (`postures` in `actions.json`): crouching halves
## its speed and, behind low cover, hides its shot as well as itself, and is
## worth more the more danger it perceives and while it reloads.
##
## Its pace is weighed the same way (`paces`): sprinting is worth more the
## further it has to go, and less the more danger it perceives -- for a
## sprinting bot may not fire, so an enemy in sight vetoes it.
##
## What is not weighed is what is not a choice: a dead bot waits, and a
## person drives the one they took over (`choose_played_pace`).
##
## A bot has no sense the player would not have: it shoots only at what its
## own eyes say it sees, after a reaction, and it turns at a limited rate
## (the honest knobs). Its decision reads the record and nothing else:
## never another bot's mind, never the match.
class_name MatchBot
extends RefCounted

const DEAD: String = "dead"  # shown through tr()
const RELOAD: String = "reload"  # shown through tr()
const FALL_BACK: String = "fall back"  # shown through tr()
const SHOOT: String = "shoot"  # shown through tr()
const MOVE: String = "move"  # shown through tr()
const HOLD: String = "hold"  # shown through tr()
## Turn towards a shot it heard.
const LOOK: String = "look"  # shown through tr()
## A person is driving it.
const PLAYED: String = "played"
## Facing within this of the target, a shot may be taken.
const AIM_CONE: float = deg_to_rad(5.0)
## Within this of its goal, a bot has arrived.
const ARRIVED: float = 0.3
## What a bot can do and why it would, as `ActionChoice` reads it.
const ACTIONS: String = "res://game3d/botmatch/actions.json"

## Postures: stand or crouch.
const STAND: String = "stand"  # shown through tr()
const CROUCH: String = "crouch"  # shown through tr()
## Paces: walk or sprint.
const WALK: String = "walk"  # shown through tr()
const SPRINT: String = "sprint"  # shown through tr()
## Enemies remembered further than this are no danger to its posture.
const DANGER_METRES: float = 20.0

## Each list of `actions.json` -- actions, postures -- read once, by key.
static var _defaults: Dictionary = {}

var id: int = 0
var team: int = 0
var squad: int = 0
## Its place among its team, which picks its spawn.
var place_in_team: int = 0
var position: Vector2 = Vector2.ZERO
## Radians, 0 facing east (+x), turning towards +z.
var facing: float = 0.0
## Radians up (positive) or down from level: a person's aim. A bot's list
## aims level at the chest and leaves it at zero.
var pitch: float = 0.0
var health: int = 100
var ammo: int = 20
## Which weapon it holds (`MatchSupply.RIFLE` or `POWER`), the rounds it
## has beyond the magazine, and its kills since it last died.
var weapon: String = "rifle"  # shown through tr()
var reserve: int = 0
var streak: int = 0
## An errand its team's supply sent it on (`MatchSupply.RESUPPLY`, `FETCH`,
## or "": none), and what it weighed: name -> [gain, walk, cost, score].
var errand: String = ""
var errand_weighing: Dictionary = {}
## The actions it weighs, and its last weighing of them, for the view.
var actions: Array[ActionChoice.Action] = MatchBot.default_choices("actions")
var last_choice: ActionChoice.Choice = null
## The postures it weighs, and its last weighing of them.
var postures: Array[ActionChoice.Action] = MatchBot.default_choices("postures")
var last_posture: ActionChoice.Choice = null
## The paces it weighs, and its last weighing of them.
var paces: Array[ActionChoice.Action] = MatchBot.default_choices("paces")
var last_pace: ActionChoice.Choice = null
## Where the shot it last heard came from, which LOOK turns it to.
var look_at: Vector2 = Vector2.INF
var fire_cooldown: float = 0.0
var reload_left: float = 0.0
var respawn_left: float = 0.0
var crouched: bool = false
## The zone its shots are aimed at: its own choice (`AimChoice`), or the
## torso, where a rifle is pointed by default.
var aim_zone: String = MatchRules.TORSO
## Its last shot's aim, for the overlay: [target id, zone names, each zone's
## own chance aimed at, each zone's expected damage, the index aimed at].
var last_aim: Array = []
## How long it has wanted to move and could not, its velocity last step,
## who refused it passage and when (bot id -> time), and its last weighing
## of the ways past a body, for the view.
var blocked_for: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var refused_by: Dictionary = {}
var last_passage: Dictionary = {}
## Running at the rules' sprint speed; it may not fire while it is.
var sprinting: bool = false
## What the list chose last, and at whom it is aimed (-1: nobody).
var action: String = HOLD
var target: int = -1
## Where it is going, the cells there, and the spot it holds (-1: none).
var goal: Vector2 = Vector2.ZERO
var path: Array[Vector2i] = []
var spot: int = -1
## When each enemy now in sight was first seen, by enemy id.
var seen_since: Dictionary = {}
## When it last chose a spot.
var chose_at: float = -INF
## Who hit it last, for the kill when it falls (-1: nobody), and when.
var last_hit_by: int = -1
var hurt_at: float = -INF
## What regeneration has given back short of a whole point (`MatchHealth`).
var regeneration_carry: float = 0.0
## Where it would hide to heal, as its last weighing found: the place's
## index and position (-1 and INF: nowhere).
var hide_spot: int = -1
var hide_place: Vector2 = Vector2.INF
## When it last looked for a place to hide, and the enemies its team knew
## of then, by id.
var hide_asked_at: float = -INF
var hide_asked_for: Array = []
## Whether it looks along the line again before each shot. Always, for an
## honest bot; `botmatch_effects.gd` plants one that does not, and the
## honesty count must catch its shots at targets gone behind cover.
var checks_its_line: bool = true
## Driven by a person instead of the list (the owner's takeover). Then the
## person's intent below is what it does, in the same body by the same rules.
var controlled: bool = false
## A stand-in's own aim error, in radians, for measuring the player model
## (T100) with a bot in a person's place at a skill of its own; negative,
## the bot aims with its team's, as every bot in a match does.
var own_aim_error: float = -1.0
## Where the person wants to walk (a direction on the floor, length up to
## 1), whether the trigger is held, and whether they want to crouch.
var wants_to_walk: Vector2 = Vector2.ZERO
var wants_to_fire: bool = false
var wants_to_crouch: bool = false
var wants_to_sprint: bool = false


## Whether it is alive. A bot brought to zero health in this step still is,
## until the step ends: two bots firing in the same step both fire, whoever
## is taken first in id order.
func alive() -> bool:
	return respawn_left <= 0.0


## Whether it has reached where it was going.
func arrived() -> bool:
	return position.distance_to(goal) <= ARRIVED


## One list every bot weighs from, by its key in `actions.json`. The
## Action objects are shared by every bot, read once: nothing writes to an
## Action after it is read, and a test that wants other numbers gives a bot
## a list of its own.
static func default_choices(key: String) -> Array[ActionChoice.Action]:
	if not _defaults.has(key):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ACTIONS))
		_defaults[key] = ActionChoice.actions_from(data[key])
	var found: Array[ActionChoice.Action] = []
	found.assign(_defaults[key])
	return found


## Decide, from what it perceives (`percepts`, the one record it reads) and
## its team's `reaction`: every action weighed, the best taken. Sets
## `action` and `target`; moving and shooting are `BotMatch`'s, by the rules.
func decide(percepts: MatchPercepts, reaction: float) -> void:
	target = -1
	see(percepts.now, percepts.in_sight)
	if not percepts.alive:
		action = DEAD
		crouched = false
		sprinting = false
		return
	if controlled:
		# PLAYED while it reloads too: the person walks on as the magazine
		# goes in, and `_played` carries the reload.
		action = PLAYED
		crouched = wants_to_crouch
		return
	var best: int = _best_target(percepts, reaction)
	var worth: float = float(percepts.shot_worth.get(best, 0.0))
	var numbers: Dictionary = numbers_of(percepts, worth)
	last_choice = ActionChoice.choose(actions, numbers)
	action = actions[last_choice.chosen].name if last_choice.chosen != -1 else HOLD
	target = best if action == SHOOT else -1
	look_at = percepts.heard_from
	numbers.merge(chosen_numbers(action))
	last_posture = ActionChoice.choose(postures, numbers)
	crouched = last_posture.chosen != -1 and postures[last_posture.chosen].name == CROUCH
	last_pace = ActionChoice.choose(paces, numbers)
	sprinting = last_pace.chosen != -1 and paces[last_pace.chosen].name == SPRINT


## What the action it chose tells its posture: whether it will move,
## shoot or reload, as numbers.
static func chosen_numbers(chosen: String) -> Dictionary:
	return {
		"moving": float(chosen == MOVE or chosen == FALL_BACK),
		"shooting": float(chosen == SHOOT),
		"reloading": float(chosen == RELOAD),
	}


## The percepts as the numbers its actions' considerations read, by name
## (`actions.json` says which reads which). `shot_worth` is what a shot at
## the target it would take is worth, 0 when there is none.
func numbers_of(percepts: MatchPercepts, shot_worth: float) -> Dictionary:
	var ready: bool = percepts.rounds > 0 and not percepts.reloading
	var someone: bool = not percepts.in_sight.is_empty()
	return {
		"ready_to_fire": float(ready),
		"shot_worth": shot_worth,
		"rounds_left": float(percepts.rounds) / percepts.capacity,
		"has_reserve": float(percepts.reserve > 0),
		"could_fire": float(ready and someone),
		"enemy_in_sight": float(someone),
		"in_retreat_wave": float(percepts.moving_in_retreat),
		"to_go": percepts.to_go(),
		"heard": percepts.heard,
		"cover": percepts.cover,
		"danger": danger_of(percepts),
	}


## How much danger it perceives, 0 to 1: 1 with an enemy in sight; else the
## louder of the shot it heard and the nearest enemy its team remembers,
## by closeness within DANGER_METRES.
static func danger_of(percepts: MatchPercepts) -> float:
	if not percepts.in_sight.is_empty():
		return 1.0
	var danger: float = percepts.heard
	for place: Vector2 in percepts.remembered:
		danger = maxf(danger, 1.0 - percepts.position.distance_to(place) / DANGER_METRES)
	return clampf(danger, 0.0, 1.0)


## Whether a person's bot sprints: while they hold the key and walk, not
## crouched, not firing and not reloading. A bot's pace is its own weighing,
## in `decide`.
func choose_played_pace() -> void:
	var walking: bool = wants_to_walk.length() > 0.1
	var free_hands: bool = not wants_to_fire and reload_left <= 0.0
	sprinting = alive() and wants_to_sprint and walking and not crouched and free_hands


## Remember when each enemy came into sight, and forget those gone from it:
## a target that ducks and comes back is reacted to again.
func see(now: float, visible: Array[int]) -> void:
	var still: Dictionary = {}
	for enemy: int in visible:
		still[enemy] = seen_since.get(enemy, now)
	seen_since = still


## Turn towards `towards` by at most `turn_rate` radians a second for `delta`
## seconds; true when it now faces it within AIM_CONE.
func turn_to(towards: Vector2, turn_rate: float, delta: float) -> bool:
	var wanted: float = (towards - position).angle()
	var left: float = wrapf(wanted - facing, -PI, PI)
	# Exactly behind, either way round is as short, and the wrap picks -PI
	# on both sides: blue turned north and red south. Turn towards +z, the
	# way the mirror across x keeps, whichever way it faces.
	if is_equal_approx(absf(left), PI):
		left = PI * signf(cos(facing)) if cos(facing) != 0.0 else PI
	facing += clampf(left, -turn_rate * delta, turn_rate * delta)
	return absf(wrapf(wanted - facing, -PI, PI)) <= AIM_CONE


# Of the enemies in sight for at least the reaction time, the one a shot is
# worth the most damage at (`MatchPercepts.shot_worth`) -- the nearest,
# mostly, but not one behind cover when another stands in the open; the
# first in sight of equal worth, and -1 when none is worth a shot.
func _best_target(percepts: MatchPercepts, reaction: float) -> int:
	var best: int = -1
	var best_worth: float = 0.0
	for enemy: int in percepts.in_sight:
		var ready: bool = percepts.now - float(seen_since.get(enemy, percepts.now)) >= reaction
		var worth: float = float(percepts.shot_worth.get(enemy, 0.0))
		if ready and worth > best_worth:
			best_worth = worth
			best = enemy
	return best
