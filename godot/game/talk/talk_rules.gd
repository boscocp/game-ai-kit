## The guard at the door: what each act the player made does to his trust.
##
## `gate.json` beside this file is a byte-for-byte copy of
## `spec/talk/gate.json`, which `gameaikit.talk` reads too, and its "about"
## is these rules in words. The language model never reaches this file: it
## said which act the player's words were, `LlmValidator` ruled on that, and
## only the act -- an intent and its argument -- arrives here. A refused
## reply arrives as `unclear`, which moves nothing and spends a turn.
##
## The rules are a list read top to bottom, the first that fits deciding.
## An act is written `intent:argument`, or the bare intent when it has no
## argument -- which the validator allows every intent, so `claim_role` alone
## is a role the model could not place. In a rule, `intent:*` is any act of
## that intent with an argument. A rule fits when its `act` names the act
## and, if it has `if_any`, when one of the acts named there -- other than
## this very act -- was made before. It moves two numbers: trust, which opens the door at
## `open_at`, and suspicion, which sounds the alarm at `alarm_at`. Saying
## the same thing twice wins no trust the second time and costs its
## suspicion again -- except `unclear`, which is nothing understood. The
## vectors in `spec/vectors/talk/` hold this file and `gameaikit.talk.rules`
## to the same numbers after every line.
##
## When not to use it: for a conversation whose outcome should be the
## model's to judge. Here no sentence the model writes can open the door.
class_name TalkRules
extends RefCounted

const SCENE_FILE: String = "res://game/talk/gate.json"
const PLAYING: String = "playing"  # not shown: an outcome's identifier, worded by TalkPanel
const OPEN: String = "open"  # not shown: an outcome's identifier
const ALARM: String = "alarm"  # not shown: an outcome's identifier
const SENT_AWAY: String = "sent_away"  # not shown: an outcome's identifier

static var _scene: Dictionary = {}


## The scene: intents, secrets, thresholds, each language's words, the rules.
static func scene() -> Dictionary:
	if _scene.is_empty():
		var reader := JSON.new()
		if reader.parse(FileAccess.get_file_as_string(SCENE_FILE)) == OK and reader.data is Dictionary:
			_scene = reader.data
	return _scene


## A guard who has heard nothing yet.
static func new_guard() -> Dictionary:
	return {"trust": 0, "suspicion": 0, "turn": 0, "said": [], "outcome": PLAYING}


## The act as the rules spell it: `intent:argument`, or the intent alone.
static func act_of(intent: String, argument: String) -> String:
	return "%s:%s" % [intent, argument] if argument != "" else intent


## The first rule that fits `act`, given the acts already `said`; {} when
## none does, which `why_scene_is_wrong` makes impossible for a known act.
static func rule_for(act: String, said: Array) -> Dictionary:
	for rule: Dictionary in scene()["rules"]:
		if names(rule["act"], act) and _fits(rule, said, act):
			return rule
	return {}


## True when `written`, as a rule spells acts, names `act`: the act itself,
## or `intent:*` for any act of that intent with an argument.
static func names(written: String, act: String) -> bool:
	if written.ends_with(":*"):
		return act.contains(":") and act.get_slice(":", 0) == written.trim_suffix(":*")
	return written == act


# True when `rule` has no `if_any`, or one of the acts it names was said
# before as some act other than `act`.
static func _fits(rule: Dictionary, said: Array, act: String) -> bool:
	if not rule.has("if_any"):
		return true
	for earlier: String in rule["if_any"]:
		if _was_said(earlier, said, act):
			return true
	return false


