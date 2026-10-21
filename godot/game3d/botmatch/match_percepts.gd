## Everything one bot of the match knows when it decides, in one record:
## what its senses gave it at this decision -- the enemies its cone and its
## line let through, the loudest enemy shot it heard -- and what its own
## body and its orders tell it.
##
## `MatchBot.decide` reads this and nothing else. That is AIMA's agent: a
## function from percepts to an action [Russell and Norvig, ch. 2], and the
## owner's ask for T67 -- a bot put on another map, or in a test with no map
## at all, decides from the same record, because the record is all it ever
## had. `MatchSenses` fills it from the match through `ai_perception`.
class_name MatchPercepts
extends RefCounted

## When it is perceived, in match seconds.
var now: float = 0.0
var alive: bool = true
## The enemies in sight now, by id in id order, and where each stands.
var in_sight: Array[int] = []
var enemy_places: Dictionary = {}
## What a shot at each of them is worth now, by id: the damage its aim
## expects (`AimChoice`, as its team aims), over a sure shot at the zone
## worth most -- 1 a sure headshot, 0 nothing of it exposed.
var shot_worth: Dictionary = {}
## The loudest enemy shot heard since its last decision, from 1 beside it
## to 0 out of hearing (`Hearing`), and where it was fired from; INF, none.
var heard: float = 0.0
var heard_from: Vector2 = Vector2.INF
## Its body: where it stands, the rounds in its magazine and how many the
## weapon holds, the rounds in reserve, and whether a reload is under way.
var position: Vector2 = Vector2.ZERO
var rounds: int = 0
var capacity: int = 1
var reserve: int = 0
var reloading: bool = false
## Its orders, from its team's tactics: where it was sent, whether it holds
## a spot there, and whether its squad's retreat has it in the moving wave.
var goal: Vector2 = Vector2.ZERO
var holds_a_spot: bool = false
var moving_in_retreat: bool = false
## What the nearest cover beside it hides: 1 at a low box -- crouched,
## nothing shows; standing, it shoots over -- 0.5 at a high one, which
## hides it either way, and 0 in the open.
var cover: float = 0.0
## Where its team remembers enemies, seen by any of them lately.
var remembered: Array[Vector2] = []


## What `bot` knows of itself and its orders at `now`, with nothing in
## sight and nothing heard: the record its senses then add to.
static func of_body(bot: MatchBot, now: float, capacity: int, moving_in_retreat: bool = false) -> MatchPercepts:
	var percepts := MatchPercepts.new()
	percepts.now = now
	percepts.alive = bot.alive()
	percepts.position = bot.position
	percepts.rounds = bot.ammo
	percepts.capacity = maxi(capacity, 1)
	percepts.reserve = bot.reserve
	percepts.reloading = bot.reload_left > 0.0
	percepts.goal = bot.goal
	percepts.holds_a_spot = bot.spot != -1
	percepts.moving_in_retreat = moving_in_retreat
	return percepts


## How far it still is from where it was sent, in metres.
func to_go() -> float:
	return position.distance_to(goal)
