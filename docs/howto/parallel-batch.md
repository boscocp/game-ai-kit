# Run a batch of waves in parallel

<!-- doc-meta
half_life: tool
verified_on: 2026-11-10
tier: 1
source: https://www.gnu.org/software/make/manual/html_node/Multiple-Rules.html
invalidated_if: GNU make stops merging the prerequisites of several rules for one target, `gh pr merge` drops --match-head-commit, or the owner changes how a batch is gated
teaches: none
-->

> How the coordinator has run a batch of three to five waves at once since
> wave 101, and what T111 (wave 123) changed so a batch costs fewer whole
> runs of `make check` and fewer conflicts at rebase. It is the routine, not
> a rule: the owner's word on a given batch wins.

## Choosing the batch

- Read each candidate task's `Files:` line. Two waves that write the same
  module, or the same game folder, do not run together (T110 waited for
  T85: both write `godot/game/tactical/`).
- A wave that changes the selector itself (`scripts/affected.py`,
  `scripts/added_gates.py`, `scripts/added_module.py`, the Makefile's
  rules) runs beside as few others as possible: every other branch is
  checked by what it changes.
- Ask the owner with one numbered list, a recommendation on each line.

## One wave, one worktree, one reviewer

1. One implementing agent per wave, in its own git worktree, with its own
   scratch folder. (An agent once ran another's `mutate.py` from a shared
   one.) The first command in a worktree is `make worktree-setup`.
2. The implementer stops at the pull request: `make check-affected
   BASE=origin/main`, the PR's title and body through
   `check_pr_message.py`, and no merge.
3. A fresh-context reviewer per pull request (invariant 12). Its findings
   go back to the same implementer, on the same branch.
4. The coordinator merges, in order, with the full sha:
   `check_pr_message.py && gh pr merge N --squash --match-head-commit <sha>`.
   Chain it with `&&`, never `;` (#36 merged with a title the lint refused).
5. After each merge the waves still open rebase on the new main.

**Where a worktree finds Godot (T143).** Since wave 150 the toolchain is
`GAK_TOOLCHAIN` when set, and the checkout's own `.toolchain` otherwise. On
the author's machine the main checkout's `.toolchain` is a link to
`/mnt/games/gamedev/toolchain`, made once by hand right after T143 merged:

```bash
ln -s /mnt/games/gamedev/toolchain /mnt/games/gamedev/game-ai-kit/.toolchain
```

`make worktree-setup` links each worktree's `.toolchain` to it, so a
worktree made before that link, or before T143, runs `make worktree-setup`
again. A worktree whose Godot gates all say "run make bootstrap" lacks the
link.

For batch 118-122 the owner said, on 2026-11-04, "Roda só o gate no último
merge", which `tasks/STATUS.md`'s section of that date records as "to run
the gate only at the last merge". That batch ran the whole `make check` once, on the
last pull request's rebased head before it merged; the others merged on
their reviewed heads, each having passed its own `check-affected`. It was
said for that batch: ask again for the next.

## What a rebase used to cost, and what T111 changed

Batch 118-122 counted at least ten whole runs of `make check`, and two
conflicts on lines every wave rewrote.

- **A vector family names itself beside its rule.** `test-vectors:` used to
  be one line listing every family. Every new family rewrote it, so any two
  waves conflicted there. Now each family's rule has a line of its own:

  ```make
  .PHONY: test-constraints-vectors
  test-vectors: test-constraints-vectors
  test-constraints-vectors: import ## The constraint vectors, against ai_constraints
  ```

  GNU make merges the prerequisites of every rule for one target into one
  list, and allows one recipe among them. So a new family adds lines and
  rewrites none, and two waves conflict only if they add theirs at the same
  place.
- **`affected.py` reads that change as a gate added (rule 5).** A name put
  into `test-vectors`, in the old one-line form or by its own rule, counts
  as one put into `check:`. A name for a target the change did not add, a
  list reordered, or a name taken out still selects everything.
- **`affected.py` reads a new module (rule 6).** A new technique's manifest,
  owning only the folders a technique takes and named after it
  (`godot/addons/<m>/`, `godot/test/<m>/`, `python/gameaikit/<stem>/`,
  `spec/vectors/<stem>/`, `python/tests/test_<stem>*.py`), new and claimed
  by no other module; the new name in a user's `depends_on`; and the
  library's two lists gaining its package: these select the module and its
  users, not everything. Any other path a new manifest claims -- a CI file,
  `godot/override.cfg`, a file in another module's folder -- leaves it
  global. `test_techniques` runs with any Python test then, because it holds
  `KIT_MODULES` to the manifests; `packages` is held by `release.py`'s own
  check, which `lint-selftests` runs on the committed head. Replayed on wave 120's diff (T95), the selection
  is `ai_constraints`, `infiltration` and `menu`, where it was everything.
- **Rule 5 had not fired since wave 83.** The Makefile gained a Windows
  conditional at its top, and `added_gates.py` read any conditional as a
  doubt, so every Makefile change was global. Now a conditional is a doubt
  only when a hunk is not below the last one. And a vector gate names its
  folder without the slash (`$(CURDIR)/spec/vectors/x`). That used to be a
  path with no owner. Now it is the module that owns the whole folder.
- **The wheel's `packages`, and `KIT_MODULES`, are sorted lists, one a
  line.** `release.py` refuses `packages` out of order, and
  `test_techniques` `KIT_MODULES`. Two additions conflict only when their names
  are neighbours: in #61, `constraints` and `core` were. A list generated
  from the manifests was the other option. Both waves would still rewrite
  it, so it would conflict just as often. It would also add a second writer
  to a file `release.py` already checks.
- **The timing gates were already their modules'.** `test-rts-budget`,
  `test-mcts-budget`, `test-inference-budget`, `test-planner-benchmark` and
  `test-rts-match` measure a frame budget. Five worktrees testing at once
  failed them, and they passed when rerun alone. Each was one module's gate
  before T111 too, so `check-affected` ran it only when the change selected
  that module; what T111 changes is that fewer changes select everything.
  They still fail under load whenever their module is selected: rerun one
  alone before reading it as a regression. `make check` runs them all.

## The timing gates run alone, in the last gate

The owner ratified on 2026-11-05 the recommendation that the timing gates
run alone in the coordinator's last gate (`tasks/STATUS.md`, item 23 of
2026-11-04). The routine:

