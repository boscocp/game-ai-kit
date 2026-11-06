# Review: wave/148-constraint-draws-from-gak-xorshift

T135 folds `ai_constraints`' own copy of Marsaglia's xorshift into the
kernel's. `ConstraintDraws` (GDScript and Python) now holds a
`GakXorshift` / `gameaikit.core.Xorshift` and keeps `next`, `index`,
`shuffle` and `SEED_FOR_ZERO`; `modules/ai_constraints.json` declares
`ai_core`; both technique pages say to copy two folders.

A fresh context reviewed PR #98 at head 7c5211d (base origin/main
b364e9f), in a throwaway worktree. It read the code, ran the gates and
planted faults one at a time, restoring each and clearing `__pycache__`
after the Python plant. It made no commit, push or PR comment.

**Verdict: approve with changes. No blocker, two should-fix findings
and two nits.** The fold is exact: the removed `_init`/`next` bodies are
character for character the kernel's in both languages, so seed 0,
negative and large seeds and the 32-bit mask behave as before, and the
kernel's own vectors already hold seeds 0, -1 and 2^32 + 1 across the two
languages. No vector was touched. What is left is the same fact -- "who
draws from the kernel" -- still told the old way in the kernel's own
files, and one header line that credits the addon with a draw the kernel
already has.

## What was reviewed

- `CLAUDE.md` (invariants 2, 11 and 12, "Readable by a person", the
  traps on `--import`, `SCRIPT ERROR` and `__pycache__`), the task file,
  the PR title and body with its five decisions and owner list, the
  single commit's message.
- The diff against `origin/main`: `constraint_draws.gd`, `draws.py`,
  `constraints/__init__.py`, `modules/ai_constraints.json`,
  `docs/techniques/ai_constraints{,.pt-BR}.md`, `tasks/STATUS.md`.
- For context: `godot/addons/ai_core/xorshift.gd`,
  `python/gameaikit/core/xorshift.py`, `modules/ai_core.json`,
  `docs/techniques/ai_core{,.pt-BR}.md`, `README.md`,
  `docs/techniques/glossary.pt-BR.md`, `spec/vectors/core/xorshift.json`
  (seeds covered), the callers of `ConstraintDraws` (`constraint_solver`,
  `wave_collapse`, both languages), `scripts/release.py`'s
  `addon_readme` (reads `depends_on`, so the release README will now say
  "It needs `ai_core`").

## What was run (green at 7c5211d unless stated)

- `./scripts/godot --headless --path godot --import`: exit 0.
- `make test-constraints-vectors`: 9 constraint and 7 collapse vectors,
  0 failures. `make test-core-vectors`: 7 seeds, 0 failures.
- `python3 -m unittest discover -s python/tests -t python -p "test_constraints*.py"`:
  38 tests, OK; `-p "test_core*.py"`: OK.
- `make test-godot-some SUITES="test/ai_constraints test/squad test/ai_core"`:
  169 cases, 0 failures. The two `SCRIPT ERROR`s in the log are
  `interfaces_test.gd`'s expected parse failures, not skipped checks.
- `make lint-addon-deps lint-modules lint-tasks lint-status lint-readability`,
  `check_glossary.py`, `check_translations_docs.py`: all exit 0.
- `check_pr_message.py` on the PR's title and body, `check_commit_msg.py`
  on the commit: exit 0. No `Co-Authored-By`, no tool named.
- `git diff origin/main -- spec/`: empty.

Planted, one at a time:

1. A skipped draw (one extra `next()` in `_init`), both languages:
   GDScript vectors 25 + 16 failures, Python 17 failures, gdUnit
   `test/ai_constraints` 19 failures and 1 error. Caught. Restored.
2. GDScript only, `index` spending a draw when `count <= 1`: vectors
   0 failures. Not caught, and not reachable: `shuffle` calls
   `index(place + 1)` with `place >= 1`, and `WaveCollapse._values`
   returns early on one tile left, so neither caller passes a count below
   two. The kernel's `index` has the same rule and its `picks` vectors do
   hold it; see finding 2. Restored.

## Findings

