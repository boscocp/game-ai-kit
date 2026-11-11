# A seeded boss fight played by a script, and the four things T157's
# acceptance asks of it, each read from what the run recorded:
#
#   * at most the pool's melee attackers at any step: the boss and the
#     minions in a melee window, the boss's heavy blow counted as the whole
#     pool, never more than the pool;
#   * every minion that waits gets a turn: none spends longer than
#     LONGEST_WAIT queued between two tokens it kept -- a grant taken back
#     in the step it was made is no turn, and the time a ranged minion's
#     request is withdrawn while the ranged hold fire is not counted, for
#     the hold is the rule, not the pool passing it over;
#   * a ranged minion never fires while melee pressure is on, the pressure
#     read here from the minions' states, not from the fight's own flag;
#   * the fight ends.
#
# And what the fight adds to them: no ranged minion is granted a token at
# a step that began with the player pressed, nor within the hold after
# pressure began; no wave brings a kind above its cap; and the overlay
# names a real holder, a real queue and a real claim at some step, not
# only "none".
#
# And T158's: the pools the run saw are the level's, every telegraph the
# boss ran is at least the level's minimum, and the director's waves came
# in build-up or with a summoning phase, never in a relief cut short, never
# while a heavy blow was underway -- that read from the boss, not from the
# director.
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
		"ended": "", "lasted": 0.0, "pool": fight.tokens.free_tokens(BossMinion.MELEE),
		"granted_pressed": [], "most_alive": {}, "summons": 0, "shown": {}, "pools": {}, "waved_heavy": []}
	var queued_for: Dictionary = {}
	var fired_before: Dictionary = {}
	while fight.time < SECONDS and fight.outcome == "":
		var pressed_before: bool = _pressure(fight)
		var events_before: int = fight.tokens.events.size()
		var directed_before: int = fight.director.events.size()
		fight.step(intent_for(fight))
		_note_waves(fight, directed_before, trace)
		trace["loads"].append({"at": fight.time, "load": melee_load(fight)})
		_note_waits(fight, queued_for, trace)
		_note_fires(fight, fired_before, trace)
		_note_grants(fight, events_before, pressed_before, trace)
		_note_alive(fight, trace)
		_note_pools(fight, trace)
		_note_shown(fight, trace)
	trace["summons"] = fight.events.filter(func(event: Dictionary) -> bool:
		return event["what"] == "summoned" and event["at"] > 0.0).size()
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


## The minions that waited longer than LONGEST_WAIT for a token they kept.
## A minion still waiting when the fight ends has its wait so far counted.
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


## The ranged minions' grants at a step that began with the player pressed.
static func granted_under_pressure(trace: Dictionary) -> Array:
	return trace["granted_pressed"]


## The ranged minions' grants inside a hold: within the pool's pressed
## ranged delay after a "held_fire" event -- read from the pool, not from
## the fight, so a fight that shortens its hold is caught. {at, held_at}.
static func granted_while_holding(fight: BossFight) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var hold: float = fight.tokens.delay_for(BossMinion.RANGED, BossFightRules.PRESSED)
	var holds: Array = fight.events.filter(func(event: Dictionary) -> bool: return event["what"] == "held_fire")
	for grant: Dictionary in ranged_grants(fight):
		for held: Dictionary in _holds_over(holds, grant["at"], hold):
			found.append({"at": grant["at"], "held_at": held["at"]})
	return found


# The holds, of `seconds` each, that `at` falls inside.
static func _holds_over(holds: Array, at: float, seconds: float) -> Array:
	return holds.filter(func(held: Dictionary) -> bool: return at >= held["at"] and at < held["at"] + seconds)


## The grants of a ranged token to a minion, in order.
static func ranged_grants(fight: BossFight) -> Array:
	return fight.tokens.events.filter(func(event: Dictionary) -> bool:
		return event["what"] == AttackTokens.GRANTED and event["kind"] == BossMinion.RANGED and event["id"] != BossBrain.ID)


## Each kind that stood above its cap at some step: "kind: most".
static func above_the_cap(fight: BossFight, trace: Dictionary) -> PackedStringArray:
	var found := PackedStringArray()
	for kind: String in trace["most_alive"]:
		if trace["most_alive"][kind] > fight.rules.wave_cap.get(kind, 0):
			found.append("%s: %d" % [kind, trace["most_alive"][kind]])
	return found


## Each kind whose pool, at some step, was not `fields`' -- one level of
## `difficulty.json` as the file writes it: "kind: sizes seen".
static func off_the_pools(trace: Dictionary, fields: Dictionary) -> PackedStringArray:
	var found := PackedStringArray()
	for kind: String in BossDifficulty.KINDS:
		var wanted: int = int(fields["tokens"]["pools"][kind])
		var seen: Array = trace["pools"].get(kind, {}).keys()
		if seen != [wanted]:
			found.append("%s: %s" % [kind, seen])
	return found


## The waves that brought more of a kind than the level's wave: "kind at
## time: count". The minions a wave adds are its "summoned" events at one
## instant, each named by its kind.
static func waves_too_big(fight: BossFight) -> PackedStringArray:
	var counts: Dictionary = {}
	for event: Dictionary in fight.events:
		if event["what"] == "summoned":
			var key: String = "%s at %.2f" % [str(event["who"]).get_slice("-", 0), event["at"]]
			counts[key] = counts.get(key, 0) + 1
	var found := PackedStringArray()
	for key: String in counts:
		if counts[key] > fight.rules.wave.get(key.get_slice(" ", 0), 0):
			found.append("%s: %d" % [key, counts[key]])
	return found


