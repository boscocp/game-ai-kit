# T11 — The planner plays

Size: L · Prereqs: T4, T10 · Files: `godot/addons/ai_planning/`, `godot/game/`

## Goal

STRIPS drives a faction: it is handed the board and a goal, and it returns a
sequence of actions — produce, move, attack — that reaches the goal. The
planner from T4 stops being a demonstration and becomes an opponent.

This is the task the whole kit has been walking towards. A build order *is* a
plan, which is why planning is taught on a strategy game and not on a maze.

## Steps

1. The domain: actions with preconditions and effects, in PDDL, read by the
   Python reader from T4 and executed in GDScript. The domain file is data, not
   code, and lives in `spec/` beside the vectors.
2. The bridge: a `BoardState` becomes a set of predicates, and a planned action
   becomes a `Move` or a production order. Keep it one file and one direction —
   predicates out, actions in.
3. `DecisionPolicy` is the interface it implements, so the game can hold a
   planner, a script or a learned model and not care which.
4. Replanning: a plan made two turns ago is wrong by now. Decide and write down
   *when* it replans — every turn, on failure, or on a changed predicate — and
   why that choice.
5. The plan must be inspectable. A planner you cannot watch think is a planner
   nobody will trust or debug: print the plan, and draw it on the board.
6. **A heuristic, a bit-packed state and a budget** (ADR 0010). Breadth-first
   stays as the readable version. Beside it go h_max (admissible, so the plan
   stays shortest) and h_add (guides harder, gives up shortest), after Bonet
   and Geffner (2001). The state is held as bits rather than as the sorted,
   joined string `WorldState.key()` builds today -- twice per generated world,
   `strips_planner.gd` calls it twice. Every call has a budget. Breadth-first
   and A\* have no complete plan until they finish, so a call that runs out
   returns the partial plan to the expanded world with the lowest `h`,
   labelled as partial, and the game acts on its first step only. If that
   proves too weak, depth-first branch and bound (Churchill and Buro) has a
   complete plan early and is the alternative to measure.
7. **Measure before choosing.** Worlds visited and milliseconds per plan, for
   breadth-first, h_max and h_add, with strings against bits, on this task's
   real domain. Publish the table in the addon header and in
   [planning in strategy games](../docs/concepts/planning-in-strategy-games.md),
   whatever it says. The heuristic the game uses is the one the table picks.
8. **Replan on a cadence and on failure**, never every turn by default: a
   fixed interval plus invalidation when a predicate the plan relies on
   changes, as Killzone 3's bots do. Write down the interval and why.

## Acceptance

```bash
make test-godot
make test-python
make test-vectors
```

```bash
./scripts/godot --headless --path godot -s res://test/planner_properties.gd
```

The property to assert, over generated boards rather than one example: every
action in a returned plan has its preconditions satisfied at the moment it is
executed, and executing the whole plan reaches the goal predicate. A plan that
is merely returned is not a plan that works.

```bash
grep -q "domain" spec/pddl/tactics-domain.pddl
```

```bash
./scripts/godot --headless --path godot -s res://test/planner_benchmark.gd
```

That script runs every search the task builds over the same seeded problems
and asserts three things. h_max's plans are exactly as short as breadth-first's,
because an admissible heuristic must not change the answer. On the seeded set
-- not on every problem, which no theorem promises, since h_add can wander and
breadth-first here tests the goal on generation while A\* tests it on
expansion -- each heuristic visits fewer worlds in total than breadth-first.
And a call given a budget returns within it. It prints the table step 7 publishes, so the numbers in the
docs have a command behind them.

## Manual check

Watch the planner play a full game against a scripted opponent, with the plan
drawn. Its mistakes should be *legible* mistakes — you should be able to say
which precondition it was wrong about.
