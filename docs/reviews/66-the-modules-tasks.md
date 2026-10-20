# Review: wave/66-the-modules-tasks

One fresh context reviewed it after it was pushed (`d99d099`), then
re-read `tasks/STATUS.md` at `66ff2fc`. It could not edit anything, and it
checked every claim against the code with grep, wc, `affected.py` and the
gates.

**Verdict: fix before merge.** Two acceptance commands were green with no
work done, the very thing invariant 4 asks about. T60 left out who owns the
Python package it splits. T63's table would have kept the dependency it
promised to remove. And the STATUS section had been spliced into a sentence.

## What was reviewed

- `CLAUDE.md`, T58's plan, the five new task files and the STATUS diff.
- Run: `check_acceptance.py`, `lint-status`, `check_no_employer_refs.py`,
  and `affected.py --paths` for `python/gameaikit/dataset/rows.py` and
  `godot/addons/ai_core/board_state.gd`. Also every acceptance grep, run
  against the current tree.

## Findings

Each finding is followed by what was done about it.

1. **Two `affected.py` checks could not fail** (T60, T61).
   `affected.py --paths` prints `selected: a, b, c` on one line, so
   `grep -qx checkers` never matches, and the `!` check passed even though
   checkers is selected today. *Fixed*: both now use
   `grep -qE '^selected:.*\b<module>\b'`. Before T60, its check now fails
   as it should (measured).
2. **T61 named `ai_steering` as a module the board selects; it is not**
   (`depends_on: []`). *Fixed*: the Goal now gives the measured 19 modules,
   and the check names four that really are selected and do not use the
   board (`ai_rts_core`, `rts`, `ai_search`, `demo_racing`).
3. **T60 split `gameaikit.training` but left it owned by `tactical`**, with
   `checkers` depending on `tactical`, so the selection would not have
   changed. *Fixed*: the generic half moves to `modules/ai_learning.json`,
   and a new acceptance check makes sure `checkers` no longer depends on
   `tactical`.
4. **T60 left out files the move affects**: three adapter suites, the
   output path of `gameaikit.cloning`, the Makefile and docs, and the
   callers of the two `DEFAULT_PATH`s. It also claimed "callers do not
   change". *Fixed*: all of them are listed, and the Files line follows.
5. **T60's line counts were whole files but labelled code-only.** *Fixed*:
   the table now gives both counts.
6. **T63's table in `game/tactical/` would still name the four T15 teams in
   `game/league/`.** *Fixed*: a new first step moves those controllers to
   the board they play. The league keeps the tournament. Size raised to M.
7. **T62's port was wrong**: the algorithms also call `contains`, and A\*'s
   Manhattan estimate overestimates on waypoints with arbitrary costs.
   *Fixed*: `contains` is in the port. The graph now owns an admissible
   `estimate`, and the waypoint test holds A\*'s cost equal to Dijkstra's.
8. **Two acceptance sections were not commands** (T62's
   `test-godot-some` had no `SUITES=`; T64's wheel check was "written here
   when it exists"). *Fixed*: `make test-godot-some SUITES=test/ai_search`,
   and `make library-check` with a planted case, which T64 step 5 creates.
9. **STATUS.md's section was spliced inside the header's sentence.** The
   insert matched the text `## Resuming after` in line 3. *Fixed* in
   `66ff2fc`, confirmed by the re-read. `lint-status` passed with the file
   broken, so the gate checks less than it seems to; recorded here, not
   fixed in this wave.
10. **STATUS rows still said "recommended" for two decided choices.**
    *Fixed* in `66ff2fc`.
11. **T62 assumed T61 was done but listed only T58 as its prerequisite.**
    *Fixed*: T62's prerequisite is now T61, and STATUS says so.
12. **Parts of T58's plan were changed or dropped without saying so.**
    *Fixed*: T61 now says it overrides T58 on `Move` and `DecisionPolicy`,
    and why. It also notes that `ai_planning` over its own `WorldState` is
    already true in code. T64 gains a step for the Python idioms, limited
    to the package's public surface.
13. **T61's table named the wrong users of `Move` and `DecisionPolicy`.**
    *Fixed*: `main.gd:141` and the tactical game use `Move`; the league
    names `DecisionPolicy` only in comments; `game/stealth` uses `Unit`.

## What checked out

The classes each `ai_learning` file uses in code. Both `DEFAULT_PATH`s.
The Python imports. `DecisionPolicy.choose`'s signature. The chain at
`tactical.gd:395`. `Search extends Pathfinder`. Every make target and
script flag named. No byline, and the employer terms are clean.
