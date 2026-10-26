## What the computer is thinking, drawn over the board and written beside it.
##
## Invariant 13 for the RTS: the decision, not only its outcome. Three
## layers, three pictures. The **commander**'s goal and its plan, each step
## with the time `BuildSchedule` jumped to -- "build lab, in 14 s, waiting
## for magma" -- and the queue under it, top wish first. Each **squad** as
## a line from its middle to the region it chose, in the colour of its
## state, with the arrow its state machine last took; while it advances,
## every region's score is written at the region. And with `I`, the side's
## **influence map**: its own strength in its colour, the enemy's as it
## believes it, fog and memory included -- so a person can watch the
## estimate go wrong.
##
## When not to use it: to show a person's side. A person is not thinking
## anything this can read.
class_name RtsThinking
extends Node2D

const STATE_COLOURS: Dictionary = {
	Squad.GATHER: Color(0.8, 0.8, 0.8), Squad.ADVANCE: Color(1.0, 0.85, 0.2),
	Squad.FIGHT: Color(1.0, 0.3, 0.2), Squad.RETREAT: Color(0.6, 0.6, 1.0),
}
const SCORE_COLOUR := Color(1.0, 1.0, 1.0, 0.9)
const PLAN_COLOUR := Color(1.0, 0.5, 0.9)
## The arm weighed, worth it and not: a sentence each.
const ARMING: Array[String] = [  # shown through tr()
	"arm a tower? raid {raid} in its reach, help in {help} s, gun in {ready} s: kills {killed}, costs {price} -- yes",
	"arm a tower? raid {raid} in its reach, help in {help} s, gun in {ready} s: kills {killed}, costs {price} -- no",
]

## The side whose thinking is drawn, or null for none.
var side: RtsSide
## While a person plays, the world and their side: the computer's squads
## and sites are drawn on the board only where that side can see -- the
## panel still says what it thinks, but the board does not draw its army
## through the person's fog (T20's review). -1 draws everything.
var world: RtsWorld
var watcher: int = -1
## Whether the influence map is drawn.
var show_influence: bool = false
## What the side's snapshot showed when last asked.
var view: RtsSnapshot


## The panel's text: the side's goal, plan, queue and squads, a line each.
func lines() -> Array[String]:
	if side == null or view == null:
		return []
	var said: Array[String] = []
	var thinking: Dictionary = side.overlay(view)
	if thinking.has("goal") and (thinking["goal"] as PackedStringArray).is_empty():
		return [tr("not thought yet: it decides twice a second once the match runs")]
	if thinking.has("plan"):
		said.append(tr("goal: {goal}  ({planner})").format({goal = ", ".join(thinking["goal"]),
			planner = tr(thinking["planner"])}))
		var number: int = 1
		for step: Dictionary in thinking["plan"]:
			said.append("  %d. %s" % [number, _timed(step)])
			number += 1
		if (thinking["plan"] as Array).is_empty():
			said.append("  " + tr("(goal met: replacing losses)"))
	var arming: Dictionary = thinking.get("arming", {})
	if not arming.is_empty() and arming["bought"]:
		said.append(tr("arm a tower: bought"))
	elif not arming.is_empty() and arming["raid"] > 0.0:
		said.append(arming_line(arming))
	said.append(tr("queue: {waiting}").format({waiting = thinking["waiting"] if thinking["waiting"] != "" else tr("empty")}))
	for squad: Dictionary in thinking["squads"]:
		said.append_array(_squad_lines(squad))
	return said


# One squad: its state and size, the region it advances to, the reason of
# its last arrow -- a key, written when the squad was made -- and its focus.
func _squad_lines(squad: Dictionary) -> Array[String]:
	var line: String = tr("squad {id}: {state}, {size} strong").format({id = squad["id"],
		state = RtsWords.word(squad["state"]), size = squad["size"]})
	var said: Array[String] = [line + (" -> " + RtsWords.word(squad["target"]) if squad["state"] == Squad.ADVANCE else "")]
	if squad["news"] != "":
		said.append("  " + tr(squad["news"]).format({size = Squad.SIZE}))
	if squad["state"] == Squad.FIGHT and not (squad["focus"] as Dictionary).is_empty():
		var focus: Dictionary = squad["focus"]
		said.append("  " + tr("focus: {kind} {id} -- {why}").format({kind = RtsWords.word(focus["kind"]), id = focus["id"],
			why = focus["why"]}))
	return said


## The arm, weighed, in one line: the enemy worth the gun would kill near
## it before help comes, against its price -- `TowerWorth`'s numbers.
static func arming_line(weighed: Dictionary) -> String:
	var line: String = ARMING[0 if weighed["worth_it"] else 1]
	return TranslationServer.translate(line).format({raid = roundi(weighed["raid"]), help = "%.0f" % weighed["help"],
		ready = "%.0f" % minf(weighed["ready"], 999.0), killed = roundi(weighed["killed"]), price = weighed["price"]})


