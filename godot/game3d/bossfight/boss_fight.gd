## The boss fight as a world a test can step: the player, the boss, its
## minions, their bolts, on a square arena with four pillars -- no scene,
## no physics, the ground plane as `Vector2`.
##
## Everyone who strikes the player shares one `AttackTokens` pool, the
## player's: the boss (`BossBrain`, T156) and the minions (`BossMinion`).
## `EngagementRings` round the player say where the minions stand. A step
## runs in an order that is the rule written down:
##
## 1. the player moves, swings, dodges, locks on;
## 2. whether the player is pressed -- a melee minion winding up or
##    striking -- is read, as of now;
## 3. every `decide_every` seconds the minions ask for tokens and points; a
##    ranged minion holding fire asks for none;
## 4. the boss decides; the pool grants;
## 5. the melee minions act -- one may start winding up;
## 6. if that pressed the player, every ranged minion's token is taken back
##    (T154's fourth way back) and its request withdrawn, and the ranged
##    minions hold fire: no ranged minion asks again while the player is
##    pressed, nor until the pool's pressed ranged delay (2 s x 3) has
##    passed since the pressure began. A ranged attacker holds fire while
##    melee is on the player: the request's account of Spider-Man, not
##    checked against the talk (`action-combat-ai.md`);
## 7. the ranged minions act, so one whose token was just taken never fires;
## 8. the boss's blow, the bolts, the summons, and who is down.
##
## The boss's own ranged attack is not held: the minions' pressure is the
## minions' rule, and the boss's blows obey only the token count (T156).
##
## A phase the boss enters with `summon` brings each kind back to the
## wave's size, never above it. T158's director replaces that rule with
## its pacing.
##
## When not to use it: for drawing. `BossfightDrawing` draws it.
class_name BossFight
extends RefCounted

const WON: String = "won"
const LOST: String = "lost"
const BOSS_SPEED: float = 3.0
const BOSS_STRONGEST: float = 10.0
const BOSS_RADIUS: float = 1.0
## How close the boss walks before it stands to choose.
const BOSS_STANDS_AT: float = 2.4
const CHARGE_SPEED: float = 10.0
## Each attack's reach, in metres; `hurl` throws a bolt instead.
const BOSS_REACH: Dictionary[String, float] = {"swipe": 3.0, "slam": 3.5, "charge": 1.8, "sweep": 3.6, "quake": 6.0}
const BOSS_LIGHT_DAMAGE: float = 0.1
const BOSS_HEAVY_DAMAGE: float = 0.2
const MINION_DAMAGE: float = 0.05
const BOLT_DAMAGE: float = 0.07
const BOLT_SPEED: float = 13.0
const BOLT_SECONDS: float = 2.0
const BOLT_RADIUS: float = 0.5
## The player's blow on the boss, doubled in its recovery: the opening.
const HIT_ON_BOSS: float = 0.03
const HIT_ON_MINION: float = 0.4
const PILLAR_RADIUS: float = 1.3

var rules: BossFightRules
var table: BossTable
var tokens: AttackTokens
var rings: EngagementRings
var boss: BossBrain
var boss_body: SteeringVehicle
var boss_facing: Vector2 = Vector2.DOWN
var player := BossFightPlayer.new()
var minions: Array[BossMinion] = []
## Bolts in flight: {position, velocity, left, damage}.
var bolts: Array[Dictionary] = []
## The arena's cells, the pillars blocked: the line of sight's map.
var graph: GakGridGraph
var time: float = 0.0
## WON, LOST, or "" while fighting.
var outcome: String = ""
## True while a melee minion winds up or strikes at the player.
var pressed: bool = false
## Until when the ranged minions hold fire after pressure began.
var held_fire_until: float = -INF
## What happened, in order: {at, what, who}: struck, fired, called_off,
## held_fire, revoked, hit, summoned, down.
var events: Array[Dictionary] = []
## Per kind, the last grant: {at, state} -- the reissue timer's start.
var last_grant: Dictionary[String, Dictionary] = {}
var _next_decision: float = 0.0
var _serial: int = 0
var _boss_landed: bool = false
var _boss_events_read: int = 0
var _arrive := ArriveBehaviour.new(Vector2.ZERO, 2.0, 0.2)
## Places every wave, the first and the summoned, from the fight's seed.
var _random := RandomNumberGenerator.new()


