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
2. **Three layers, as ADR 0010 sets out**: a commander that plans, squads
   that score, units that move. Only the commander plans. Squads choose
   regions by utility over the influence maps (Dill's Kohan II chapter);
   units take A\* or a flow field.
3. **The economy as priority queues** under the commander, which is what AoE
   II, Supreme Commander and 0 A.D. ship. A commander that does not beat the
   queues alone has not earned its cost, and the match test says which.
4. Build orders as plans: the PDDL domain at level 1, with resources as income
   rates and time jumping to the next legal action rather than stepping frame
   by frame (Churchill and Buro, 2011). It is replanned on T11's cadence
   against a world that does not wait, and that difference from T11 is the
   lesson of the task. Whether the commander is T11's heuristic STRIPS or
   T15's HTN is measured here, and ADR 0010 is amended with the answer.
5. Fog of war, which makes planning under uncertainty real rather than
   theoretical, and which the influence maps from T14 already know how to draw.
6. Group movement with the flow fields from T19.
7. The difficulty levels and the human-likeness axis from T12 and T25, still
   not cheating.

## Acceptance

```bash
make check
```

```bash
./scripts/godot --headless --path godot -s res://test/rts_match.gd
```

That script plays a full AI-against-AI match headless with a fixed seed and
asserts it terminates, that the winner is consistent across runs, that the
frame budget from T19 held throughout, and that no single planning call
exceeded its budget. It also plays the commander against the priority queues
alone and prints the win rate. A match that only works when somebody is
watching is not a match that works.

## Manual check

Play a full game against the middle difficulty. It should lose to a good player
and beat a careless one, and when it loses you should be able to say what it
got wrong.
