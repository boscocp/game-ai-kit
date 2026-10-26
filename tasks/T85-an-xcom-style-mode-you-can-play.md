# T85 — The XCOM-style mode you can play, against an enemy that weighs

Size: M · Prereqs: T84 · Files: `godot/game/squad/`, `godot/test/squad/`, `godot/menu/catalogue.json`, `godot/locale/squad.csv`, `modules/squad.json`, `scripts/check_demos.py`, `Makefile`, `docs/godot/squad.md`

## Goal

The owner, 2026-10-26: the XCOM-style mode of the tactical game (T84's
quote). This task makes T84's rules a thing a person plays against the
computer: a board, the squad, the fog, the hit chance shown before a shot,
and a first enemy that is an agent -- it perceives through its side's view
and weighs its options -- before T86 and T87 put search behind it.

The owner's standing rules apply: a bot is an AIMA agent that weighs what
it perceives, with as few fixed if/else as can be; every example builds on
a game people know (here XCOM, by name on the card).

## Decisions written down first (the owner confirms in review)

- **The first enemy weighs one action ahead**: for each legal action of the
  unit to move, its expected value under the rules (hit chance times
  damage, cover gained or lost, flank exposure from the enemies it sees),
  the best taken. It is the baseline the searches must beat, the way
  `LeveledBlue` is the tactical game's. If T100 has landed, it uses
  `ai_utility`; if not, the scoring is local and T100 moves it.
- **The controller sees its side's view only**, never the state (T84's
  fog). A gate holds it: moving an unseen unit must not change any
  controller's decision -- the tactical racer's and the bot match's
  "does not cheat" shape.
- **Keys**: the same as the tactical game's where they mean the same
  thing (select, move, attack, end turn, undo a move that drew no dice);
  C cycles controllers, as in `make demo-tactical`; V shows the decision.

## Steps

1. A scene `godot/game/squad/squad.tscn` drawing T84's state with shapes:
   cells, cover as edge marks (half, full), soldiers and aliens as
   lettered tokens, the fog as dark cells and last-seen ghosts. Art is
   T88's; the scene must work and its gates pass without it.
2. Input for the person's side: select a soldier, its reachable cells for
   one and for two actions, the targets it sees with **the hit chance and
   the cover that made it** shown before the shot.
3. `SquadController`, the interface every later controller implements
   (the side's view in, one action out), and `WeighedSquad`, the
   one-action enemy above. Registered in a roster like `TacticalRoster`,
   so T86 and T87 add rows, not branches.
4. **The decision, drawn** (invariant 13): with V, each option the enemy
   weighed for the unit about to act -- the cell or target, its score and
   the hit chance in it -- drawn on the board before the action is played,
   as T21 made the tactical game's blue.
5. `make demo-squad`; a menu card in `godot/menu/catalogue.json` naming
   XCOM as the known game; `check_demos.py` holds the card, the scene and
   the overlay; the locale table `godot/locale/squad.csv` (T78's
   mechanism, both languages).
6. Gates: the does-not-cheat check above; a seeded match of
   `WeighedSquad` against itself replays to its digest; the baseline beats
   a random mover in at least 80 of 100 seeded matches per seat, measured
   and written down (`make test-squad-match`).

## Acceptance

```bash
make test-godot-some SUITES="test/squad"
make test-squad-match
python3 scripts/check_demos.py
python3 scripts/check_translations_game.py
make test-locale-screen
make lint-modules
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

Play a match with `make demo-squad`, in English and in PT-BR. Is the hit
chance shown before every shot, and is the reason for it (cover, flank)
readable? With V on, can you say before the enemy moves which option it
will take? Does it ever seem to know where an unseen soldier is?

How invariant 13 is met: step 4 -- every option the enemy weighed, with
its score and hit chance, on the board before it acts; `check_demos.py`
holds that the overlay is populated, and the seeing stays the person's.
