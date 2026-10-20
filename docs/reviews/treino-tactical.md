# Review: chore/treino-tactical

The owner's two recordings of the tactical board, made with
`make record-tactical` on 2026-10-19 -- T25's human reference, the data the
human-likeness half of that task waits for. They were kept untracked until now;
this branch commits them, by the owner's hand. No code, no rule, no decision.

## What was reviewed

The diff against `main`: two files under `data/tactical/`, one line each.

- Both parse as JSON and carry the same top-level fields
  (`decisions`, `dice_seed`, `end`, `format`, `opponent`, `player`, `side`,
  `version`), with 107 and 93 decisions.
- Nothing else in the tree changes.

Not checked: that each game replays to the end it records. There is no command
for that yet -- `make test-replay` covers the fighting game's recorded fight,
not these -- and saying it was checked would be the false green this project
exists to avoid.

## Findings

None.
