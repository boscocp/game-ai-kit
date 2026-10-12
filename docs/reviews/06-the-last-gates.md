# Review: wave/06-the-last-gates

Reviewed 2026-10-12 by a context that did not write any of this code. The
session that wrote the wave ended before it could finish; this one picked the
branch up from `tasks/STATUS.md` and the git history, read the diff against
`main`, and did not take the planted cases on trust — they were written by the
same author as the gates, which is the symmetry the apparatus exists to break.

## What was reviewed

The four commits on this branch at `59c9f1d`: the four gates that close T1
(`check_addon_deps.py`, `check_tiers.py`, `check_links.py`,
`check_workflow.py`), the two rounds of fixes before them, and ADR 0005.

Method: `make check` and every `--self-test`; **26 mutations**, each deleting
exactly one rule from one gate and asking whether that gate's own self-test
noticed; a probe project run on the pinned engine to settle one question about
Godot rather than argue it; and a read of each gate against the claim in its own
docstring.

The branch was red when this session found it, and the reason was the subject of
the last commit's closing paragraph: the gate for invariant 10 was reporting the
repository's own history as dirty, correctly.

## Findings

**Nine confirmed.** Three of them are the gate for invariant 10 failing the
invariant it holds.

1. **The employer gate exempted its own file.** `SKIP_PATHS` listed
   `scripts/check_no_employer_refs.py`, justified as "scanning the gate's own
   file would be circular". It is not circular — the file holds a salt and some
   rules, never a term. What the exemption actually bought was the one place in
   the repository where a match could be quoted while being documented and no
   gate would object. Four such quotes were sitting in it.

2. **And the same quote had reached two commit messages**, which is what made
   `make check` red. Documenting a match by reproducing it is the own goal the
   invariant exists to prevent.

3. **That gate's line-break planted case was decorative.** Deleting the rule
   left the self-test green. The fixture split the term inside a longer word, so
   the word-start rule above rejected it first and the line-break rule was never
   the reason for the pass.

4. **`check_workflow.py`'s self-test asserted an exit code and nothing else**,
   and its rules overlap — a command that is not `make` is also a command whose
   words are not targets; a workflow with no steps is also a workflow that
   reaches no gate. W1, W2, W3 and W4 could each be **deleted outright** with
   the self-test still green. Four planted cases proving nothing about the rule
   they are filed under.

5. **Dead code reading as a check.** The same gate's W5 built a set called
   `expanded`, compared against it, and had already unioned exactly that set
   into `reachable` two lines earlier. Reaching the inner test made it true.

6. **`check_links.py` promised anchors in its docstring and never checked
   one.** A `#fragment` was cut off and discarded, so every anchor in the
   repository resolved by definition. Its planted case linked to `#a-heading`
   from a file whose only heading was in a *different* file — and passed, which
   is what a case looks like when it is measuring nothing.

7. **Two addons declaring the same `class_name` were invisible.**
   `check_addon_deps.py` kept owners in a dict, so the second addon silently
   overwrote the first. In Godot that collision is a load error, not a style
   question.

8. **A relative `preload` crosses addons, and the gate only knew `res://`.**
   Measured rather than argued, on the pinned 4.7.2: a script in `addons/ai_a/`
   with `const Other := preload("../ai_b/probe_b.gd")` parses, resolves and
   calls into the other addon. That is exactly the dependency invariant 2
   forbids, wearing a path the gate could not see.

9. **An addon's own class names were rebuilt from disk once per file**, so an
   addon of n files read its own n files n times. Nobody measured a problem; it
   just reads badly in a repository whose premise is that you can read it.

**Handed over as a suspicion, not a claim.** `check_tiers.py` only looks under
`docs/`. If a lesson ever lives in `README.md`, in `python/`, or beside the code
it teaches, invariant 5 stops being checked for it without anything going red.
Not reproduced as a defect, because today every page is under `docs/`.

**What held up.** All 26 mutations outside `check_workflow.py` were caught by
the gates' own self-tests. `check_tiers.py` survived every mutation tried
against it, including making every tier count as reachable. The CI workflow does
reach both halves of the link gate — `make lint-links-remote` is a real step,
not an intention. The note-printing gates (`A0`, `R5`, `T0`) do say they
inspected nothing rather than passing in silence, and `check_links.py` refuses
to pass on a tree with no markdown at all.

## What was done about them

All nine are fixed on this branch.

Findings 1, 2 and 3 were fixed by rebuilding the two unmerged commits that
carried them, with the owner's approval: the quoted match is gone from both the
messages and the file content, the exemption is gone so the gate now scans
itself, and the line-break case now begins its match at a word start, which
leaves the line break as the only thing between it and a finding. The backup
branch was deleted afterwards, since a ref holding the old blobs is the term
still in the repository.

Findings 4 to 9 are in `8b1b288`. Each one carries the reproduction that found
it as a planted case, and each was re-mutated afterwards: deleting the rule now
turns the gate's own self-test red. The Godot measurement behind finding 8 is in
`docs/godot/addon-anatomy.md` with the engine version it was taken on, not in a
commit message, because that is the layer with a six-month half-life.

What this record does **not** claim: the fixes were not themselves reviewed by a
fresh context. They were written by the same session that found the defects, and
that is the same gap wave 05's record named. The mutation sweep is the only
thing standing behind them, and a mutation sweep is written by the person it is
meant to catch.

One thing remains open and is the owner's, not a defect in the code: the two
commits were rebuilt, so the old objects are unreachable but still sitting in
`.git` until a `git gc --prune=now`. This session did not have permission to run
it.
