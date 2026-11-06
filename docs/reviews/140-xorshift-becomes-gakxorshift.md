# Review: wave/140, T120 -- Xorshift becomes GakXorshift

T120: the kernel's seeded generator takes the `Gak` prefix before anything is
published. The PR renames the GDScript `class_name`, keeps the file (and so
its `.uid`) and the Python twin `gameaikit.core.Xorshift`, updates the pages
in both languages, and records the 0.1.0 promise as an open question.

A fresh context reviewed PR #89 at head 1f4cd9a (merged with origin/main
97ab8b4). It read the task and its Notes, ADR 0024, the PR body and the diff,
and ran narrow checks and a planted change in a throwaway worktree. It made
no commit, push or PR comment.

**Verdict: approved, no blocker, no should-fix.** The rename is complete in
GDScript and in the docs, no draw moved, and the planted change to the
arithmetic went red. Three nits follow.

## What was reviewed

- The 31-file diff, the task's Notes, ADR 0024 (table, amendment) and the
  guide in both languages.
- `git grep -nw Xorshift` over `godot/`: no match. What remains outside is
  `XorshiftVector` (the test helper, a different class), the Python twin
  (`python/`, `docs/techniques/ai_core*.md:32/34`), ADR 0021, the reviews
  and `docs/godot/maze.md:198,212` (history, and the algorithm's name).
- The English and pt-BR pages say the same: `ai_core`, the guide's table row,
  the sentence on the promise, and the `translation_of` hashes.

## Checks

- Import: `./scripts/godot --headless --path godot --import` in the fresh
  worktree. The first run on a cold cache exited 139 (a Godot crash while
  reimporting, not tied to this diff); the second exited 0. `git status`
  clean afterwards, `xorshift.gd.uid` unchanged (`uid://b27to42n548w8`), no
  new `.uid`.
- `make test-core-vectors` (7 seeds, 0 failures), `make test-adversarial-vectors`
  (4 draw, 12 search, 7 expectiminimax, 0 failures), `make test-bandit-vectors`
  (7, 0 failures).
- `make test-godot-some SUITES="test/ai_core test/maze"`: 50 cases, 0 failures.
  The two `SCRIPT ERROR` lines are `interfaces_test.gd`'s planted
  abstract-class cases.
- `make test-python`: 604 tests, OK, so the Python twin still agrees with the
  shared vectors. `python3 scripts/check_glossary.py`: exit 0.

## Planted

| plant | caught by |
|---|---|
| `xorshift.gd`: first shift `<< 13` becomes `<< 14` | `test-core-vectors`: 21 failures; `test-adversarial-vectors`: red |

Restored with `git checkout`; the worktree was clean afterwards.

## Findings

1. **Nit.** `docs/techniques/using-the-library.md:~262` and
   `.pt-BR.md:~265`: "prefixed so it cannot collide with yours". A prefix makes
   a collision unlikely, not impossible, and the same page's collision
   paragraph says what to do when one happens. Fix: "so it is unlikely to
   collide with yours". Both lines are also much longer than the page's
   wrap; rewrap while there.
2. **Nit.** `spec/squad/positions.json` (the note, "with the same
   `GakXorshift`"): the note names the two runners, one of which is Python,
   whose class is `Xorshift`. Fix: "the same generator (`GakXorshift` in
   GDScript, `Xorshift` in Python)".
3. **Nit.** `docs/adr/0021-the-board-is-the-examples-kernel.md:123-129`:
   "Pending the owner" still says `Xorshift` keeps its name and "the owner
   decides". The owner did decide (2026-11-05, in ADR 0024's amendment). The
   PR keeps 0021 as history on purpose (its decision 3, which I agree
   with), but a one-line pointer "decided 2026-11-05, landed in T120; see ADR
   0024" stops a reader taking the item as open.

## Open question, checked (item 5)

ADR 0024's new paragraph records the ten-name promise as open: the lead
paragraph and the item above the table still say nine, the new text says the
record "promises nine, and `GakXorshift` is prefixed and not promised". The
guide says the same in both languages ("except `GakXorshift` ... not promised
yet"). The two do not contradict. One wrinkle, not a finding: the table now
has ten rows while the record promises nine, which the paragraph beneath it
explains.

## The owner's decisions

1. **Ten names in the 0.1.0 promise?** Agree with the recommendation, ten. A
   game that seeds the generator writes `GakXorshift` in its own code, and a
   prefix that is not promised is paid for and then free to be broken. The
   follow-up is small (drop "except", nine to ten, ADR line). Until then the
   PR's wording is the honest one.
2. **"Both languages" means English and pt-BR pages.** Agree: Python's
   modules are its namespace, ADR 0024 says "The Python names stay", and
   renaming the wheel's `Xorshift` is an API change for a separate task.
3. **History keeps the old name.** Agree, with finding 3's pointer so the
   stale "pending" item does not read as open.

## What was done

All three nits applied on the branch, in one commit:

1. The guide, in both languages: "unlikely to collide with yours" ("que
   seja improvável colidir com um seu"), rewrapped to the page's width;
   the pt-BR `translation_of` updated.
2. `spec/squad/positions.json`'s note: "the same generator (`GakXorshift`
   in GDScript, `Xorshift` in Python)". Only the note changed; the
   positions and their visits are as they were.
3. ADR 0021's pending item gains a line: decided on 2026-11-05,
   `GakXorshift`, landed in T120 (wave 140), see ADR 0024's amendment.
