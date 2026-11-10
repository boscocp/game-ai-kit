# T164 — The deed log and the valley's rules

Size: M · Prereqs: T163 · Files: `godot/game/valley/`, `godot/test/valley/`, `python/gameaikit/valley/`, `python/tests/`, `spec/vectors/valley/`, `modules/valley.json`, `Makefile`

## Goal

This is the memory under the example, with no screen yet. The player's
deeds on places are recorded, and the valley's state each day is rebuilt
from that record.

## Decisions written down first

_The owner asked for a karma system on 2026-11-10: the player's actions and choices have a visible impact on the world and its people, and they persist between sessions like a save. The owner chose this design from a research brief: the valley remembers what the player did to **places**. It has no combat and no opponent, and it is 2D and turn-based. The owner approves the ADR (T163), and that approval gates T164-T166. The other decisions below are this session's proposal, and the wave confirms them._

- **The deeds act on places.** The verbs are: burn, repair, pull down the
  bridge, build a footbridge, divert the water, plant, dig a well, open
  or close a gate.
- **A deed is `{day, verb, place}`.** The schema accepts only places, and
  the test refuses a planted `{"verb": "...", "target": "villager_3"}`.
- **`DeedLog`** is appended to and never edited. **`ValleySave`** is the
  only class that writes or erases the file, at the place T163 decided.
- **`ValleyRules`** advances the world one day by authored rules, place
  to place, in `valley_rules.json` with a `why` for each rule. For
  example, a burnt barn leaves the market without bread the next day.
- **`ValleyWorld`** is the rebuilt world, and it is never saved.
- **A Python twin with shared vectors**, as the kit's other rule sets
  have (the infiltration director's events are the pattern). The
  property tests cover three things:
  - rebuilding twice gives the same world;
  - a record cut at day n gives the world of day n;
  - an unknown verb, or a target that is a person, is refused by name.
- **The names** (`valley`, `DeedLog`, `ValleySave`, `ValleyRules`,
  `ValleyWorld`) are this session's proposal. The wave may change them,
  and must say so.

## Acceptance

```bash
make test-godot-some SUITES="test/valley"
make test-valley-vectors
make test-python
make lint-no-training
make lint-modules
```

## Manual check

- `valley_rules.json` reads as a list of consequences a designer wrote,
  each with its reason.
