# Review: wave/56-ai-behaviour

One fresh context reviewed it, in the main worktree, at the wave's first
commit (0a70aec), and again at the fix commit (1f056d5). It wrote nothing in
the repository; the probes it ran it deleted, and the tree was clean both
times.

**Verdict: merge after fixes.** No blocker. Every gate passed and the
engines were sound -- GOAP's regression, the HTN's backtracking, the tree's
semantics, the state machine's one arrow an update. What was wrong was what
a person would see and what the tests would let through: the demo left to
run showed one behaviour every brain shared, and the tests that were meant
to tell the four apart would have passed a brain that never decided.

## What was reviewed

- `CLAUDE.md`, T15, the concept page's GOAP and HTN sources, and the whole
  diff `main...HEAD`.
- Run: `make check`, `make test-godot` (951, then 957), `demo_overlays.gd`,
  the benchmark (its numbers reproduced), `check_readability`,
  `check_addon_deps`, `check_license`, `check_demos`; probes of 200 and 600
  turns a brain, and of single boards, deleted after.

## Findings

1. *major* -- left to run, the guard followed the intruder one cell behind
   for ever: every brain went to look on almost every turn, and none chased,
   caught or looked round. The manual check would have failed as shipped.
2. *major* -- the agree and differ tests expected "walk the round", every
   brain's fallback: a GOAP brain that always answered it passed the suite.
3. *major* -- the state machine chased an intruder it could not see, towards
   its true cell, through walls: it knew more than the other three.
4. *major* -- steps 1 and 2 ask the demo to draw the machine with its state
   lit and to show the shared subtree; it did neither, and the tree's trail
   left out every composite node.
5. *minor* -- STRIPS's claim of the shortest plan, against GOAP's cheapest,
   was not said.
6. *minor* -- "the same number of worlds" compared tasks with worlds, and the
   time gap was put down to the direction of search, not to this GOAP.
7. *minor* -- the admissibility condition was stated wrongly.
8. *minor* -- the HTN's rollback and GOAP's budget had no test that bit.
9-13. *nits* -- `gave_up` on a search that was not cut off; the state
   machine's diagram; "the same six things"; doc comments repeating the line
   below; a fresh brain showing a deed it had not decided.

At the second look all thirteen were fixed, and five new ones found: the
tree's "go and look" under the chase never shows unattended; the 300-turn
test named a tuning result as a law; "2-3 worlds" in STATUS; the record
saying every brain chases; an intruder restarting on the guard's cell.

## What was done about them

Fixed on this branch, and the fix was reviewed again before the merge; the
second look's five were fixed after it, small enough not to need a third.

- 1: the intruder sprints a loop and stands silent at its corners, one of
  them the lit doorway; "at the place" is on or beside it. Left to run, the
  state machine and the HTN look, chase and catch; the tree and GOAP turn
  back -- on this loop -- and GOAP chooses the tree's deed every turn.
- 2: boards where all four must chase and must catch, the fading search's
  intermediate deeds, and the 300-turn run; GOAP answering "walk the round"
  every turn now fails.
- 3: the intruder's cell is known only while seen; alerted and blind, the
  state machine goes and looks. Tested.
- 4: `BrainPanel` draws the state, the trail -- composites in it, "go and
  look" marked -- and the plan with its step lit; a test holds "go and look"
  under both branches.
- 5-8: said; the HTN undoes a branch in one place, and removing it fails a
  test.
- 9-13 and the second look's five: as asked. The manual check now says to
  swap to the tree while the state machine chases.

Not fixed, on purpose: the panel's drawing is checked by no command --
`--headless` draws nothing (invariant 13) -- so it is the manual check's.