## A fight on `fight_rules` against `boss_table`, its first wave placed by
## `seed_value`.
func _init(fight_rules: BossFightRules, boss_table: BossTable, seed_value: int) -> void:
	rules = fight_rules
	table = boss_table
	tokens = AttackTokens.new(rules.token_config())
	rings = EngagementRings.new(rules.rings_config())
	boss = BossBrain.new(table, tokens)
	boss_body = SteeringVehicle.new(Vector2(0, -5), Vector2.ZERO, BOSS_SPEED, BOSS_STRONGEST)
	player.position = Vector2(0, 6)
	graph = _arena_graph()
	_random.seed = seed_value
	_fill_wave()


## The shipped fight.
static func shipped(seed_value: int) -> BossFight:
	return BossFight.new(BossFightRules.read(), BossTable.from_file(), seed_value)


## Why it cannot fight, or "": the boss's own refusal.
func refusal() -> String:
	return rules.refusal if rules.refusal != "" else boss.refusal


## One step of `rules.step_seconds`, in the order the header gives.
func step(intent: BossFightIntent) -> void:
	if outcome != "" or refusal() != "":
		return
	time += rules.step_seconds
	_player_acts(intent)
	pressed = _pressing()
	rings.place(player.position)
	if time >= _next_decision:
		_next_decision = time + rules.decide_every
		_minions_decide(intent)
	boss.decide(time, player.position.distance_to(boss_body.position), _player_faces_boss())
	_grant()
	_minions_act(BossMinion.MELEE)
	_hold_fire()
	_minions_act(BossMinion.RANGED)
	_boss_acts()
	_move_bolts()
	_summon()
	_settle()


## The time of the next round of minion decisions.
func next_decision() -> float:
	return _next_decision


## The player's state the pool reads: PRESSED or FREE.
func player_state() -> String:
	return BossFightRules.PRESSED if pressed else BossFightRules.FREE


## Seconds until `kind` may be granted again: the delay set at its last
## grant, by the state the player was in then, less the time since; for
## ranged, at least until the minions stop holding fire.
func next_grant_in(kind: String) -> float:
	var left: float = 0.0
	if last_grant.has(kind):
		var record: Dictionary = last_grant[kind]
		left = record["at"] + tokens.delay_for(kind, record["state"]) - time
	if kind == BossMinion.RANGED:
		left = maxf(left, held_fire_until - time)
	return maxf(0.0, left)


## True while the ranged minions hold fire: the player pressed, or the
## pressed ranged delay not yet over since the pressure began.
func holding_fire() -> bool:
	return pressed or time < held_fire_until


## How long the ranged minions hold fire after pressure begins: the pool's
## ranged delay with the pressed multiplier -- 2 s x 3 shipped.
func hold_fire_seconds() -> float:
	return tokens.delay_for(BossMinion.RANGED, BossFightRules.PRESSED)


## Where the enemy with token id `who` stands, or the player's own place
## when it is gone.
func position_of(who: String) -> Vector2:
	if who == BossBrain.ID:
		return boss_body.position
	for minion: BossMinion in minions:
		if minion.id == who and minion.alive():
			return minion.body.position
	return player.position


## True when the line from `from` to `to` crosses no pillar.
func clear_line(from: Vector2, to: Vector2) -> bool:
	return LineOfSight.clear(graph, _cell(from), _cell(to))


# A new minion. Its own function so a test can plant one that breaks a rule.
func _make_minion(kind: String, serial: int, at: Vector2) -> BossMinion:
	return BossMinion.new(kind, serial, at)


## Minions of `kind` standing now.
func alive_of(kind: String) -> int:
	return minions.filter(func(minion: BossMinion) -> bool: return minion.alive() and minion.kind == kind).size()


# How many of `kind` a wave adds: up to the wave's size, never above it.
# Its own function so a test can plant a summon that piles on.
func _missing(kind: String) -> int:
	return maxi(0, rules.wave.get(kind, 0) - alive_of(kind))


func _fill_wave() -> void:
	for kind: String in [BossMinion.MELEE, BossMinion.RANGED]:
		for count: int in range(_missing(kind)):
			_serial += 1
			var angle: float = _random.randf_range(0.0, TAU)
			var at: Vector2 = Vector2.from_angle(angle) * (rules.arena_half - 2.0)
			minions.append(_make_minion(kind, _serial, at))
			events.append({"at": time, "what": "summoned", "who": minions[-1].id})


func _player_acts(intent: BossFightIntent) -> void:
	if intent.toggle_lock:
		player.locked = "" if player.locked != "" else _lock_target(intent)
	if player.locked != "" and position_of(player.locked) == player.position:
		player.locked = ""
	if intent.dodge:
		player.dodge(intent.direction)
	if intent.attack:
		player.swing()
	var toward: Vector2 = position_of(player.locked) - player.position if player.locked != "" else Vector2.ZERO
	if player.move(intent.direction, toward, rules.step_seconds):
		_swing_lands()


