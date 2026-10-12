# T20 — The RTS demo

Size: L · Prereqs: T19, T12 · Files: `godot/game/rts/`

## Goal

The real-time strategy demo: build orders, unit counters, fog of war, and the
planner from T11 running against the clock instead of against a turn.

Last on purpose. It needs the tactical content from T10, the honest difficulty
ladder from T12, the second core from T19, and everything the three earlier
games taught about making an AI legible. Built first, it would have been a
large pile of code with no lesson in it.

## Steps

1. The tactical content from T10, moved onto the real-time core. The unit
   types, towers, buildings and terrain are the same; what changes is time.
2. Build orders as plans: the same PDDL domain, replanned against a world that
   does not wait. The difference between this and T11 is the whole lesson of
   the task.
3. Fog of war, which makes planning under uncertainty real rather than
   theoretical, and which the influence maps from T14 already know how to draw.
4. Group movement with the flow fields from T19.
5. Three difficulties, built from T12's knobs and still not cheating.

## Acceptance

```bash
make check
```

```bash
./scripts/godot --headless --path godot -s res://test/rts_match.gd
```

That script plays a full AI-against-AI match headless with a fixed seed and
asserts it terminates, that the winner is consistent across runs, and that the
frame budget from T19 held throughout. A match that only works when somebody is
watching is not a match that works.

## Manual check

Play a full game against the middle difficulty. It should lose to a good player
and beat a careless one, and when it loses you should be able to say what it
got wrong.
