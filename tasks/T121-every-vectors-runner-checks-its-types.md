# T121 — Every vectors runner refuses a vector of the wrong type

Size: M · Prereqs: T109 · Files: `godot/test/`, `godot/game/squad/`, `godot/game/tactical/`, `godot/game/maze/`, `godot/game3d/botmatch/`, `godot/game/talk/`, `godot/game/checkers/`, `godot/game/tictactoe/`, `godot/game3d/racing/`, `godot/game3d/infiltration/`

## Goal

The owner ratified on 2026-11-05 ("todas conforme recomendado") the
recommendation of STATUS's 2026-11-04 item B9: open a follow-up task to
give every `*_vectors_runner.gd` the type checks the core runner gained.
`mcts_vectors_runner.gd` has the same hole.

T109's review (`docs/reviews/122-one-seeded-generator-in-ai-core.md`,
finding 1) planted `"cases": "x"` and a list of the wrong type in a
vector file. The core runner then printed "0 failure(s)" and exited 0.
The fix there checks each field with `is Array` / `is Dictionary`, and
returns a reason, so the runner exits 2 on a vector it cannot read. Its
planted cases are in `godot/test/ai_core/xorshift_test.gd`,
`test_a_broken_vector_is_refused`. The reviewer showed the same exit 0
in `mcts_vectors_runner.gd`, with `draws` turned into a string. There
are 25 runners under `godot/test/`, and only the core one was fixed.

A vector gate that goes green on a file it could not read is the defect
invariant 4 names.

## Decisions written down first

_The owner ratified only the item quoted above. The decisions below are this session's proposal, written on 2026-11-05; the wave that takes the task confirms them, or brings them back to the owner._

- **The same shape as the core runner.** A vector that is not the shape
  the runner reads exits 2 with a reason, never 0 and never 1. 1 stays
  "a case disagreed".
- **One planted case per runner, at least:** a list replaced by a
  string, in a copy of one of that family's real files. Planted in the
  family's own gdUnit suite, as the core's is.
- **Measure first.** Plant the string in every family and list which
  runners exit 0 today. Fix those. A runner that already exits 2 gains
  only the planted case.
- **A helper only if it reads better.** If the checks repeat, a small
  shared reader under `godot/test/` may hold them. A runner's family may
  not depend on another addon for it (invariant 2): the helper is test
  code, not an addon.

## Steps

1. List today's runners (`git ls-files 'godot/test/*_vectors_runner.gd'`)
   and plant the string in each.
2. Fix the ones that exit 0, one family at a time.
3. A planted case in each family's suite.
4. Read each runner's output for `SCRIPT ERROR` (CLAUDE.md's trap): a
   typed-array mismatch aborts a function and the run still exits 0.

## Acceptance

```bash
make test-vectors
make test-godot
python3 scripts/check_readability.py
make lint-modules
make lint-tasks lint-status
```

## Manual check

None beyond reading each runner's output once for `SCRIPT ERROR` lines,
which no exit code shows.

## Notes

- Shares `godot/test/ai_adversarial/`, `godot/test/squad/` and the
  squad's runner with T88, and `godot/test/ai_constraints/` and
  `godot/test/squad/` with T96. It touches many folders, so it runs alone
  or after them.
- The `Files` line names the game folders because some runners read
  their vector shape from a class there. A runner that needs no game
  change leaves its game folder alone.
