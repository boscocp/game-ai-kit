## The valley's words (T165): the status line, the two chains and the
## deeds on offer, worded from `ValleyShown`'s overlay in the language
## chosen.
##
## The facts, goals and plan steps stay as the code names them
## (`bridge.standing`, `bread`, `grind_wheat`), as every planner's do in
## this kit; the sentences round them, the places, the deeds and the
## reasons the rules give are translated. Static, like the other panels,
## so a test can word an overlay with no scene.
##
## When not to use it: to decide anything. It only words what the overlay
## already holds.
class_name ValleyPanel
extends RefCounted

## Each deed's words, by "verb place".
const DEEDS: Dictionary = {  # shown through tr()
	"burn barn": "burn the barn", "burn mill": "burn the mill", "burn orchard": "burn the orchard",
	"repair barn": "repair the barn", "repair mill": "repair the mill", "repair bridge": "repair the bridge",
	"pull_down bridge": "pull the bridge down", "build_footbridge ford": "build a footbridge at the ford",
	"divert_water river": "divert the river onto the field", "plant field": "sow the field",
	"plant orchard": "plant the orchard again", "dig_well square": "dig a well in the square",
	"open_gate gate": "open the orchard gate", "close_gate gate": "close the orchard gate",
}
## Each link of a villager's chain but the search, as a sentence.
const LINKS: Dictionary = {  # shown through tr()
	"fact": "{fact} is {value}: {why}",
	"quiet": "nothing {name} reads has changed since the first day",
	"reach": "{name} cannot reach: {places}",
	"plan": "{name}'s goal {goal}: {plan}",
}
## The virtues, and the three people with a manner.
const VIRTUES: Dictionary = {"care": "care", "fear": "fear"}  # shown through tr()
const PEOPLE: Dictionary = {  # shown through tr()
	"ferryman": "the ferryman", "merchant": "the merchant", "priestess": "the priestess",
}
## Each line of the chronicle, by its pattern's name in `chronicle.json`
## (T166). `{place}` and `{deed}` are worded; `{first.day}` is the day of
## the event the pattern names `first`.
const CHRONICLE: Dictionary = {  # shown through tr()
	"third-time": "On day {third.day} it was done for the third time: {deed}.",
	"no-bread": "The market ran out of bread on day {lack.day}, because of a deed on day {done.day}: {deed}.",
	"no-travellers": "Travellers stopped coming to the market on day {lack.day}, because of a deed on day {done.day}: {deed}.",
	"bread-again": "The market had no bread from day {gone.day}, and had bread again on day {back.day}.",
	"rebuilt": "On day {burned.day} {place} burned, and on day {rebuilt.day} it was rebuilt.",
	"still-burnt": "On day {burned.day} {place} burned, and nobody has rebuilt it.",
}
## What a night did to a fact, by "place.fact value": the facts the rules
## change overnight. `chronicle_test.gd` holds that every rule's change has
## its words here.
const NIGHT: Dictionary = {  # shown through tr()
	"mill.turning true": "the mill's wheel turned again", "mill.turning false": "the mill's wheel stopped",
	"market.bread true": "the market had bread again", "market.bread false": "the market had no bread",
	"market.travellers true": "travellers came to the market again",
	"market.travellers false": "no travellers came to the market",
	"field.watered true": "the field was watered", "field.watered false": "the field went dry",
	"field.harvest true": "the field bore a harvest", "field.harvest false": "the field bore nothing",
	"orchard.fruit true": "the orchard bore fruit", "orchard.fruit false": "the orchard bore no fruit",
}
## A deed as the rules word it in a reason: "day 2, burn the barn: ...".
const DEED_REASON: String = "^day (\\d+), (\\w+) the (\\w+): (.*)$"  # not shown: a pattern


## The line at the top: the day, the record, the standing, the keys.
static func status(overlay: Dictionary, paused: bool) -> String:
	var sums: Dictionary = overlay["standing"]
	var line: String = TranslationServer.translate(
		"Day {day}, turn {turn} of {turns}  ·  deeds kept: {deeds}  ·  care {care}, fear {fear}").format({
		day = overlay["day"], turn = overlay["turn"], turns = overlay["day_turns"],
		deeds = overlay["deeds"], care = sums["care"], fear = sums["fear"]})
	var clock: String = TranslationServer.translate("P runs the clock") if paused \
		else TranslationServer.translate("P pauses")
	var keys: String = TranslationServer.translate(
		"1-9 a deed  ·  space one turn  ·  {clock}  ·  N ends the day  ·  Tab next villager  ·  C the chronicle  ·  E erases").format(
		{clock = clock})
	return line + "\n" + keys


## The chain behind the followed villager's plan, then each manner's.
static func describe(overlay: Dictionary) -> String:
	var lines: Array[String] = [TranslationServer.translate("{name}'s day, and why:").format(
		{name = overlay["watching"]})]
	for link: Dictionary in overlay["chain"]:
		lines.append("  " + link_words(link))
	lines.append("")
	lines.append(TranslationServer.translate("What the valley thinks of you, and who it shows:"))
	for met: Dictionary in overlay["manners"]:
		lines.append("  " + manner_words(met))
		lines.append("      \"%s\"" % TranslationServer.translate(str(met["greeting"])))
	return "\n".join(lines)


