# Run a batch of waves in parallel

<!-- doc-meta
half_life: tool
verified_on: 2026-11-04
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

Since 2026-11-04 the owner has said to run the whole gate only once per
batch, on the last pull request's rebased head before it merges. The others
merge on their reviewed heads, each having passed its own
`check-affected`.

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
- **`affected.py` reads a new module (rule 6).** A new manifest owning only
  new files, the new name in a user's `depends_on`, and the library's two
  lists (`KIT_MODULES`, pyproject's `packages`) gaining that module's
  package select the module and its users, not everything.
  `test_techniques` runs with any Python test then, because it holds those
  lists to the manifests. Replayed on wave 120's diff (T95), the selection
  is `ai_constraints`, `infiltration` and `menu`, where it was everything.
- **Rule 5 had not fired since wave 83.** The Makefile gained a Windows
  conditional at its top, and `added_gates.py` read any conditional as a
  doubt, so every Makefile change was global. Now a conditional is a doubt
  only when a hunk is not below the last one. And a vector gate names its
  folder without the slash (`$(CURDIR)/spec/vectors/x`). That used to be a
  path with no owner. Now it is the module that owns the whole folder.
- **The wheel's `packages` stay a sorted list, one a line.** `release.py`
  now refuses one out of order. Two additions conflict only when their names
  are neighbours: in #61, `constraints` and `core` were. A list generated
  from the manifests was the other option. Both waves would still rewrite
  it, so it would conflict just as often. It would also add a second writer
  to a file `release.py` already checks.
- **The timing gates follow their modules.** `test-rts-budget`,
  `test-mcts-budget`, `test-inference-budget`, `test-planner-benchmark` and
  `test-rts-match` measure a frame budget. Five worktrees testing at once
  failed them, and they passed when rerun alone. Each is one module's gate,
  so `check-affected` runs it only when the change selects that module.
  `make check` still runs them all.

What still selects everything, on purpose: a change to a script under
`scripts/`, CI, the engine pin, `godot/project.godot`, or a path no module
owns. In batch 118-122 every wave had one of those besides its Makefile
line, so this task would have saved wave 120 and not the other four.

## Manual check

In the next batch, count the waves whose `make affected BASE=origin/main`
said `selected: everything`, and the rebases that conflicted on the
Makefile or `python/pyproject.toml`.
