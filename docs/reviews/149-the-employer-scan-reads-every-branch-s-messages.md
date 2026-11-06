# Review: wave/149-the-employer-scan-reads-every-branch-s-messages

T145 makes `check_no_employer_refs.py` read commit messages and author
and committer identities with `git log --all`, the way it already read
blobs (`rev-list --all --objects`). The log is split per commit on a NUL
before each `%H`, each commit is scanned on its own, and an E2 finding
now names its commit (12 hex digits) beside the term. The scan moved
into a new `scan_messages`. A planted case puts the term only in a
message on a branch `HEAD` does not reach, expects exit 3 and expects
the finding to name that commit.

A fresh context reviewed PR #97 at head f1a59ad (base origin/main
b364e9f), in a throwaway worktree. No forbidden term was read, printed
or recovered: every probe used the self-test's made-up term, and probe
output was filtered so not even that was echoed. The reviewer made no
commit, push or PR comment.

**Verdict: changes requested. No blocker. One should-fix in scope, one
should-fix that predates this change (a follow-up task is fine), and
five nits.** The change does what the task asks, and the planted case
does its job: putting the HEAD-only log back makes the self-test fail
for the right reason. The gap that matters is decoding. A message git
cannot re-encode crashes the gate with a traceback and exit 1, and
`--all` now reads twice as many commits that could hold one.

## What was reviewed

- `CLAUDE.md` (invariants 4, 10 and 11, the trap about the untracked
  term list), the task file, the PR title and body with its 5 decisions,
  and the review record of wave 142 for shape.
- The diff against `origin/main`: `scripts/check_no_employer_refs.py`
  (all of it, including the parts the diff does not touch) and the
  `tasks/STATUS.md` row.

## What was run (green at f1a59ad unless stated)

