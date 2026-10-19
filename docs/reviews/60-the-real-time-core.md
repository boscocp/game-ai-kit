# Review: wave/60-the-real-time-core

One fresh context reviewed it at its first commit (1834f37), in a worktree
of its own. It committed nothing; its probes and mutation drivers lived
outside the tree, every mutated file was restored byte for byte, and the
worktree was clean. gdUnit4 was copied in to run the suites and removed
after.

**Verdict: do not merge yet** -- two high findings and four medium. The
determinism, replay and budget machinery held, and every acceptance script
passed; but the snapshot leaked the enemy's buildings through the fog, a
building could be raised over a unit standing in its cell and wall it in
for good, and the tests never exercised BUILD nor checked that the digest
reads the units.

## What was reviewed

- `CLAUDE.md`, T19, ADR 0019, the whole diff; every file of
  `ai_rts_core` and the four test files.
- Run: `rts_core_budget.gd` (exit 0; ai_core 49.89 ms a step; simulation
  0.70 / p95 0.82 ms; flow fields 0.36 / p95 1.31 ms), `rts_simulation.gd`
  (exit 0; 72.5x real time), gdUnit `rts_core_test.gd` (13/13), `make
  test-godot` (999 cases, 0 failures), `check_readability`,
  `check_addon_deps`, `check_license`, `check_workflow`, `check_status` (all
  0). No `SCRIPT ERROR` in any run.
- Probes on `economies(19)` and small boards, and 16 mutations, of which
  5 survived: the digest without the units, a decision clock reading a
  constant, BUILD never completing or ignoring `is_free`, delivery adding
  nothing, and the budget recording zero (a self-report, said so).

## Findings

1. *high* -- fog leak through `RtsSnapshot.graph`. The snapshot copied the
   world's graph, where every building is a blocked cell: on `economies(19)`
   LEFT saw no enemy unit, yet its board had RIGHT's base, barracks and
   mines blocked. The test only checked `is_same`.
2. *high* -- units walled in by buildings. `is_free` looked within 0.5 of
   the cell's centre, so a unit at (5.05, 5.05) did not count and a build
   on (5, 5) was accepted; its cell then blocked, every later move gave up,
   and after 600 ticks it had not moved. A move whose goal was built over
   walked into the building.
3. *medium* -- the straight-line walk cut diagonal corners the
   four-connected board forbids: across a diagonal wall the field said
   unreachable, and the soldier walked through.
4. *medium* -- a building going up healed and rose again: its health was
   overwritten every tick, so a 200-point blow was undone the next, and a
   site killed earlier in the tick came back at 251 and was not buried.
5. *medium* -- the rules leaked fog: "not in sight" against "there is no
   unit" told which unseen ids were alive, BUILD had no sight check, and
   "not free to build on" revealed an unseen enemy worker. Refusals are
   free, so this was an oracle.
6. *medium* -- the tests were not honest about the digest or BUILD: the
   survivors above.
7. *low* -- the flow-field budget counted cells settled, not steps taken;
   stale pops and empty buckets were free.
8. *low* -- stale prose: the interface line printed even on failure;
   `RtsWorld.why_refused` named for `RtsRules.why_refused`;
   `LONGEST_SIGHT` copied from the table by hand with nothing holding it;
   `_why_train_refused` read `unit_ids[0]` before checking the size.
9. *low* -- the snapshot showed an enemy's order, load and queue.
10. *low* -- the view's cost was charged to nobody.

## What was done about them

Fixed on this branch in c3b5f54, and the fix was reviewed again before the
merge.

1. The snapshot's board restores the bare cost (`RtsWorld.bare_cost`) of
   every building the side cannot see; an enemy shows id, side, kind,
   position, health and complete only (also 9). gdUnit holds both.
2. `is_free` refuses a cell anybody's position falls in, corners included;
   a move whose goal has been built over ends. gdUnit holds the first.
3. `_step_is_clear` lets a diagonal step through only with both cells it
   slips between open, the goal cell included. gdUnit walks a soldier at a
   diagonal wall -- and caught the first version of the fix, which still
   exempted the goal.
4. A site gains its share of health a tick and keeps its damage; a dead
   site ends the order. gdUnit strikes one going up.
5. A gone and an unseen target get one refusal; BUILD asks for sight before
   it asks whether the cell is free.
6. `rts_simulation.gd` now nudges one unit and wants the digest to change,
   wants every side to carry income home (`RtsWorld.delivered`) and finish a
   building (`RtsWorld.raised`, because the second barracks can be raised
   and then lost), and wants the decision times to vary. The scripted sides
   now build. Re-run: the digest, delivery, constant-clock and
   never-progressing-build mutations each fail it; `is_free` ignored still
   passes it and fails gdUnit.
7. `FlowField.work` counts steps, and the slice is spent in steps.
8. The line prints only when its checks passed; the reference is fixed;
   gdUnit holds `LONGEST_SIGHT` to the table; the size is checked first.
10. Each decision logs `view_microseconds` beside its own time, uncharged.

The budget's self-reported time (survivor 5) stays as it is: the layers are
timed by the world that runs them, and that is said in `FrameBudget`'s
header.

**The second look.** The same reviewer re-ran everything at c3b5f54 (both
scripts exit 0, gdUnit 19/19, no `SCRIPT ERROR`), found all ten fixed, no
regression in replay, auto-attack or diagonal gathering, and the 326
refusals all TRAIN without the money. It found two more:

- A. *medium* -- the MOVE refusal was still a fog oracle: it read the
  world's graph, so a move onto an unseen enemy base was refused while the
  side's own board showed the cell open. A blocked cell is now refused only
  when the side can see it; a move into one in the fog is taken and ends
  where `_move` finds the goal blocked, as a player's would.
- B. *low* -- three fixes had no test that failed without them: a dead site
  raised again, a move walking into a goal built over, an enemy's orders
  shown. Each has a gdUnit case now, and each mutation was re-run and
  fails it (23 cases). The dead site is struck to exactly 0, the one
  health the next tick's share of 1 would otherwise bring back.
