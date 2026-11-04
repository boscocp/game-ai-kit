# T111 — A new gate selects its module, and merges clean

Size: S · Prereqs: T71 · Files: `Makefile`, `scripts/added_gates.py`, `scripts/affected.py`, `python/pyproject.toml`, `scripts/release.py`, `docs/howto/`, `CLAUDE.md`

## Goal

In waves 118 to 122, five branches ran in parallel. Each one added a
family of vectors to the one-line `test-vectors:` list in the Makefile.
That one edit cost the batch twice:

- **It selected all of `make check`, every time.** `added_gates.py` (T71)
  accepts a Makefile change that only adds gates. That covers new
  `test-...` targets, and new names put into `check:`. It does not cover
  `test-vectors:`. A new name there counts as doubt, and doubt is global.
  So every wave's run after review fixes, and every rerun after a rebase,
  paid for the whole suite. The implementers' reports count at least
  ten whole runs.
- **Every rebase conflicted on that line.** Each branch rewrote the same
  line. The `packages` list in `python/pyproject.toml` did the same for
  each new technique package. Both conflicts were unions, and they were
  still resolved by hand (#61, #62).

The owner asked on 2026-11-04 for parallel waves to cost less and redo
less. This task removes those two costs, and gives up nothing on the
selector's rule that doubt means global.

## Decisions written down first

_The decisions below are this session's proposal, written on 2026-11-04; the owner has not ratified them. The wave that takes the task confirms them, or brings them back to the owner._

- **`test-vectors:` is read like `check:`.** If the change is only new
  names, added to that line in the same words and the same order, for
  targets the same change adds, the change selects their module. Anything
  else in that line is still global.
- **The list stops being one line, if that reads well.** One option: each
  family's target declares itself beside its rule, so that a new family
  is one added line and never an edit. Two forms qualify: a
  prerequisite-only line, `test-vectors: test-x-vectors`, which Make
  accepts repeated, or `VECTOR_TARGETS += ...`. `added_gates.py` must
  then accept that form, and nothing broader, with planted cases. If
  neither reads well, keep the line and say why.
- **The wheel's `packages` stay an explicit list.** The examples'
  packages (checkers, maze, tactical, ...) are left out on purpose, and
  `release.py` holds the list equal to the technique and kernel
  manifests. So `find_packages` is not the answer. Two answers are: the
  list sorted one per line, so that two additions conflict only when
  they are adjacent, or the list generated from the manifests by
  `release.py`. Measure which one keeps the check.
- **The timing gates are not part of `check-affected`** unless the change
  selects their module (`rts`, `ai_adversarial`, ...). `make check` keeps
  them. Under the load of five worktrees they failed in almost every wave
  and passed when rerun alone. That rerun is what this saves.
- **No rule of `affected.py` gets looser.** A path nobody owns, the
  scripts, CI and the engine pin all stay global.

## Steps

1. Read `scripts/added_gates.py`, `scripts/affected.py` (rule 5 and its
   planted cases) and the Makefile's `check:` and `test-vectors:` lines.
2. Accept a new name in `test-vectors:` the way `check:` is accepted,
   with planted cases: a name for a target the change does not add, a
   reordered list, and a removed name must each stay global.
3. If it reads well, split the list as above.
4. Make the `packages` list merge clean, and keep `release.py`'s check.
5. Keep the timing gates out of `check-affected` unless their module is
   selected, and say on the target's line which gates those are.
6. Measure: replay wave 120's diff, which added `ai_constraints` and its
   vectors, through `affected.py --explain`. It must select that module
   and the infiltration, not everything.
7. Write the coordinator's routine for a parallel batch into
   `docs/howto/`, as it has run since wave 101, plus what this task
   changes. CLAUDE.md's trap on `check-affected` points at it.

## Acceptance

```bash
python3 scripts/affected.py --self-test
python3 scripts/release.py --self-test
make lint-modules lint-selftests
make check-affected BASE=origin/main
```

## Manual check

In the next parallel batch, count how many waves selected all of
`make check`, and how many rebases conflicted on the Makefile or
`pyproject.toml`. Compare with batch 118-122: five, and two of the three
the coordinator did.

## Done (wave 123), and where it departs from the above

Step 6's replay of wave 120 (`affected.py --base 7d9faaa^ --head 7d9faaa
--explain`) selected everything at the start, for five paths, not one. The
`test-vectors:` line was only one of them. The reading behind each change:

1. **Rule 5 had not fired since wave 83.** `added_gates.py` read any
   conditional in the Makefile as a doubt, and wave 83 put one at its top
   for Windows' shell. Its planted cases had none, so they stayed green.
   Now a conditional, `define` or `include` is a doubt only when a hunk is
   not below the last one. Planted: a gate inside a conditional, a
   conditional added, a conditional changed, and one above every rule,
   which must select its module.
2. **A vector gate's folder had no owner.** Every vector recipe names
   `$(CURDIR)/spec/vectors/<family>` without the slash, and no prefix
   matched it. Now a folder belongs to the module that owns all of it.
   Planted: a folder another module has a part of.
3. **`test-vectors:` is read like `check:`** (decision 1), and **the list
   is split** (decision 2): each family has `test-vectors: test-x-vectors`
   beside its rule. `make -p` gives the same 24 prerequisites. Planted: a
   name the change did not add, a reordered list, a name taken out, a name
   moved from `check:`, an old target attached, an attaching rule with a
   recipe, and one naming two. `check_workflow.py` now reads every rule
   for a target (planted: a gate on a second rule that CI misses).
4. **A new non-gate target (`measure-level-constraints`) selects nothing.**
   No gate runs it, and a new rule may depend only on old names, so no
   gate can. This is not in the decisions. Planted: a gate that needs a
   new target.
5. **Rule 6, `scripts/added_module.py`, is new, and is not in the
   decisions.** A new manifest that owns only new files and whose gates
   the Makefile added for it, a user's `depends_on` gaining it (with prose
   changes to `about`/`summary`), and `KIT_MODULES` or `packages` gaining
   only its package select that module and its users. `test_techniques`
   runs with every Python selection, because it holds the two lists to
   the manifests. Planted: the cases in `planted_module_changes`. Without
   this rule, step 6 could not hold: the new manifest, `techniques.py` and
   `pyproject.toml` were global paths besides the Makefile.
6. **`packages`** (decision 3): kept as a sorted list, one a line, and
   `release.py` now refuses an unsorted one (planted). In #61 the two
   additions were neighbours (`constraints`, `core`), so they conflict
   either way. A generated list is rewritten by both waves too, so it
   would conflict no less.
7. **Timing gates** (decision 4): already true, since each is one module's
   gate and `always_run` takes only `lint-`. The `check-affected` line
   names them, and a target case holds that a change to `b` runs no gate
   of `a`.

The replay now selects `ai_constraints, infiltration, menu` (menu for
`godot/menu/catalogue.json`). The other four waves of batch 118-122 still
select everything, each for a script, `godot/project.godot` or a manifest
change rule 6 does not read. So this would have saved one whole run of
the batch's five, plus the reruns after its rebases. The routine is in
`docs/howto/parallel-batch.md`.
