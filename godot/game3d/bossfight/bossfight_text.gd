## The words beside the boss fight: the level and its numbers, who holds
## each token and who is queued, the reissue timer with its multiplier, the
## director and its next wave, each ring's claims, and the words over each
## head. Text, so a person can read the numbers the floor draws.
class_name BossfightText
extends RefCounted

## The ring names, as the rings call them, worded for the panel.
const RING_NAMES: Dictionary = {  # shown through tr()
	EngagementRings.INNER: "inner ring", EngagementRings.WAITING: "waiting ring", EngagementRings.RANGED: "ranged band",
}
## The levels' names, as `difficulty.json` writes them: data the translation
## gate cannot read, so named here for it.
const LEVEL_NAMES: Array[String] = ["easy", "normal", "hard"]  # shown through tr()
## The minions' and the boss's states, as the code names them.
const STATES: Array[String] = [  # shown through tr()
	"circling", "closing", "winding", "striking", "aiming", "recovering", "staggered", "fallen",
	"telegraph", "active", "recovery", "waiting", "defeated",
]


## The panel: your health and the boss's, the level and every number it
## sets, the player's state, each kind's tokens and timer, the director,
## each ring's claims; with the reasoning hidden, only the health and the
## level. A fight that cannot start says why.
static func panel(fight: BossFight, thinking: bool) -> String:
	var lines: PackedStringArray = [_health(fight)]
	if fight.refusal() != "":
		lines.append(TranslationServer.translate("The fight cannot start: {why}").format({"why": fight.refusal()}))
	if fight.outcome != "":
		lines.append(_outcome(fight))
	lines.append_array(_level(fight))
	if not thinking:
		return "\n".join(lines)
	lines.append(_director(fight))
	lines.append(_pressure(fight))
	for kind: String in [BossMinion.MELEE, BossMinion.RANGED]:
		lines.append_array(_tokens(fight, kind))
	for ring: Dictionary in BossFightShown.rings(fight):
		lines.append(TranslationServer.translate("{ring}: {claims}").format({"ring": TranslationServer.translate(RING_NAMES[ring["ring"]]),
			"claims": _names(ring["claims"])}))
	return "\n".join(lines)


## Over a minion: its name, what it does, and its place in the queue.
static func over_minion(fight: BossFight, minion: BossMinion) -> String:
	var words: String = "%s %s" % [minion.id, TranslationServer.translate(minion.state)]
	var queue: PackedStringArray = fight.tokens.waiting(minion.kind)
	if minion.id in queue:
		words += " " + TranslationServer.translate("#{place} in the queue").format({"place": queue.find(minion.id) + 1})
	return words


## Over the boss: its phase, and the attack it winds up or swings.
static func over_boss(fight: BossFight) -> String:
	var seen: Dictionary = BossFightShown.boss(fight)
	if seen["attack"] == BossFightShown.NONE:
		return TranslationServer.translate("{phase}: {state}").format({"phase": seen["phase"], "state": TranslationServer.translate(seen["state"])})
	return TranslationServer.translate("{phase}: {state} {attack}").format({"phase": seen["phase"], "state": TranslationServer.translate(seen["state"]), "attack": seen["attack"]})


# The level, Tab to change it, and what it sets: nothing it gives the
# boss's side is hidden.
static func _level(fight: BossFight) -> PackedStringArray:
	var shown: Dictionary = BossFightShown.difficulty(fight)
	var named: String = TranslationServer.translate("level {level} (Tab changes it): tells x {speed}, never under {least} s").format({
		"level": TranslationServer.translate(shown["level"]), "speed": Language.decimal(shown["telegraph_scale"], 2),
		"least": Language.decimal(shown["minimum_telegraph"], 2)})
	var lines: PackedStringArray = [named]
	for kind: String in [BossMinion.MELEE, BossMinion.RANGED]:
		lines.append(TranslationServer.translate("   {kind}: {pool} tokens, {delay} s apart; waves of {wave}, at most {cap} standing").format({
			"kind": TranslationServer.translate(kind), "pool": shown[kind]["pool"], "delay": Language.decimal(shown[kind]["delay"], 1),
			"wave": shown[kind]["wave"], "cap": shown[kind]["cap"]}))
	return lines


# The director: its state and what the next wave waits for.
static func _director(fight: BossFight) -> String:
	var shown: Dictionary = BossFightShown.director(fight)
	return TranslationServer.translate("director: {state}, wave {waves}; {waits}").format({
		"state": TranslationServer.translate(shown["pacing"]), "waves": shown["waves"], "waits": _next_wave(fight, shown)})


# What the next wave waits for, worded: the heavy blow, fewer standing (or
# the peak's end), the relief's end, or the time left.
static func _next_wave(fight: BossFight, shown: Dictionary) -> String:
	var left: String = Language.decimal(shown["next_wave_in"], 1)
	match shown["waits_for"]:
		BossDirector.WAITS_FOR_HEAVY:
			return TranslationServer.translate("the next wave waits for the heavy blow to end")
		BossDirector.WAITS_FOR_FEWER:
			var peak_left: float = maxf(0.0, fight.director.since + fight.director.peak_seconds - fight.time)
			var words: Dictionary = {"least": fight.director.relief_at, "left": Language.decimal(peak_left, 1)}
			return TranslationServer.translate("no wave until {least} or fewer stand, or {left} s pass").format(words)
		BossDirector.WAITS_FOR_RELIEF:
			return TranslationServer.translate("a pause: build-up again in {left} s").format({"left": left})
	return TranslationServer.translate("the next wave in {left} s").format({"left": left})


static func _health(fight: BossFight) -> String:
	return TranslationServer.translate("you {you}%   boss {boss}%").format({"you": roundi(fight.player.health * 100.0),
		"boss": roundi(fight.boss.health * 100.0)})


static func _outcome(fight: BossFight) -> String:
	if fight.outcome == BossFight.WON:
		return TranslationServer.translate("The boss is down. N fights again.")
	return TranslationServer.translate("You fell. N fights again.")


static func _pressure(fight: BossFight) -> String:
	if fight.pressed:
		return TranslationServer.translate("pressed: a melee minion is on you, so the ranged lose their tokens and hold fire")
	if fight.holding_fire():
		return TranslationServer.translate("holding fire: the ranged ask again in {left} s, after melee was on you").format(
			{"left": Language.decimal(fight.held_fire_until - fight.time, 1)})
	return TranslationServer.translate("free: no melee minion is striking, so the ranged may shoot")


# A kind's two lines: who holds and who waits, then the reissue timer.
static func _tokens(fight: BossFight, kind: String) -> PackedStringArray:
	var shown: Dictionary = BossFightShown.tokens(fight, kind)
	var held: String = TranslationServer.translate("{kind} tokens {free} of {pool} free; held by {holders}; queue {queue}").format({
		"kind": TranslationServer.translate(kind), "free": shown["free"], "pool": shown["pool"],
		"holders": _names(shown["holders"]), "queue": _names(shown["queue"])})
	var timer: String = TranslationServer.translate("   next in {left} s: delay {delay} s x {factor}, set while {state}").format({
		"left": Language.decimal(shown["next_in"], 1), "delay": Language.decimal(shown["delay"], 1),
		"factor": Language.decimal(shown["factor"], 1), "state": TranslationServer.translate(shown["set_while"])})
	return PackedStringArray([held, timer])


# A list of names, or "none" in the language on screen.
static func _names(names: PackedStringArray) -> String:
	if names[0] == BossFightShown.NONE:
		return TranslationServer.translate("none")
	return ", ".join(names)