- **A wave's own run does not settle a timing gate.** While other
  worktrees test, a failure of `test-rts-budget`, `test-mcts-budget`,
  `test-inference-budget`, `test-planner-benchmark` or `test-rts-match`
  is load, until a run alone says otherwise. The implementer says in the
  pull request which of them failed under load.
- **The coordinator runs them alone, last.** After the batch's other
  checks, with no other worktree testing, the coordinator runs each
  timing gate the batch selected, one at a time. That run is the one the
  merge rests on. A failure there is a regression.
- **The whole `make check`** that closes a batch counts as that run only
  if nothing else was testing while it ran.

What still selects everything, on purpose: a change to a script under
`scripts/`, CI, the engine pin, `godot/project.godot`, or a path no module
owns. In batch 118-122 every wave had one of those besides its Makefile
line, so this task would have saved wave 120 and not the other four.

## A faster batch (2026-11-10)

Batch 164-168 ran five waves at once. It took about seven hours, and
most of that time was waiting, not work:

- GitHub's full CI took one to two hours per run (the T140 push on main
  took 1 h 51 min).
- Every push to a branch cancelled its run and started another.
- Every merge sent the open branches back to CI after a rebase.
- Nine agents testing at once pushed the load to 15-20 on 12 threads.
  Each local `make check` then took about 50 minutes, and the timing
  gates failed until they were run alone.
- The implementer and the reviewer each ran the same full check on the
  same head.

The owner decided the following for that batch (`tasks/STATUS.md`,
2026-11-10). The coordinator proposes it as the routine; the owner
confirms that, batch by batch, as this page's opening says:

- **At most three waves at once.**
- **The reviewer runs the gates of what the change touches**, and plants
  each case it doubts. It does not rerun a `make check-affected` that
  selects everything when the implementer already ran it on the same
  head.
- **A review's findings go back in one push**, not one per finding.
- **The merge does not wait for the pull request's CI.** The coordinator
  merges with `--admin` once three things are true:
  - the review and its fixes are in;
  - the rebased head passes its modules' gates locally;
  - the timing gates passed alone.
  CI then runs on main after each merge. A red run there is fixed
  forward, in a pull request of its own.
- **The full `make check` is skipped** for a wave whose change selects
  everything only because it touches `scripts/` or the Makefile. Instead
  the wave runs `make check-no-engine` and the gates of the scripts it
  changed.

## Manual check

In the next batch, count the waves whose `make affected BASE=origin/main`
said `selected: everything`, and the rebases that conflicted on the
Makefile or `python/pyproject.toml`.