# The nearest enemy in front of the camera, or the boss.
func _lock_target(intent: BossFightIntent) -> String:
	var best: String = BossBrain.ID
	var nearest: float = player.position.distance_to(boss_body.position)
	for minion: BossMinion in minions:
		var offset: Vector2 = minion.body.position - intent.view_from
		var distance: float = player.position.distance_to(minion.body.position)
		if minion.alive() and offset.dot(intent.view_forward) > 0.0 and distance < nearest:
			best = minion.id
			nearest = distance
	return best


func _swing_lands() -> void:
	if player.reaches(boss_body.position, BOSS_RADIUS) and boss.state != BossBrain.DEFEATED:
		var opening: float = 2.0 if boss.state == BossBrain.RECOVERY else 1.0
		boss.take_damage(HIT_ON_BOSS * opening)
	for minion: BossMinion in minions:
		var reached: bool = minion.alive() and player.reaches(minion.body.position, BossMinion.RADIUS)
		if reached and minion.hurt(HIT_ON_MINION, tokens, rings, time):
			events.append({"at": time, "what": "down", "who": minion.id})


# Each ring point's line of sight to the player, the bodies each minion
# keeps apart from -- the boss and the minions standing, not the fallen --
# then every minion's choice.
func _minions_decide(intent: BossFightIntent) -> void:
	for point: EngagementRings.Point in rings.points:
		point.line_of_sight = _inside(point.position) and clear_line(point.position, player.position)
	var bodies: Array[SteeringVehicle] = [boss_body]
	for minion: BossMinion in minions:
		if minion.alive():
			bodies.append(minion.body)
	for minion: BossMinion in minions:
		minion.keep_apart_from(bodies)
		var hold: bool = minion.kind == BossMinion.RANGED and holding_fire()
		minion.decide(tokens, rings, intent.view_from, intent.view_forward, time, hold)


# The pool grants; each grant starts its kind's reissue timer, noted with
# the player's state now, which set the delay.
func _grant() -> void:
	for who: String in tokens.step(time, player_state()):
		var kind: String = BossMinion.MELEE if who in tokens.holders(BossMinion.MELEE) else BossMinion.RANGED
		last_grant[kind] = {"at": time, "state": player_state()}


func _minions_act(kind: String) -> void:
	for minion: BossMinion in minions:
		if minion.kind != kind or not minion.alive():
			continue
		var sight: bool = clear_line(minion.body.position, player.position)
		var happened: String = minion.act(tokens, rings, player.position, sight, time, rules.step_seconds)
		_keep_inside(minion.body)
		if happened == "struck" and minion.body.position.distance_to(player.position) <= BossMinion.MELEE_REACH + 0.4:
			_hurt_player(MINION_DAMAGE, minion.id)
		elif happened == "fired":
			_launch(minion.body.position, BOLT_DAMAGE)
		if happened in ["struck", "fired", "called_off"]:
			events.append({"at": time, "what": happened, "who": minion.id, "pressed": pressed})


# True when a melee minion winds up or strikes at the player.
func _pressing() -> bool:
	return minions.any(func(minion: BossMinion) -> bool: return minion.state in BossMinion.PRESSING)


# Melee on the player takes back every ranged minion's token -- the fourth
# way back -- and its request, and starts the hold when the pressure is
# new. Its own function so a test can plant a fight that forgets.
func _hold_fire() -> void:
	var was_pressed: bool = pressed
	pressed = _pressing()
	if not pressed:
		return
	if not was_pressed:
		held_fire_until = time + hold_fire_seconds()
		events.append({"at": time, "what": "held_fire", "who": BossMinion.RANGED})
	for minion: BossMinion in minions:
		if minion.kind != BossMinion.RANGED:
			continue
		if tokens.release(minion.id, AttackTokens.REVOKED, time):
			events.append({"at": time, "what": "revoked", "who": minion.id})
		tokens.withdraw(minion.id, time)


