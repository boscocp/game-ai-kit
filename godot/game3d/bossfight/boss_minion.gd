## One of the boss's minions: game code over the kit's parts, no new AI.
##
## It asks the player's `AttackTokens` for a token of its kind, and strikes
## only while it holds one. It asks `EngagementRings` where to stand: the
## waiting ring without a token, the inner ring with a melee token, the
## ranged band always if it shoots. It walks there with `ai_steering`'s
## arrive, kept apart from the others by separation. A ranged minion aims
## only along a clear line, `ai_perception`'s line of sight on the arena's
## grid. A melee attack is a wind-up, a strike and a recovery, like the
## boss's windows; a ranged one is an aim and a bolt.
##
## The order is the fight's (`BossFight.step`): decide, then the tokens,
## then the melee act, then the ranged -- so a ranged minion whose token was
## taken back because a melee one started never fires.
##
## When not to use it: an enemy that fights alone needs no tokens or rings;
## its own state machine is enough.
class_name BossMinion
extends RefCounted

const MELEE: String = "melee"  # shown through tr()
const RANGED: String = "ranged"  # shown through tr()
## What it is doing, as the overlay names it.
const CIRCLING: String = "circling"  # shown through tr()
const CLOSING: String = "closing"  # shown through tr()
const WINDING: String = "winding"  # shown through tr()
const STRIKING: String = "striking"  # shown through tr()
const AIMING: String = "aiming"  # shown through tr()
const RECOVERING: String = "recovering"  # shown through tr()
const STAGGERED: String = "staggered"  # shown through tr()
const DOWN: String = "fallen"  # shown through tr()
## The melee states that are pressure on the player: a ranged token is
## taken back while any minion is in one.
const PRESSING: Array[String] = [WINDING, STRIKING]
## The states a token is needed for: lost in one, the attack is called off.
const ATTACKING: Array[String] = [CLOSING, WINDING, STRIKING, AIMING]

const WIND_SECONDS: float = 0.6
const AIM_SECONDS: float = 0.9
const STRIKE_SECONDS: float = 0.25
const RECOVER_SECONDS: float = 0.6
const STAGGER_SECONDS: float = 0.7
## After an attack, how long before it asks again.
const REST_SECONDS: float = 0.8
## A little past the inner ring, so a minion on its point is in reach.
const MELEE_REACH: float = 2.4
const SPEED: float = 3.4
const STRONGEST: float = 14.0
const RADIUS: float = 0.45
const TOO_CLOSE: float = 1.3

## Its name in the token pool: "melee-1", "ranged-2".
var id: String
## Its number in the rings, which take an int.
var number: int
var kind: String
var state: String = CIRCLING
## 1 full, 0 down.
var health: float = 1.0
var body: SteeringVehicle
## The ring point it claims, by index into `EngagementRings.points`, or -1.
var point: int = -1
## The ring it asked for last.
var ring: String = EngagementRings.WAITING
## Bolts fired, and strikes landed or missed: what a test counts.
var fired: int = 0
var struck: int = 0
var _window_left: float = 0.0
var _rest_until: float = 0.0
var _arrive := ArriveBehaviour.new(Vector2.ZERO, 1.5, 0.2)
var _apart := SeparationBehaviour.new(TOO_CLOSE)


func _init(minion_kind: String, serial: int, at: Vector2) -> void:
	kind = minion_kind
	number = serial
	id = "%s-%d" % [kind, serial]
	body = SteeringVehicle.new(at, Vector2.ZERO, SPEED, STRONGEST)


## True unless it is down.
func alive() -> bool:
	return state != DOWN


## True while it holds a token of its kind.
func holds_token(tokens: AttackTokens) -> bool:
	return id in tokens.holders(kind)


