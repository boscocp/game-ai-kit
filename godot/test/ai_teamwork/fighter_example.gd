# The minimal example on docs/techniques/ai_teamwork.md, run by
# fighter_example_test.gd. A fighter of your own that weighs every action
# at once against what it perceives, and takes the highest -- utility.
extends Node

## The actions, as data a designer edits. A score is the weight times every
## consideration's answer, each 0 to 1, so one answer of 0 vetoes the
## action: no enemy in sight, no shot. A `step` curve answers `above` from
## `at` up and `below` under it (1 and 0 unless given); a `linear` one
## answers slope times the percept plus intercept, clamped to 0 and 1.
const ACTIONS: Array = [
	{"name": "shoot", "weight": 0.7, "considerations": [
		{"percept": "enemy_visible", "curve": "step", "at": 1.0},
		{"percept": "ammo", "curve": "step", "at": 1.0},
	]},
	{"name": "reload", "weight": 0.8, "considerations": [
		{"percept": "ammo", "curve": "linear", "slope": -0.1, "intercept": 1.0},
	]},
	{"name": "take cover", "weight": 0.9, "considerations": [
		{"percept": "enemy_visible", "curve": "step", "at": 1.0},
		{"percept": "health", "curve": "linear", "slope": -0.01, "intercept": 1.0},
	]},
	{"name": "patrol", "weight": 0.1, "considerations": []},
]

var _actions: Array[ActionChoice.Action] = ActionChoice.actions_from(ACTIONS)


## The action to take, given `percepts` by name -- `enemy_visible` 0 or 1,
## `ammo` rounds left, `health` 0 to 100 -- or "" when nothing scores.
func decide(percepts: Dictionary) -> String:
	var choice: ActionChoice.Choice = ActionChoice.choose(_actions, percepts)
	return "" if choice.chosen == -1 else _actions[choice.chosen].name


## Every action's score, by name: draw it, and the player sees why the
## fighter did what it did, and what came second.
func scores(percepts: Dictionary) -> Dictionary:
	var choice: ActionChoice.Choice = ActionChoice.choose(_actions, percepts)
	var by_name: Dictionary = {}
	for index: int in range(_actions.size()):
		by_name[_actions[index].name] = choice.scores[index]
	return by_name
