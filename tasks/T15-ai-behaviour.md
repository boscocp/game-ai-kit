# T15 — `ai_behaviour`: the three ways to decide

Size: L · Prereqs: T14 · Files: `godot/addons/ai_behaviour/`, `godot/demos/behaviour/`

## Goal

A finite state machine, a behaviour tree, and GOAP — the same guard, written
three times, on the same board.

Written three times on purpose. The question a reader actually has is not "what
is a behaviour tree", it is "when would I use one instead of the thing I have",
and that question is only answerable side by side. STRIPS from T11 is the
fourth corner of the comparison and is already written.

## Steps

1. The FSM: patrol, suspicious, searching, alerted. Small enough to draw, and
   the demo should draw it with the current state lit.
2. The behaviour tree: the same guard, as selectors and sequences. Where it wins
   over the FSM is reuse and composition, and the demo should show the same
   subtree appearing in two places.
3. GOAP: the same guard again, as goals and actions with costs — and the
   comparison with STRIPS, which is the same idea with a different frontier and
   a different claim about optimality.
4. One table, in the addon's header, saying when each of the four is the right
   answer. That table is the deliverable; the code is the evidence for it.
5. Each implements `DecisionPolicy`, so the demo can swap them while the game
   runs.

## Acceptance

```bash
make test-godot
python3 scripts/check_addon_deps.py
python3 scripts/check_readability.py
```

```bash
grep -c "func test_" godot/test/behaviour_test.gd | grep -qvx 0
```

The suite must assert that all three produce the same decision on a board built
so that they must — if they disagree there, one of them is wrong, and if they
can never disagree anywhere the comparison has nothing to teach. Assert both: a
board where they agree, and a board where they are documented to differ.

## Manual check

Swap between the three while a guard is mid-patrol. The seams should be
visible: the FSM snaps, the tree reconsiders, GOAP replans. If all three look
identical, the demo is not showing the difference it was built for.
