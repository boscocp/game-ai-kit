# Review: wave/77-a-new-gate-selects-its-module

A fresh context reviewed T71 at `14d7fb0`: `scripts/added_gates.py`, which
reads the hunks of a `Makefile` and a manifest change, and `affected.py`'s
rule 5, under which a change that only adds a gate selects that gate's
module and its dependents instead of everything. It was not allowed to
edit the worktree. It ran the self-test, the Python tests (325 OK),
`check_readability` and `check_modules`, all green, and probed the reader
with crafted diffs in a scratch copy, confirming each with `make -n`.

**Verdict: fix before merge.** The rule's whole promise is to fail towards
running more, and three changes that alter another target were read as
"only adds a gate".

## What was reviewed

- `CLAUDE.md`, T71's task, `scripts/affected.py`, `scripts/added_gates.py`
  and where they meet `scripts/check_modules.py`; `git diff origin/main...HEAD`.
- How make itself reads a line the reader calls new: continuations,
  comment lines inside a recipe, `define` and conditionals, rules for old
  targets, double-colon rules, variables, prerequisites.
- Whether each planted case fails for the reason it names, by deleting
  guards one at a time.

## Findings

1. **A trailing backslash swallowed the next rule** (high): a new recipe
   whose last line ends in `\` joins the old rule below it, so another
   module's gate disappears while only the new gate's module is selected.
   The Makefile has 42 recipe lines ending in `\`. The same with a
   backslash on the old line before the hunk.
2. **Comment lines inside a recipe** (medium): the search for a following
   recipe line skipped only blank lines; make also skips comments, so a
   gate inserted above one stole the rest of an old recipe. Also: a hunk
   inside `define ... endef` was accepted. Latent: neither exists today.
3. **The `check:` reader compared words, not lines** (medium): one hunk
   joining the next line (`FLAGS = --strict`) into `check:` was accepted,
   and a global variable silently emptied.
4. **"New" meant "no rule head"** (low): a name the old Makefile already
   used as a prerequisite, or the second target of a two-target rule,
   counted as new.
5. **"An owns changed" passed for the wrong reason** (low): it had no
   Makefile change, so it selected everything whatever the guard did.

## What was done about them

All five fixed on the branch (`8d45823`, `232f9b5`):

1. A new gate whose last recipe line, or the line before the hunk, ends in
   `\` is global.
2. Comment lines are skipped as make skips them; a Makefile with a
   conditional, a `define` or an `include` anywhere is global whatever
   changed -- this one has none, so nothing is lost.
3. Removed and added lines must both lie inside the old `check:` line,
   read from the hunk header's old start, and new names come before its
   `##` comment.
4. A name is known if it is any whole word of the old Makefile.
5. The owns case now carries the wave-75 Makefile change and the gate in
   `play`'s manifest.

Seven planted cases were added, one per hole; rule 5 has 21 cases, 1
honest and 20 planted. Each of the 16 guards was deleted once in a scratch
copy and its case went red. Re-run after the fixes, rebased on main with
wave 75: the self-test, `make check-no-engine` (every lint and the Python
tests), exit 0. On wave 75's merged commit the selection is `menu,
racing3d` instead of everything, `test-racing3d-you-drive` among the
gates.
