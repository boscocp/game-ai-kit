## The panel's lines of what the watched bot is reasoning with, one per
## decision: every action's score, where it aimed and what each zone was
## worth, its errands, and its last weighing of the ways past a body. Read
## off the bot, built here so the scene keeps to drawing and keys.
##
## The panel is rebuilt every frame, as it was before T80. Each sentence is
## one key with named placeholders, and each name in it an identifier the
## bot compares, translated where it is shown (`BotMatchWords`). A lookup
## measured 0.56 us on 4.7.2 (docs/godot/localisation.md): the forty or so
## a frame cost about a fortieth of a millisecond. The overlays below are
## the gate's, never drawn, and keep their English.
class_name BotMatchLines
extends RefCounted

## A team's switch, as the panel says it: on, then off.
const ON_OFF: Array[String] = ["on", "OFF"]  # shown through tr()
## The score: while watching, once the match is over, and while a person
## plays with the AI's thinking hidden and shown.
const SCORE: Array[String] = [  # shown through tr()
	"{time} s   blue {blue} - {red} red",
	"{time} s   blue {blue} - {red} red   (over)",
	"{time} s   blue {blue} - {red} red     T give it back, V show the AI's thinking",
	"{time} s   blue {blue} - {red} red     T give it back, V hide the AI's thinking",
]
## The last body in its way, by the teammate's answer: none asked, granted,
## refused -- one sentence each, so no verb is glued in.
const PASSED: Array[String] = [  # shown through tr()
	"past bot {blocker}: {ways}",
	"past bot {blocker}: {ways} (bot {blocker} granted it: saves {saves} s, costs it {cost} s)",
	"past bot {blocker}: {ways} (bot {blocker} refused it: saves {saves} s, costs it {cost} s)",
]


## The whole panel while watching bot `watched`, and while a person plays bot
## `played` (-1 when nobody does), with the AI's thinking `thinking_shown`.
static func panel(world: BotMatch, watched: int, played: int, thinking_shown: bool) -> String:
	if played != -1:
		return TranslationServer.translate(SCORE[3 if thinking_shown else 2]).format(_score(world))
	var lines: Array[String] = [TranslationServer.translate(SCORE[1 if world.over() else 0]).format(_score(world))]
	for team: MatchTeam in world.teams:
		lines.append(TranslationServer.translate("{team}: claims {claims}, commander {commander}, retreat {retreat}").format({
			team = BotMatchWords.word(team.name),
			claims = _on(team.use_claims), commander = _on(team.use_commander), retreat = _on(team.may_retreat)}))
	var bot: MatchBot = world.bots[watched]
	lines.append(_watching(world, bot, played))
	lines.append(action_line(bot))
	lines.append(aim_line(bot))
	lines.append(errand_line(bot))
	lines.append(passage_line(bot))
	lines.append(TranslationServer.translate("1/2/3 blue's switches, Shift red's; Tab bot, T take it over, M map, C camera, F fast, P pause, N new, L arena"))
	return "\n".join(lines)


static func _score(world: BotMatch) -> Dictionary:
	return {time = "%.0f" % world.time, blue = "%.0f" % world.score[0], red = "%.0f" % world.score[1]}


static func _on(value: bool) -> String:
	return TranslationServer.translate(ON_OFF[0 if value else 1])


# Which bot is watched, what it is doing and at whom; and, played, its rounds.
static func _watching(world: BotMatch, bot: MatchBot, played: int) -> String:
	var words: Dictionary = {bot = bot.id, team = BotMatchWords.word(world.teams[bot.team].name),
		action = BotMatchWords.word(bot.action), target = bot.target}
	var line: String = TranslationServer.translate("watching bot {bot} ({team}): {action}").format(words)
	if bot.target != -1:
		line = TranslationServer.translate("watching bot {bot} ({team}): {action} at bot {target}").format(words)
	if played == bot.id:
		line += TranslationServer.translate("  -- YOU: {ammo}/{magazine} ammo, {health}").format({ammo = bot.ammo,
			magazine = world.rules.magazine, health = BotMatchHud.health_text(world.rules, bot, world.time)})
	return line


## The watched bot's last weighing of what to do: each action's score, and
## the one it took; before its first decision, that there was none.
static func action_overlay(bot: MatchBot) -> Dictionary:
	if bot.last_choice == null:
		return {"weighed": "not yet"}  # not shown
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
		return TranslationServer.translate("nothing weighed yet")
	var parts: Array[String] = [TranslationServer.translate("weighs: {options}").format({
		options = _weighing(bot.actions, bot.last_choice)})]
	if bot.last_posture != null:
		parts.append(TranslationServer.translate("body: {options}").format({
			options = _weighing(bot.postures, bot.last_posture)}))
	if bot.last_pace != null:
		parts.append(TranslationServer.translate("pace: {options}").format({
			options = _weighing(bot.paces, bot.last_pace)}))
	return "   ".join(parts)