## A decision: ask for a token when free to, and choose a point on the ring
## that fits it. -1 from the rings -- every point taken, or a bump -- leaves
## it where it is, and it asks again at its next decision.
func decide(tokens: AttackTokens, rings: EngagementRings, view_from: Vector2, view_forward: Vector2, now: float) -> void:
	if state not in [CIRCLING, CLOSING]:
		return
	var holds: bool = holds_token(tokens)
	if not holds and now >= _rest_until:
		tokens.request(id, kind, 1, 0, body.position.distance_to(rings.target), now)
	ring = EngagementRings.ring_for(holds, kind == RANGED)
	point = rings.choose(number, ring, body.position, view_from, view_forward)


## One step of its body and its windows; what happened, for the fight:
## "" or one of "struck", "fired", "called_off", "ended". `sight` says
## whether it can see the player from where it stands.
func act(tokens: AttackTokens, rings: EngagementRings, player: Vector2, sight: bool, now: float, step: float) -> String:
	if state == DOWN:
		return ""
	if state in ATTACKING and state != CLOSING and not holds_token(tokens):
		_back_to_circling(now)
		return "called_off"
	_steer(rings, player, step)
	if state in [WINDING, STRIKING, AIMING, RECOVERING, STAGGERED]:
		return _through_windows(tokens, now, step)
	var holds: bool = holds_token(tokens)
	if state == CLOSING and not holds:
		state = CIRCLING
	elif state == CIRCLING and holds:
		state = CLOSING if kind == MELEE else CIRCLING
	if kind == MELEE and state == CLOSING and body.position.distance_to(player) <= MELEE_REACH:
		_open(WINDING, WIND_SECONDS)
	elif kind == RANGED and holds and sight:
		_open(AIMING, AIM_SECONDS)
	return ""


## Hit by the player for `amount`: a wind-up or an aim is interrupted and
## its token goes back; at no health it is down, and its token and its
## claim go back. True when it went down.
func hurt(amount: float, tokens: AttackTokens, rings: EngagementRings, now: float) -> bool:
	if state == DOWN:
		return false
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		state = DOWN
		tokens.release(id, AttackTokens.DIED, now)
		rings.release(number)
		point = -1
		return true
	if state in [WINDING, AIMING, CLOSING]:
		tokens.release(id, AttackTokens.INTERRUPTED, now)
		_open(STAGGERED, STAGGER_SECONDS)
	return false


## Seconds left in the window it is in, for the overlay.
func window_left() -> float:
	return maxf(0.0, _window_left)


# Wind-up to strike to recovery, or aim to bolt to recovery; the token goes
# back when recovery ends. A stagger ends back on the ring.
func _through_windows(tokens: AttackTokens, now: float, step: float) -> String:
	_window_left -= step
	if _window_left > 0.0:
		return ""
	match state:
		WINDING:
			_open(STRIKING, STRIKE_SECONDS)
			struck += 1
			return "struck"
		AIMING:
			_open(RECOVERING, RECOVER_SECONDS)
			fired += 1
			return "fired"
		STRIKING:
			_open(RECOVERING, RECOVER_SECONDS)
		RECOVERING:
			tokens.release(id, AttackTokens.ENDED, now)
			_back_to_circling(now)
			return "ended"
		STAGGERED:
			_back_to_circling(now)
	return ""


func _open(window: String, seconds: float) -> void:
	state = window
	_window_left = seconds
	body.velocity = Vector2.ZERO


func _back_to_circling(now: float) -> void:
	state = CIRCLING
	_rest_until = now + REST_SECONDS


# Walk to the claimed point, or straight at the player when closing with no
# point; stand still in a window. Separation keeps the group apart.
func _steer(rings: EngagementRings, player: Vector2, step: float) -> void:
	if state not in [CIRCLING, CLOSING]:
		return
	if point >= 0:
		_arrive.target = rings.points[point].position
	elif state == CLOSING:
		_arrive.target = player
	else:
		_arrive.target = body.position
	var forces: Array[Vector2] = [_arrive.force(body), _apart.force(body)]
	body.step(Steering.combined(body, forces, PackedFloat64Array([1.0, 1.5])), step)


## The bodies it keeps apart from: the other minions and the boss.
func keep_apart_from(others: Array[SteeringVehicle]) -> void:
	_apart.neighbours = others
