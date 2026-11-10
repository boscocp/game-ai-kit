# T163 — A save is a record of deeds, not a model of the player

Size: S · Prereqs: none · Files: `docs/adr/`, `docs/godot/user-data.md`, `scripts/check_no_training.py`, `python/tests/`

## Goal

Every example in the kit forgets when it closes. ADR 0016 refuses "any
count that survives the fight", and N14 refuses a player model read back
from `user://`, because a profile outlives the match. A karma system has to
remember across sessions, so the rule that allows it has to be written
before any code that uses it.

## Decisions written down first

_The owner asked for a karma system on 2026-11-10: the player's actions and choices have a visible impact on the world and its people, and they persist between sessions like a save. The owner chose this design from a research brief: the valley remembers what the player did to **places**. It has no combat and no opponent, and it is 2D and turn-based. The owner approves the ADR (T163), and that approval gates T164-T166. The other decisions below are this session's proposal, and the wave confirms them._

- **A new ADR, 0025, "A save is a record of deeds, not a model of the
  player".** It amends 0016 and 0022 and cites them. Its rule, to confirm:

  > Only a record of deeds may persist between sessions. The record is
  > appended to and never edited, it has a schema version, and one class
  > of the example writes it. Nothing derived is saved. The world is
  > rebuilt each session by applying the record, in order, to fixed,
  > authored rules, and a test rebuilds it twice and compares. The
  > player's standing is a sum of fixed, authored weights over the
  > deeds. It is rebuilt from the record, never saved, never fitted to
  > the player, never an estimate of skill, and it never sets
  > difficulty. N14 still holds within a match. No deed
  > has a person as its target. Nothing about a person is saved. No
  > person reads another person's state. Nothing tunes difficulty. The
  > game has an erase button, which removes the file and starts again
  > from the first day.

- **N20 in `check_no_training.py`.** It is a net for the common
  spellings, as N9, N13 and N14 are, and not a proof. Its planted cases
  must be refused (invariant 4):
  - a save written by any other file;
  - derived state, the standing included, written beside the record;
  - an authored weight changed at game time, as a step toward a target;
  - a deed whose target is a person;
  - the record or the standing read to set difficulty.
- **Where the save lives, read and measured first** (invariant 8, and
  "check the documentation before writing the rule"). Two cases:
  - **In the checkout**, `user://` is `.user-data/` (ADR 0022). ADR 0022
    says nothing there needs to survive, and `git clean -fdx` deletes it.
    The ADR amends that sentence for the save alone.
  - **In an exported build**, `user://` would be the player's home
    folder. The wave reads the 4.7.2 documentation on `user://` and
    `use_custom_user_dir`, measures it, and writes the choice, with its
    source, in `docs/godot/user-data.md`.
- **Time moves only while the player plays.** No wall clock, so a session
  is deterministic and testable.
- **Erasing:** the in-game button, with confirmation, and a `make`
  target that removes the checkout's save.

## Acceptance

```bash
make lint-no-training
make lint-selftests
make lint-docs-freshness
```

## Manual check

- **The owner reads the ADR and approves it.** Until then T164, T165 and
  T166 stay `todo` and are not started.
