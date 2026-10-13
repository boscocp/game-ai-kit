# T15 — `ai_behaviour`: the four ways to decide

Size: L · Prereqs: T14 · Files: `godot/addons/ai_behaviour/`, `godot/demos/behaviour/`

## Goal

A finite state machine, a behaviour tree, GOAP and an HTN — the same guard,
written four times, on the same board.

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
4. HTN: the same guard as tasks decomposed by methods, planned forward from
   the current state. The comparison with GOAP is the one shipped games made:
   at one studio a forward HTN was "considerably faster" than the GOAP system
   before it (Humphreys, Game AI Pro ch. 12). GOAP and STRIPS search backward
   from the goal, and HTN can return a partial plan. Measure both on this
   guard, with the same counters T11 uses, and say whether the claim holds
   here.
5. One table, in the addon's header, saying when each of the five is the right
   answer, STRIPS included. That table is the deliverable; the code is the
   evidence for it. Its sources are in
   [planning in strategy games](../docs/concepts/planning-in-strategy-games.md).
6. Each implements `DecisionPolicy`, so the demo can swap them while the game
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

The suite must assert that all four produce the same decision on a board built
so that they must — if they disagree there, one of them is wrong, and if they
can never disagree anywhere the comparison has nothing to teach. Assert both: a
board where they agree, and a board where they are documented to differ.

## Manual check

Swap between the four while a guard is mid-patrol. The seams should be
visible: the FSM snaps, the tree reconsiders, GOAP replans, the HTN carries on
down the method it chose. If they all look identical, the demo is not showing
the difference it was built for.