1. **should fix** -- the kernel still lists the generator's users
   without `ai_constraints`. `godot/addons/ai_core/xorshift.gd:12-13`
   ("Monte Carlo search, the particle filter, the bandit and the maze's
   ghosts all draw from it"), `modules/ai_core.json:4` ("four
   techniques"), `docs/techniques/ai_core.md:36-37` and `:41-44` ("today
   `ai_search`, `ai_perception`, `ai_rts_core`, and `ai_adversarial` and
   `ai_bandit` for the generator") and their twins at
   `docs/techniques/ai_core.pt-BR.md:38-39` and `:44-47`. This wave makes
   that list false, and the ai_core page's "When you need it" is exactly
   where a person decides which folders to copy; the ai_constraints page
   now says two folders and the ai_core page says otherwise. Deferring is
   not cheaper: the manifest change already runs all of `make check`, so
   touching `ai_core` selects nothing new. Fix: add `ai_constraints` (WFC
   and the solver's tie order) to the three lists, "four" to "five" in the
   manifest, and refresh `ai_core.pt-BR.md`'s `translation_of`. Owner
   list item 3 would then close here.

2. **should fix** -- `godot/addons/ai_constraints/constraint_draws.gd:9-11`
   and `python/gameaikit/constraints/draws.py:6-7` say "What this class
   adds is the addon's own: a choice among `count`, and a Fisher-Yates
   shuffle". `GakXorshift.index` (`ai_core/xorshift.gd`, `index`) and
   `Xorshift.index` already are that choice, with the same "no draw for
   one" rule, held by `spec/vectors/core/` `picks`. A reader told the
   addon adds it will go looking for a difference that is not there; and
   the addon's copy of the rule is the one no vector reaches (plant 2).
   Fix (preferred): `index` returns `_numbers.index(count)` /
   `self._numbers.index(count)`, and the header says only the shuffle is
   the addon's own. If decision 2 stands instead, the header should say
   `index` repeats the kernel's rule on purpose, and why.

3. **nit** -- `docs/techniques/ai_constraints.md:148` and
   `docs/techniques/ai_constraints.pt-BR.md:155`: after "Two folders",
   "Wave function collapse is two of its files" / "são dois arquivos
   dela" no longer has one antecedent (the addon or the kernel). Fix:
   "two of `ai_constraints`' files" / "dois arquivos do
   `ai_constraints`", and rewrap the line, which the edit left at 117 and
   113 columns.

4. **nit** -- same lines: "(T135; the addon used to carry a copy)" /
   "(T135; o *addon* carregava uma cópia dele)" is the repository's
   history in a reader's instruction; someone copying folders does not
   need it, and the class headers already keep it. Fix: drop the
   parenthesis in both languages (and refresh `translation_of`).

Checked and fine: equivalence (identical bodies, masking unchanged in
both languages); invariant 2 (`lint-addon-deps` green, only `ai_core`
named); `depends_on` feeds the release README; pt-BR uses "núcleo" for
kernel as `ai_core.pt-BR.md` and `ai_rts_core.pt-BR.md` already do, and
`*seed*` as the glossary defines; `translation_of` matches
(`check_translations_docs.py` green); composition over inheritance keeps
the old surface; `SEED_FOR_ZERO` re-exported so both callers compile
unchanged; doc comments say what and why, types are static, and no
"copy" claim remains about the current code.

## What was done about them

Applied on the same branch, on top of 7c5211d.

1. **Should-fix, fixed (the coordinator overrode the deferral).** `ai_constraints` now appears beside the other users in four places. These are `ai_core/xorshift.gd`'s header, `modules/ai_core.json` ("five techniques", T109 and T135), `ai_core.md`'s `GakXorshift` entry and its "When you need it" list, and the same two places in `ai_core.pt-BR.md`, whose `translation_of` is refreshed. Owner list item 3 is closed.
2. **Should-fix, fixed.** `index` now returns `_numbers.index(count)` (GDScript) and `self._numbers.index(count)` (Python). Both headers say that a number and a choice are the kernel's, passed through, and that only the shuffle is the addon's own. No vector moved: 9 + 7 vectors and 38 Python tests are green. Planted again: the kernel seeded one ahead fails 24 + 12 vectors and 17 Python tests. A draw spent on `index(count <= 1)`, planted in `ConstraintDraws.index` in both languages, is still not caught by the constraints vectors, the Python suite or `test/ai_constraints`. No caller passes a count below two, and the rule now lives only in the kernel, where `spec/vectors/core/` `picks` hold it. Both plants were restored and `__pycache__` cleared.
3. **Nit, fixed.** "two of `ai_constraints`' files" / "dois arquivos do `ai_constraints`", and both paragraphs are rewrapped under 80 columns.
4. **Nit, fixed.** The "(T135; ...)" parenthesis is dropped in both languages, and `translation_of` is refreshed.
