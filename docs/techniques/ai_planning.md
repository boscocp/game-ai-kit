# ai_planning — the steps to a goal nobody wrote down

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: book:Stuart Russell and Peter Norvig, "Artificial Intelligence: A Modern Approach", 4th edition, Pearson, 2020 -- chapter 11, classical planning ; https://en.wikipedia.org/wiki/Stanford_Research_Institute_Problem_Solver
invalidated_if: the kit's StripsAction, WorldState, StripsPlanner, HeuristicPlanner or PlanResult signatures change, or the demos that use them are renamed
teaches: planning
-->

> Português: [ai_planning.pt-BR.md](ai_planning.pt-BR.md). The words that
> stay in English are in the [glossary](glossary.pt-BR.md).

## What it decides {#what}

The order of actions that makes a goal true, found by search rather than
written by a designer. A world is a set of facts that hold (`WorldState`);
an action (`StripsAction`) needs some facts, stops some being true and
makes others true -- STRIPS, Fikes and Nilsson's form. `StripsPlanner` is
breadth-first over worlds, the version to read first; `HeuristicPlanner` is
what the games run: the same problem over bits, A\* guided by a relaxed
estimate of the steps left, inside a budget, with a horizon that is the
difficulty knob. Either answers a `PlanResult` that tells "already done"
from "no plan" from "ran out of budget". The book: Russell and Norvig,
*AIMA*, chapter 11.

## When not to use it {#when-not}

When the designer already knows the order: then it is a search every time
for an answer someone could have written down -- an HTN (`ai_behaviour`)
decomposes the designer's recipes instead. A domain with numbers in it --
"enough gold", "three units": STRIPS facts are true or false, so turn
amounts into facts first. And a plan followed to its end without asking
again: a partial plan from a budget is a direction, not a promise; act on
its first step and plan again.

## Where to watch it {#watch}

- `make demo-rts` -- the computer's build order is a plan. **H** switches
  its planner between STRIPS and an HTN over the same domain, and the panel
  shows the plan and the step it is on; **C** changes its level, whose
  horizon is how far ahead it plans.
- `make demo-tactical` -- **C** until the computer is "planner": a STRIPS
  plan towards taking red's workshop decides what blue buys, and a walker
  the plan counts on says which step it is carrying out.
- Which demo uses which technique, both ways: [the catalogue](catalogue.md#ai_planning).

## In this kit {#in-this-kit}

`godot/game/rts/build_order.gd` turns what a side has into facts, asks
`HeuristicPlanner.new().plan(actions, WorldState.new(held), goal,
HeuristicPlanner.Guide.H_MAX, budget, horizon)`, and carries out the first
step. `godot/game/tactical/planned_blue.gd` does the same on the tactical
board and plans again every few turns, or as soon as the plan stops
running from the board. The knobs that matter:

| knob | where | what it changes |
|---|---|---|
| the domain | your `Array[StripsAction]` | everything the planner can reason about; nothing else exists for it |
| the guide | `HeuristicPlanner.Guide.H_MAX`, `H_ADD` or `BREADTH_FIRST` | H_MAX keeps the plan shortest; H_ADD may look at fewer worlds |
| the budget | `plan(..., budget)` | worlds it may look at before it answers what it has, marked `partial` |
| the horizon | `plan(..., horizon)` | how many actions ahead it sees: the difficulty; `HeuristicPlanner.NO_HORIZON` for all |

## In your own project {#your-project}

### What to copy {#copy}

From the library: unzip `ai_planning-<version>.zip` into your project's
root, `res://` -- [using the library](using-the-library.md) has every step,
the Python wheel too. Or copy it from a checkout:

One folder: `godot/addons/ai_planning/`. It needs nothing else, not even
`ai_core`. Open the project once, or run `godot --headless --import`, so
Godot registers its classes. `GakGameDomain` and `Difficulty` in it are the
kit's own domain and levels; yours replace them. For a domain written in
PDDL, the reader is on the Python side, in `python/gameaikit/pddl/`.

### A minimal example {#example}

A character of yours asked for an open door. From the door, with the key on
the table, it finds four steps: walk to the table, take the key, walk to
the door, unlock it. This file is run by `door_example_test.gd`, and the
gate holds the page equal to it.

<!-- example: godot/test/ai_planning/door_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_planning.md, run by
# door_example_test.gd. A character of your own that is asked for a goal
# -- the door open -- and finds for itself the steps that get there.
extends Node

## What it can do: what each needs, what stops being true, what starts.
## The planner knows nothing else about your game.
var actions: Array[StripsAction] = [
	StripsAction.new("walk to the table", ["at_door"], ["at_door"], ["at_table"]),
	StripsAction.new("walk to the door", ["at_table"], ["at_table"], ["at_door"]),
	StripsAction.new("take the key", ["at_table", "key_on_table"], ["key_on_table"], ["has_key"]),
	StripsAction.new("unlock the door", ["at_door", "has_key"], [], ["door_open"]),
]


## The steps from what is true now, `facts`, to `goal`, by name. Empty when
## the goal already holds, or when there is no way -- `solved` on the
## `PlanResult` from `plan_for` tells those apart.
func steps(facts: PackedStringArray, goal: PackedStringArray) -> PackedStringArray:
	return plan_for(facts, goal).action_names()


## The whole answer: the steps, whether they reach the goal, and how many
## worlds the planner looked at to find them.
func plan_for(facts: PackedStringArray, goal: PackedStringArray) -> PlanResult:
	return HeuristicPlanner.new().plan(actions, WorldState.new(facts), goal, HeuristicPlanner.Guide.H_MAX)
```

### What you implement {#implement}

The facts and the doing. Each turn, write what holds in your game as a
`PackedStringArray` of fact names -- amounts become facts, such as
`resources_banked` -- ask for a plan, carry out its first step with your
own code (walking, building), and ask again when that step is done or the
world changed under it. `PlanResult.solved` false with `gave_up` true means
"not found in the budget", never "impossible"; `partial` means the steps
lead to the world that looked nearest. A domain has at most 63 facts, since
a world is one `int`.

## Deeper {#deeper}

- STRIPS, PDDL and the planner, from the start:
  [concepts/planning.md](../concepts/planning.md).
- How shipped strategy games plan, and why only at the top:
  [concepts/planning-in-strategy-games.md](../concepts/planning-in-strategy-games.md).
- Every argument of the two planners: [godot/planning.md](../godot/planning.md).
