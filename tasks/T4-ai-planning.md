# T4 — `ai_planning`: STRIPS over the game's own domain

Size: L · Prereqs: T2 · Files: `godot/addons/ai_planning/`, `python/gameaikit/pddl/`

## Goal

A STRIPS planner the AI uses to answer *what do I have to do first*: to attack I
need a unit, to have a unit I need resources, to have resources I need to hold
the node. The chain is short enough to follow by hand and long enough that a
reactive rule cannot produce it.

The planner runs in the game, in GDScript. The PDDL **file parser** stays in
Python, because reading a domain file is not something a game does at runtime —
it is something a tool does once, offline.

## Steps

1. State as a set of predicates; an action with preconditions, add and delete
   lists. Forward state-space search, reusing the frontier from `ai_search`
   conceptually but **not** by import — invariant 2.
2. The game's domain written out in full, in one readable file.
3. A Python reader for a PDDL subset, so a domain can come from a file a
   non-programmer wrote.
4. Conformance vectors in `spec/vectors/planning/` that both sides run.

## Acceptance

```bash
make test-godot
make test-python
make test-vectors
python3 scripts/check_readability.py
```

The two failure modes that matter, asserted — an unsolvable domain must return
an empty plan rather than hang, and a solvable one must return a plan whose
every step's preconditions hold when it runs:

```bash
./scripts/godot --headless --path godot -s res://test/planner_properties.gd
```

## Manual check

Read the domain file and decide whether someone who has never seen STRIPS could
tell what the AI is reasoning about.
