# T19 — The real-time core

Size: L · Prereqs: T10 · Files: `godot/addons/ai_rts_core/`

## Goal

The state model an RTS needs, which is not the one `ai_core` has.

`BoardState.apply` returns a **new** state and copies every unit into it. That
is exactly right for a search trying a thousand moves, and exactly wrong for
two hundred units at sixty frames a second. This task is where that is measured
rather than asserted, and where the second core is built if the measurement
says it is needed.

**Start by trying to prove this task unnecessary.** Benchmark the existing core
at RTS scale first. If it holds, the honest outcome is to write that down and
delete this task.

## Steps

1. A benchmark, before any new code: `BoardState` with 200 units, stepped 60
   times, timed. Publish the number whatever it says.
2. If it does not hold: a mutable world with continuous positions, and a
   separate immutable *snapshot* for anything that searches. The split is the
   design — the game mutates, the planner reads a frozen copy.
3. Spatial partitioning for neighbour queries, because the linear scan in
   `unit_at` is O(n) per lookup and an RTS does thousands per frame.
4. Flow-field pathing for groups, beside the per-unit A\* from T3. One unit
   asks a question; two hundred units ask the same question and should pay once.
5. **A frame budget the planner shares.** Movement and flow fields are not
   the only per-frame cost. The strategic planner (ADR 0010) and the
   influence maps run in slices spread across frames, as Killzone 3's anytime
   path planners do, and the budget states each slice's share in
   milliseconds. The StarCraft survey puts strategy on a scale of minutes and
   reactive control near a second. That is how *often* each layer needs to
   decide, not how much of a frame it gets: a strategic replan may be heavy and
   rare, so it is the one that has to be cut into slices.
6. An ADR recording why there are two cores, so the next reader does not assume
   it was an accident.

## Acceptance

```bash
make test-godot
python3 scripts/check_addon_deps.py
```

```bash
./scripts/godot --headless --path godot -s res://test/rts_core_budget.gd
```

That script holds the whole task honest: it runs both cores at the stated scale
and asserts the frame budget. If `ai_core` passes it, this addon should not
exist and the script says so by passing without it.

## Manual check

None that a person can do better than the benchmark. The number is the answer.
