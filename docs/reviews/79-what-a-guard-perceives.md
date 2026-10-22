# Review: wave/79-what-a-guard-perceives

A fresh context reviewed T69 at `fbf9e4c`: in `ai_perception`, vision
zones and body points, light at the feet, hearing by path length (with a
cost flood in `ai_search`), typed events, an awareness accumulator with
phases read from data, a target memory and a belief map; the
`infiltration` module wiring them to guard types in `guard_types.json`,
with the fuzzy rate and the flood passed in as data; Python twins,
vectors and a properties script over generated levels. It was not
allowed to edit the worktree. It ran the perception, search and fuzzy
vectors (0 failures), `make test-python` (334 OK), the gdUnit suites of
`ai_perception`, `infiltration` and `ai_search` (113 cases), the
addon-dependency, module and readability gates, and
`awareness_properties.gd` (exit 0, no SCRIPT ERROR); it regenerated the
perception vectors from `derive.py` byte for byte, and mutated the fuzzy
rate to a constant in a scratch copy -- the inverted-light plant then came
back uncaught and the run failed, as it should.

**Verdict: fix one gap, then merge.**

## What was reviewed

- `CLAUDE.md` (invariants 2, 3, 4, 6, the readability limits, the SCRIPT
  ERROR trap), T69's task, `docs/concepts/stealth-ai.md`, the owner's rule
  that a guard is an agent weighing what it perceives.
- Invariant 2 by reading each addon's references: `ai_perception` names
  only `GridGraph`.
- That nothing in the guard's mind reads where the target really is:
  `GuardMind` reads only `GuardPercept`; the memory is written only from
  what was seen or heard; the belief has no position input.
- The belief map's mass (kept by construction, renormalised only after
  zeroing what was seen), the flood's correctness, the twins line by line.
- Every claim's planted case, and the cited numbers against wave 74's
  quotes (not re-fetched).

## Findings

1. **The portability claim's key check had no planted case** (medium,
   invariant 4): the planted row with a `post_cell` never reached it.
2. **Hearing in the open is a diamond** on the 4-connected walk graph,
   slow ground is quieter, a door is only blocked, no height -- unsaid (low).
3. **An awareness row was never validated** (low): a caution floor at or
   above the last phase keeps a guard alert forever.
4. **Light and motion counted twice**, by the task's design, unsaid (low).
5. **A long falling step decays less** than many short ones (low).
6. **The walks never exercised stance**; the "too few points" and "outside
   every zone" checks each one trivial case (low).
7. **The footstep radius duplicated** in the test (low).
8. **The belief reseed was O(V·seen)**, not the O(V+E) claimed (low).
9. **Some kit-chosen numbers** were not labelled as the kit's (low).
10. A note for T70: "seen" must mean a target standing there would be
    perceived, by stance and light, or the belief loses a hidden player.

## What was done about them

All nine applied in `98de154`, rebased on main (`be346f5`):

1. Two pairs, each with its own planted case: the guard rows' keys, and a
   noise posted at a fixed cell on generated levels; the comment says the
   key check matches by name only.
2-5. Said in the headers of `path_hearing.gd`, `sound_paths.gd`,
   `guard_type.gd` and `awareness.gd`; T70 is pointed to an octile or a
   separate sound graph.
3. `Awareness.problem(row)` refuses a bad row, asserted for both guard
   types with two planted bad rows.
6. The walk draws a stance and puts low cover on some cells; a crouched
   body with one point showing and a body off to the side were added.
7. The radius is read from the data's events.
8. The reseed uses a set, in both languages.
9. Every kit-chosen number is listed; finding 10 is carried in the
   research page as a note for T70.

Re-run after the fixes: the three vector gates, `make test-python`, 115
gdUnit cases, `awareness_properties.gd` (11 pairs, every plant caught, no
SCRIPT ERROR), the dependency, module, readability, task, status and
freshness gates -- all green. The full `make check` ran green before the
review; the fixes stay inside `ai_perception`, `infiltration` and docs.
