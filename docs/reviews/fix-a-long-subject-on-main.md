# Review: a long subject on main, recorded as a published exception

PR #38. Reviewed by a context that did not write it, on 2026-10-26.

## What it fixes

PR #36 was squash-merged by hand while CI is disabled. `check_pr_message.py`,
run locally just before, refused its 78-character title, and the merge ran
after it anyway: the two commands were joined by `;`, not `&&`. Main's
subject is 84 characters, and `make lint-commits` failed on main. A subject
on main is not rewritten; it is named in `PUBLISHED_EXCEPTIONS` with why.

## Findings, and what was done

1. **The reason said the merge "did not wait for the check"**, which reads
   as CI's check -- and no CI check ran on #36, CI being off. Reworded: the
   check was run locally and refused, and the merge ran regardless.
2. The self-test's comment "the table is empty in a young repository" is
   general and still true; left.
3. `lint-commits` reads the last 30 subjects, so the entry stops mattering
   in about 30 commits; the self-test checks every entry, so it stays held.

## What stops it recurring: nothing in code yet

While CI is off, merges go through a bare `gh pr merge`, and no message gate
runs on that path. The reviewer's smallest fix, not done here: a local-check
mode for `make wave-merge` (or a `make pr-merge-local`) that checks the exact
squash subject with `check_commit_msg.py` and the title and body with
`check_pr_message.py` before merging. Until then the merge is chained with
`&&` after the check.

## Found sound

The string equals main's subject exactly (84 characters, the concatenation
keeps its one space); `make lint-commits` passes with the entry and fails
without it; `--self-test` passes; only `scripts/check_commit_msg.py` changed;
no tooling byline in the commit, title or body.