func _draw() -> void:
	if side == null or view == null:
		return
	if show_influence:
		_draw_influence()
	for squad: Squad in side.squads:
		if _shown(squad.centre):
			_draw_squad(squad)
	var top: String = side.queue.wishes[0]["what"] if not side.queue.wishes.is_empty() else ""
	var site: Vector2i = side.queue.planned_site
	if top != "" and RtsKinds.is_building(top) and site != Vector2i(-1, -1) and _shown(Vector2(site)):
		draw_rect(Rect2(RtsView.to_screen(Vector2(site)), Vector2(RtsView.CELL, RtsView.CELL)), PLAN_COLOUR, false, 2.0)


# Whether the person's side may be shown what stands at `point`.
func _shown(point: Vector2) -> bool:
	return watcher < 0 or world == null or world.visible_to(watcher, point)


func _draw_squad(squad: Squad) -> void:
	if squad.members.is_empty():
		return
	var colour: Color = STATE_COLOURS.get(squad.machine.current, Color.WHITE)
	var from: Vector2 = RtsView.to_screen(squad.centre)
	draw_circle(from, 4.0, colour)
	draw_string(ThemeDB.fallback_font, from + Vector2(6.0, -6.0), "%d %s" % [squad.id, RtsWords.word(squad.machine.current)],
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, colour)
	if squad.machine.current == Squad.FIGHT:
		_draw_focus(squad, from, colour)
	if squad.machine.current != Squad.ADVANCE or squad.target == "":
		return
	var to: Vector2 = RtsView.to_screen(Vector2(RtsScenario.REGIONS[squad.target]["cell"]) + Vector2(0.5, 0.5))
	draw_dashed_line(from, to, colour, 2.0, 8.0)
	var scores: Dictionary = squad.scores
	for region: String in scores:
		var at: Vector2 = RtsView.to_screen(Vector2(RtsScenario.REGIONS[region]["cell"]))
		draw_string(ThemeDB.fallback_font, at + Vector2(-8.0, -4.0), "%.2f" % scores[region],
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, SCORE_COLOUR)


# The enemy a fighting squad chose to strike, ringed, with its score; the
# next best, faintly, so a person can see what it was weighed against.
func _draw_focus(squad: Squad, from: Vector2, colour: Color) -> void:
	for rank: int in range(mini(squad.focus_scores.size(), 3)):
		var scored: Dictionary = squad.focus_scores[rank]
		var at: Vector2 = _seen_at(scored["id"])
		if at == Vector2.INF:
			continue
		var chosen: bool = not squad.focus.is_empty() and scored["id"] == squad.focus["id"]
		var ring := Color(1.0, 0.25, 0.2) if chosen else Color(1.0, 1.0, 1.0, 0.35)
		draw_arc(at, RtsView.CELL * 0.55, 0.0, TAU, 20, ring, 2.5 if chosen else 1.0)
		draw_string(ThemeDB.fallback_font, at + Vector2(-12.0, -RtsView.CELL * 0.75), "%.2f" % scored["score"],
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, ring)
		if chosen:
			draw_line(from, at, colour, 1.5)


# Where the unit `id` stands in the side's view, on the screen; INF when
# the side cannot see it.
func _seen_at(id: int) -> Vector2:
	for unit: Dictionary in view.units:
		if unit["id"] == id:
			return RtsView.to_screen(unit["position"])
	return Vector2.INF


# Each square of the coarse grid tinted by who the side believes holds it.
func _draw_influence() -> void:
	var belief: RtsInfluence = side.belief
	var own_colour: Color = RtsView.SIDE_COLOURS[side.side]
	var enemy_colour: Color = RtsView.SIDE_COLOURS[RtsScenario.enemy_of(side.side)]
	var square := Vector2(RtsInfluence.CELL, RtsInfluence.CELL) * RtsView.CELL
	for index: int in range(belief.width * belief.height):
		var lead: float = belief.own[index] - belief.enemy[index]
		if absf(lead) < 1.0:
			continue
		var colour: Color = own_colour if lead > 0.0 else enemy_colour
		colour.a = clampf(absf(lead) / 600.0, 0.08, 0.55)
		var square_at := Vector2(index % belief.width, index / belief.width)
		draw_rect(Rect2(RtsView.to_screen(square_at * RtsInfluence.CELL), square), colour)


static func _timed(step: Dictionary) -> String:
	var words: Dictionary = {step = step["step"], waits = RtsWords.word(step["waits"]), seconds = roundi(step["starts"])}
	if step["starts"] == BuildSchedule.NEVER:
		return TranslationServer.translate("{step}: never -- nothing mines {waits}").format(words)
	if step["starts"] < 0.5:
		return TranslationServer.translate("{step}: now").format(words)
	if step["waits"] == "":
		return TranslationServer.translate("{step}: in {seconds} s").format(words)
	return TranslationServer.translate("{step}: in {seconds} s, waiting for {waits}").format(words)
