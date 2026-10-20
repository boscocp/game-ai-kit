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

## The side whose thinking is drawn, or null for none.
var side: RtsSide
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
	if thinking.has("plan"):
		said.append("goal: %s  (%s)" % [", ".join(thinking["goal"]), thinking["planner"]])
		var number: int = 1
		for step: Dictionary in thinking["plan"]:
			said.append("  %d. %s" % [number, _timed(step)])
			number += 1
		if (thinking["plan"] as Array).is_empty():
			said.append("  (goal met: replacing losses)")
	said.append("queue: " + (thinking["waiting"] if thinking["waiting"] != "" else "empty"))
	for squad: Dictionary in thinking["squads"]:
		said.append("squad %d: %s, %d strong%s" % [squad["id"], squad["state"], squad["size"],
			" -> " + squad["target"] if squad["state"] == Squad.ADVANCE else ""])
		if squad["news"] != "":
			said.append("  " + squad["news"])
	return said


func _draw() -> void:
	if side == null or view == null:
		return
	if show_influence:
		_draw_influence()
	for squad: Squad in side.squads:
		_draw_squad(squad)
	var top: String = side.queue.wishes[0]["what"] if not side.queue.wishes.is_empty() else ""
	var site: Vector2i = side.queue.planned_site
	if top != "" and RtsKinds.is_building(top) and site != Vector2i(-1, -1):
		draw_rect(Rect2(RtsView.to_screen(Vector2(site)), Vector2(RtsView.CELL, RtsView.CELL)), PLAN_COLOUR, false, 2.0)


func _draw_squad(squad: Squad) -> void:
	if squad.members.is_empty():
		return
	var colour: Color = STATE_COLOURS.get(squad.machine.current, Color.WHITE)
	var from: Vector2 = RtsView.to_screen(squad.centre)
	draw_circle(from, 4.0, colour)
	draw_string(ThemeDB.fallback_font, from + Vector2(6.0, -6.0), "%d %s" % [squad.id, squad.machine.current],
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, colour)
	if squad.machine.current != Squad.ADVANCE or squad.target == "":
		return
	var to: Vector2 = RtsView.to_screen(Vector2(RtsScenario.REGIONS[squad.target]["cell"]) + Vector2(0.5, 0.5))
	draw_dashed_line(from, to, colour, 2.0, 8.0)
	var scores: Dictionary = squad.scores
	for region: String in scores:
		var at: Vector2 = RtsView.to_screen(Vector2(RtsScenario.REGIONS[region]["cell"]))
		draw_string(ThemeDB.fallback_font, at + Vector2(-8.0, -4.0), "%.2f" % scores[region],
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, SCORE_COLOUR)


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
		draw_rect(Rect2(RtsView.ORIGIN + square_at * square, square), colour)


static func _timed(step: Dictionary) -> String:
	if step["starts"] == BuildSchedule.NEVER:
		return "%s: never -- nothing mines %s" % [step["step"], step["waits"]]
	if step["starts"] < 0.5:
		return "%s: now" % step["step"]
	var waits: String = "" if step["waits"] == "" else ", waiting for " + step["waits"]
	return "%s: in %d s%s" % [step["step"], roundi(step["starts"]), waits]
