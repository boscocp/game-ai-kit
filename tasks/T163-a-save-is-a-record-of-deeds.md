# T163 — A save is a record of deeds, not a model of the player

Size: S · Prereqs: none · Files: `docs/adr/` (0025, and the "amended by" notes in 0016 and 0022), `CLAUDE.md` (invariant 6's row), `docs/godot/user-data.md`, `scripts/check_no_training.py`, `python/tests/`, `Makefile` (`make valley-erase`)

## Goal

Every example in the kit forgets when it closes. ADR 0016 refuses "any
count that survives the fight", and N14 refuses a player model read back
from `user://`, because a profile outlives the match. A karma system has to
remember across sessions, so the rule that allows it has to be written
before any code that uses it.

## Decisions written down first

_The owner asked for a karma system on 2026-11-10: the player's actions and choices have a visible impact on the world and its people, and they persist between sessions like a save. The owner chose this design from a research brief: the valley remembers what the player did to **places**, and the player's standing, read from those deeds, sets prices and doors. It has no combat and no opponent, and it is 2D and turn-based. The owner approves the ADR (T163), and that approval gates T164-T166. The other decisions below are this session's proposal, and the wave confirms them._

- **A new ADR, 0025, "A save is a record of deeds, not a model of the
  player".** It amends 0016 and 0022 and cites them. Its rule, to confirm:

  > Only a record of deeds may persist between sessions. The record is
  > appended to and never edited, it has a schema version, and one class
  > of the example writes it. Nothing derived is saved. The world is
  > rebuilt each session by applying the record, in order, to fixed,
  > authored rules, and a test rebuilds it twice and compares. The
  > player's standing is a sum of fixed, authored weights over the
  > deeds: the weights never change, and its value changes only when a
  > deed is added. It is rebuilt from the record, never saved, never
  > fitted to the player, never an estimate of skill, and it never sets
  > difficulty. No deed has a person as its target. Nothing about a
  > person is saved. No villager reads another villager's state; the
  > only thing about the player a villager may read is the standing,
  > rebuilt from the record. The
  > game has an erase button, which removes the file and starts again
  > from the first day.

- **This is the amendment to ADR 0016**, which refuses any count that
  survives the fight. The ADR says why the standing is not 0016's player
  model:
  - its weights are fixed and authored;
  - it estimates no skill;
  - it sets no difficulty.
  N14 is unchanged, and N20 neither widens nor weakens it.
- **Difficulty and consequence, defined.**
  - *Difficulty* is a parameter of how hard the game makes a challenge:
    an opponent's strength or aim, a timing window, a search depth. The
    valley has none.
  - A *consequence* is what an authored weight does in the world: a
    price, a door, a greeting. The consequence keys are listed in
    `standing.json`, and those are the only things the standing may
    set. N20's difficulty plant is the standing, or the record, read by
    code that sets a challenge parameter.
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
    source, in `docs/godot/user-data.md`. The ADR states whether
    invariant 8 covers an exported build at all. `check_disk_layout.py`'s
    D1 already flags this project's `user://` in the home folder.
- **Time moves only while the player plays.** No wall clock, so a session
  is deterministic and testable.
- **Erasing:** the in-game button, with confirmation, and `make
  valley-erase`, which removes the checkout's save.

## Acceptance

```bash
make lint-no-training
make lint-disk-layout
make lint-selftests
make lint-docs-freshness
```

## Manual check

- **The owner reads the ADR and approves it.** Until then T164, T165 and
  T166 stay `todo` and are not started.