## The chronicle (C): each line the valley tells, and under it the events
## its pattern matched -- why that line is there.
static func chronicle(overlay: Dictionary) -> String:
	var lines: Array[String] = [TranslationServer.translate("The valley's chronicle, from the record (C goes back):")]
	if overlay["chronicle"] == [ValleyShown.NONE]:
		lines.append("  " + TranslationServer.translate("Nothing yet worth telling: do a deed, and end the day."))
		return "\n".join(lines)
	for told: Dictionary in overlay["chronicle"]:
		lines.append("  " + chronicle_words(told))
		var matched: Array[String] = []
		for event: Dictionary in told["events"]:
			matched.append(event_words(event))
		lines.append("      <- " + "; ".join(matched))
	return "\n".join(lines)


## One line of the chronicle, worded from its pattern's sentence: the
## place and the deed in the language chosen, the days as they are.
static func chronicle_words(told: Dictionary) -> String:
	var values: Dictionary = (told["values"] as Dictionary).duplicate()
	if values.has("place"):
		if values.has("verb"):
			values["deed"] = deed_words("%s %s" % [values["verb"], values["place"]])
		values["place"] = place_words(str(values["place"]))
	for name: Variant in values.keys():
		if values[name] is float:
			values[name] = int(values[name])
	return TranslationServer.translate(CHRONICLE[told["pattern"]]).format(values)


## One event the chronicle matched: a deed, or a fact a night changed.
static func event_words(event: Dictionary) -> String:
	if event["kind"] == "deed":
		return TranslationServer.translate("day {day}, {deed}").format({day = int(event["day"]),
			deed = deed_words("%s %s" % [event["verb"], event["place"]])})
	var change: String = "%s.%s %s" % [event["place"], event["fact"], "true" if event["value"] else "false"]
	return TranslationServer.translate("day {day}, {deed}").format({day = int(event["day"]),
		deed = TranslationServer.translate(NIGHT.get(change, change))})


## The deeds on offer, numbered for the keys; or why there are none.
static func deeds_offered(overlay: Dictionary) -> String:
	var offered: Array = overlay["offered"]
	if offered == [ValleyShown.NONE]:
		return TranslationServer.translate("Today's deed is done: N ends the day.")
	var lines: Array[String] = [TranslationServer.translate("Your deed today (one a day):")]
	for index: int in range(mini(offered.size(), 9)):
		lines.append("  %d  %s" % [index + 1, deed_words(str(offered[index]))])
	return "\n".join(lines)


## One link of the villager's chain, as a sentence.
static func link_words(link: Dictionary) -> String:
	if not LINKS.has(link["link"]):
		return search_words(link)
	var values: Dictionary = {name = link.get("who", ""), fact = link.get("fact", ""),
		value = str(link.get("value", "")), why = reason_words(str(link.get("why", ""))),
		places = ", ".join(places_words(link.get("places", []))), goal = link.get("goal", ""),
		plan = " -> ".join(link.get("plan", []))}
	return TranslationServer.translate(LINKS[link["link"]]).format(values)


## The A* search towards where the villager is going.
static func search_words(link: Dictionary) -> String:
	var words: String = "A* to {place}: {expanded} cells expanded, {frontier} on the frontier"  # shown through tr()
	if not link["reached"]:
		words = "A* to {place}: no way there; {expanded} cells searched"  # shown through tr()
	return TranslationServer.translate(words).format({place = place_words(str(link["heading"])),
		expanded = link["expanded"], frontier = link["frontier"]})


## One person's manner: the virtue it read, from which deeds, and what it
## sets.
static func manner_words(met: Dictionary) -> String:
	var who: String = TranslationServer.translate(PEOPLE[met["who"]])
	var because: String = TranslationServer.translate("no virtue at stake")
	if met["virtue"] != ValleyShown.NONE:
		because = TranslationServer.translate("{virtue} {value} (deeds {deeds})").format({
			virtue = TranslationServer.translate(VIRTUES[met["virtue"]]), value = met["value"],
			deeds = ", ".join((met["deeds"] as Array).map(func(index: Variant) -> String: return str(index)))})
	var asks: String = "asks {price} coins, {usual} as a rule"  # shown through tr()
	if int(met["sets"]) == 1:
		asks = "asks {price} coin, {usual} as a rule"  # shown through tr()
	var sets: String = TranslationServer.translate(asks).format({price = met["sets"], usual = met["usual"]})
	if met["consequence"] == "door":
		sets = TranslationServer.translate("the door opens") if int(met["sets"]) == 1 \
			else TranslationServer.translate("the door stays shut")
	return "%s: %s -> %s" % [who, because, sets]


## A reason the world keeps, in the language chosen: a rule's, or a deed's
## as "day n, the deed: what it did".
static func reason_words(why: String) -> String:
	var deed := RegEx.create_from_string(DEED_REASON).search(why)
	if deed == null:
		return TranslationServer.translate(why)
	return TranslationServer.translate("day {day}, {deed}: {why}").format({day = deed.get_string(1),
		deed = deed_words("%s %s" % [deed.get_string(2), deed.get_string(3)]),
		why = TranslationServer.translate(deed.get_string(4))})


## A deed's words, from "verb place".
static func deed_words(verb_place: String) -> String:
	return TranslationServer.translate(DEEDS.get(verb_place, verb_place))


## A place's words, "the barn"; home is the villager's.
static func place_words(place: String) -> String:
	return TranslationServer.translate(ValleyView.PLACE_WORDS.get(place, place))


## Several places' words.
static func places_words(places: Array) -> Array[String]:
	var words: Array[String] = []
	for place: Variant in places:
		words.append(place_words(str(place)))
	return words
