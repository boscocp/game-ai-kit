# A seeded boss fight played by a script, and the four things T157's
# acceptance asks of it, each read from what the run recorded:
#
#   * at most the pool's melee attackers at any step: the boss and the
#     minions in a melee window, the boss's heavy blow counted as the whole
#     pool, never more than the pool;
#   * every minion that waits gets a turn: none waits longer than
#     LONGEST_WAIT without a grant -- a wait ends only in a grant, a death
#     or the fight's end, so a bounded wait is a turn given;
#   * a ranged minion never fires while melee pressure is on, the pressure
#     read here from the minions' states, not from the fight's own flag;
#   * the fight ends.
#
# The scripted player goes for the nearest minion close by, else the boss;
# it swings in reach, dodges a telegraph about to land and a bolt about to
# hit, and wobbles by its seed so no two runs are the same fight.
extends RefCounted

const SECONDS: float = 60.0
## The longest a minion may wait for a token without being granted one.
const LONGEST_WAIT: float = 15.0
const DODGE_AT: float = 0.7
const CLOSE_BY: float = 2.5
const MELEE_WINDOWS: Array[String] = [BossMinion.WINDING, BossMinion.STRIKING, BossMinion.RECOVERING]

## Whether the scripted player swings at all: a planted run sets it false.
var swings: bool = true
var _random := RandomNumberGenerator.new()


func _init(seed_value: int) -> void:
	_random.seed = seed_value


## Play `fight` for at most SECONDS, or until it ends; what was seen.
func run(fight: BossFight) -> Dictionary:
	var trace: Dictionary = {"loads": [], "waits": {}, "granted": {}, "fired_pressed": [], "fired": 0,
		"ended": "", "lasted": 0.0, "pool": fight.tokens.free_tokens(BossMinion.MELEE)}
	var waiting_since: Dictionary = {}
	var fired_before: Dictionary = {}
	while fight.time < SECONDS and fight.outcome == "":
		fight.step(intent_for(fight))
		trace["loads"].append({"at": fight.time, "load": melee_load(fight)})
		_note_waits(fight, waiting_since, trace)
		_note_fires(fight, fired_before, trace)
	for event: Dictionary in fight.tokens.events:
		if event["what"] == AttackTokens.GRANTED:
			trace["granted"][event["id"]] = true
	trace["ended"] = fight.outcome
	trace["lasted"] = fight.time
	return trace


## The melee attackers now, by the tokens their windows need: a minion in a
## melee window one, the boss in one its attack's cost.
static func melee_load(fight: BossFight) -> int:
	var load: int = 0
	for minion: BossMinion in fight.minions:
		if minion.kind == BossMinion.MELEE and minion.state in MELEE_WINDOWS:
			load += 1
	if fight.boss.state in BossBrain.WINDOW_STATES and fight.boss.attack != "":
		var blow: BossTable.Blow = fight.table.attacks[fight.boss.attack]
		if blow.kind == BossMinion.MELEE:
			load += fight.boss.pool_size(BossMinion.MELEE) if blow.heavy else 1
	return load


## The steps where the load passed the pool: {at, load}.
static func over_the_pool(trace: Dictionary) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for sample: Dictionary in trace["loads"]:
		if sample["load"] > trace["pool"]:
			found.append(sample)
	return found


## The minions that waited longer than LONGEST_WAIT for a token. A minion
## still waiting when the fight ends has its wait so far counted.
static func left_waiting(trace: Dictionary) -> PackedStringArray:
	var found := PackedStringArray()
	for who: String in trace["waits"]:
		var record: Dictionary = trace["waits"][who]
		if record["longest"] > LONGEST_WAIT:
			found.append("%s waited %.1f s, granted %s" % [who, record["longest"], trace["granted"].has(who)])
	return found


## The moments a ranged minion fired while a melee one wound up or struck.
static func fired_under_pressure(trace: Dictionary) -> Array:
	return trace["fired_pressed"]


## What the scripted player does this step.
func intent_for(fight: BossFight) -> BossFightIntent:
	var intent := BossFightIntent.new()
	var me: Vector2 = fight.player.position
	var target: Vector2 = _target(fight)
	var to_target: Vector2 = target - me
	intent.direction = to_target.normalized() if to_target.length() > 1.6 else Vector2.ZERO
	intent.direction = (intent.direction + Vector2.from_angle(_random.randf() * TAU) * 0.3).limit_length(1.0)
	intent.attack = swings and to_target.length() <= BossFightPlayer.REACH
	var danger: Vector2 = _danger(fight)
	if danger != Vector2.ZERO:
		intent.dodge = true
		intent.direction = danger
	intent.view_forward = fight.player.facing
	intent.view_from = me - fight.player.facing * 4.5
	return intent


# Where to go: the nearest minion close by, else the boss; the player turns
# to face it as it walks.
func _target(fight: BossFight) -> Vector2:
	var best: Vector2 = fight.boss_body.position
	var nearest: float = CLOSE_BY
	for minion: BossMinion in fight.minions:
		var distance: float = minion.body.position.distance_to(fight.player.position)
		if minion.alive() and distance < nearest:
			best = minion.body.position
			nearest = distance
	return best


# The way to dodge, or zero: away from a boss whose telegraph is nearly
# done with the player in reach, or across a bolt about to arrive.
func _danger(fight: BossFight) -> Vector2:
	var away: Vector2 = fight.player.position - fight.boss_body.position
	var reach: float = BossFight.BOSS_REACH.get(fight.boss.attack, 2.0) + 1.0
	if fight.boss.telegraph_progress(fight.time) > DODGE_AT and away.length() < reach:
		return away.normalized()
	for bolt: Dictionary in fight.bolts:
		var offset: Vector2 = fight.player.position - bolt["position"]
		if offset.length() < 3.0 and offset.dot(bolt["velocity"]) > 0.0:
			return bolt["velocity"].orthogonal().normalized()
	return Vector2.ZERO


func _note_waits(fight: BossFight, waiting_since: Dictionary, trace: Dictionary) -> void:
	for minion: BossMinion in fight.minions:
		var waits: bool = minion.alive() and minion.id in fight.tokens.waiting(minion.kind)
		if not waits:
			waiting_since.erase(minion.id)
			continue
		if not waiting_since.has(minion.id):
			waiting_since[minion.id] = fight.time
		var record: Dictionary = trace["waits"].get(minion.id, {"longest": 0.0})
		record["longest"] = maxf(record["longest"], fight.time - waiting_since[minion.id])
		trace["waits"][minion.id] = record


func _note_fires(fight: BossFight, fired_before: Dictionary, trace: Dictionary) -> void:
	var pressure: bool = fight.minions.any(func(minion: BossMinion) -> bool: return minion.state in BossMinion.PRESSING)
	for minion: BossMinion in fight.minions:
		if minion.kind != BossMinion.RANGED or minion.fired == fired_before.get(minion.id, 0):
			continue
		fired_before[minion.id] = minion.fired
		trace["fired"] += 1
		if pressure:
			trace["fired_pressed"].append({"at": fight.time, "who": minion.id})
