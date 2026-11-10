## What the playing brain is thinking, drawn: the part of each way of
## deciding a person should be able to point at.
##
## - the state machine: its four states, the one it is in lit, and the arrow
##   it last took;
## - the behaviour tree: the nodes the last tick asked, in order, with "go
##   and look" in blue wherever it appears -- one subtree, under two
##   branches, which the legend says;
## - GOAP: the goal, and the plan it made this turn, first step lit, and the
##   worlds it looked at to make it;
## - the HTN: the method it chose, its plan, the step it is on lit, and why it
##   last planned -- the evidence that it carries on down a method rather
##   than plan every turn as GOAP does.
##
## The brains think in English names -- a state, a node, a method, a deed --
## and the addon writes them in its own notation, "from -> to: why" and
## "name: answer". `words` translates each name of a line and keeps the
## notation, so a Portuguese reader sees "ronda -> desconfiado: ..." (T79).
##
## When not to use it: as the decision. It reads `GuardBrain.thinking`; it
## never asks the brain anything that could change it.
class_name BrainPanel
extends Control

const LINE: float = 22.0
const FONT_SIZE: int = 16
const LIT: Color = Color(1.0, 0.85, 0.3, 0.9)
const SHARED: Color = Color(0.5, 0.8, 1.0, 0.9)
const TEXT: Color = Color(0.95, 0.95, 0.95)
const DIM: Color = Color(0.6, 0.6, 0.6)
## The subtree the tree uses in two places.
const SHARED_SUBTREE: String = "go and look"  # shown through tr()
## A tree node's answers, as `BehaviourTree.said` writes them in the trail:
## the addon's words, translated here by `words`.
const TREE_ANSWERS: Array[String] = ["success", "failure", "running"]  # shown through tr()

var _brain: GuardBrain


## A line of a brain's thinking in the language spoken: each name in it
## translated, the addon's notation kept -- "from -> to: why" for a state
## machine's arrow, "name: answer" for a tree's trail and an HTN's method. A
## name with no translation, a number, stays as it is.
static func words(line: String) -> String:
	var arrow: int = line.find(" -> ")
	var colon: int = line.find(": ")
	if colon < 0:
		return _word(line)
	var why: String = _word(line.substr(colon + 2))
	if arrow < 0 or arrow > colon:
		return "%s: %s" % [_word(line.left(colon)), why]
	var to: String = line.substr(arrow + 4, colon - arrow - 4)
	return "%s -> %s: %s" % [_word(line.left(arrow)), _word(to), why]


static func _word(name: String) -> String:
	return TranslationServer.translate(name)


## Draw what `brain` is thinking.
func show_brain(brain: GuardBrain) -> void:
	_brain = brain
	queue_redraw()


func _draw() -> void:
	if _brain == null:
		return
	var rows: Array[Array] = [[words(_brain.brain_name()), TEXT, false]]
	var thinking: Dictionary = _brain.thinking()
	if _brain is GuardFsm:
		rows.append_array(_machine_rows(thinking))
	elif _brain is GuardTree:
		rows.append_array(_tree_rows(thinking))
	else:
		rows.append_array(_plan_rows(thinking))
	for index: int in range(rows.size()):
		_draw_row(index, rows[index][0], rows[index][1], rows[index][2])


# [words, colour, lit] for each line of a state machine.
static func _machine_rows(thinking: Dictionary) -> Array[Array]:
	var rows: Array[Array] = []
	for state: String in thinking["states"]:
		rows.append(["  " + words(state), TEXT, state == thinking["state"]])
	rows.append([words(thinking["changed"]), DIM, false])
	return rows


# A tree's trail, the shared subtree marked.
static func _tree_rows(thinking: Dictionary) -> Array[Array]:
	var rows: Array[Array] = []
	for asked: String in thinking["trail"]:
		var shared: bool = asked.begins_with(SHARED_SUBTREE)
		rows.append(["  " + words(asked), SHARED if shared else TEXT, false])
	return rows


# A plan: what it is for, then its steps, the one being done lit.
static func _plan_rows(thinking: Dictionary) -> Array[Array]:
	var rows: Array[Array] = []
	var aim: String = TranslationServer.translate("method: {methods}").format({methods = _listed(thinking.get("method", []))})
	if thinking.has("goal"):
		aim = TranslationServer.translate("goal: {goals}").format({goals = _listed(thinking["goal"])})
	rows.append([aim, DIM, false])
	var at: int = thinking.get("step", 0)
	var steps: Array = thinking["plan"]
	for index: int in range(steps.size()):
		rows.append(["  %d. %s" % [index + 1, words(steps[index])], TEXT, index == at])
	rows.append([TranslationServer.translate("worlds looked at: {count}").format({count = thinking.get("visited", 0)}), DIM, false])
	if thinking.get("planned", "") != "":
		# On a row of its own: the longest reason fills the column by itself.
		rows.append([TranslationServer.translate("planned because:"), DIM, false])
		rows.append([" " + thinking["planned_words"], DIM, false])
	return rows


# Names, each in the language spoken, one after another.
static func _listed(names: Array) -> String:
	var shown: PackedStringArray = PackedStringArray()
	for name: String in names:
		shown.append(words(name))
	return ", ".join(shown)


func _draw_row(index: int, words: String, colour: Color, lit: bool) -> void:
	var top: float = index * LINE
	if lit:
		draw_rect(Rect2(0.0, top + 2.0, size.x, LINE), LIT)
	draw_string(ThemeDB.fallback_font, Vector2(4.0, top + LINE - 5.0), words, HORIZONTAL_ALIGNMENT_LEFT, size.x - 8.0, FONT_SIZE,
		Color.BLACK if lit else colour)
