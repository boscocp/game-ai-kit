## The words beside the boss fight: who holds each token and who is queued,
## the reissue timer with its multiplier, each ring's claims, and the words
## over each head. Text, so a person can read the numbers the floor draws.
class_name BossfightText
extends RefCounted

## The ring names, as the rings call them, worded for the panel.
const RING_NAMES: Dictionary = {  # shown through tr()
	EngagementRings.INNER: "inner ring", EngagementRings.WAITING: "waiting ring", EngagementRings.RANGED: "ranged band",
}
## The minions' and the boss's states, as the code names them.
const STATES: Array[String] = [  # shown through tr()
	"circling", "closing", "winding", "striking", "aiming", "recovering", "staggered", "fallen",
	"telegraph", "active", "recovery", "waiting", "defeated",
]


## The panel: your health and the boss's, the player's state, each kind's
## tokens and timer, each ring's claims; or only the health and the keys
## with the reasoning hidden.
static func panel(fight: BossFight, thinking: bool) -> String:
	var lines: PackedStringArray = [_health(fight)]
	if fight.outcome != "":
		lines.append(_outcome(fight))
	if not thinking:
		return "\n".join(lines)
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


static func _health(fight: BossFight) -> String:
	return TranslationServer.translate("you {you}%   boss {boss}%").format({"you": roundi(fight.player.health * 100.0),
		"boss": roundi(fight.boss.health * 100.0)})


static func _outcome(fight: BossFight) -> String:
	if fight.outcome == BossFight.WON:
		return TranslationServer.translate("The boss is down. N fights again.")
	return TranslationServer.translate("You fell. N fights again.")


static func _pressure(fight: BossFight) -> String:
	if fight.pressed:
		return TranslationServer.translate("pressed: a melee minion is on you, so every ranged token is taken back")
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
