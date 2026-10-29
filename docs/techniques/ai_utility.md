# ai_utility — weighing every option at once

<!-- doc-meta
half_life: practice
verified_on: 2026-10-29
tier: 2
source: https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter09_An_Introduction_to_Utility_Theory.pdf ; https://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter13_Choosing_Effective_Utility-Based_Considerations.pdf
invalidated_if: the kit's ActionChoice or ErrandChoice signatures change, or the demos that use them are renamed
teaches: ways-to-decide
-->

> Português: [ai_utility.pt-BR.md](ai_utility.pt-BR.md). The words that
> stay in English are in the [glossary](glossary.pt-BR.md).

## What it decides {#what}

What one agent does now, by scoring every option and taking the highest.
`ActionChoice` scores every action at once -- its weight times each
consideration's answer, from 0 to 1, read off a percept through a response
curve -- so one answer of 0 vetoes an action and the others grade it. That
is **utility**, in the form *Guild Wars 2* decided with. `ErrandChoice` is
the plainest utility of all: each errand a gain less its costs, in one
unit, and the largest taken when it is above zero -- going back for rounds
and health, fetching a power weapon, hiding to heal. Each keeps its
numbers, so a view can show why. Nothing in either is about a team: until
T101 they lived in `ai_teamwork`, and a game that wanted scored choice had
to take teamwork with it. The sources: Graham, *An Introduction to Utility
Theory*, *Game AI Pro*, chapter 9; Lewis, *Choosing Effective Utility-Based
Considerations*, *Game AI Pro 3*, chapter 13.

## When not to use it {#when-not}

An order that must be kept over time -- a reload finished before a shot,
the steps of a plan: that is a plan's (`ai_planning`, an HTN), or a
commitment your percepts must carry. Many actions tuned against each other:
the numbers interact, so a curve tuned for one moves the others -- keep the
list short and the curves plain. And a choice with two options and one
reason: an `if` says the same with less to explain.

## Where to watch it {#watch}

- `make demo-botmatch` -- six against six. **Tab** watches the next bot,
  and **V** shows the AI's scores: every action, posture and pace it
  weighed, each with its score, the one taken marked. **T** takes the
  watched bot over.
- `make demo-infiltration` -- the guards choose by `ActionChoice` from
  `guard_actions.json`; **Tab** watches the next guard, and the panel
  lists every action it could take with its score, the one taken marked.
- Which demo uses which technique, both ways: the
  [catalogue](catalogue.md).

## In this kit {#in-this-kit}

`godot/game3d/botmatch/match_bot.gd` reads its actions, postures and paces
from `actions.json` with `ActionChoice.actions_from`, and asks
`ActionChoice.choose` every decision; `match_supply.gd` weighs each bot's
errands with `ErrandChoice` and lets a team send one bot for the power
weapon. The knobs that matter:

| knob | where | what it changes |
|---|---|---|
| an action's weight | `"weight"` in the data | how much it matters when everything favours it |
| a curve | `"curve": "linear"` (`slope`, `intercept`) or `"step"` (`at`, `below`, `above`) | how a percept becomes an answer from 0 to 1 |
| a veto | a consideration that answers 0 | the action is out, whatever else favours it |
| an errand's prices | `ErrandChoice.Weights` (`resupply_walk`, `leave_holding`, `power_danger`, ...) | what a second of walking, leaving a post or an enemy near is worth against the gain |

## In your own project {#your-project}

### What to copy {#copy}

One folder: `godot/addons/ai_utility/`. It needs nothing else, not even
`ai_core`. Open the project once, or run `godot --headless --import`, so
Godot registers its classes. Both classes read plain numbers your game
measured, so neither needs your scene.

### A minimal example {#example}

A fighter of yours that weighs shooting, reloading, taking cover and
patrolling against what it perceives. With an enemy in sight, a full
magazine and health 20, taking cover (0.72) beats shooting (0.7); at full
health it shoots. This file is run by `fighter_example_test.gd`, and the
gate holds the page equal to it.

<!-- example: godot/test/ai_utility/fighter_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_utility.md, run by
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
```

### What you implement {#implement}

The percepts: each one a number your game measured this decision, by name
-- a percept not given reads as 0, nothing perceived. And the acting: the
name that comes back is yours to carry out, and an action that takes time
(a reload) is your game's to finish before it asks again. Keep the actions
in a JSON file a designer edits, and load them with
`ActionChoice.actions_from(data)`: a misspelt key or curve is refused whole
with an error, rather than weighed silently with a default. `ErrandChoice`
takes facts the same way -- `Resupply`, `Fetch`, `Hide` are inner classes
you fill with numbers -- and its `Weights` are your game's prices.

## Deeper {#deeper}

- How shooter AI is made, and why a utility choice replaced a priority
  list in the bot match: [concepts/shooter-ai.md](../concepts/shooter-ai.md).
- The four other ways to decide, and when each is right:
  [concepts/ways-to-decide.md](../concepts/ways-to-decide.md).
- A team that shares the work, the addon this one came out of:
  [ai_teamwork.md](ai_teamwork.md).
