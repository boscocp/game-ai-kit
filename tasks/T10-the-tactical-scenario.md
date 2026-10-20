# T10 — The tactical scenario

Size: L · Prereqs: T8 · Files: `godot/game/`, `godot/addons/ai_core/`

## Goal

A turn-based tactical scenario with enough in it to make a plan worth making:
five unit types, two kinds of defence tower, the buildings that produce them,
and terrain that matters. Shaped like Advance Wars rather than StarCraft, and
that is the point — it reuses `ai_core` exactly as it is.

**Why turn-based first.** `BoardState.apply` returns a *new* state and copies
the units into it. That is what lets a search try a thousand moves without the
board remembering any of them, and it is why a real-time version needs a
different core — which is T19, in its own milestone, deliberately after this.

## Steps

1. Five unit types, differing in what a planner can reason about: movement,
   range, what they are strong against, and what they cost to produce. Rock-
   paper-scissors is a lesson, not a cliché — it is what makes a plan beat a
   reflex.
2. Two defence towers: one that shoots, one that sees. A tower is a unit that
   cannot move, so this should add a field, not a hierarchy.
3. Buildings that produce units, and a resource to pay with. The smallest set
   that makes a build order a real decision: one producer, one resource, one
   upgrade.
4. Terrain: rock (blocked), trees (expensive, blocks sight), water (blocked for
   most, passable for one unit type). All of it is already `GridGraph` costs —
   terrain *types* belong to the game, not to `ai_core`.
5. Names and silhouettes that are yours. Mechanics are not copyrightable;
   names, unit designs and trade dress are. Do not call anything a marine.

## Acceptance

```bash
make test-godot
make test-vectors
python3 scripts/check_addon_deps.py
python3 scripts/check_readability.py
```

```bash
grep -q "class_name UnitType" godot/addons/ai_core/unit_type.gd
grep -c "func test_" godot/test/tactical/tactical_scenario_test.gd | grep -qvx 0
```

The suite must include: a unit that cannot enter water and one that can; a
tower that cannot move; a build order that is refused for cost and the same one
accepted after income; and the counter table being symmetric in the way it
claims to be.

## Manual check

Play one side against yourself for three turns. The five types should feel
different without reading their numbers, and the terrain should change where
you want to stand.
