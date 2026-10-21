## One bot of the match: its body, what it knows, and the plainest selector
## that holds -- a priority list, asked again whenever the world is looked at.
##
## The list, highest first [Jakatdar 2017; T49]:
##
##   1. dead: wait to respawn;
##   2. out of ammunition, or reloading: reload, crouched;
##   3. in the moving wave of a retreat: fall back to its spot;
##   4. an enemy in its own sight row, seen for at least its reaction time:
##      turn to it, and shoot once facing it;
##   5. otherwise go to the spot its team's tactics chose, and hold it.
##
## A bot has no sense the player would not have: it shoots only at what its
## own row of the sight table says it sees, after a reaction, and it turns at
## a limited rate (the honest knobs). `MatchBot` never reads another bot's
## mind; what it knows of enemies it was told by `BotMatch`'s sight table.
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
var fire_cooldown: float = 0.0
var reload_left: float = 0.0
var respawn_left: float = 0.0
var crouched: bool = false
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


## Whether it is alive. A bot brought to zero health in this step still is,
## until the step ends: two bots firing in the same step both fire, whoever
## is taken first in id order.
func alive() -> bool:
	return respawn_left <= 0.0


## Whether it has reached where it was going.
func arrived() -> bool:
	return position.distance_to(goal) <= ARRIVED


## The priority list. `visible` is this bot's row of the sight table, enemy
## ids it sees now; `positions` every bot's place by id; `moving_in_retreat`
## whether its squad's retreat has it in the moving wave. Sets `action` and
## `target`; moving and shooting are `BotMatch`'s, by the rules.
func decide(now: float, visible: Array[int], positions: Dictionary, reaction: float,
		moving_in_retreat: bool) -> void:
	target = -1
	if controlled:
		action = DEAD if not alive() else (RELOAD if reload_left > 0.0 else PLAYED)
		crouched = wants_to_crouch and alive()
		return
	if not alive():
		action = DEAD
	elif reload_left > 0.0 or ammo <= 0:
		action = RELOAD
	elif moving_in_retreat:
		action = FALL_BACK
	else:
		target = _reacted_target(now, visible, positions, reaction)
		action = SHOOT if target != -1 else (HOLD if arrived() else MOVE)
	crouched = action == RELOAD or (action == HOLD and spot != -1)


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
func _reacted_target(now: float, visible: Array[int], positions: Dictionary, reaction: float) -> int:
	var best: int = -1
	var best_distance: float = INF
	for enemy: int in visible:
		var ready: bool = now - float(seen_since.get(enemy, now)) >= reaction
		var distance: float = position.distance_to(positions[enemy])
		if ready and distance < best_distance:
			best_distance = distance
			best = enemy
	return best
