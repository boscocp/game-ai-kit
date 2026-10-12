# Review: wave/05-the-wave-flow

Reviewed 2026-10-12 by a context that did not write any of this code, with
instructions not to trust the planted cases in the self-tests — they were
written by the same author as the gates, which is the symmetry the apparatus
exists to break.

## What was reviewed

The repository as of `232fda4`: ten gate scripts under `scripts/`, the Makefile,
the task files, the CI workflow and three documentation files. Almost none of
the product exists yet, so what was under review was the verification apparatus
itself.

The reviewer ran `make check`, ran every `--self-test`, applied **19 mutations**
each deleting one rule from a gate, and built its own violations in a scratch
tree. It also asked the pinned engine what it had actually loaded, rather than
trusting a configuration file to mean what it says.

The repository was not static during the review: it gained
`check_branch_base.py`, the pre-commit hook, the CI workflow and
`CONTRIBUTING.md` while the review was running. The reviewer said so, and named
the commit it reviewed.

## Findings

**All 19 mutations were caught by the gate's own self-test.** No self-test is a
no-op and no planted case is decorative. Every defect below is about what a gate
never looked at, which no mutation of its rules could reveal.

Eighteen confirmed, in four classes:

1. **The gate looked at the wrong unit.** `check_acceptance.py` judged a whole
   line where it should judge a command, so a second Godot invocation on the
   same line was covered by the first one's `--headless`. `check_readability.py`
   counted tabs, so a space-indented file produced an empty function body and
   six levels of nesting passed a three-level limit. `check_renderer.py` took
   the first regex match, so commenting the compliant line out and adding
   another below it stayed green while the engine loaded Forward+.

2. **The gate could not fail.** An empty code fence satisfied the acceptance
   gate, because `findall` returns `[""]`, which is truthy — the gate failed its
   own stated question, *does this pass on an empty scene?* A `` ```text ``
   fence disabled both halves at once. `|| true`, `; true` and `set +e` — what a
   person writes when a criterion is inconvenient — were not covered.

3. **The gate had no caller.** `check_commit_msg.py` was in no Makefile target
   at all, while its own docstring claimed CI ran it over the history. The
   stdin mode and the published-exceptions table served a caller that did not
   exist. The CI workflow hand-listed gate targets beside `make check`, which is
   two lists that drift.

4. **The documentation claimed more than was true.** `CLAUDE.md` said "Every one
   of these has a gate". Four invariants had none.

One defect was worse than a wrong result: `lint-selftests` chose an interpreter
with `python3 "$script" || bash "$script"`. When a Python self-test failed, bash
read the same file and executed the backticks in its module docstring. One gate
documents `` `adb logcat` ``, which on a machine with adb installed streams
forever — so a failing self-test **hung** rather than reporting. On CI that is a
job burning to its six-hour limit instead of showing a red X.

Three suspected findings were handed over as suspicions, not claims. Three
places were named as hard to read, one of which was where the hanging defect
lived.

## What was done about them

All eighteen confirmed findings are fixed on this branch, in four commits
(`718f067`, `3e006cc`, `aec328c`, `ae2858a`). Each fix carries the reviewer's
own reproduction as a planted case, so the gate that missed it now rejects it.

Two findings were answered by changing the structure rather than the rule:
`lint-selftests` became `scripts/run_selftests.py`, with a self-test whose
planted cases include the hanging shape; and the four unenforced invariants are
now a table in `CLAUDE.md` saying which have a gate and which do not. They are
marked rather than dropped — a rule you know is unenforced is worth keeping, and
one you believe is enforced is worse than none.

The three suspected findings were measured:

- a latin-1 file skipped like a binary: **confirmed and fixed**;
- the history scan's cost: **0.26s over 140 blobs**, recorded as a number rather
  than left as a worry;
- that the index's row pattern matches prose: **not reproduced**. The pattern is
  anchored to a line starting with `|`. Left alone, and said so rather than
  changed to look responsive.

Fixing the fence-tag finding introduced a new defect — a loop variable named
`text` shadowed the variable holding the file, so a later check searched a code
fence instead. The self-test caught it on the first run. That is the argument
for the self-tests existing, and it is also why this record does not claim the
fixes were reviewed as carefully as the code they fix: they were not reviewed by
a fresh context at all. The next wave should start by reviewing this one.