func _boss_acts() -> void:
	var to_player: Vector2 = player.position - boss_body.position
	if boss.state in [BossBrain.CLOSING, BossBrain.WAITING]:
		_arrive.target = player.position - to_player.normalized() * BOSS_STANDS_AT
		boss_body.step(_arrive.force(boss_body), rules.step_seconds)
		boss_facing = to_player.normalized() if to_player != Vector2.ZERO else boss_facing
	elif boss.state == BossBrain.TELEGRAPH and to_player != Vector2.ZERO:
		boss_facing = to_player.normalized()
	elif boss.state == BossBrain.ACTIVE and boss.attack == "charge":
		boss_body.position += boss_facing * CHARGE_SPEED * rules.step_seconds
	_keep_inside(boss_body)
	if boss.state != BossBrain.ACTIVE:
		_boss_landed = false
	elif not _boss_landed and _boss_holds_token():
		_boss_blow()


func _boss_blow() -> void:
	var blow: BossTable.Blow = table.attacks[boss.attack]
	if blow.kind == BossMinion.RANGED:
		_launch(boss_body.position, BOSS_LIGHT_DAMAGE)
		_boss_landed = true
		events.append({"at": time, "what": "fired", "who": BossBrain.ID, "pressed": pressed})
	elif player.position.distance_to(boss_body.position) <= BOSS_REACH.get(boss.attack, 2.0):
		var damage: float = BOSS_HEAVY_DAMAGE if blow.heavy else BOSS_LIGHT_DAMAGE
		_boss_landed = _hurt_player(damage, BossBrain.ID)


func _boss_holds_token() -> bool:
	return BossBrain.ID in tokens.holders(table.attacks[boss.attack].kind)


func _launch(from: Vector2, damage: float) -> void:
	var velocity: Vector2 = (player.position - from).normalized() * BOLT_SPEED
	bolts.append({"position": from, "velocity": velocity, "left": BOLT_SECONDS, "damage": damage})


func _move_bolts() -> void:
	var flying: Array[Dictionary] = []
	for bolt: Dictionary in bolts:
		bolt["position"] += bolt["velocity"] * rules.step_seconds
		bolt["left"] -= rules.step_seconds
		var landed: bool = bolt["position"].distance_to(player.position) <= BOLT_RADIUS and _hurt_player(bolt["damage"], "bolt")
		if not landed and bolt["left"] > 0.0 and _inside(bolt["position"]) and not _in_pillar(bolt["position"]):
			flying.append(bolt)
	bolts = flying


func _hurt_player(amount: float, by: String) -> bool:
	if not player.take(amount):
		return false
	events.append({"at": time, "what": "hit", "who": by})
	return true


# A phase that summons brings the group back to the wave's size.
func _summon() -> void:
	while _boss_events_read < boss.events.size():
		var event: Dictionary = boss.events[_boss_events_read]
		_boss_events_read += 1
		if event["what"] == "phase" and event["summon"]:
			_fill_wave()


func _settle() -> void:
	if boss.state == BossBrain.DEFEATED:
		outcome = WON
	elif player.health <= 0.0:
		outcome = LOST
	_keep_inside_player()


# 1 when the player looks straight at the boss, -1 with its back to it.
func _player_faces_boss() -> float:
	var to_boss: Vector2 = boss_body.position - player.position
	return player.facing.dot(to_boss.normalized()) if to_boss != Vector2.ZERO else 1.0


func _keep_inside_player() -> void:
	var body := SteeringVehicle.new(player.position, Vector2.ZERO, 1.0, 1.0)
	_keep_inside(body)
	player.position = body.position


# Inside the walls, and out of the pillars.
func _keep_inside(body: SteeringVehicle) -> void:
	var limit: float = rules.arena_half - 0.5
	body.position = body.position.clamp(Vector2(-limit, -limit), Vector2(limit, limit))
	for pillar: Vector2i in rules.pillars:
		var centre: Vector2 = Vector2(pillar) + Vector2.ONE
		var offset: Vector2 = body.position - centre
		if offset.length() < PILLAR_RADIUS:
			body.position = centre + (offset.normalized() if offset != Vector2.ZERO else Vector2.RIGHT) * PILLAR_RADIUS


func _inside(point: Vector2) -> bool:
	var limit: float = rules.arena_half - 0.5
	return absf(point.x) <= limit and absf(point.y) <= limit


func _in_pillar(point: Vector2) -> bool:
	return graph.is_blocked(_cell(point))


func _cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x) + rules.arena_half, floori(point.y) + rules.arena_half)


# The arena as a grid, a cell a metre: each pillar blocks two by two.
func _arena_graph() -> GakGridGraph:
	var arena := GakGridGraph.new(rules.arena_half * 2, rules.arena_half * 2)
	for pillar: Vector2i in rules.pillars:
		for offset: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			arena.block(_cell(Vector2(pillar + offset)))
	return arena
