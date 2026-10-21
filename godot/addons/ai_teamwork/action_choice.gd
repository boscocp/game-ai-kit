## What to do now: every action scored at once by how much what the agent
## perceives favours it, and the highest taken -- utility, the plainest way
## to weigh many actions against each other.
##
## An action has a weight, its importance, and considerations. Each
## consideration reads one percept -- a number the game measured -- and
## answers how much it favours the action, 0 to 1, through a response
## curve: a straight line clamped to 0 and 1, or a step at a threshold. The
## action's score is its weight times every answer, so one answer of 0
## vetoes it -- an empty magazine vetoes a shot, whatever else favours it --
## and the others grade it: a nearer enemy, a fuller magazine, a louder shot
## heard each move the choice by degrees. That is the form Guild Wars 2:
## Heart of Thorns decided with, after the Infinite Axis Utility System:
## each consideration "normalized to the interval [0, 1]", "processed
## through a response curve", the answers "multiplied together", so that
## "any consideration can disqualify an entire decision from being selected
## simply by scoring zero" [Lewis 2017]. This keeps two curves, and is data
## driven as that one is. The highest score wins, the first listed of
## equal scores, and when nothing scores above zero nothing is chosen.
##
## Why not the other ways `ai_behaviour` compares in its table: a behaviour
## tree's selector is a priority list -- "or else", in an order a designer
## wrote -- which is what this replaces; GOAP searches for a chain of
## actions to a goal, and a bot choosing one action each decision, each a
## step from its effect, has no chain to find -- the guard there found the
## same deed on every turn. Utility asks every action every time, from the
## same percepts, and the numbers say why one won.
##
## O(actions x considerations). When not to use it: an order that must be
## kept over time -- a reload finished before a shot, steps of a plan -- is
## a plan's (HTN, GOAP), or a commitment the percepts must carry; and its
## numbers interact, so a curve tuned for one action moves the others. The
## answers are kept in `Choice` so a view can show every one.
class_name ActionChoice
extends RefCounted

## The two curves.
const LINEAR: String = "linear"
const STEP: String = "step"


## One reason for or against an action: a percept, and the curve that turns
## it into an answer from 0 to 1.
class Consideration extends RefCounted:
	## The percept it reads, by name; one not given is 0, nothing perceived.
	var percept: String = ""
	var curve: String = LINEAR
	## LINEAR: slope times the percept, plus intercept, clamped to [0, 1].
	var slope: float = 1.0
	var intercept: float = 0.0
	## STEP: `above` from `at` up, `below` under it.
	var at: float = 0.5
	var below: float = 0.0
	var above: float = 1.0


## Something the agent can do, how much it matters, and its reasons.
class Action extends RefCounted:
	var name: String = ""
	var weight: float = 1.0
	var considerations: Array[Consideration] = []


## Every action's score and every answer behind it, and the one taken.
class Choice extends RefCounted:
	## In the actions' order.
	var scores: PackedFloat64Array = PackedFloat64Array()
	## For each action, its considerations' answers in their order.
	var answers: Array[PackedFloat64Array] = []
	## The action taken, by index; -1 when none scored above zero.
	var chosen: int = -1


## How much `consideration` favours its action, given `percepts` (name ->
## number).
static func answer(consideration: Consideration, percepts: Dictionary) -> float:
	var value: float = float(percepts.get(consideration.percept, 0.0))
	if consideration.curve == STEP:
		return consideration.above if value >= consideration.at else consideration.below
	return clampf(consideration.slope * value + consideration.intercept, 0.0, 1.0)


## The answers to each of `action`'s considerations, in their order.
static func answers_of(action: Action, percepts: Dictionary) -> PackedFloat64Array:
	var found := PackedFloat64Array()
	for consideration: Consideration in action.considerations:
		found.append(answer(consideration, percepts))
	return found


## Every action scored -- its weight times its answers -- and the highest
## taken, the first of equal scores; nothing, when none is above zero.
static func choose(actions: Array[Action], percepts: Dictionary) -> Choice:
	var choice := Choice.new()
	var best: float = 0.0
	for index: int in range(actions.size()):
		var answers: PackedFloat64Array = answers_of(actions[index], percepts)
		var score: float = actions[index].weight
		for value: float in answers:
			score *= value
		choice.answers.append(answers)
		choice.scores.append(score)
		if score > best:
			best = score
			choice.chosen = index
	return choice


## Actions from plain data, as a JSON file writes them: a list of
## {name, weight, considerations: [{percept, curve, and its numbers}]}.
static func actions_from(data: Array) -> Array[Action]:
	var actions: Array[Action] = []
	for entry: Dictionary in data:
		var action := Action.new()
		action.name = str(entry["name"])
		action.weight = float(entry.get("weight", 1.0))
		for fields: Dictionary in entry.get("considerations", []):
			action.considerations.append(_consideration_from(fields))
		actions.append(action)
	return actions


static func _consideration_from(fields: Dictionary) -> Consideration:
	var consideration := Consideration.new()
	consideration.percept = str(fields["percept"])
	consideration.curve = str(fields.get("curve", LINEAR))
	for key: String in ["slope", "intercept", "at", "below", "above"]:
		if fields.has(key):
			consideration.set(key, float(fields[key]))
	return consideration
