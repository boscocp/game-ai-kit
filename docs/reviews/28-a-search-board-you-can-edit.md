# Review: wave/28-a-search-board-you-can-edit

One fresh context reviewed it, in its own git worktree, detached at the
feature commit. It read the task, the diff and the docs, measured the boards
and the text against the window, checked the replayed frontier on every
named board and on edited ones, and ran 26 mutations. The session ended
mid-review once; it was resumed from its transcript and finished.

## What was reviewed

Commit 978164c on this branch:
- `godot/demos/search/search_board.gd`: the four named boards as text, their
  promises and the checks that keep them;
- `godot/demos/search/search_demo.gd`: painting, erasing, the dots, the price
  of mud, B, C and R, re-searching on every change, and "no route";
- the scene's new help panel, `godot/test/search_demo_test.gd`, and the
  README, `docs/concepts/search.md` and `docs/godot/examples.md`.

## Findings

Of 26 mutations, 7 were killed and 19 survived.

### Must fix

- **The mouse had no test at all**, and the mouse is what the owner asked
  for. Four mutations survived: a press on the goal painted instead of
  picking it up; motion did nothing, so no drag; letting go did not stop the
  brush; a right-click painted. Headless delivers no input, but nothing
  stopped the handlers from being called with a constructed event.

### Should fix

- The start could be moved onto the goal: only the goal onto the start was
  tested.
- R after C rebuilt the first board, not the one you started from, as the
  header and the help said.
- The depth-first trap's check held on the open field too (51 against 13):
  it checked a dear route, not the sweep that makes it a trap.
- Untested: the open-ground brush, which way B steps, the price of mud
  carried into the next board, and moving a dot marking the board edited.

### Notes

- A price key on a board with no mud marked it edited.
- A fast drag left gaps, because only the cell under each motion event was
  painted.
- `frontier_after(0)` was unpinned, and `searches()` had a `#` comment where
  a public function needs `##`.
- Four sub-clauses of the promise checks are redundant on today's layouts.
- Mud of two prices would merge once the price walked onto the other.
- The wall-and-mud numbers quoted in the README had no test.
- Checked and clean: every line fits its label; the maze is a perfect maze
  (95 cells, 94 passages, no cycle); the frontier derivation matched the
  real one on all boards, walled off and edited; the quoted numbers match.

## What was done about them

- The mouse layer is `pointer(event, cell)`: public, handed the cell, so
  only reading the cursor is left untested. Seven tests drive it with
  constructed events, covering press, right press, drag, a fast drag, letting
  go, and picking up each dot.
- A drag now paints every cell on the line since the last event.
- R remembers the named board through C. The trap's check also asks that
  depth-first expands more than five times what Dijkstra does (137 against
  9). Its negative case is now the open field, the board that passed the old
  check.
- New tests pin:
  - the start not landing on the goal;
  - the open-ground brush, and one press of B going to the maze;
  - a new board's price of mud, and both dots marking the board edited;
  - a price key on a board without mud editing nothing;
  - the frontier before any step, and the wall-and-mud numbers.
- A price key that reprices nothing no longer edits. The latent merge is
  written down where the repricing is.
- The 12 real survivors, the trap check, the fast drag and the no-op price
  were planted again against the fixes. All 15 went red, each on the test
  written for it. M10 was caught by the older rebuild test, which fails first
  in the suite.
- Left as they are: the redundant clauses, which are harmless and are
  noted; and `searches()` now has its `##`.

The fixes were not reviewed by a second fresh context.
