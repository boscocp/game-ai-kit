# T15 — `ai_behaviour`: the four ways to decide

Size: L · Prereqs: T14, T11 · Files: `godot/addons/ai_behaviour/`, `godot/demos/behaviour/`

## Goal

A finite state machine, a behaviour tree, GOAP and an HTN — the same guard,
written four times, on the same board.

Written four times on purpose. The question a reader actually has is not "what
is a behaviour tree", it is "when would I use one instead of the thing I have",
and that question is only answerable side by side. STRIPS from T11 is the
fifth corner of the comparison and is already written.

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
   before it (Humphreys, Game AI Pro ch. 12). GOAP searches backward from the
   goal (this kit's STRIPS planner searches forward, so say which you
   compare), and HTN can return a partial plan. Measure both on this
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
grep -c "func test_" godot/test/demo_behaviour/behaviour_test.gd | grep -qvx 0
```

The suite must assert that all four produce the same decision on a board built
so that they must — if they disagree there, one of them is wrong, and if they
can never disagree anywhere the comparison has nothing to teach. Assert both: a
board where they agree, and a board where they are documented to differ.

## Manual check

(Added in wave 56: swap to 2, the tree, while the state machine is chasing,
to see "go and look" lit under the chase branch as well as under the
investigation.)

Swap between the four while a guard is mid-patrol. The seams should be
visible: the FSM snaps, the tree reconsiders, GOAP replans, the HTN carries on
down the method it chose. If they all look identical, the demo is not showing
the difference it was built for.

## What was done (2026-10-19, wave 56) -- done, manual check still a person's

- `ai_behaviour`: `StateMachine`, `BehaviourTree`, `GoapPlanner` (A\* backwards
  from the goal, a cost per action, the cheapest plan) and `HtnPlanner`
  (forwards, methods in order, backtracking), with `BehaviourPlan`;
  `WaysToDecide` is the table, with STRIPS -- forwards, the fewest actions --
  as the fifth row.
- `demos/behaviour/`: T14's room and perception, one guard -- patrol,
  suspicious, searching, alerted -- written four times, each a
  `DecisionPolicy`; `make demo-behaviour` swaps them mid-round (1-4), and a
  panel draws what the playing brain thinks: the state machine's states with
  the current one lit, the tree's path with "go and look" marked under each
  branch that reached it, the plan with its step lit. An intruder sprints a
  loop and stands silent at its corners -- one of them the lit doorway -- so
  with nobody at the keys the guard notices, loses and looks, and with the
  state machine or the HTN chases and catches too; the tree and GOAP turn
  back before that on this loop, so their "go and look" under the chase is
  seen by swapping to them while another brain is chasing.
- `test/demo_behaviour/behaviour_test.gd`, 17 cases: the engines; then the guard. All four
  agree on a calm round, on setting out to look, on a chase and on a catch;
  none chases what it does not see; as suspicion fades mid-search the state
  machine and the HTN carry on and the tree and GOAP turn back; and over 300
  turns the two that commit look, chase and catch while the two that
  reconsider never chase -- GOAP choosing the tree's deed every turn.

**GOAP against HTN, measured** (`make test-behaviour-benchmark`): in four
moments GOAP took 2, 3, 2, 3 worlds off its frontier and the HTN took up 2,
3, 2, 3 tasks -- the nearest counts, not one unit -- and the HTN was faster
per plan, about 6-8 microseconds against 6-16. That holds for these two
implementations; much of GOAP's extra is how this one keeps its frontier, so
the guard cannot say it holds for the two directions of search.

**Found on the way.** A test caught the GOAP planner dropping a goal fact the
world already had, which let an action that undoes it into a plan; nodes now
keep the whole goal. The HTN walked to where it already stood until a "look
here" method was written. The review found the unattended demo settling into
one behaviour every brain shared, the state machine chasing an intruder it
could not see, and tests a brain answering "walk the round" every turn would
have passed; all fixed, each fix held by a test that fails without it.
