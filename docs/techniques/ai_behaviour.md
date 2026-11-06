# ai_behaviour — what to do next

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: book:Ian Millington, "AI for Games", 3rd edition, CRC Press, 2019 -- chapter 5 on decision making ; book:Steve Rabin (ed.), "Game AI Pro", CRC Press, 2013 -- ch. 12 (Humphreys, HTN planners)
invalidated_if: the kit's StateMachine, BehaviourTree, GoapPlanner or HtnPlanner signatures change, or the demos that use them are renamed
teaches: ways-to-decide
-->

> Português: [ai_behaviour.pt-BR.md](ai_behaviour.pt-BR.md). The words that
> stay in English are in the [glossary](glossary.pt-BR.md).

## What it decides {#what}

Which deed an agent does now, given the facts your game knows -- chase,
investigate, patrol. Four ways to decide it, each a class: a **state
machine** (`StateMachine`), a **behaviour tree** (`BehaviourTree`), **GOAP**
(`GoapPlanner`, which searches backwards from a goal for the cheapest list of
actions) and an **HTN** (`HtnPlanner`, which breaks a task down by methods a
designer wrote). Each one leaves a record of why: the arrow taken, the
tree's trail, the plan. The book: Millington, *AI for Games*, chapter 5;
Humphreys in *Game AI Pro*, chapter 12.

## When not to use it {#when-not}

A state machine with more than a handful of states, or behaviour shared
between them -- a tree composes. A tree when the agent must find the order of
steps for itself -- a planner searches for one. A planner when the designer
already knows the order -- it is a search every time, for an answer someone
could have written down. `WaysToDecide` holds the whole table, measured on
one guard.

## Where to watch it {#watch}

- `make demo-behaviour` -- one guard, four brains. **1-4** swap state
  machine, tree, GOAP and HTN mid-round; **space** plays a turn, **enter**
  ten. The panel beside the board lights the arrow taken, the tree's trail,
  or the plan.
- `make demo-tactical` -- **C** changes the computer player, among them the
  state machine, the tree, GOAP and the HTN on the same board.
- `make demo-rts` -- each squad is a state machine.
- Which demo uses which technique, both ways: [the catalogue](catalogue.md#ai_behaviour).

## In this kit {#in-this-kit}

`godot/demos/behaviour/guard_tree.gd` builds the guard's tree;
`guard_fsm.gd`, `guard_goap.gd` and `guard_htn.gd` are the same guard the
other three ways, all fed the same facts. The knobs that matter:

| knob | where | what it changes |
|---|---|---|
| the facts | the `Dictionary` you pass each tick | everything the agent knows; your game fills it in |
| the order of children | `BehaviourTree.Selector` / `Sequence` | which branch is asked first, so which wins |
| the order of arrows | `StateMachine.add_arrow` | the first arrow whose condition holds is taken |
| an action's cost | `GoapAction` | which plan GOAP finds cheapest |
| the order of methods | `HtnDomain` | which way of doing a task the HTN tries first |

## In your own project {#your-project}

### What to copy {#copy}

From the library: unzip `ai_behaviour-<version>.zip` into your project's
root, `res://` -- [using the library](using-the-library.md) has every step,
the Python wheel too. Or copy it from a checkout:

One folder: `godot/addons/ai_behaviour/`. It needs nothing else, not even
`ai_core`. Open the project once, or run `godot --headless --import`, so
Godot registers its classes.

### A minimal example {#example}

A guard of yours, as a behaviour tree: chase what it sees, look where it
heard something, otherwise walk its round. Call `decide(facts)` from your own
game loop and act on what it returns; draw `trail()` to show why. This file
is run by `guard_example_test.gd`, and the gate holds the page equal to it.

<!-- example: godot/test/ai_behaviour/guard_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_behaviour.md, run by
# guard_example_test.gd. A guard of your own: chase what it sees, look
# where it heard something, otherwise walk its round.
extends Node

## What the last tick chose. Your game reads it and moves the guard.
var doing: String = ""

var _tree: BehaviourTree


func _ready() -> void:
	_tree = BehaviourTree.new(BehaviourTree.Selector.new("guard", [
		BehaviourTree.Sequence.new("chase", [
			BehaviourTree.Condition.new("sees someone?", _fact.bind("sees_player")),
			BehaviourTree.Action.new("run at them", _choose.bind("chase")),
		] as Array[BehaviourTree.TreeNode]),
		BehaviourTree.Sequence.new("investigate", [
			BehaviourTree.Condition.new("heard something?", _fact.bind("heard_noise")),
			BehaviourTree.Action.new("go and look", _choose.bind("investigate")),
		] as Array[BehaviourTree.TreeNode]),
		BehaviourTree.Action.new("walk the round", _choose.bind("patrol")),
	] as Array[BehaviourTree.TreeNode]))


## Ask the tree once, from the root, with what your game knows this tick.
func decide(facts: Dictionary) -> String:
	_tree.tick(facts)
	return doing


## Every node the last tick asked and what each answered: draw it, and the
## player sees why the guard did what it did.
func trail() -> Array[String]:
	return _tree.trail.duplicate()


# A condition: one fact, read from what the game filled in.
func _fact(facts: Dictionary, fact_name: String) -> bool:
	return facts.get(fact_name, false)


# An action: here it only records the choice; your game acts on `doing`.
func _choose(_facts: Dictionary, choice: String) -> BehaviourTree.Status:
	doing = choice
	return BehaviourTree.Status.SUCCESS
```

### What you implement {#implement}

The facts and the deeds. A condition is any `Callable` taking the facts and
returning a `bool`; an action is one returning a `BehaviourTree.Status` --
`RUNNING` for something that takes several ticks, like walking somewhere.
The tree keeps nothing between ticks, so your game keeps the world. A state
machine takes the same kind of condition on each arrow, with a sentence
saying why it fires.

## Deeper {#deeper}

- One guard written four ways, and when each is right:
  [concepts/ways-to-decide.md](../concepts/ways-to-decide.md).
- Planning, GOAP's forward cousin STRIPS: [concepts/planning.md](../concepts/planning.md).
