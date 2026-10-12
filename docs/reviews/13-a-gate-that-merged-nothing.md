# Review: fix/13-a-gate-that-merged-nothing

Not reviewed by a fresh context. The finding was not found by reading anything
-- it was found by falling into it, in this session, five minutes before the
fix was written.

## What was reviewed

`check_branch_base.py --check-review` and the `wave-merge` target, against what
actually happened when a commit was refused.

## Findings

**`make wave-merge` merged a branch with no commits on it and printed
"merged".** The sequence, exactly as it happened: a commit was refused by
`.githooks/commit-msg` because the subject used a type that is not in the list;
nothing was committed; the review record was sitting in the working tree, where
`record.exists()` found it and approved it; `make check` passed, because it
also reads the working tree; and the merge then fast-forwarded a branch that
was identical to main. Every gate was green and no work had been merged,
because there was none.

Two separate holes, each of which would have been enough on its own: the gate
never asked whether the branch was **ahead of main**, and it accepted a review
record that existed **on disk** rather than in the branch being merged.

**A third hole found while fixing the first two.** The first planted case for
the empty-branch rule was masked: a branch with no commits also has no
committed record, so deleting the empty-branch rule left the self-test green
because the record rule fired instead. The same masking pattern this project
found in `check_workflow.py` two waves ago, reproduced by the fix for
something else.

## What was done about them

Three rules -- R6, R7, R8 -- and three planted cases, each built so that only
the rule it belongs to can fail it. The empty-branch case needed a record
committed on main and inherited by the branch, which is the one shape where the
record rule cannot fire. The unknown-branch case needed a record on disk and no
branch at all. Deleting any of the three now turns the self-test red; before
the extra cases, deleting two of them did not.

The docstring says how the hole was found, because "a refused commit looks
exactly like this" is the sentence that would have saved the time.
