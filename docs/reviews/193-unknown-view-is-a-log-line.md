# Review: fix/193-unknown-view-is-a-log-line

Pull request #151, reviewed at `b003e43e` (the branch head, equal to
`origin/fix/193-unknown-view-is-a-log-line`).

## What was reviewed

The whole diff against `origin/main`: one line in
`godot/game/tactical/tactical.gd:147`, the `push_error` that names an unknown
`--view=`, now ending in `# not shown: for the log`. Read alongside it:
`_ready`, `unknown_view` and `teaching_asked` in the same file; the other
uses of the marker in `godot/game/`; `scripts/check_translations_game.py`'s
L1 rule and its `NOT_SHOWN` marker; review record 191, where the line came
from; and `modules/tactical.json` with the `check-affected` target.

Run on the branch: `python3 scripts/check_translations_game.py` (exit 0, no
findings) and `make lint-readability lint-status lint-tasks` (exit 0).
Since the branch differs from main by this one line, and the lint is clean
with it, that line was main's only `lint-translations-game` finding.

## Findings

1. **Correct, no change needed.** The marker matches the convention
   exactly: the same trailing `# not shown: for the log` sits on four other
   `push_error` lines (`maze/maze_rules.gd:126`, `maze/mdp_pac_man.gd:65`
   and `:190`, `squad/mcts_squad.gd:122`). The lint reads `not shown` as
   the marker, so the `: for the log` reason is the house wording, not
   something the lint needs.
2. **Correct, the message is never on screen.** `unknown_view` is a pure
   static function over the arguments after `--`; `_ready` passes its
   result only to `push_error`, which goes to stderr and the engine log. No
   label, status or legend receives it: `_set_words()` and the view run
   after it and do not read `unknown`. The marker therefore tells the
   truth. That a person who typed `VIEW=teaching` sees the error only in the
   terminal is the design review 191 chose ("refuses aloud", to the log),
   and the terminal is where they typed it.
3. **Follow-up worth a line in a task, not a gate (process).** The line
   arrived in #149's review-fix commit, and that commit's rerun list (review
   record 191, "Rerun after the fixes") was hand-picked: test suites,
   `check_demos.py`, `check_readability.py`, `lint-tasks lint-status`, but
   not `lint-translations-game`, nor `make check-affected`, which runs
   every lint. With GitHub CI disabled until the repository is public,
   nothing else ran the lints on the merged head, so main went red. The
   cheap fix is a rule in `docs/howto/parallel-batch.md`: after applying a
   review's findings, the rerun is `make check-affected BASE=origin/main`
   in full, not a chosen subset. A stronger one, while CI is off, is for
   `make wave-merge` to run the lints itself on the head it merges; worth
   weighing, since the same gap will recur on any late edit.

## What was done about them

1. and 2. Nothing to change: the marker and the reading hold.
3. Taken up by the coordinator for the rest of this batch: before each
   merge, `make check-no-engine` runs on the head being merged, so every
   lint sees what lands. The rule for `docs/howto/parallel-batch.md` is
   recorded as a follow-up in the batch's STATUS section.