static func _weighing(options: Array[ActionChoice.Action], choice: ActionChoice.Choice) -> String:
	var parts: Array[String] = []
	for index: int in range(options.size()):
		var mark: String = "> " if index == choice.chosen else ""
		parts.append("%s%s %.2f" % [mark, BotMatchWords.word(options[index].name), choice.scores[index]])
	return " | ".join(parts)


## The watched bot's last aim: each zone's own chance and expected damage,
## and the zone it aimed at; before its first shot, that there was none.
static func aim_overlay(bot: MatchBot) -> Dictionary:
	if bot.last_aim.is_empty():
		return {"aimed": "no shot yet"}  # not shown
	var zones: Array = []
	for index: int in range((bot.last_aim[1] as Array).size()):
		zones.append({"zone": bot.last_aim[1][index], "chance": bot.last_aim[2][index], "expected": bot.last_aim[3][index]})
	return {"target": bot.last_aim[0], "aimed": bot.last_aim[1][bot.last_aim[4]], "zones": zones}


## One line for the panel: "aims at torso: head 5% 0.10 | torso ...".
static func aim_line(bot: MatchBot) -> String:
	if bot.last_aim.is_empty():
		return TranslationServer.translate("no shot aimed yet")
	var aim: Dictionary = aim_overlay(bot)
	var parts: Array[String] = []
	for zone: Dictionary in aim["zones"]:
		parts.append("%s %.0f%% %.2f" % [BotMatchWords.word(zone["zone"]), float(zone["chance"]) * 100.0, zone["expected"]])
	return TranslationServer.translate("aims at {zone} (chance, damage a shot): {zones}").format({
		zone = BotMatchWords.word(aim["aimed"]), zones = " | ".join(parts)})


## Two lines for the panel: its weapon and rounds, and each errand's score
## as gain - walk x its weight - cost, the one it took marked, so the sum
## on the screen is the sum the bot made.
static func errand_line(bot: MatchBot) -> String:
	var parts: Array[String] = []
	for errand: String in bot.errand_weighing:
		var weighed: Array = bot.errand_weighing[errand]
		var mark: String = "> " if errand == bot.errand else ""
		var weight: float = (weighed[0] - weighed[2] - weighed[3]) / weighed[1] if weighed[1] > 0.0 else 0.0
		parts.append(TranslationServer.translate("{mark}{errand} {gain} - {walk} s x {weight} - {cost} = {score}").format({
			mark = mark, errand = BotMatchWords.word(errand), gain = "%.2f" % weighed[0], walk = "%.1f" % weighed[1],
			weight = "%.2f" % weight, cost = "%.2f" % weighed[2], score = "%.2f" % weighed[3]}))
	var weighed_errands: String = " | ".join(parts) if not parts.is_empty() else TranslationServer.translate("none weighed yet")
	# Two lines: in Portuguese one ran off the window (T80).
	return TranslationServer.translate("{weapon} {ammo}/{reserve}, streak {streak}").format({
		weapon = BotMatchWords.word(bot.weapon), ammo = bot.ammo, reserve = bot.reserve, streak = bot.streak}) \
		+ "\n" + TranslationServer.translate("errands: {errands}").format({errands = weighed_errands})


## The watched bot's last weighing of the ways past a body: each way and
## its cost in seconds, or "impossible", the one taken, and the teammate's
## answer; before it was ever blocked, that it was not.
static func passage_overlay(bot: MatchBot) -> Dictionary:
	if bot.last_passage.is_empty():
		return {"blocked": "never yet"}  # not shown
	var costs: Dictionary = {}
	for index: int in range(PassageChoice.WAYS.size()):
		var cost: float = bot.last_passage["costs"][index]
		costs[PassageChoice.WAYS[index]] = "impossible" if is_inf(cost) else cost  # not shown
	var answer: String = str(bot.last_passage.get("answer", ""))
	return {"blocker": bot.last_passage["blocker"], "costs": costs, "chosen": bot.last_passage["chosen"],
			"answer": answer if answer != "" else "none asked"}  # not shown


## One line for the panel: the ways past the last body in its way, each
## one's cost in seconds, the one taken marked, and the teammate's answer.
static func passage_line(bot: MatchBot) -> String:
	if bot.last_passage.is_empty():
		return TranslationServer.translate("never blocked yet")
	var parts: Array[String] = []
	var costs: PackedFloat64Array = bot.last_passage["costs"]
	for index: int in range(PassageChoice.WAYS.size()):
		var way: String = PassageChoice.WAYS[index]
		var mark: String = "> " if way == bot.last_passage["chosen"] else ""
		parts.append("%s%s %s" % [mark, BotMatchWords.word(way), "-" if is_inf(costs[index]) else TranslationServer.translate("{seconds} s").format({
			seconds = "%.1f" % costs[index]})])
	var words: Dictionary = {blocker = bot.last_passage["blocker"], ways = " | ".join(parts),
		saves = "%.1f" % float(bot.last_passage.get("saves", 0.0)),
		cost = "%.1f" % float(bot.last_passage.get("their_cost", 0.0))}
	var answer: String = str(bot.last_passage.get("answer", ""))
	return TranslationServer.translate(PASSED[["", "granted", "refused"].find(answer)]).format(words)
