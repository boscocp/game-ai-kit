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

## Manual check

Watch the planner play a full game against a scripted opponent, with the plan
drawn. Its mistakes should be *legible* mistakes — you should be able to say
which precondition it was wrong about.
