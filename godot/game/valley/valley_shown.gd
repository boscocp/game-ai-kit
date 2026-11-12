## What the valley's screen shows, as data (T165): the two chains
## invariant 13 asks for, ready for the panel to word and a test to read.
##
## The villagers' chain runs from a deed to a fact, from the fact to a
## place a villager can no longer reach, from that to the plan it chose
## instead, and to the A\* search that found its new way: "day 2, the
## bridge pulled down -> bridge.standing false -> the market unreachable ->
## Ana's bread: take_wheat, grind_wheat, bake_bread -> A\* to the barn".
## The manners' chain runs from the deeds to a virtue to what a person
## sets: "fear 6 (deeds 1, 3) -> the ferryman asks 8, his fare 4".
## The chronicle (T166) is a third: each line beside the events its
## pattern matched, "the bridge came down for the third time <- day 5,
## day 8, day 10".
##
## Every list holds something: an empty one is written as "none", so the
## screen and `test-demo-overlays` both see that nothing is there rather
## than nothing at all.
##
## When not to use it: as the game's state. Everything here is read off
## `ValleyGame` once a frame and thrown away.
class_name ValleyShown
extends RefCounted

## What an empty list is shown as.
const NONE: String = "none"  # not shown: worded by ValleyPanel


## The whole overlay of `game`, following the villager at `watching`.
static func overlay(game: ValleyGame, watching: int) -> Dictionary:
	var sums: Dictionary = game.standing_now()
	var people: Array[Dictionary] = []
	for villager: ValleyVillager in game.villagers:
		people.append(villager_shown(villager))
	var followed: ValleyVillager = game.villagers[watching]
	return {"day": game.today, "turn": game.turn, "day_turns": game.day_turns,
			"deeds": game.record.size(), "standing": sums, "offered": offered_shown(game),
			"last_deed": last_deed_shown(game), "save": game.refused if game.refused != "" else "kept",
			"watching": followed.name, "chain": chain(game, followed), "villagers": people,
			"manners": manners_shown(game, sums), "chronicle": filled(game.chronicle_now(), [NONE])}


## One villager's decision: its goal, plan, route and A\* search, and the
## walks and scores it decided from.
static func villager_shown(villager: ValleyVillager) -> Dictionary:
	var search: SearchResult = villager.search
	return {"name": villager.name, "cell": villager.cell,
			"goal": villager.goal if villager.goal != "" else "rest",
			"plan": filled(villager.plan, ["rest"]), "step": villager.next_step,
			"heading": villager.heading, "route": filled(villager.route, ["arrived"]),
			"frontier": filled(search.frontier if search != null else [], [NONE]),
			"expanded": search.expanded.size() if search != null else 0,
			"walks": filled_table(villager.walks), "scores": filled_table(villager.scores),
			"met": filled(villager.met, [NONE]), "decisions": villager.decisions}


## The chain behind `villager`'s plan, link by link: every fact it reads
## that a deed or a night changed, with why; the places it cannot reach;
## the goal and plan it chose; the search to where it is going.
static func chain(game: ValleyGame, villager: ValleyVillager) -> Array[Dictionary]:
	var links: Array[Dictionary] = []
	for fact: String in villager.reads().filter(func(read: String) -> bool: return game.world.because.has(read)):
		links.append({"link": "fact", "fact": fact, "value": game.world.fact(fact), "why": game.world.because[fact]})
	if links.is_empty():
		links.append({"link": "quiet", "who": villager.name})
	var unreachable: Array = villager.walks.keys().filter(
		func(place: String) -> bool: return int(villager.walks[place]) < 0)
	if not unreachable.is_empty():
		links.append({"link": "reach", "who": villager.name, "places": unreachable})
	links.append({"link": "plan", "who": villager.name, "goal": villager.goal if villager.goal != "" else "rest",
		"plan": filled(villager.plan, ["rest"])})
	links.append(search_link(villager))
	return links


## The last link: the A* search towards where the villager is going.
static func search_link(villager: ValleyVillager) -> Dictionary:
	var search: SearchResult = villager.search
	if search == null:
		return {"link": "search", "heading": villager.heading, "expanded": 0, "frontier": 0, "reached": false}
	return {"link": "search", "heading": villager.heading, "expanded": search.expanded.size(),
		"frontier": search.frontier.size(), "reached": search.reached}


## Each person's manner met: the virtue its rule read, that virtue's value
## and the deeds that made it, what the rule sets against the usual, the
## greeting.
static func manners_shown(game: ValleyGame, sums: Dictionary) -> Array[Dictionary]:
	var shown: Array[Dictionary] = []
	for manner: VillagerManner in game.manners:
		shown.append(manner_shown(game, manner, sums))
	return shown


## One person's manner met, as `manners_shown` lists it.
static func manner_shown(game: ValleyGame, manner: VillagerManner, sums: Dictionary) -> Dictionary:
	var met: Dictionary = manner.meets(sums, game.world.facts)
	var virtue: String = str(manner.rules[int(met["rule"])]["virtue"])
	return {"who": manner.who, "consequence": manner.consequence,
		"sets": int(met[manner.consequence]), "usual": manner.usual,
		"greeting": met[VillagerManner.GREETING], "rule": int(met["rule"]),
		"virtue": virtue if virtue != "" else NONE, "value": int(sums.get(virtue, 0)),
		"deeds": filled(deeds_behind(game, virtue), [NONE])}


## The deeds that moved `virtue`, by their place in the record, counted
## from 1; none for no virtue.
static func deeds_behind(game: ValleyGame, virtue: String) -> Array[int]:
	var found: Array[int] = []
	if virtue == "":
		return found
	var kept: Array[Dictionary] = game.record.deeds()
	for index: int in range(kept.size()):
		if game.standing.weight(kept[index], virtue) != 0:
			found.append(index + 1)
	return found


## The deeds offered now, as "verb place".
static func offered_shown(game: ValleyGame) -> Array:
	var shown: Array[String] = []
	for offered: Dictionary in game.offered():
		shown.append("%s %s" % [offered["verb"], offered["place"]])
	return filled(shown, [NONE])


## The last deed kept, as "day n: verb place", and the facts it changed.
static func last_deed_shown(game: ValleyGame) -> String:
	if game.last_deed.is_empty():
		return NONE
	return "day %d: %s %s -> %s" % [int(game.last_deed["day"]), game.last_deed["verb"],  # not shown: the overlay's own words, read by tests
			game.last_deed["place"], ", ".join(game.last_changed)]


## `list` as it is, or `instead` when it is empty.
static func filled(list: Array, instead: Array) -> Array:
	return list.duplicate() if not list.is_empty() else instead


## `table` as it is, or a table saying "none" when it is empty.
static func filled_table(table: Dictionary) -> Dictionary:
	return table.duplicate() if not table.is_empty() else {NONE: 0}
