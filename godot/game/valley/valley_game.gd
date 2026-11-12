## One session in the valley, without a screen (T165, ADR 0025): the record
## loaded, the world of today rebuilt from it, the villagers living the
## day, and the player's deeds kept.
##
## A session starts on the day after the record's last deed -- the first
## day on an empty record. The days the player only watched are not kept,
## because only deeds are; the valley's nights carry a deed's consequences
## to rest within three. A day is `day_turns` turns of the villagers, then
## a night, which `ValleyRules` plays.
##
## The player may do one deed a day, and only one that changes a fact of
## today's world: a deed that changes nothing is neither offered nor kept
## (T164's review, finding 4), so shutting a shut gate cannot be done
## again and again to stand better. Whether a deed changes anything needs
## the world of that day, which the record and the save never see -- so it
## is decided here, where the game offers deeds.
##
## When a deed is kept the world is rebuilt from the record, and every
## villager decides again from the new facts. Nothing here is saved but the
## deed, through `ValleySave`; the villagers, the world and the standing
## are rebuilt every session.
##
## A turn costs one step of each villager; a deed, one rebuild and a
## decision of each villager.
##
## When not to use it: for a game whose time runs on the wall clock. A day
## here is a run of turns, so a session is a function of the record and
## the deeds, and a test can play three of them.
class_name ValleyGame
extends RefCounted

## The rules, the standing's weights and the save, all authored or given.
var rules := ValleyRules.new()
var standing := Standing.new()
var save: ValleySave
## The record, as loaded and appended to this session.
var record: DeedLog
## Why the save was refused when it was loaded, or "". A refused save is
## left on disk untouched, and nothing can be appended to it.
var refused: String = ""
## Today, and the turn of the day.
var today: int = 1
var turn: int = 0
## How many turns a day lasts.
var day_turns: int = 1
## The world at this moment of today: the night's facts and today's deeds.
var world: ValleyWorld
## The villagers of today, and the three people with a manner.
var villagers: Array[ValleyVillager] = []
var manners: Array[VillagerManner] = []
## Whether the player has done today's deed.
var acted_today: bool = false
## The last deed kept, and the facts it changed, for the screen; empty
## until one is.
var last_deed: Dictionary = {}
var last_changed: Array[String] = []
## The chronicle's patterns (T166). It reads the record; nothing here
## reads the chronicle back.
var chronicle := ValleyChronicle.new()

# The chronicle last told, and the deeds and day it was told for.
var _told: Array[Dictionary] = []
var _told_for: Array[int] = [-1, -1]


## A session on `kept`, the save it reads and appends to.
func _init(kept: ValleySave) -> void:
	save = kept
	day_turns = int(ValleyVillager.table()["day_turns"])
	manners = VillagerManner.everyone()
	_load()


## The deeds the player may do now: each verb on each place it acts on,
## when it would change a fact of today's world. None once today's deed
## is done, or while the save is refused.
func offered() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if acted_today or refused != "":
		return found
	for verb: String in rules.verbs:
		var places: Array = (rules.verbs[verb] as Dictionary).keys()
		for place: String in places.filter(func(where: String) -> bool: return changes(DeedLog.make(today, verb, where))):
			found.append(DeedLog.make(today, verb, place))
	return found


## The facts `deed` would change in today's world, by name: empty when it
## changes nothing.
func changed_by(deed: Dictionary) -> Array[String]:
	var place: String = str(deed["place"])
	var sets: Dictionary = rules.verbs[str(deed["verb"])][place]["sets"]
	var changed: Array[String] = []
	for fact: String in sets:
		var name: String = "%s.%s" % [place, fact]
		if world.fact(name) != bool(sets[fact]):
			changed.append(name)
	return changed


## Whether `deed` would change anything in today's world.
func changes(deed: Dictionary) -> bool:
	return not changed_by(deed).is_empty()


## Do `verb` on `place` today: keep it in the record and the save, rebuild
## the world, and have every villager decide again. Returns "" when it was
## kept, or why it was refused -- a second deed today, a deed that changes
## nothing, or whatever the record or the save refuse.
func act(verb: String, place: String) -> String:
	if refused != "":
		return "the save was refused, so nothing can be kept: %s" % refused  # not shown: reached only through the API; the UI acts on offered deeds
	if acted_today:
		return "one deed a day, and today's is done"  # not shown: reached only through the API; the UI acts on offered deeds
	var deed: Dictionary = DeedLog.make(today, verb, place)
	var why: String = record.refusal(deed)
	if why != "":
		return why
	var changed: Array[String] = changed_by(deed)
	if changed.is_empty():
		return "%s the %s changes nothing today" % [verb, place]  # not shown: reached only through the API; the UI acts on offered deeds
	why = save.append(record, deed)
	if why != "":
		return why
	acted_today = true
	last_deed = deed
	last_changed = changed
	world = rules.rebuild(record, today)
	for villager: ValleyVillager in villagers:
		villager.decide(world.facts)
	return ""


## One turn: every villager steps once. The last turn of a day ends it.
func step_turn() -> void:
	if turn >= day_turns:
		next_day()
		return
	for villager: ValleyVillager in villagers:
		villager.step(world.facts)
	turn += 1


## The night, then the next day: its world rebuilt, the villagers at home.
func next_day() -> void:
	today += 1
	_start_day()


## The player's standing now, for each virtue: rebuilt from the record.
func standing_now() -> Dictionary:
	return standing.of(record)


## The valley's chronicle up to now (T166): told again only when a deed is
## kept or the day changes, since nothing else changes what happened.
func chronicle_now() -> Array[Dictionary]:
	if _told_for != [record.size(), today]:
		_told = chronicle.tell(rules, record, today)
		_told_for = [record.size(), today]
	return _told


## Remove the save and start again from the first day, with nothing kept.
## Returns the save's answer.
func forget() -> Error:
	var answer: Error = save.erase()
	if answer == OK:
		_load()
	return answer


# The record read from the save, and today the day after its last deed.
func _load() -> void:
	record = rules.new_record()
	refused = save.load_into(record)
	if refused != "":
		record = rules.new_record()
	var kept: Array[Dictionary] = record.deeds()
	today = int(kept[-1]["day"]) + 1 if not kept.is_empty() else 1
	last_deed = {}
	last_changed = []
	_told_for = [-1, -1]
	_start_day()


# Today's world from the record, every villager at home deciding its day.
func _start_day() -> void:
	turn = 0
	acted_today = false
	world = rules.rebuild(record, today)
	villagers = ValleyVillager.everyone()
	for villager: ValleyVillager in villagers:
		villager.decide(world.facts)
