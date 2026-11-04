# Review: wave/123-a-new-gate-selects-its-module

T111: a new gate selects its module, and merges clean. Rule 5
(`added_gates.py`) now reads `test-vectors:` the way it reads `check:`.
It also accepts a family that attaches itself with `test-vectors:
test-x-vectors`, new non-gate targets beside a gate, and a Makefile with
a conditional above every hunk, and it reads a vector folder named
without its slash. A new rule 6 (`added_module.py`) reads a new manifest,
a user's `depends_on`, `KIT_MODULES` and pyproject's `packages`.
`check_workflow.py` now reads every rule for a target. `release.py`
refuses an unsorted `packages`. The PR also adds
`docs/howto/parallel-batch.md` and edits CLAUDE.md's trap.

A fresh context reviewed PR #66 at head 057d586 in a throwaway worktree.
It wrote nothing to the branch.

**Verdict: changes requested, one blocker.** Rule 6 lets a new manifest
claim any path that no file occupied at the fork. A path nobody owns, a
CI file, a file inside another module's vector or test folder, or a
package that shadows the registry then selects only the new module.
That breaks "any doubt is global", which the task says must survive.
There are also three should-fix findings, four nits and four items for
the owner.

## What was reviewed

The diff against main: `scripts/added_gates.py`, `scripts/added_module.py`,
`scripts/affected.py` (rules, fixtures, planted cases), `scripts/check_workflow.py`,
`scripts/release.py`, the Makefile hunks, `docs/howto/parallel-batch.md`,
CLAUDE.md, the task file and the STATUS row. The reviewer attacked the
selector on the real tree by editing the working tree and running
`affected.py --base origin/wave/123-a-new-gate-selects-its-module --explain`,
which reads the uncommitted state.

What holds, measured:

- `affected.py --self-test`, `check_workflow.py --self-test`,
  `release.py --self-test`, and `make lint-modules lint-selftests
  lint-workflow lint-readability lint-status lint-links
  lint-docs-freshness` all pass.
- `make -pRrq` gives `test-vectors` the same 24 prerequisites on main and on
  the head (only their order differs). `check_workflow.target_prerequisites`
  finds 24.
