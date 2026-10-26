# T85 — The XCOM-style mode in the tactical scene, against an enemy that weighs

Size: M · Prereqs: T84 · Files: `godot/game/tactical/`, `godot/test/tactical/`, `godot/game/squad/`, `godot/test/squad/`, `godot/menu/`, `godot/test/menu/`, `godot/locale/tactical.csv`, `godot/locale/squad.csv`, `modules/squad.json`, `modules/menu.json`, `scripts/check_demos.py`, `Makefile`, `docs/godot/squad.md`

## Goal

The owner, 2026-10-26: an XCOM-style **mode of the tactical game**, not a
new game (T84 quotes it). T84 gave the tactical scene a second ruleset;
this task makes it something a person plays: chosen from the tactical
game's own card and scene, on its map, with its pieces and keys, against
a first enemy that is an agent -- it perceives through its side's view and
weighs its options -- before T87 and T88 put search behind it.

The owner's standing rules apply: a bot is an AIMA agent that weighs what
it perceives, with as few fixed if/else as can be; every example builds on
a game people know (here XCOM, named on the card's mode).

## Decisions written down first (the owner confirms in review)

- **One card, one scene, two modes.** The tactical card in
  `godot/menu/catalogue.json` gains `modes` (Advance Wars, the default,
  and XCOM); the menu opens the tactical scene with the mode chosen; a key
  in the scene (M, free today) switches mode and starts a new game, as C
  does for controllers. `make demo-tactical MODE=squad` opens the menu
  straight into the tactical card in that mode. There is no second card
  and no `demo-squad` target.
- **Everything the person meets is the tactical game's** where it means
  the same thing: click a piece and its reach lights up (one action's
  range and the dash range in two tints), click a target, Z undoes a walk
  that drew no dice, space ends the turn, C cycles the computer, S swaps
  sides. T, the threat map in Advance Wars, shows in this mode each enemy
  piece's hit chance on the cell under the cursor.
- **The first enemy weighs one action ahead**: for the unit to move, each
  legal action's expected value under the rules (hit chance times damage,
  cover gained or lost, flank exposure from the enemies it sees), the best
  taken. It is the baseline the searches must beat, the way `LeveledBlue`
  is in Advance Wars. If T101 has landed, it uses `ai_utility`; if not,
  the scoring is local and T101 moves it.
- **It sees its side's view only**, never the state; a gate holds it:
  moving a piece it cannot see must not change its decision -- the racer's
  and the bot match's "does not cheat" shape.

## Steps

1. The tactical scene reads its rulesets from its opener (T84's seam); the
   M key; the mode named in the status line; the fog drawn as darkened
   cells and last-seen ghosts, through `board_view.gd`.
2. **The hit chance shown before a shot**, with the cover and the flank
   that made it -- the number and its reasons, on the target.
3. `WeighedSquad`, a `BlueController` row in `SquadRoster`; C cycles that
   roster in this mode and `TacticalRoster` in the other.
4. **The decision, drawn** (invariant 13): with the scene's decision view,
   each option the enemy weighed for the unit about to act -- the cell or
   target, its score and the hit chance in it -- before it is played and
   before space plays it, as the tactical game draws blue's today.
5. `check_demos.py`: a card's `modes` are held like its controllers (C9),
   each mode's controllers to its roster, both ways, with a planted case;
   the locale tables gain the mode's words (T78's mechanism, both
   languages).
6. Gates: the does-not-cheat check; a seeded match of `WeighedSquad`
   against itself replays to its digest; the baseline beats a random mover
   in at least 80 of 100 seeded matches per seat, measured and written
   down (`make test-squad-match`).

## Acceptance

```bash
make test-godot-some SUITES="test/squad test/tactical test/menu"
make test-squad-match
make test-decisions
python3 scripts/check_demos.py
python3 scripts/check_demos.py --self-test
python3 scripts/check_translations_game.py
make test-locale-screen
make lint-modules
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

From `make menu`, open the tactical card in XCOM mode, and play a match in
English and in PT-BR; press M and play a few turns of Advance Wars. Does
it read as one game with two modes? Is the hit chance shown before every
shot, and its reason readable? With the decision view on, can you say
before the enemy acts which option it will take? Does it ever seem to know
where an unseen piece is?

How invariant 13 is met: step 4 -- every option the enemy weighed, with
its score and hit chance, on the board before it acts; `check_demos.py`
holds that the overlay is populated, and the seeing stays the person's.
