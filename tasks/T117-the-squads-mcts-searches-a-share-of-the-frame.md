# T117 — The squad's MCTS searches a share of the frame, in play

Size: S · Prereqs: T87 · Files: `godot/game/squad/`, `godot/test/squad/`, `spec/squad/rules.json`, `docs/godot/squad.md`

## Goal

The owner ratified on 2026-11-05 ("todas conforme recomendado") the
recommendation of STATUS's item A6, T87's decision 12: a follow-up that
searches a time share of the frame in play, and keeps the iteration count
for matches and tests.

`MctsSquad` searches a fixed 4 iterations a frame. That leaves about
11 ms of the 16.7 ms frame unused (PR #69, decision 12), so a decision of
1,000 iterations takes longer to watch than it needs to.

## Decisions written down first

_The owner ratified only the item quoted above. The decisions below are this session's proposal, written on 2026-11-05; the wave that takes the task confirms them, or brings them back to the owner._

- **In the scene, a share of the frame.** The search runs until a time
  share of the frame is spent, as `FrameBudget` does for the RTS
  (`godot/addons/ai_rts_core/frame_budget.gd`). The share is a constant
  in `spec/squad/rules.json` `search`, beside the iteration count.
- **In matches and tests, the count.** `make test-squad-match`,
  `make measure-squad-mcts` and the vectors keep counting iterations, so
  a seeded run is the same on any machine.
- **The decision is still 1,000 iterations.** Only how many run in one
  frame changes, so what is played does not depend on the machine's
  speed, only how soon.

## What wave 186 decided

The first and third decisions confirmed. The second confirmed for the
matches, the duel, the vectors and every test but those of the share --
and changed for `make measure-squad-mcts`: it now searches as the scene
does, on the share, because step 4 asks it for the frames a person sees,
and a counted measure would time frames the scene no longer runs. What it
plays is unchanged: a decision is still its iterations, so its wins are a
counted run's, and the measurement before and after won the same games by
the same number of decisions.

Two more, not in the proposal: the frame a decision is asked keeps its 4
counted iterations, being already the heavy one (it plays the last
decision, looks, guesses and finds the routes); and a frame on the share
runs one iteration at least, reading the clock after every one, so it
overruns its share by one iteration at most. `ExpectiSquad` keeps its
count: the share is in `SearchingSquad`, but only `MctsSquad` names one.

## Steps

1. Read `FrameBudget` and how the RTS scene uses it.
2. Give `MctsSquad` the two modes, the scene the time share.
3. A scene test: a frame's search stops by its share. A seeded test: the
   counted mode plays the same answers as before.
4. Measure the worst frame with `make measure-squad-mcts`, and write it
   on the page.

## Acceptance

```bash
make test-godot-some SUITES="test/squad"
make test-squad-search-vectors
make test-squad-match
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

In the XCOM mode, give the enemy to MCTS (C) with V on: does a decision
take visibly less time than with 4 iterations a frame, and does the
window still feel smooth?

## Notes

- Shares `godot/game/squad/` and `godot/test/squad/` with T88, T96,
  T124, T125, T126 and T127, and `spec/squad/` with T88, T96, T120 and
  T125. It does not run beside any of them.