- Wave 120 replayed (`7d9faaa^..7d9faaa`, the PR's three scripts copied in)
  selects `ai_constraints, infiltration, menu`, as the STATUS row says.
- All of these stay global on the real Makefile:
  - an edit inside the Windows `ifeq` plus a new gate;
  - a new `measure-` target alone;
  - `VAR :=` and `override` lines, which `new_targets` refuses as non-rule lines;
  - an old target attached to `test-vectors`;
  - a reordered list, a removed name, or a name moved between lists
    (planted);
  - a manifest named for one module that declares another (`load_modules`
    refuses it);
  - a duplicate name in `KIT_MODULES` or `packages`.
- `make export:`-style rule names (`override:`, `vpath:`, `include:` and
  others) are parsed by GNU make as plain targets, so `RULE` matching them
  does no harm.
- The CLAUDE.md edit is limited to the `check-affected` trap.

## Findings

1. **Blocker: a new manifest launders paths that were global or someone
   else's.** `scripts/added_module.py:67` refuses a new manifest only when
   its `owns` covers a file the fork tracked. It never asks who else claims
   the prefix: another module, the GLOBAL list, or nobody. Under longest
   prefix wins, the new module then owns those new paths. Each case below
   was reproduced with an uncommitted change and `affected.py --base ...
   --explain`, and `check_modules.py` stayed `ok` every time:
   - `modules/zz_sneak.json` owning `spec/vectors/search/zz-wrong-answer.json`,
     plus that file. Selected: `zz_sneak`. `test-search-vectors` and
     Python's search vectors read every file in that folder, and neither
     runs. The next wave that touches `ai_search` goes red on a file it
     did not write.
   - The same manifest owning `.github/workflows/zz.yml` and
     `godot/test/ai_search/zz_breaks_test.gd` (a failing suite). Selected:
     `zz_sneak`. CI changed, and nothing was global. This contradicts
     `affected.py:33-35` ("The scripts, CI, ... are never read this way")
     and `docs/howto/parallel-batch.md:97-99`.
   - `modules/zz_shadow.json` owning `python/gameaikit/techniques/`, with an
     `__init__.py` that raises. This shadows `techniques.py`, which is global,
     so `import gameaikit.techniques` fails. Selected: `zz_shadow`. No
     Python test runs, because the module owns none and `test_techniques`
     is added only to a Python selection.
   - `modules/zz_cfg.json` owning `godot/override.cfg`. Godot applies that
     file over `project.godot` in every scene. Selected: `zz_cfg`. Without
     the manifest, rule 1 selects everything.

   No planted case covers any of these. Fix: refuse a new manifest when any
   prefix it owns:
   - is claimed by an old module (`claims(prefix)` non-empty);
   - is inside, or contains, an old module's prefix;
   - is global (`global_claim`), or lies inside a GLOBAL prefix;
   - is a Python package whose name is a module file at the fork
     (`python/gameaikit/<name>.py`).

   Simpler still: allow only the shapes a technique takes (`godot/addons/<n>/`,
   `godot/test/<n>/`, `spec/vectors/<n>/`, `python/gameaikit/<n>/`,
   `python/tests/test_*.py`), each one a folder or file absent at the fork.
   Plant each of the four cases above.

2. **Should-fix: a new gate may depend on any old target, side effects
   included.** `added_gates.py:171` requires a new rule's prerequisites to be
   words of the old Makefile, and nothing more. Appending
   `test-vectors: test-fuzzy-zz` and
   `test-fuzzy-zz: wave-merge solve-maze ## planted` (recipe
   `res://test/ai_fuzzy/zz.gd` plus `$(CURDIR)/spec/vectors/fuzzy`), and
   appending the gate to `modules/ai_fuzzy.json`, selects `ai_fuzzy` and its
   users. `make -n test-fuzzy-zz` then shows `gh pr merge`, and
   `solve-maze` rewrites `godot/game/maze`, the maze's files, which are not
   selected. Main had no check on prerequisites at all, so this is not a
   regression. The new docstring (`added_gates.py:150-153`) still reads as if
   the hole were closed. Every existing gate depends on `import`, a
   `test-...` target, or nothing (`grep -E '^test-' Makefile`), so allow
   only those. Plant `test-x: wave-merge`. The same applies to paths: a
   recipe path such as `$(CURDIR)/spec/vectors/fuzzy/../search` is owned by
   `ai_fuzzy` (`REPO_PATH` allows `..`). Refuse `..`.

3. **Should-fix: what holds `packages` is misdescribed, and the timing-gate
   step is described as a change it did not make.**
   - `added_module.py:28-30` and `docs/howto/parallel-batch.md:75-76` say
     `test_techniques` holds both lists to the manifests. It reads only
     `KIT_MODULES` (`python/tests/test_techniques.py:42-49`). `packages` is
     held by `release.py`'s `project_table`, run by `lint-selftests` through
     `check_the_wheel`, and only on the committed HEAD.
   - Step 5's timing gates already followed their modules on main
     (`git show origin/main:scripts/affected.py`, line 194 picks
     `module.gates` of the chosen modules only). `parallel-batch.md:90-95`
     lists it under "what T111 changed", and the Makefile comment at line
     706 reads the same way. Say that it was already so, and that the
     failures under load remain whenever their module is selected.

4. **Should-fix: `KIT_MODULES` still conflicts.** The task's goal is a
   technique wave that merges clean, but `python/gameaikit/techniques.py:39-42`
   is a two-line packed tuple that every new technique rewrites. `packages`
   was made one per line, and the registry was not. Make it one name per
   line, sorted (rule 6 already compares it as an AST, so the layout costs
   nothing), or say why not in `parallel-batch.md`.

5. **Nit: the order of `test-vectors` changed.** The 24 prerequisites are
   the same set, but they now follow file order rather than the old line's
   order. That is harmless serially. One sentence in the Makefile comment
   would save someone comparing logs.

6. **Nit: Python functions over 40 lines.** `affected.py`
   `planted_gate_changes` is 44 lines (new), `release.py` `project_table`
   41 (was under 40), and `check_manifest_refusals` 57 (was 54).
   `check_readability.py` reads only `*.gd` (line 108), so no gate sees
   this.

7. **Nit: rule 6 does not check `kind`.** A new `example` module whose
   package is added to `packages` is accepted by `listed_module`, and only
   `release.py` refuses it, on a committed HEAD. Require
   `kind in SHIPPED_KINDS` in `born_packages`.

8. **Nit: a manifest change that only touches prose selects its module.**
   That is the same as main for an empty `gates` diff, and it is harmless,
   but no planted case says it is meant.

## Items for the owner

1. Rule 6, accepting non-gate targets, and the sort refusal in `release.py`
   go beyond the task's decisions, as the STATUS row says. They need
   ratifying.
2. `parallel-batch.md:43-46` says the owner decided on 2026-11-04 that the
   whole gate runs once per batch, on the last PR. The reviewer found no
   record of this in `tasks/STATUS.md`. Confirm it, or remove it.
3. The decision on `packages` (sorted rather than generated) rests on
   "both waves would still rewrite it". That holds only if the generated
   list is committed. If it were generated at build time, it would never
   conflict. That is the owner's choice.
4. The timing gates still fail under load whenever their module is
   selected. Nothing here addresses that. It needs either a retry policy
   or a serial slot in the batch.

## How to reproduce

```bash
git worktree add /tmp/r origin/wave/123-a-new-gate-selects-its-module && cd /tmp/r && make worktree-setup
B=origin/wave/123-a-new-gate-selects-its-module
echo '{"module":"zz","kind":"technique","about":"x","owns":["spec/vectors/search/zz.json",".github/workflows/zz.yml"]}' > modules/zz.json
echo '{}' > spec/vectors/search/zz.json; mkdir -p .github/workflows; echo 'on: push' > .github/workflows/zz.yml
python3 scripts/affected.py --base $B --explain     # selected: zz   (finding 1)
python3 scripts/check_modules.py                    # ok
```

## What was done about them

1. **Blocker, fixed.** A new manifest is read only if it is of kind
   `technique` and every `owns` entry has one of the shapes a technique
   takes, named after it: `godot/addons/<m>/`, `godot/test/<m>/`,
   `python/gameaikit/<stem>/`, `spec/vectors/<stem>/`, or
   `python/tests/test_<stem>*.py`, where `<stem>` is the name without
   `ai_` (`TECHNIQUE_SHAPES`). The coordinator's list named
   `docs/techniques/` and `modules/`, which no manifest owns. It left out
   `python/tests/`, and wave 120's module owns two files there, so they are
   added. Each entry must also be claimed by no other module, neither
   inside nor around it, and must not be global. A package folder is
   refused when `python/gameaikit/<stem>.py` was a file at the fork.
   Planted cases: another module's vector folder, a CI workflow, a package
   that shadows the registry, `godot/override.cfg`, a shape another module
   claims, and a module of kind example. Each selects everything. The
   shadow rule also has a direct case in `shape_cases`. Mutation: each of
   the four checks, removed, fails the self-test.
2. **Fixed.** A new gate may depend only on `import` and old `test-`
   targets (`prerequisites_allowed`), and a recipe path containing `..` is
   a doubt. Planted cases: `test-play-you: import wave-merge` and
   `$(CURDIR)/spec/vectors/play/../a`. Both mutations are caught.
3. **Fixed.**
   - `added_module.py`, `parallel-batch.md` and the PR now say that
     `test_techniques` holds `KIT_MODULES` and `release.py` (through
     `lint-selftests`, on the committed head) holds `packages`.
   - The timing gates are described as already their modules' before T111,
     still failing under load whenever their module is selected. This is in
     `affected.py`'s docstring, the Makefile comment and the page.
4. **Fixed.** `KIT_MODULES` is sorted, one a line. `test_techniques`
   refuses it out of order.
5. **Nit, done.** The Makefile comment says the families now run in the
   Makefile's order. The PR body says it too.
6. **Nit, done.**
   - `planted_gate_changes` is split into `planted_recipe_changes`, and
     `planted_vector_changes` into `planted_target_changes`.
   - `release.py`'s `project_table` gives the sort to `sorted_packages`,
     and `check_manifest_refusals` its plants to `manifest_plants`.
   - `select`, `self_test` and `main` in `affected.py` were 41-43 lines on
     main already, and are unchanged in length.
7. **Nit, done** by the blocker's fix: only kind `technique` is read.
8. **Nit, done.** Planted case "a manifest whose prose alone changed"
   selects its module, with a comment saying this is intended.

Items for the owner 1 to 4 are in the PR body's list. On item 2: STATUS's
2026-11-04 section does record it ("The owner said on 2026-11-04 to run the
gate only at the last merge"). The page now quotes it as said for that
batch, not as a standing rule.