## The boss's attacks shown for less than `minimum` seconds: {attack, telegraph}.
static func telegraphs_under(fight: BossFight, minimum: float) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for event: Dictionary in fight.boss.events:
		if event["what"] == "attack" and event["telegraph"] < minimum - 0.0001:
			found.append({"attack": event["attack"], "telegraph": event["telegraph"]})
	return found


## The director's waves that came out of turn: in a relief, in a peak
## without a phase summoning them, or while a heavy blow was underway.
static func waves_out_of_turn(fight: BossFight, trace: Dictionary) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for event: Dictionary in fight.director.events:
		var allowed: bool = event["state"] == BossDirector.BUILD_UP or (event["state"] == BossDirector.PEAK and event.get("summon", false))
		if event["what"] == "wave" and not allowed:
			found.append(event)
	for at: float in trace["waved_heavy"]:
		found.append({"at": at, "what": "wave in a heavy blow"})
	return found


## The reliefs that ended in build-up before the rules' relief seconds --
## read from the rules, so a director that cuts its own is caught.
static func short_reliefs(fight: BossFight) -> Array[float]:
	var found: Array[float] = []
	var relief_from: float = -1.0
	for event: Dictionary in fight.director.events:
		if event["what"] != "pacing":
			continue
		if event["state"] == BossDirector.BUILD_UP and relief_from >= 0.0 and event["at"] - relief_from < float(fight.rules.director["relief_seconds"]) - 0.0001:
			found.append(relief_from)
		relief_from = event["at"] if event["state"] == BossDirector.RELIEF else -1.0
	return found


## The overlay's lists that never named anyone: "holders", "queue", "claims".
static func never_named(trace: Dictionary) -> PackedStringArray:
	var found := PackedStringArray()
	for field: String in ["holders", "queue", "claims"]:
		if not trace["shown"].get(field, false):
			found.append(field)
	return found


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


# A wait is the time a minion spends queued since it last kept a token: it
# grows only while the minion is in the queue -- a request withdrawn while
# the ranged hold fire pauses it, the hold being the rule and not the pool
# passing it over -- and ends only when the minion holds a token at the end
# of a step, or falls. A grant taken back in its own step is no turn.
func _note_waits(fight: BossFight, queued_for: Dictionary, trace: Dictionary) -> void:
	for minion: BossMinion in fight.minions:
		if not minion.alive() or minion.holds_token(fight.tokens):
			queued_for.erase(minion.id)
			continue
		if not (minion.id in fight.tokens.waiting(minion.kind)):
			continue
		queued_for[minion.id] = queued_for.get(minion.id, 0.0) + fight.rules.step_seconds
		var record: Dictionary = trace["waits"].get(minion.id, {"longest": 0.0})
		record["longest"] = maxf(record["longest"], queued_for[minion.id])
		trace["waits"][minion.id] = record


static func _pressure(fight: BossFight) -> bool:
	return fight.minions.any(func(minion: BossMinion) -> bool: return minion.state in BossMinion.PRESSING)


func _note_grants(fight: BossFight, events_before: int, pressed_before: bool, trace: Dictionary) -> void:
	for index: int in range(events_before, fight.tokens.events.size()):
		var event: Dictionary = fight.tokens.events[index]
		var ranged: bool = event["kind"] == BossMinion.RANGED and event["id"] != BossBrain.ID
		if pressed_before and ranged and event["what"] == AttackTokens.GRANTED:
			trace["granted_pressed"].append({"at": event["at"], "who": event["id"]})


# A wave the director sent this step while the boss was in a heavy blow.
func _note_waves(fight: BossFight, directed_before: int, trace: Dictionary) -> void:
	for index: int in range(directed_before, fight.director.events.size()):
		if fight.director.events[index]["what"] == "wave" and fight.boss.heavy_underway():
			trace["waved_heavy"].append(fight.time)


# Each kind's pool as the pool itself counts it: free and held.
func _note_pools(fight: BossFight, trace: Dictionary) -> void:
	for kind: String in BossDifficulty.KINDS:
		var sizes: Dictionary = trace["pools"].get(kind, {})
		sizes[fight.tokens.free_tokens(kind) + fight.tokens.held(kind)] = true
		trace["pools"][kind] = sizes


func _note_alive(fight: BossFight, trace: Dictionary) -> void:
	for kind: String in [BossMinion.MELEE, BossMinion.RANGED]:
		trace["most_alive"][kind] = maxi(trace["most_alive"].get(kind, 0), fight.alive_of(kind))


func _note_shown(fight: BossFight, trace: Dictionary) -> void:
	var shown: Dictionary = BossFightShown.overlay(fight)
	var lists: Array = []
	for kind: String in [BossMinion.MELEE, BossMinion.RANGED]:
		lists.append(["holders", shown["tokens"][kind]["holders"]])
		lists.append(["queue", shown["tokens"][kind]["queue"]])
	for ring: Dictionary in shown["rings"]:
		lists.append(["claims", ring["claims"]])
	for pair: Array in lists:
		if pair[1][0] != BossFightShown.NONE:
			trace["shown"][pair[0]] = true


func _note_fires(fight: BossFight, fired_before: Dictionary, trace: Dictionary) -> void:
	var pressure: bool = _pressure(fight)
	for minion: BossMinion in fight.minions:
		if minion.kind != BossMinion.RANGED or minion.fired == fired_before.get(minion.id, 0):
			continue
		fired_before[minion.id] = minion.fired
		trace["fired"] += 1
		if pressure:
			trace["fired_pressed"].append({"at": fight.time, "who": minion.id})
