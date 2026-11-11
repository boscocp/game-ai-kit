## One villager's day in the valley (T165): which goal next, the plan that
## meets it, and the walk to each step of the plan.
##
## A day is a few goals from `villagers.json` -- bread, water, fruit. Each
## time the villager is free, or the world it reads changes, it decides:
##
## 1. **Where can I get to?** A\* (`ai_search`) over the valley's grid
##    (`ai_core`), built from the day's facts, from where the villager
##    stands to every place an action is done at. A place with no route is
##    a fact too: `market.reachable` false.
## 2. **How would I meet each goal?** GOAP (`ai_behaviour`) over the
##    actions, each costing its walk plus its work. Bread is bought at the
##    market, or the wheat taken from the barn, ground at the mill and baked
##    at home: GOAP finds whichever is cheaper today, and the other when the
##    first is shut -- nobody wrote "if the bridge is down".
## 3. **Which goal now?** `ActionChoice` (`ai_utility`) scores the goals
##    left: no plan scores 0, a dearer plan less.
##
## `decide` and `step` receive the world's facts and nothing else; the rest
## is the villager's own state of the day. It never reads another
## villager, nor the player's standing, and nothing of it is saved: each
## day starts again at home with nothing carried.
##
## Deciding costs one A\* search per place and one GOAP search per goal.
##
## When not to use it: for villagers who must share a place's capacity or
## queue behind each other. They would need to read one another, which is
## exactly what this one may not do; that is a reservation table's job.
class_name ValleyVillager
extends RefCounted

const FILE: String = "res://game/valley/villagers.json"
## The place an action done at home names.
const HOME: String = "home"  # not shown: a place's identifier, worded by ValleyPanel

## The villager's name, and where the day starts and ends.
var name: String = ""
var home: Vector2i = Vector2i.ZERO
## The goals of the day, in the file's order, and those already met.
var goals: Array[String] = []
var met: Array[String] = []
## Where the villager stands now.
var cell: Vector2i = Vector2i.ZERO
## What the villager carries, by fact: `has_bread`.
var carried: Dictionary = {}
## The goal being met, or "" while going home or resting there.
var goal: String = ""
## The plan for it, as action names, and the index of the step under way.
var plan: Array[String] = []
var next_step: int = 0
## The cells still to walk to the next step's place.
var route: Array[Vector2i] = []
## The place the villager is walking to, and the A\* search that found it.
var heading: String = HOME
var search: SearchResult = null
## From the last decision: each place's walk, -1 when there is no route.
var walks: Dictionary = {}
## From the last decision: each goal left, its plan's steps (empty: none)
## and its score.
var plans: Dictionary = {}
var scores: Dictionary = {}
## How many times the villager has decided today.
var decisions: int = 0

static var _table: Dictionary = {}


func _init(person: Dictionary) -> void:
	name = str(person["name"])
	home = Vector2i(int(person["home"][0]), int(person["home"][1]))
	goals.assign(person["goals"])
	cell = home
	for fact: String in table()["carried"]:
		carried[fact] = false


## The villagers' file, read once: it never changes.
static func table() -> Dictionary:
	if _table.is_empty():
		_table = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	return _table


## Everyone in the valley, each at home at the start of a day.
static func everyone() -> Array[ValleyVillager]:
	var found: Array[ValleyVillager] = []
	for person: Dictionary in table()["people"]:
		found.append(ValleyVillager.new(person))
	return found


## The action called `action_name`, as the file writes it.
static func action_named(action_name: String) -> Dictionary:
	for action: Dictionary in table()["actions"]:
		if action["name"] == action_name:
			return action
	return {}


## Choose the next goal and its plan from the day's `facts` and the
## villager's own state, and set off towards the plan's first place --
## or home, when no goal left has a plan.
func decide(facts: Dictionary) -> void:
	decisions += 1
	var graph: GakGridGraph = ValleyMap.authored().graph_for(facts)
	var searches: Dictionary = {}
	for place: String in _places_used():
		searches[place] = _search_to(place, graph)
		walks[place] = (searches[place] as SearchResult).cost
	var known: Dictionary = _known(facts)
	plans = {}
	var percepts: Dictionary = {}
	for wanted: String in goals_left():
		var found: BehaviourPlan = GoapPlanner.new().plan(_goap_actions(), known, table()["goals"][wanted])
		plans[wanted] = found.steps if found.solved else [] as Array[String]
		percepts[wanted + ".planned"] = 1.0 if found.solved else 0.0
		percepts[wanted + ".cost"] = float(plan_cost(found.steps))
	goal = _choose(percepts)
	plan.assign(plans.get(goal, []))
	next_step = 0
	_set_off(searches)