## One more act: the rule that fired, what it moved, and the guard after it,
## as `{act, rule, trust, suspicion, guard}`. A decided guard stays decided.
static func step(guard: Dictionary, intent: String, argument: String) -> Dictionary:
	var act: String = act_of(intent, argument)
	if guard["outcome"] != PLAYING:
		return {"act": act, "rule": "", "trust": 0, "suspicion": 0, "guard": guard}
	var rule: Dictionary = rule_for(act, guard["said"])
	var trust: int = int(rule.get("trust", 0))
	var suspicion: int = int(rule.get("suspicion", 0))
	var fired: String = rule.get("id", "")
	if act in guard["said"] and not (act in scene()["said_before"]["except"]):
		trust = 0
		fired = scene()["said_before"]["id"]
	var said: Array = (guard["said"] as Array).duplicate()
	said.append(act)
	var after: Dictionary = {"trust": int(guard["trust"]) + trust,
			"suspicion": int(guard["suspicion"]) + suspicion,
			"turn": int(guard["turn"]) + 1, "said": said, "outcome": PLAYING}
	after["outcome"] = outcome_of(after)
	return {"act": act, "rule": fired, "trust": trust, "suspicion": suspicion, "guard": after}


## The alarm first, then the door, then the last turn; otherwise playing.
## The alarm wins a tie: a guard both trusting and alarmed calls it in.
static func outcome_of(guard: Dictionary) -> String:
	if int(guard["suspicion"]) >= int(scene()["alarm_at"]):
		return ALARM
	if int(guard["trust"]) >= int(scene()["open_at"]):
		return OPEN
	if int(guard["turn"]) >= int(scene()["turns"]):
		return SENT_AWAY
	return PLAYING


## A rule's reason in `language` (`en` or `pt_BR`), or "" for no rule.
static func why_of(rule_id: String, language: String) -> String:
	if rule_id == scene()["said_before"]["id"]:
		return scene()["said_before"]["why"][language]
	for rule: Dictionary in scene()["rules"]:
		if rule["id"] == rule_id:
			return rule["why"][language]
	return ""


## The words of `language`: instructions, fallback line, endings.
static func words(language: String) -> Dictionary:
	return scene()["languages"][language]


## What the validator holds the model's replies to, in `language`.
static func validator(language: String) -> LlmValidator:
	return LlmValidator.new(scene()["intents"], words(language)["fallback"],
		PackedStringArray(scene()["secrets"]))


## Why the scene cannot be played, or "": every act needs a rule, the rules
## may name only acts the guard understands, and no secret may be in the
## instructions -- the same three checks as `gameaikit.talk.rules`.
static func why_scene_is_wrong() -> String:
	if scene().is_empty():
		return "%s cannot be read" % SCENE_FILE  # not shown: a test's message
	for act: String in every_act():
		if rule_for(act, every_act()).is_empty():
			return "the act %s has no rule" % act  # not shown: a test's message
	for rule: Dictionary in scene()["rules"]:
		var named: String = _unknown_act_in(rule)
		if named != "":
			return "the rule %s names %s, which is not an act" % [rule["id"], named]  # not shown: a test's message
	for language: String in scene()["languages"]:
		if validator(language).gives_away_a_secret(words(language)["instructions"]):
			return "the %s instructions contain a secret" % language  # not shown: a test's message
	return ""


# The first act `rule` names that no act the guard understands answers to, or "".
static func _unknown_act_in(rule: Dictionary) -> String:
	var acts: Array[String] = every_act()
	for named: String in [rule["act"]] + Array(rule.get("if_any", [])):
		if not acts.any(func(act: String) -> bool: return names(named, act)):
			return named
	return ""


## Every act the validator can hand the guard: each intent with each of its
## arguments, and each intent alone -- an empty argument passes R7 for every
## intent, not only for those that take none.
static func every_act() -> Array[String]:
	var acts: Array[String] = []
	for intent: String in scene()["intents"]:
		for argument: String in scene()["intents"][intent]:
			acts.append(act_of(intent, argument))
		acts.append(intent)
	return acts


# True when an act `earlier` names was said, as some act other than `act`:
# one role claimed twice is one role.
static func _was_said(earlier: String, said: Array, act: String) -> bool:
	for other: String in said:
		if other != act and names(earlier, other):
			return true
	return false