- `python3 scripts/check_no_employer_refs.py --self-test`: ok, exit 0.
- `python3 scripts/check_no_employer_refs.py` on this checkout, with the
  list present (no E0 note): exit 0. 786 commits under `--all` against
  367 along `HEAD` (the remote has gained refs since the PR's 776).
- `make lint-tasks lint-status`, `check_readability.py`: exit 0.
- `check_commit_msg.py` on f1a59ad's message and `check_pr_message.py`
  on the PR's title and body: exit 0. No tooling byline anywhere, and
  the author is the owner (invariant 11).
- **Reverting the change, one piece at a time** (restored after each,
  `__pycache__` cleared at the end):
  - `git log --all` put back to `git log`: the self-test fails with
    `term in a message on an unmerged branch: expected exit 3, got 0`
    and `a message finding does not name its commit`, exit 1. The
    planted case holds the change.
  - The commit name taken out of the E2 text: `a message finding does
    not name its commit`, exit 1. Decision 2 is held too.
- **Probes**, each a scratch repository with the made-up term and its
  hash:
  - the term only in an annotated tag's message, and only in its
    tagger: exit 3, through E3 (`rev-list --objects` lists the tag
    object under its name). Not a message finding, but not missed.
  - only in a stash message: exit 3, E2.
  - only on a commit kept alive by a `refs/remotes/origin/...` ref
    whose local branch was reset away: exit 3, E2.
  - only in a git note: exit 3, E3.
  - only in a merge commit's message: exit 3, E2.
  - only in a latin-1 message with an `encoding` header: exit 3, E2
    (git re-encodes to UTF-8 on output).
  - in a message whose bytes git cannot re-encode (`encoding bogus`, a
    0xE9 byte): **traceback, exit 1**. Finding 1. The old gate does the
    same; the traceback names a byte offset, never the text.
  - an even-length latin-1 *file* holding the term, with `--no-history`:
    **exit 0**. Finding 2.
- **Timing** on this checkout: the whole gate takes 47 s, as the old one
  does (47 s). `scan_messages` alone takes 0.19 s for 786 commits: the
  blob loop is the cost, and this change adds nothing measurable to it.

## Findings

1. **should fix** -- `scripts/check_no_employer_refs.py:260-264`. The
   log is read with `text=True`, so Python decodes it strictly as UTF-8.
   A commit whose message git cannot re-encode (no or a wrong `encoding`
   header, a latin-1 byte) raises `UnicodeDecodeError`, which `main`
   does not catch (`:590` catches only `OSError` and
   `CalledProcessError`). The result is a traceback and exit 1. Exit 1
   is documented as "a forbidden term in the working tree", and the
   blob scan after it never runs. This is older than the PR, but the
   PR's point is that no message goes unread, and `--all` now reads 786
   commits where it used to read 367. Fix: drop `text=True`, split the
   bytes on `b"\x00"`, and decode each record leniently: UTF-8 first,
   then latin-1, which cannot fail. Do not use `decode_leniently` as it
   stands (see finding 2). Add a planted case: a commit made with
   `git -c i18n.commitEncoding=bogus commit -F` on a message holding the
   term and a 0xE9 byte, which must exit 3.
2. **should fix (predates this PR; a follow-up task is acceptable)** --
   `scripts/check_no_employer_refs.py:221`. `decode_leniently` tries
   `utf-16` before `latin-1`. Without a BOM, Python's `utf-16` decodes
   almost any even-length byte string into CJK-looking garbage, so
   `latin-1` is reached only for odd lengths. Measured: a 20-byte
   latin-1 file holding the term passes with exit 0. The self-test's
   latin-1 case (`:460`) passes only because its file is 19 bytes, an
   odd length. The same gap covers every non-UTF-8 blob in history (E3).
   Fix: try `utf-16` only when the bytes start with a UTF-16 BOM, and
   add an even-length latin-1 planted case beside `:459`. The PR could
   carry it, since it is the same file, or a T-number could be opened
   from this record.
3. **nit** -- `scripts/check_no_employer_refs.py:244` (and `:229`,
   `:276`). The new function copied the annotation `hashes: set[str]`,
   but the value is `set[tuple[int, str]]` (`load_hashes`, `:92`). The
   reader loses the signature, and the signature is the point of the
   static-types rule. Fix: annotate `set[tuple[int, str]]` in the new
   function, and in the two it was copied from while there.
4. **nit** -- `scripts/check_no_employer_refs.py:266`. The format starts
   with a NUL, so the first split record is the empty string and gets
   scanned as a commit with no id. It is harmless today. If anything is
   ever written before the first NUL, it would be reported as
   `commit :`. Fix: `if not record: continue`, or use
   `log.stdout.split("\x00")[1:]` with a one-line comment saying why.
5. **nit** -- `scripts/check_no_employer_refs.py:420-423`.
   `rev-parse --short=12` can return more than 12 digits when the prefix
   is ambiguous, while the finding always prints `commit[:12]`. Fix:
   `rev-parse side` and slice `[:12]` in the test, so the two match by
   construction rather than by the repository being tiny.
6. **nit** -- `scripts/check_no_employer_refs.py:253-255`. "a finished
   branch `main` never merged -- and which is published with the
   rest --" reads as though a branch were called `main`. Fix: "so a
   finished branch that `main` never merged, which is published with
   the rest, had its messages skipped (T145)."
7. **nit** -- PR body, "For the owner" item 2. `--all` reads the local
   refs, not the remote's. A stale remote-tracking ref is a false alarm,
   which item 2 already covers with `git fetch --prune`. The other
   direction is the risky one: a branch on the remote that was never
   fetched here is published and never scanned. Fix: make the advice
   `git fetch --all --prune` before the last scan before opening, and
   say why in one line. `self_test` is also far over the 40-line rule
   and grows by 20 lines here. That predates the PR, and splitting it
   is not this wave's job, but a helper such as
   `planted_on_unmerged_branch(root, secret, failures)` would keep the
   new case from adding to it.

Not findings, checked and fine:

- **Coverage.** `--all` covers branches, remote-tracking refs, tags
  (whose commits get walked) and `refs/stash`. Reflogs are not
  published and not read, as before.
- **Fields.** Author and committer name and email are both in the
  format. Merges are included, since there is no `--no-merges`.
- **Splitting per commit loses no match.** `offending_tokens` already
  refuses any match that crosses a line break (`:178`), so no match ever
  crossed two commits.
- **Output.** E0 still returns before any scan, so a machine without
  the list prints no term. Finding text is unchanged apart from the
  commit id. A term repeated in N commits now prints N lines where it
  printed one. That is intended (decision 2), and it does not leak
  anything new.
- **Exit codes and usage.** The docstring's exit codes (`:39-45`) and
  usage (`:47-51`) still match the code. 1/2/3 keep their meanings,
  apart from the crash in finding 1.

## What was done about them

1. **Should fix, fixed.** The log is read as bytes, split on NUL, and each record goes through a new `decode_message` (UTF-8, then latin-1). Planted: `i18n.commitEncoding=bogus` over a 0xE9 byte. It raised the traceback before the fix and exits 3 after it.
2. **Should fix, fixed here.** `decode_leniently` tries UTF-16 only behind a byte order mark, then UTF-8, then latin-1. Planted: an even-length latin-1 file, which passed with exit 0 before the fix and exits 1 after it. Side effect: a UTF-16 file with a BOM used to be skipped as binary (it holds NULs), and it is now scanned.
3. **Nit, fixed.** `scan_tree`, `scan_messages` and `scan_history` take `set[tuple[int, str]]`.
4. **Nit, fixed.** The empty piece before the first NUL is dropped (`[1:]`), with a comment saying why.
5. **Nit, fixed.** The test takes the full `rev-parse side` and slices `[:12]`, as the finding does.
6. **Nit, fixed.** The docstring now reads "a finished branch that `main` never merged, which is published with the rest".
7. **Nit, fixed.** The PR body advises `git fetch --all --prune` before the last scan, and says why. `self_test` is split into a `Planted` helper and five named groups (tree, history, unmerged branch, encodings, spellings). Each function is under 40 lines, and every earlier case is kept with its comment.
