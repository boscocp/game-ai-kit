# The maze: Pac-Man, and ghosts by the arcade's rules

<!-- doc-meta
half_life: practice
verified_on: 2026-10-29
tier: 1
source: https://www.gamedeveloper.com/design/the-pac-man-dossier
invalidated_if: spec/maze/rules.json or spec/maze/maze.json changes, or a ghost's choice stops being the Dossier's
teaches: none
-->

> T97's example. A small maze, four pellets, you as Pac-Man and Blinky
> deciding the way the arcade's ghosts decide. T98 solves it as an MDP in
> Python; this page is the game that MDP plays.

## What it is

`make demo-maze`, or the menu's Pac-Man card. 52 floor cells, no dead end,
four pellets in the corners; one ghost, Blinky, and Pinky with G. The game
waits for an arrow (or the stick, or the D-pad), then runs at four steps a
second, one cell a step for everyone. Pac-Man keeps running the way he
faces until a wall stops him, and a direction pressed early is taken at the
first cell where it is open, as in the arcade. Eat all four to win; one
catch ends the game. P pauses, space plays one step, R starts again with
the next seed.

## The ghosts' rules, from the Dossier

Jamey Pittman's *Pac-Man Dossier* (Game Developer, 2009; opened on
2026-10-26 and again on 2026-10-29) is the reading of the arcade's code
everybody else cites. What this game takes from it, in its words:

- **Modes.** "Ghosts have three mutually-exclusive modes of behavior they
  can be in during play: chase, scatter, and frightened." Level one
  alternates scatter 7 s, chase 20 s, scatter 7, chase 20, scatter 5,
  chase 20, scatter 5, then chase for good. Here each of those seconds is
  two steps.
- **Forced reversal.** "Ghosts are forced to reverse direction by the
  system anytime the mode changes" between chase and scatter (and into
  frightened). On the step a mode changes, every ghost's next move is back
  the way it came, chosen by nobody.
- **No reversing otherwise.** "In all three modes of behavior, the ghosts
  are prohibited from reversing their direction of travel."
- **The choice.** At an intersection a ghost "looks one tile beyond the
  intersection in each of the three remaining directions", and "whichever
  direction's test tile has the shortest distance to the target becomes
  the direction the ghost will take"; on a tie, "the ghost prefers
  directions in this order: up, left, down, right". Distance is the
  straight line; both languages compare it squared, a whole number.
- **The target is the personality.** Blinky in chase uses "Pac-Man's
  current tile as his target". Pinky aims "four tiles away from Pac-Man in
  the direction Pac-Man is currently moving" -- and when Pac-Man moves up,
  an overflow bug in the arcade's code adds four to the left as well,
  which this game keeps. In scatter each heads for a fixed tile outside
  the walls, its home corner (Blinky top right, Pinky top left), so it
  circles the block nearest it.
- **Collisions.** "Any time Pac-Man occupies the same tile as a ghost, he
  is considered to have collided with that ghost." The Dossier describes a
  rare pass-through, a swap within one frame; here Pac-Man moves first, so
  a swap would mean walking onto the ghost's cell, which is a catch.

### What is not the arcade's

Written in `spec/maze/rules.json`'s "about" too, each on purpose:

- **One cell a step for everyone.** The arcade runs Pac-Man at 80% and the
  ghosts at 75% on level one; equal speeds keep T98's model a function of
  positions only.
- **A ghost chooses on the cell it is on**, at the end of a step, rather
  than one tile ahead -- so the choice is on the screen before the move.
- **No energizers, so no frightened mode;** no ghost house, tunnel, fruit
  or lives. Four plain pellets keep T98's state space near 320,000.
  Frightened mode -- the Dossier's random turns -- is the decision left to
  the owner (below).
- **The imprecise ghost.** In chase, at a fork of two or more ways, a
  uniform draw below `precision` (0.8) keeps the Dossier's way; otherwise a
  second draw picks any way evenly, the Dossier's included. So a way is
  taken with probability

      precision x [it is the Dossier's way] + (1 - precision) / ways

  (`gameaikit.maze.rules.chances`). That is the chance an MDP needs, and
  making it a rule of the game makes T98's transition model exact rather
  than an estimate of a deterministic ghost.

## One game, two languages

T98's value iteration runs on the Python rules and its policy is looked up
in Godot, so a move must land in the same place in both.
`python/gameaikit/maze/` and `godot/game/maze/` read byte-for-byte copies of
`spec/maze/maze.json` and `rules.json` (ADR 0007), and draw from the same
generator, Marsaglia's 32-bit xorshift, written out in each. The vectors in
`spec/vectors/maze/` are a seed and Pac-Man's moves in, every step's
positions, choices and targets out, derived by a third copy that imports
nothing (`derive.py`). The generator is the one `ai_adversarial` already
has, copied rather than used so that the maze does not appear to use
adversarial search.

Held by `python3 -m unittest discover -s python/tests -t python -p
"test_maze*.py"` (the rules one by one; over 200 seeded games, that no
ghost reverses outside a mode change, that every mode change reverses,
that no ghost enters a wall, that a seeded game replays; the chances
against 20,000 draws; the vectors; the copies) and `make
test-maze-vectors` (the vectors against the Godot game), with
`make test-godot-some SUITES="test/maze"` holding the Godot rules to the
same properties.

## How invariant 13 is met

With V (on by default), each ghost draws its target tile -- a crossed
square in its colour, with a dashed line to it -- and every way it may take
as a line to the cell beyond, with that cell's straight-line distance to
the target written on it. The way it chose is white before the ghost
moves; a way the dice picked is orange, with a die beside the ghost. The
panel says the same in words: the mode, the target and why, each way with
its distance, and how it chose -- the roll against the precision, and the
second draw.

## Decisions for the owner

- **Frightened mode** is not in the game, since four plain pellets have no
  energizer. Adding one energizer would bring in the Dossier's random turns
  and a third mode, and multiply T98's states.
- **The generator exists twice** (`ai_adversarial`'s `Xorshift` and the
  maze's `MazeDice`). Moving one copy into `ai_core` would let both use it,
  and is ADR 0021's to decide.
- **The schedule's scale**, two steps a second of the Dossier's, and the
  precision, 0.8, are numbers in `rules.json`, chosen rather than measured.
