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
