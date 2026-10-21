# Review: wave/67-learning-and-the-small-kernel

One fresh context reviewed the wave commit by commit at `9536f2d`, the
STATUS commit after it included. It was not allowed to edit, or to run
`make check`, `make check-affected` or `make test-godot`. It ran the lints,
the Python suite (309 tests), every T60 and T61 acceptance command on HEAD
and on a `git archive` of `origin/main`, and planted cases in scratch copies
of both trees.

**Verdict: fix before merge.** The refactor moved the code and the gates
mostly followed, but `check_no_training.py` quietly lost two pieces of
coverage, the kind of loss nobody investigates because the gate stays
green.

## What was reviewed

- `CLAUDE.md`, T60, T61, ADR 0021 and the six commits. The two
  "moves only" commits were confirmed to be renames with no content change.
- The manifests against `check_modules.py` and against intent: `board`
  (kernel), `skirmish`, and `unit_view.gd` owned by `tactical` by path.
- Every rewritten comment, in the addons and in `godot/game/board/`.

## Findings

Each one is followed by what was done about it.

1. **N11 watched a constant that no longer exists.** `CLONE_NAMES_RE` matched
   `ClonedPlayer.DEFAULT_PATH`, which T60 deleted, and its planted case wrote
   through that deleted name. So the self-test stayed green while a real
   write through `FightCloneOpponent.PUBLISHED_PATH` raised no finding. The
   reviewer showed this by planting such a write in a copy of HEAD.
   *Fixed*: the pattern and the planted case now name `PUBLISHED_PATH`, and
   so does the docstring.
2. **N2 and N3's strict rules stopped at the addon's folder.** "Writes no
   file" and "reads an indexed value back into itself" exist because a
   review once hid gradient descent under the name `_numbers`.
   `learned_policy.gd`, the code that runs the model every decision, had
   left the folder. The reviewer planted both lines in it: HEAD said
   nothing, main flagged both. Scoping all of `game/tactical/` would
   false-fire on four ordinary files (measured). *Fixed*: `INFERENCE_FILES`
   names the three adapter files, the rules apply to the addon plus those,
   and each rule has a planted case in the adapter.
3. **`pathfinder.gd` and `search.gd` still named `Move`**, which a reader
   copying `ai_core` and `ai_search` no longer has. *Fixed*: the contract is
   stated without it, and the cost is defined as the sum of `cost_at`.
4. **`rts_world.gd` sent turn-based games to `ai_core`**, which after ADR 0021
   holds only the grid. *Fixed*: it now points to a board that hands back a
   new state per move, as `godot/game/board/` does.
5. **Stale paths** in `decision_scenarios.gd`, `learned_policy_test.gd` and
   `spec/vectors/learning/README.md`. *Fixed*.
6. **`unit_view.gd` is owned by `tactical` but sits in the shared folder**,
   which is a trap for a reader, though correct for the selector. *Fixed*
   with a header paragraph saying who owns it and why. Moving the file
   would also have meant editing two scenes for a cosmetic gain, so that
   is left for a wave that touches those scenes anyway.

## What checked out

No tooling byline in any of the six commits, and `check_commit_msg.py`
passes on each. `check_readability`, `check_addon_deps`,
`check_no_employer_refs`, `check_license` and `check_modules` (26 modules)
all pass. Python: 309 tests OK. Every T60/T61 acceptance command passes on
HEAD and fails on main for a real reason. N4's guard is honest, and its
planted case lives in the tactical game. `weights.json` differs only in
`generated_by`, and `weights.txt` is byte-identical. The Makefile,
`.gitignore`, `release.py` and `gameaikit.cloning` point at the new places.
No file is owned twice or by nobody. A change to `board_state.gd` selects 10
modules, and a change to `rows.py` no longer selects checkers.

## What was done about them

All six were fixed in one commit after the review: two planted cases added
and `check_no_training.py --self-test` rerun, which passes. The real tree has
no findings under the wider scope. `make check-affected BASE=origin/main`
(all of `make check`, since the manifests changed) runs before the merge.
Its log is read for `SCRIPT ERROR`, and only the six planted ones are
expected.
