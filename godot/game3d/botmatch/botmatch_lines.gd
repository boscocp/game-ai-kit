## The panel's lines of what the watched bot is reasoning with, one per
## decision: every action's score, where it aimed and what each zone was
## worth, its errands, and its last weighing of the ways past a body. Read
## off the bot, built here so the scene keeps to drawing and keys.
class_name BotMatchLines
extends RefCounted


## The watched bot's last weighing of what to do: each action's score, and
## the one it took; before its first decision, that there was none.
static func action_overlay(bot: MatchBot) -> Dictionary:
	if bot.last_choice == null:
		return {"weighed": "not yet"}
	var scores: Dictionary = {}
	for index: int in range(bot.actions.size()):
		scores[bot.actions[index].name] = bot.last_choice.scores[index]
	var chosen: int = bot.last_choice.chosen
	var found: Dictionary = {"chosen": bot.actions[chosen].name if chosen != -1 else "none", "scores": scores}
	if bot.last_posture != null:
		found["posture"] = _scores(bot.postures, bot.last_posture)
	if bot.last_pace != null:
		found["pace"] = _scores(bot.paces, bot.last_pace)
	return found


static func _scores(options: Array[ActionChoice.Action], choice: ActionChoice.Choice) -> Dictionary:
	var scores: Dictionary = {}
	for index: int in range(options.size()):
		scores[options[index].name] = choice.scores[index]
	return scores


## One line for the panel: "weighs: > shoot 0.92 | reload 0.00 | ...",
## then its posture's weighing: "body: stand 0.33 | > crouch 0.51".
static func action_line(bot: MatchBot) -> String:
	if bot.last_choice == null:
		return "nothing weighed yet"
	var line: String = "weighs: %s" % _weighing(bot.actions, bot.last_choice)
	if bot.last_posture != null:
		line += "   body: %s" % _weighing(bot.postures, bot.last_posture)
	if bot.last_pace != null:
		line += "   pace: %s" % _weighing(bot.paces, bot.last_pace)
	return line


static func _weighing(options: Array[ActionChoice.Action], choice: ActionChoice.Choice) -> String:
	var parts: Array[String] = []
	for index: int in range(options.size()):
		var mark: String = "> " if index == choice.chosen else ""
		parts.append("%s%s %.2f" % [mark, options[index].name, choice.scores[index]])
	return " | ".join(parts)


## The watched bot's last aim: each zone's own chance and expected damage,
## and the zone it aimed at; before its first shot, that there was none.
static func aim_overlay(bot: MatchBot) -> Dictionary:
	if bot.last_aim.is_empty():
		return {"aimed": "no shot yet"}
	var zones: Array = []
	for index: int in range((bot.last_aim[1] as Array).size()):
		zones.append({"zone": bot.last_aim[1][index], "chance": bot.last_aim[2][index], "expected": bot.last_aim[3][index]})
	return {"target": bot.last_aim[0], "aimed": bot.last_aim[1][bot.last_aim[4]], "zones": zones}


## One line for the panel: "aims at torso: head 5% 0.10 | torso ...".
static func aim_line(bot: MatchBot) -> String:
	if bot.last_aim.is_empty():
		return "no shot aimed yet"
	var aim: Dictionary = aim_overlay(bot)
	var parts: Array[String] = []
	for zone: Dictionary in aim["zones"]:
		parts.append("%s %.0f%% %.2f" % [zone["zone"], float(zone["chance"]) * 100.0, zone["expected"]])
	return "aims at %s (chance, damage a shot): %s" % [aim["aimed"], " | ".join(parts)]


## One line for the panel: its weapon and rounds, and each errand's score
## as gain - walk x its weight - cost, the one it took marked, so the sum
## on the screen is the sum the bot made.
static func errand_line(bot: MatchBot) -> String:
	var parts: Array[String] = []
	for errand: String in bot.errand_weighing:
		var weighed: Array = bot.errand_weighing[errand]
		var mark: String = "> " if errand == bot.errand else ""
		var weight: float = (weighed[0] - weighed[2] - weighed[3]) / weighed[1] if weighed[1] > 0.0 else 0.0
		parts.append("%s%s %.2f - %.1f s x %.2f - %.2f = %.2f" % [mark, errand, weighed[0], weighed[1], weight, weighed[2], weighed[3]])
	var rounds: String = "%s %d/%d, streak %d" % [bot.weapon, bot.ammo, bot.reserve, bot.streak]
	return "%s; errands: %s" % [rounds, " | ".join(parts) if not parts.is_empty() else "none weighed yet"]


## The watched bot's last weighing of the ways past a body: each way and
## its cost in seconds, or "impossible", the one taken, and the teammate's
## answer; before it was ever blocked, that it was not.
static func passage_overlay(bot: MatchBot) -> Dictionary:
	if bot.last_passage.is_empty():
		return {"blocked": "never yet"}
	var costs: Dictionary = {}
	for index: int in range(PassageChoice.WAYS.size()):
		var cost: float = bot.last_passage["costs"][index]
		costs[PassageChoice.WAYS[index]] = "impossible" if is_inf(cost) else cost
	var answer: String = str(bot.last_passage.get("answer", ""))
	return {"blocker": bot.last_passage["blocker"], "costs": costs, "chosen": bot.last_passage["chosen"],
			"answer": answer if answer != "" else "none asked"}


## One line for the panel: the ways past the last body in its way, each
## one's cost in seconds, the one taken marked, and the teammate's answer.
static func passage_line(bot: MatchBot) -> String:
	if bot.last_passage.is_empty():
		return "never blocked yet"
	var parts: Array[String] = []
	var costs: PackedFloat64Array = bot.last_passage["costs"]
	for index: int in range(PassageChoice.WAYS.size()):
		var way: String = PassageChoice.WAYS[index]
		var mark: String = "> " if way == bot.last_passage["chosen"] else ""
		parts.append("%s%s %s" % [mark, way, "-" if is_inf(costs[index]) else "%.1f s" % costs[index]])
	var answer: String = str(bot.last_passage.get("answer", ""))
	var reply: String = "" if answer == "" else " (bot %d %s it: saves %.1f s, costs it %.1f s)" % [
			bot.last_passage["blocker"], answer, bot.last_passage["saves"], bot.last_passage["their_cost"]]
	return "past bot %d: %s%s" % [bot.last_passage["blocker"], " | ".join(parts), reply]
