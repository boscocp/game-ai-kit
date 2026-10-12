# Review: tasks/12-the-second-milestone

Not reviewed by a fresh context. It adds no code and changes no gate: thirteen
task files, two milestone tables, and a note in the resuming log.

## What was reviewed

The thirteen new task files against `check_acceptance.py` and
`check_status.py`, which is a weaker review than a person reading them and is
said plainly rather than dressed up. Every file has a header carrying both
`Size:` and `Prereqs:`, every prerequisite names a task that exists, every
acceptance block is commands with exit codes, and everything needing eyes is
under `## Manual check`.

## Findings

**T8 exists because a manual check worked.** The owner ran `make run` and could
not tell what he was looking at. T2 promised the board would be legible without
reading the code -- whose turn it is, where a unit may go, what it costs -- and
it is not. The failure was measured rather than described: a 384x256 board in a
1280x720 window drawn at (80, 80), a palette of three dark colours, no grid
lines, a status line 620px from the board it describes, a reachable highlight
that replaces the terrain tile so the ground is hidden exactly when its cost
matters, and the cost never drawn at all.

That is the first evidence in this repository of a `## Manual check` catching
something no gate could. It is worth saying out loud, because the manual checks
have so far been written and never run.

**Three decisions are taken in the task files rather than left open**, each
with its reason, because the next agent will otherwise rediscover them badly:
the strategy game is turn-based first (BoardState.apply copies every unit into
a new state -- right for a search, wrong for 200 units at 60fps); art is CC0
now and generated later; and the RTS is last of everything.

**Two task files are deliberately uncomfortable.** T16 says most of the
fighting game is not AI work. T19 opens by telling whoever picks it up to try
to prove the task unnecessary, benchmark first, and delete it if the existing
core holds. A task that cannot be cancelled by evidence is a plan, not a task.

## What was done about them

They are the deliverable, not findings to fix. `make wave-next` still answers
T4: milestone 1 is finished before milestone 2 starts, which is what the table
order means.

What this record cannot claim: nobody has read these thirteen files for whether
the work they describe is the right work. The gates checked their shape. The
owner chose their order and their three big decisions; the decomposition inside
each one is this session's guess and should be argued with when it is picked up.
