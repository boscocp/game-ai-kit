# Review: wave/63-modules-and-selective-gates

One fresh context reviewed it at `62c09a4`, with no permission to edit,
commit or run the engine targets while `make check` was running beside it.
Its probes lived under the job's scratch directory, outside the tree.

**Verdict: do not merge yet** -- one confirmed under-selection with three
causes (a change to `spec/pddl/` skipped both gates that read it), and a
second (a move between modules selected only the new owner). Both are the
defect this wave exists to avoid: a check that goes green having skipped
what it should have run.

## What was reviewed

- `CLAUDE.md`, T58 and its notes, and the whole diff `origin/main...HEAD`:
  `modules/*.json`, `scripts/check_modules.py`, `scripts/affected.py`, the
  test move, the Makefile targets, `check_no_training.py --retrain`,
  `check_workflow.py`'s continuation fix, `check_disk_layout.py`'s D5 on a
  runner, the CI workflow and `make wave-merge`.
- Run: both new gates' self-tests and real runs, `affected.py` over planted
  paths, a scratch git repository for renames, a script that every suite
  and every Python test can be selected, a search for stale test paths and
  orphan `.uid` files (none).

## Findings, and what was done about them

1. **Confirmed: `spec/pddl/*` selected neither planning-vector gate.**
   Three holes in the measuring: a folder owned file by file was dropped;
   Makefile recipes were never read (`test-planning-vectors` hands the
   engine `$(CURDIR)/spec/pddl`); pathlib joins and relative imports in
   Python were invisible. *Fixed*: a folder reaches every module owning a
   file in it, each gate's recipe is measured for its module, and both
   Python spellings are read -- each with a planted case. Closing the holes
   found a real code dependency the old measure hid: `gameaikit.training`
   imports the tactical dataset, so it went back to the tactical module,
   and checkers declares the tactical trainer it borrows (T58, D4).
2. **Confirmed: a rename selected only the new owner.** *Fixed* with
   `--no-renames`, and a planted move in a real git repository that fails
   without it (checked by mutation).
3. **Confirmed, low: an escaped quote cut the line.** *Fixed*, planted.
4. **Plausible: a PR title of 73-80 characters passes, and the squash's
   " (#NN)" then breaks `lint-commits` on main for good.** *Fixed*:
   `check_pr_message.py` leaves eight characters, planted both ways.
5. **Plausible: `gh pr merge` merges whatever head GitHub has.** *Fixed*:
   `--match-head-commit` with the commit that was checked.
6. **Plausible, low: CI on main.** `HEAD^1` covered one commit of a push of
   several, a failing selector step skipped the full check, and a newer
   push could cancel main's only full check. *Fixed*: the base is
   `github.event.before` (through `env:`), the full check runs on
   `!cancelled()`, and main's runs are never cancelled.
7. **Low: missing planted cases** -- M0's unknown kind, M7's gate owned
   twice, the selector's "everything is `make check`", and tests one
   folder deeper than the selector looks. *Fixed*: all planted, and a new
   rule, M8, refuses a test the selector cannot reach.
8. **Readability, minor**: both self-tests over 40 lines, and missing
   docstrings. *Fixed*: split into named groups, docstrings added, D5's
   runner switch explained.

## Found after the review, while measuring step 7

The walk followed test-only reach on to the users of a module whose code
had not changed: an RTS change ran the tactical game's whole suite, 287 s.
Manifests now carry `tests_depend_on` beside `depends_on`, both measured
and held by M3/M4; the selector stops at the first. The same change: 64 s.

## Before the merge

The fixes were reviewed again by a second fresh context (below), and the
merge waits for CI on the pull request.
