# Planning: search over worlds instead of cells

<!-- doc-meta
half_life: concept
verified_on: 2026-10-18
tier: 1
source: https://en.wikipedia.org/wiki/Stanford_Research_Institute_Problem_Solver ; https://en.wikipedia.org/wiki/Planning_Domain_Definition_Language
invalidated_if: StripsPlanner stops being breadth-first over whole worlds, HeuristicPlanner's heuristics stop being h_max and h_add, or the PDDL reader accepts parameters or conditional effects
teaches: planning
-->

> What STRIPS is, why a queue gives the shortest plan, and why the game's
> domain is a lesson about delete lists. Needs Python 3 and nothing else to
> follow along. The code is
> [`godot/addons/ai_planning/`](../../godot/addons/ai_planning/) and
> [`python/gameaikit/pddl/`](../../python/gameaikit/pddl/), and
> [the Godot page](../godot/planning.md) is how to call it.

## A world is a set of facts

STRIPS was developed by Richard Fikes and Nils Nilsson at SRI International in
1971. It describes a situation as a set of facts that are true -- `node_held`,
`barracks_built` -- and everything not in the set as false. An action has
three lists:

* **preconditions**, which must all hold for the action to run;
* a **delete list**, the facts that stop holding when it does;
* an **add list**, the facts that start holding.

Running an action is set arithmetic: take the world, remove the delete list,
add the add list. Nothing else about the world changes, which is the
assumption that makes the whole thing tractable.

## Planning is search, one level up

[Search](search.md) walked from cell to cell. A planner walks from world to
world: the start is the opening world, the neighbours of a world are the
worlds each applicable action leads to, and the goal is any world where the
goal facts hold.

`StripsPlanner` does exactly that, with a **queue** as the frontier. Worlds
come off in the order they were reached, so the first plan to arrive is one
with the fewest actions -- breadth-first, over worlds instead of cells. Two
details make it practical. A visited set, because several orders of the same
actions reach the same world. And a budget, so "no plan" can say *which* kind
of no: the space was exhausted (none exists) or the search was (it gave up).

Take the queue's newest world instead of its oldest and the planner still
answers, with a plan that wanders. A review found that one-word change left
every test in the repository green; a property test over randomly generated
domains that **fork** now catches it.

## The game's domain, and why it is a lesson

| action | needs | deletes | adds |
|---|---|---|---|
| march_to_node | army_in_reserve | army_in_reserve | army_at_node |
| take_the_node | army_at_node | -- | node_held |
| mine_the_node | node_held | -- | resources_banked |
| build_barracks | resources_banked | resources_banked | barracks_built |
| train_unit | resources_banked, barracks_built | resources_banked | unit_trained |
| scout_the_enemy | army_at_node | -- | enemy_scouted |
| attack | unit_trained, enemy_scouted | unit_trained | enemy_beaten |

The delete lists are where the planning is. The barracks and the unit are both
paid out of one bank, so the bank has to be filled **twice** with the barracks
in between. The shortest plan is eight actions. A reactive rule -- "if you have
resources, train a unit" -- never builds the barracks it needs, and that
difference between reacting and planning is what the domain exists to show.

## PDDL: the same domain, in the format everyone else reads

PDDL was created by Drew McDermott and colleagues in 1998 for the
International Planning Competition. It splits a planning task into a
**domain** (the actions, true of every situation) and a **problem** (one
starting world and one goal). Any planner outside this kit can read the game's
domain from [`spec/vectors/planning/`](../../spec/vectors/planning/).

The reader here accepts propositional STRIPS and nothing else, and refuses
everything outside it by name. A reader that skipped what it did not
understand would hand back a domain that parses perfectly and plans wrongly.
Try it, from the repository root:

```bash
PYTHONPATH=python python3 -c "
from gameaikit.pddl.reader import read_domain
domain = read_domain(open('spec/vectors/planning/supply-chain-domain.pddl').read())
for action in domain.actions: print(action)
"
```

## When not to use it

A domain with more than a dozen or so facts. The number of worlds is up to
two to the power of the number of facts, and a breadth-first planner looks at
them one by one -- `PlanResult.visited` reports how many. Real planners use a
heuristic (relaxed plans, landmarks) for exactly that reason, and the number
this one reports is the argument for them.

That argument is made in the kit too, since T11. `HeuristicPlanner` holds a
world as the bits of one integer and orders its frontier by actions taken plus
a guess (`RelaxedCost`, after Bonet and Geffner, 2001): drop every delete list,
and ask how many actions each fact is from being true. h_max takes the
dearest precondition and never overestimates, so the plan stays shortest;
h_add sums them, guides harder, and gives that up. On the tactical domain,
over the 60 boards with a plan from 18 real games:

| search | worlds visited | ms a plan |
|---|---:|---:|
| breadth-first, strings | 11102 | 5.07 |
| breadth-first, bits | 11102 | 0.70 |
| A\* with h_max, bits | 383 | 0.59 |
| A\* with h_add, bits | 383 | 0.58 |

`./scripts/godot --headless --path godot -s res://test/planner_benchmark.gd`
prints it, and asserts what the table's claims rest on.
