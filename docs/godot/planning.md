# Wiring ai_planning into a game

<!-- doc-meta
half_life: practice
verified_on: 2026-10-18
tier: 2
source: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html
invalidated_if: Godot changes how class_name registers a class, or the StripsPlanner or PlanResult signatures change
teaches: planning
-->

> How to describe a domain in GDScript, ask for a plan and tell the two kinds
> of failure apart. Every snippet was run on the pinned Godot 4.7.2 on
> 2026-10-13 (the heuristic planner's on 2026-10-18), and the outputs shown are what it printed. Why it works is
> [the concept page](../concepts/planning.md).

**In the game since T11.** `make demo-tactical`, then C: blue is played by a
plan over the tactical domain (`spec/pddl/tactics-domain.pddl`), drawn on the
board, and listed on the panel and in the decision overlay. The game plans with `HeuristicPlanner`;
`StripsPlanner` is the version to read first. What follows is how to call
either from your own code.

## What to copy

`addons/ai_planning/` on its own -- the planner needs nothing from `ai_core`,
because it plans over facts rather than over a board. From a release, unzip
`ai_planning-<version>.zip` into `res://addons/`.

## A plan, from the game's own domain

```gdscript
var plan: PlanResult = StripsPlanner.new().plan(
	GakGameDomain.actions(), GakGameDomain.opening_world(), GakGameDomain.goal())
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
	GakGameDomain.actions(), GakGameDomain.opening_world(), GakGameDomain.goal(), 3)
print(hurried.solved, " ", hurried.gave_up)
# false true
```

The budget counts worlds taken off the frontier, and defaults to
`StripsPlanner.DEFAULT_BUDGET`. A planner runs inside a frame when it runs in a
game, so set the budget from the time you can afford, and treat `gave_up` as
"decide something simpler this turn" rather than as "impossible".

## Faster: bits, a guess, and a budget that still answers

`HeuristicPlanner` takes the same actions, start and goal, and a search:

```gdscript
var planner := HeuristicPlanner.new()
var plan: PlanResult = planner.plan(GakGameDomain.actions(), GakGameDomain.opening_world(),
	GakGameDomain.goal(), HeuristicPlanner.Guide.H_MAX)
print(plan.solved, " ", plan.visited, " ", plan.steps.size())
# true 12 8
var hurried: PlanResult = planner.plan(GakGameDomain.actions(), GakGameDomain.opening_world(),
	GakGameDomain.goal(), HeuristicPlanner.Guide.H_ADD, 3)
print(hurried.partial, " ", hurried.gave_up, " ", " -> ".join(hurried.action_names()))
# true true march_to_node -> take_the_node
```

`H_MAX` keeps the plan shortest; `H_ADD` guides harder and may not;
`BREADTH_FIRST` is `StripsPlanner`'s search over bits, with no partial plan to
give. A partial plan is the way to the world that looked nearest the goal when
the budget ran out: act on its first step and plan again. The measured table
is in `heuristic_planner.gd`'s header. A domain with more than 63 facts does
not fit in an `int`; the call says so with `push_error` and returns
`gave_up`, never "impossible".

A sixth argument, the **horizon**, is how many actions ahead the search may
look (T12). A world that far from the start is weighed and not expanded, so a
goal further off comes back as a partial plan of at most that many steps --
never as "impossible", because what was cut off was not searched. The budget
bounds the work; the horizon bounds how far the plan sees, which is a
difficulty knob, not a performance one:

```gdscript
var short: PlanResult = planner.plan(GakGameDomain.actions(), GakGameDomain.opening_world(),
	GakGameDomain.goal(), HeuristicPlanner.Guide.H_MAX, HeuristicPlanner.DEFAULT_BUDGET, 3)
# short.partial is true, and short.steps holds at most 3 actions
```

## How much it may think: `Difficulty`

`Difficulty` is a level as three numbers and nothing else: `plan_horizon` (the
argument above), `search_depth` in plies and `evaluation_noise`. It holds no
logic; a controller reads it. `Difficulty.presets()` is the ladder the tactical
board plays (`LeveledBlue`), and `Difficulty.KNOBS` is the allowlist
`test/tactical/difficulty_knobs.gd` holds every preset to -- a level with a field more,
such as more vision, is refused. On that board every preset plans 0 actions
ahead: measured, T11's plan made a side weaker, and a knob that weakens what it
is meant to strengthen is not a difficulty knob there.

## From a PDDL file

The game does not read PDDL -- parsing a domain file is a tool's job, done
once, offline. `python/gameaikit/pddl/` reads one; the domain the game plans
over is written out in PDDL in `spec/vectors/planning/`, and the conformance
vectors hold the two descriptions to the same plans. The tactical domain is
the same arrangement in `spec/pddl/`: the PDDL, a JSON twin `make test-python`
holds equal to it, and a byte-for-byte copy of the JSON the game reads.
