# Wiring ai_planning into a game

<!-- doc-meta
half_life: practice
verified_on: 2026-10-13
tier: 2
source: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html
invalidated_if: Godot changes how class_name registers a class, or the StripsPlanner or PlanResult signatures change
teaches: planning
-->

> How to describe a domain in GDScript, ask for a plan and tell the two kinds
> of failure apart. Every snippet was run on the pinned Godot 4.7.2 on
> 2026-10-13, and the outputs shown are what it printed. Why it works is
> [the concept page](../concepts/planning.md).

**Not yet in the game.** The planner is complete and tested, and nothing in
`make run` calls it yet; T11 is the task that puts it on the board. What
follows is how to call it from your own code.

## What to copy

`addons/ai_planning/` on its own -- the planner needs nothing from `ai_core`,
because it plans over facts rather than over a board. From a release, unzip
`ai_planning-<version>.zip` into `res://addons/`.

## A plan, from the game's own domain

```gdscript
var plan: PlanResult = StripsPlanner.new().plan(
	GameDomain.actions(), GameDomain.opening_world(), GameDomain.goal())
print(plan.solved, " ", plan.visited)
print(" -> ".join(plan.action_names()))
# true 14
# march_to_node -> take_the_node -> mine_the_node -> build_barracks -> mine_the_node -> train_unit -> scout_the_enemy -> attack
```

Note `mine_the_node` twice. The barracks and the unit are paid out of one bank,
and that is the whole lesson of the domain.

## Your own domain

An action is a name and three lists of facts:

```gdscript
var actions: Array[StripsAction] = [
	StripsAction.new("chop_wood", ["has_axe"], [], ["has_wood"]),
	StripsAction.new("build_raft", ["has_wood"], ["has_wood"], ["has_raft"]),
]
var plan: PlanResult = StripsPlanner.new().plan(
	actions, WorldState.new(["has_axe"]), PackedStringArray(["has_raft"]))
```

`WorldState` is the set of facts that hold; a fact not in it is false. Facts
are plain strings, so a typo is a fact nobody ever adds -- name them as
constants the way `game_domain.gd` does.

## Two kinds of "no plan"

| `solved` | `gave_up` | meaning |
|---|---|---|
| true | false | a plan, and it is one of the shortest |
| false | false | **no plan exists**: every reachable world was looked at |
| false | true | the search ran out of budget; a plan may still exist |

```gdscript
var hurried: PlanResult = StripsPlanner.new().plan(
	GameDomain.actions(), GameDomain.opening_world(), GameDomain.goal(), 3)
print(hurried.solved, " ", hurried.gave_up)
# false true
```

The budget counts worlds taken off the frontier, and defaults to
`StripsPlanner.DEFAULT_BUDGET`. A planner runs inside a frame when it runs in a
game, so set the budget from the time you can afford, and treat `gave_up` as
"decide something simpler this turn" rather than as "impossible".

## From a PDDL file

The game does not read PDDL -- parsing a domain file is a tool's job, done
once, offline. `python/gameaikit/pddl/` reads one; the domain the game plans
over is written out in PDDL in `spec/vectors/planning/`, and the conformance
vectors hold the two descriptions to the same plans.
