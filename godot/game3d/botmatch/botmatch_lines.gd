## The panel's lines of what the watched bot is reasoning with, one per
## decision: where it aimed and what each zone was worth, its errands, and
## its last weighing of the ways past a body. Read off the bot, built here
## so the scene keeps to drawing and keys.
class_name BotMatchLines
extends RefCounted


## The watched bot's last aim: each zone's own chance and expected damage,
## and the zone it aimed at; empty before its first shot.
static func aim_overlay(bot: MatchBot) -> Dictionary:
	if bot.last_aim.is_empty():
		return {}
	var zones: Array = []
	for index: int in range((bot.last_aim[1] as Array).size()):
		zones.append({"zone": bot.last_aim[1][index], "chance": bot.last_aim[2][index], "expected": bot.last_aim[3][index]})
	return {"target": bot.last_aim[0], "aimed": bot.last_aim[1][bot.last_aim[4]], "zones": zones}


## One line for the panel: "aims at torso: head 5% 0.10 | torso ...".
static func aim_line(bot: MatchBot) -> String:
	var aim: Dictionary = aim_overlay(bot)
	if aim.is_empty():
		return "no shot aimed yet"
	var parts: Array[String] = []
	for zone: Dictionary in aim["zones"]:
		parts.append("%s %.0f%% %.2f" % [zone["zone"], float(zone["chance"]) * 100.0, zone["expected"]])
	return "aims at %s (chance, damage a shot): %s" % [aim["aimed"], " | ".join(parts)]


## One line for the panel: its weapon and rounds, and each errand's score
## as gain - walk - cost, the one it took marked.
static func errand_line(bot: MatchBot) -> String:
	var parts: Array[String] = []
	for errand: String in bot.errand_weighing:
		var weighed: Array = bot.errand_weighing[errand]
		var mark: String = "> " if errand == bot.errand else ""
		parts.append("%s%s %.2f - %.1f s - %.2f = %.2f" % [mark, errand, weighed[0], weighed[1], weighed[2], weighed[3]])
	var rounds: String = "%s %d/%d, streak %d" % [bot.weapon, bot.ammo, bot.reserve, bot.streak]
	return "%s; errands: %s" % [rounds, " | ".join(parts) if not parts.is_empty() else "none weighed yet"]


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
