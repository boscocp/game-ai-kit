# ai_teamwork — weighing actions, and a team that shares the work

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: https://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter13_Choosing_Effective_Utility-Based_Considerations.pdf ; https://www.gameaipro.com/
invalidated_if: the kit's ActionChoice, RoleArbiter, TeamCommander, TacticalPositions or SearchCoordinator signatures change, or the demos that use them are renamed
teaches: shooter-ai
-->

> Português: [ai_teamwork.pt-BR.md](ai_teamwork.pt-BR.md). The words that
> stay in English are in the [glossary](glossary.pt-BR.md).

## What it decides {#what}

Two things. What one bot does now: `ActionChoice` scores every action at
once -- its weight times each consideration's answer, from 0 to 1, read off
a percept through a response curve -- and takes the highest, so one answer
of 0 vetoes an action and the others grade it. That is **utility**, in the
form *Guild Wars 2* decided with. And how a team shares the work, each a
weighing of its own: `TeamCommander` sends squads to objectives,
`TacticalPositions` picks where a bot stands and keeps two from claiming
one spot, `RoleArbiter` lets one bot flank while the others shoot,
`SearchCoordinator` splits the places to search, `SquadConfidence` says
when to attack, hold or retreat, and `AimChoice`, `ErrandChoice` and
`PassageChoice` weigh the rest. Each keeps its numbers, so a view can show
why. The sources: Lewis, *Choosing Effective Utility-Based Considerations*,
*Game AI Pro 3*, chapter 13, and the chapters each class names.

## When not to use it {#when-not}

An order that must be kept over time -- a reload finished before a shot,
the steps of a plan: that is a plan's (`ai_planning`, an HTN), or a
commitment your percepts must carry. Many actions tuned against each other:
the numbers interact, so a curve tuned for one moves the others -- keep the
list short and the curves plain. And team classes for one squad or one
place to stand: nearest-first is the same answer with less to explain.

## Where to watch it {#watch}

- `make demo-botmatch` -- six against six. **Tab** watches the next bot:
  the discs round it are every spot it weighed, with its score, and **V**
  shows the AI's scores. **1-3** switch blue's claims, commander and
  retreat (**shift** for red's), so you can watch the team with each part
  off. **T** takes the watched bot over.
- `make demo-infiltration` -- the guards choose by `ActionChoice` from
  data, search with `SearchCoordinator`, and fight under `RoleArbiter`;
  **2** and **3** switch the coordinator and the arbiter, **Tab** watches
  the next guard.
- Which demo uses which technique, both ways: the catalogue (T76, coming).

## In this kit {#in-this-kit}

`godot/game3d/botmatch/match_bot.gd` reads its actions, postures and paces
from `actions.json` with `ActionChoice.actions_from`, and asks
`ActionChoice.choose` every decision; `team_tactics.gd` runs the commander
and the squads' confidence for each team. The knobs that matter:

| knob | where | what it changes |
|---|---|---|
| an action's weight | `"weight"` in the data | how much it matters when everything favours it |
| a curve | `"curve": "linear"` (`slope`, `intercept`) or `"step"` (`at`, `below`, `above`) | how a percept becomes an answer from 0 to 1 |
| a veto | a consideration that answers 0 | the action is out, whatever else favours it |
| flankers | `RoleArbiter.grant(requests, use_arbiter, max_flankers)` | how many may go round at once; someone always shoots |
| claims | `TacticalPositions.choose(...)` | whether a spot another bot took is dropped |

## In your own project {#your-project}

### What to copy {#copy}

One folder: `godot/addons/ai_teamwork/`. It needs nothing else, not even
`ai_core`. Open the project once, or run `godot --headless --import`, so
Godot registers its classes. Every class reads plain numbers your game
measured -- distances, line of fire already cast -- so none needs your
scene.

### A minimal example {#example}

A fighter of yours that weighs shooting, reloading, taking cover and
patrolling against what it perceives. With an enemy in sight, a full
magazine and health 20, taking cover (0.72) beats shooting (0.7); at full
health it shoots. This file is run by `fighter_example_test.gd`, and the
gate holds the page equal to it.

<!-- example: godot/test/ai_teamwork/fighter_example.gd -->
```gdscript
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
```

### What you implement {#implement}

The percepts: each one a number your game measured this decision, by name
-- a percept not given reads as 0, nothing perceived. And the acting: the
name that comes back is yours to carry out, and an action that takes time
(a reload) is your game's to finish before it asks again. Keep the actions
in a JSON file a designer edits, and load them with
`ActionChoice.actions_from(data)`: a misspelt key or curve is refused whole
with an error, rather than weighed silently with a default. The team
classes take the same kind of input -- `Candidate`, `Objective`,
`SquadReport` are inner classes you fill with numbers -- and are worth
reading in the order the bot match uses them.

## Deeper {#deeper}

- How shooter AI is made: one bot, a team, a search:
  [concepts/shooter-ai.md](../concepts/shooter-ai.md).
- The bot match, every knob and key: [godot/botmatch.md](../godot/botmatch.md).
- The four other ways to decide, and when each is right:
  [concepts/ways-to-decide.md](../concepts/ways-to-decide.md).
