## One bot of the match: its body, what it knows, and the plainest selector
## that holds -- a priority list, asked again whenever the world is looked at.
##
## The list, highest first [Jakatdar 2017; T49]:
##
##   1. dead: wait to respawn;
##   2. its magazine empty with rounds in reserve, or reloading: reload,
##      crouched;
##   3. in the moving wave of a retreat: fall back to its spot;
##   4. fewer than `reload_below` rounds, no enemy in sight, and standing
##      where it was going -- its cover spot, usually: reload early, so the
##      magazine is not empty in the next fight;
##   5. an enemy in its own sight row, seen for at least its reaction time,
##      and a round to fire:
##      turn to it, and shoot once facing it;
##   6. otherwise go where its team's tactics sent it -- the spot chosen,
##      or an errand to its base or to the power weapon -- and hold it.
##
## Then, apart from the list, its pace: it sprints while it moves with no
## enemy in sight and far to go, and never while it shoots (`choose_pace`).
##
## A bot has no sense the player would not have: it shoots only at what its
## own eyes say it sees, after a reaction, and it turns at a limited rate
## (the honest knobs). Its decision reads one record, `MatchPercepts` --
## what its cone and its ears gave it, its body and its orders -- and
## nothing else: never another bot's mind, never the match.
class_name MatchBot
extends RefCounted

const DEAD: String = "dead"
const RELOAD: String = "reload"
const FALL_BACK: String = "fall back"
const SHOOT: String = "shoot"
const MOVE: String = "move"
const HOLD: String = "hold"
## A person is driving it.
const PLAYED: String = "played"
## Facing within this of the target, a shot may be taken.
const AIM_CONE: float = deg_to_rad(5.0)
## Within this of its goal, a bot has arrived.
const ARRIVED: float = 0.3

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
var weapon: String = "rifle"
var reserve: int = 0
var streak: int = 0
## An errand its team's supply sent it on (`MatchSupply.RESUPPLY`, `FETCH`,
## or "": none), and what it weighed: name -> [gain, walk, cost, score].
var errand: String = ""
var errand_weighing: Dictionary = {}
## The rules' early reload threshold, given it by the match.
var reload_below: int = 0
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
## Whether it looks along the line again before each shot. Always, for an
## honest bot; `botmatch_effects.gd` plants one that does not, and the
## honesty count must catch its shots at targets gone behind cover.
var checks_its_line: bool = true
## Driven by a person instead of the list (the owner's takeover). Then the
## person's intent below is what it does, in the same body by the same rules.
var controlled: bool = false
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


## The priority list, over what it perceives (`percepts`, the one record it
## reads) and its team's `reaction`. Sets `action` and `target`; moving and
## shooting are `BotMatch`'s, by the rules.
func decide(percepts: MatchPercepts, reaction: float) -> void:
	target = -1
	see(percepts.now, percepts.in_sight)
	if controlled:
		# PLAYED while it reloads too: the person walks on as the magazine
		# goes in, and `_played` carries the reload.
		action = DEAD if not alive() else PLAYED
		crouched = wants_to_crouch and alive()
		return
	var there: bool = percepts.to_go() <= ARRIVED
	if not percepts.alive:
		action = DEAD
	elif percepts.reloading or (percepts.rounds <= 0 and percepts.reserve > 0):
		action = RELOAD
	elif percepts.moving_in_retreat:
		action = FALL_BACK
	elif percepts.rounds < reload_below and percepts.reserve > 0 and percepts.in_sight.is_empty() and there:
		action = RELOAD
	else:
		# An empty weapon shoots at nobody: it goes where its errand sends it.
		target = _reacted_target(percepts, reaction) if percepts.rounds > 0 else -1
		action = SHOOT if target != -1 else (HOLD if there else MOVE)
	crouched = action == RELOAD or (action == HOLD and percepts.holds_a_spot)


## Whether to sprint, after `decide`: a person sprints while they hold the
## key and walk, not crouched, not firing and not reloading; a bot while it moves with no
## enemy in its sight row and at least `sprint_from` metres to go. Sprinting
## is what lets it reach a far point sooner, and seeing an enemy is when a
## shot may be needed, so the one rule serves both.
func choose_pace(visible: Array[int], sprint_from: float) -> void:
	if controlled:
		var walking: bool = wants_to_walk.length() > 0.1
		var free_hands: bool = not wants_to_fire and reload_left <= 0.0
		sprinting = alive() and wants_to_sprint and walking and not crouched and free_hands
		return
	var moving: bool = action == MOVE or action == FALL_BACK
	sprinting = moving and visible.is_empty() and position.distance_to(goal) >= sprint_from


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
	facing += clampf(left, -turn_rate * delta, turn_rate * delta)
	return absf(wrapf(wanted - facing, -PI, PI)) <= AIM_CONE


# The nearest enemy in sight that has been in sight for the reaction time.
func _reacted_target(percepts: MatchPercepts, reaction: float) -> int:
	var best: int = -1
	var best_distance: float = INF
	for enemy: int in percepts.in_sight:
		var ready: bool = percepts.now - float(seen_since.get(enemy, percepts.now)) >= reaction
		var distance: float = percepts.position.distance_to(percepts.enemy_places[enemy])
		if ready and distance < best_distance:
			best_distance = distance
			best = enemy
	return best
