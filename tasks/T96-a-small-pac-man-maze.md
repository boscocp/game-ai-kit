# T96 — A small Pac-Man maze, with ghosts that follow the arcade's rules

Size: M · Prereqs: none · Files: `godot/game/maze/`, `godot/test/maze/`, `modules/maze.json`, `spec/maze/`, `spec/vectors/maze/`, `python/gameaikit/maze/`, `python/tests/`, `godot/menu/catalogue.json`, `godot/locale/maze.csv`, `scripts/check_demos.py`, `docs/godot/`, `Makefile`

## Goal

The owner, 2026-10-26, answering T73's question 6: the MDP gets a small
**Pac-Man-style maze demo** (one or few ghosts), with value iteration in
Python and the policy shipped (invariant 6). This task is the game; T97 is
the MDP that plays it.

The ghosts are an AI lesson in themselves, and a famous one. Pittman's
*Pac-Man Dossier*, opened on 2026-10-26 [Pittman 2009]: ghosts are in one
of three modes -- chase, scatter, frightened; at an intersection a ghost
discards the reverse direction, measures from the tile beyond each exit to
its **target tile**, and takes the shortest, ties broken in the order "up,
left, down, right"; a mode change from chase or scatter forces a reversal;
frightened ghosts "use a pseudo-random number generator (PRNG) to pick a
way to turn at each intersection". Each ghost's personality is only its
target tile.

## Decisions written down first (the owner confirms in review)

- **Small on purpose**: a maze of about 50 walkable cells, a handful of
  pellets (four, so T97's state space stays small -- see there), one
  ghost by default and a second as an option; grid movement, one cell per
  step, a fixed clock. Not the arcade's full board.
- **The ghost follows the Dossier's rules as written**, with Blinky's
  target in chase -- "Pac-Man's current tile as his target" -- and his
  home corner in scatter, and one addition for T97, written in the rules
  file and on screen: in chase, at
  each intersection the ghost takes the Dossier's choice with a fixed
  probability and a random legal exit otherwise -- an imprecise ghost. Its
  reason: an MDP needs chance in the world, and stating it as a rule of the
  game makes T97's model exact rather than an approximation.
- **The person plays Pac-Man**; T97 adds the MDP as a controller and C
  cycles between them, as in the tactical game.
- **A Python twin of the rules**, held by vectors (a seed and inputs in,
  the positions every step out), because T97's value iteration runs on the
  Python rules and its policy must mean the same thing in Godot.

## Steps

1. Read the Dossier's sections on ghost movement and modes; write the
   rules, their numbers in `spec/maze/rules.json`, and the maze in
   `spec/maze/maze.json`.
2. `python/gameaikit/maze/` and `godot/game/maze/`, the same rules; vectors
   in `spec/vectors/maze/`; a property check over seeded games (no ghost
   reverses outside a mode change, a ghost never enters a wall, a seeded
   game replays).
3. The scene: walls, pellets, Pac-Man, the ghost, shapes only (no art
   needed; open art could follow under ADR 0020's rule, as T88).
4. `make demo-maze`; a menu card naming Pac-Man; `check_demos.py`;
   `godot/locale/maze.csv`.

## Acceptance

```bash
python3 -m unittest discover -s python/tests -t python -p "test_maze*.py"
make test-maze-vectors
make test-godot-some SUITES="test/maze"
python3 scripts/check_demos.py
python3 scripts/check_translations_game.py
make test-locale-screen
make lint-modules
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

Play `make demo-maze`: does the ghost feel like Blinky -- on your tail in
chase, off to its corner in scatter? With the ghost's view on, do its
target tile and its choice at each intersection match what it then does?

How invariant 13 is met: with V, the ghost's target tile marked, and at
each intersection the distances from each exit to the target written on
the exits, the chosen one highlighted before the ghost turns -- and, on an
imprecise turn, the dice shown as such.

References, opened on 2026-10-26: Pittman, J. "The Pac-Man Dossier."
Game Developer, 2009 <https://www.gamedeveloper.com/design/the-pac-man-dossier>.
