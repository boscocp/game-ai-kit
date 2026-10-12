# Review: docs/09-what-was-not-written-down

Reviewed 2026-10-12. **This branch was not reviewed by a fresh context**, and
saying so is the first thing in the record rather than the last. It is
documentation only — no code, no gate, no test — and it exists because somebody
asked whether the project was in a state another agent could pick up, and the
answer turned out to be *nearly*.

## What was reviewed

The handover itself, checked by reading what a fresh agent is told to read:
`tasks/STATUS.md`'s topmost section, `CLAUDE.md`, `CONTRIBUTING.md`, the four
records under `docs/reviews/`, and `tasks/T4-ai-planning.md`. Then everything
this session learned the expensive way was listed and checked against those
files, one by one.

## Findings

**1. The wave 08 section of `STATUS.md` predated its own review and never
mentioned it.** Twelve findings had landed since it was written — the dead
branch in `dijkstra.gd`, the retraction in `astar.gd`, the unvalidated search
start, the runner that was a gate with no planted case, the demo hiding the
terrain it exists to explain — and the resuming prompt said none of it and did
not link `docs/reviews/08-ai-search.md`. A fresh agent would have begun from a
picture of the repository that was two commits and twelve findings out of date.

**2. Counts in the task table had already gone stale.** T2 said "34 tests" and
T3 "72 tests"; the suite is 90. A reviewer had already made this point about a
different number in a different file, and the same mistake was sitting in the
index.

**3. Four traps this session hit were written down nowhere.** Each cost real
time and each would cost it again:

- a new `class_name` is invisible until `--import` runs, and the failure reads
  like a typo (`Could not find type "X"`);
- a failing gdUnit4 suite stops at the first red test, so the case count in a
  red run is not the number of tests in the file;
- the forbidden-term list is untracked and a checkout of anything older than
  wave 6 deletes it from disk, after which the gate reports that it checked
  nothing;
- `make` collapses failures to exit 2 — this one *was* written down, and is
  listed here only because it is the model the other three now follow.

## What was done about them

The wave 08 section now carries its review in summary and links the record. The
task table's counts are gone rather than corrected, because a count in an index
is a number that goes stale on the next commit; what is left says what kind of
checking exists, which does not.

The three missing traps are in `CLAUDE.md` under "Traps that have already cost
time", which is the section a new agent reads before starting. Two of them were
already in `docs/godot/addon-anatomy.md` in full; the entries in `CLAUDE.md` are
the one-line warning with a pointer, because the half-life page is where the
measurement belongs and the instructions file is where somebody will see it.

`STATUS.md` also now tells the next wave to begin by reviewing this one. Three
reviews in this project have each found real defects in work the previous review
had passed over or never reached, which is the argument for the rule rather than
against it.