## One turn: a cell further along the route, or, on arriving, the step's
## action done. Returns the action done, or "" for a turn of walking or
## resting.
func step(facts: Dictionary) -> String:
	if not route.is_empty():
		cell = route.pop_front()
		return ""
	if goal == "":
		return ""
	if next_step >= plan.size():
		met.append(goal)
		decide(facts)
		return ""
	var action: Dictionary = action_named(plan[next_step])
	if not ValleyRules.holds(action["needs"], _known(facts)):
		decide(facts)
		return ""
	carried.merge(action["makes"], true)
	next_step += 1
	if next_step >= plan.size():
		met.append(goal)
	if next_step >= plan.size() or not _head_for(place_of(plan[next_step]), facts):
		decide(facts)
	return str(action["name"])


## The goals of the day not met yet, in the file's order.
func goals_left() -> Array[String]:
	var left: Array[String] = []
	for wanted: String in goals:
		if not wanted in met:
			left.append(wanted)
	return left


## What `steps` cost as this villager would plan them now: each action's
## walk from where it stands, plus its work.
func plan_cost(steps: Array[String]) -> int:
	var total: int = 0
	for action_name: String in steps:
		var action: Dictionary = action_named(action_name)
		total += maxi(int(walks.get(place_of(action_name), 0)), 0) + int(action["work"])
	return total


## The world facts this villager's actions read, and the crossings: every
## fact a deed can change that would change what it decides.
func reads() -> Array[String]:
	var read: Array[String] = []
	read.assign(ValleyMap.authored().crossings.values())
	for action: Dictionary in table()["actions"]:
		var needs: Array = (action["needs"] as Dictionary).keys()
		read.append_array(needs.filter(func(fact: String) -> bool: return not fact in carried and not fact in read))
	return read


## The place `action_name` is done at.
static func place_of(action_name: String) -> String:
	return str(action_named(action_name).get("at", HOME))


# Every place an action is done at, home among them.
func _places_used() -> Array[String]:
	var used: Array[String] = []
	for action: Dictionary in table()["actions"]:
		if not str(action["at"]) in used:
			used.append(str(action["at"]))
	return used


# The cheapest A* route from the villager's cell to any cell of `place`;
# when none is reached, the last search, which shows how far it got.
func _search_to(place: String, graph: GakGridGraph) -> SearchResult:
	var targets: Array[Vector2i] = [home]
	if place != HOME:
		targets = ValleyMap.authored().cells_of(place)
	var best: SearchResult = null
	for target: Vector2i in targets:
		var found: SearchResult = AStarSearch.new().search(GridSearchGraph.new(graph), cell, target)
		if best == null or (found.reached and (not best.reached or found.cost < best.cost)):
			best = found
	return best


# What GOAP plans from: the world's facts, which places can be walked to,
# and what the villager carries.
func _known(facts: Dictionary) -> Dictionary:
	var known: Dictionary = facts.duplicate()
	for place: String in walks:
		known[place + ".reachable"] = int(walks[place]) >= 0
	known.merge(carried, true)
	return known


# Each action as GOAP takes it: its place must be reachable, and it costs
# its walk there plus its work.
func _goap_actions() -> Array[GoapAction]:
	var actions: Array[GoapAction] = []
	for action: Dictionary in table()["actions"]:
		var needs: Dictionary = (action["needs"] as Dictionary).duplicate()
		needs[str(action["at"]) + ".reachable"] = true
		var walk: int = maxi(int(walks.get(str(action["at"]), 0)), 0)
		actions.append(GoapAction.new(str(action["name"]), walk + int(action["work"]), needs, action["makes"]))
	return actions


# The goal ActionChoice scores highest among those left, or "" when none
# scores above nothing. Every goal's score is kept for the screen.
func _choose(percepts: Dictionary) -> String:
	var choosing: Array[ActionChoice.Action] = []
	for action: ActionChoice.Action in ActionChoice.actions_from(table()["choice"]):
		if action.name in goals_left():
			choosing.append(action)
	var choice: ActionChoice.Choice = ActionChoice.choose(choosing, percepts)
	scores = {}
	for index: int in range(choosing.size()):
		scores[choosing[index].name] = choice.scores[index]
	return choosing[choice.chosen].name if choice.chosen >= 0 else ""


# Off to the plan's first place, or home with no goal.
func _set_off(searches: Dictionary) -> void:
	heading = place_of(plan[0]) if not plan.is_empty() else HOME
	search = searches[heading]
	route = search.path.duplicate() if search.reached else [] as Array[Vector2i]


# A new route to `place`, after a step done elsewhere. False when there is
# none, and the villager must decide again.
func _head_for(place: String, facts: Dictionary) -> bool:
	heading = place
	search = _search_to(place, ValleyMap.authored().graph_for(facts))
	route = search.path.duplicate() if search.reached else [] as Array[Vector2i]
	return search.reached
