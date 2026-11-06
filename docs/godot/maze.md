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
> Python, and C hands Pac-Man to the policy it found; this page is the
> game, and how that policy plays it.

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
  or lives. No Cruise Elroy: in the arcade Blinky speeds up once few dots
  are left (20 on level one) and keeps chasing through scatter, which with
  four pellets would hold from the first step. No red zones, the arcade's
  cells above the ghost house where a ghost may not turn up. Four plain pellets keep T98's state space small:
  82,160 states that the rules allow, measured.
  Frightened mode -- the Dossier's random turns -- stays out, decided by
  the owner (below).
- **The imprecise ghost.** In chase, at a fork of two or more ways, a
  uniform draw below `precision` (0.8) keeps the Dossier's way; otherwise a
  second draw picks any way evenly, the Dossier's included. So a way is
  taken with probability

      precision x [it is the Dossier's way] + (1 - precision) / ways

  (`gameaikit.maze.rules.chances`; exact up to the generator's bias of
  about 2^-32, since a draw is 1 to 2^32 - 1 taken modulo the ways). That
  is the chance an MDP needs, and making it a rule of the game makes T98's
  model of a ghost's turn exact rather than an estimate of a deterministic
  ghost -- exact except for the timed schedule: the mode, and so the forced
  reversal, depend on the step count, which T98's state does not hold.
  The owner chose (2026-10-29) that T98 solves the stationary regime,
  chase for ever, where its state is exact.

## One game, two languages

T98's value iteration runs on the Python rules and its policy is looked up
in Godot, so a move must land in the same place in both.
`python/gameaikit/maze/` and `godot/game/maze/` read byte-for-byte copies of
`spec/maze/maze.json` and `rules.json` (ADR 0007), and draw from the same
generator, Marsaglia's 32-bit xorshift, written out in each. The vectors in
`spec/vectors/maze/` are a seed and Pac-Man's moves in, every step's
positions, choices and targets out, derived by a third copy that imports
nothing (`derive.py`). The generator is `ai_core`'s `GakXorshift`, and
`gameaikit.core`'s in Python (T109): the maze had its own copy, `MazeDice`,
so as not to appear to use adversarial search, until there was a shared
place to put one.

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

## The MDP plays (T98)

C hands Pac-Man to a policy that value iteration computed in Python
(`python/gameaikit/mdp/`, the concepts in
[`docs/concepts/mdp.md`](../concepts/mdp.md)). The game restarts in the
regime the MDP was solved for -- Blinky alone, chasing for ever, so no
scheduled mode change and no forced reversal (`spec/maze/mdp.json`) -- and
Pac-Man moves at once. C again gives him back to you, in the arcade's
schedule; G does nothing while the MDP plays, since Pinky is not in its
model.

- **The state** is Pac-Man's cell, Blinky's cell and heading, and the
  pellets left: 82,160 that the rules allow (the task's estimate was
  160,000; a ghost's heading must point away from a floor cell behind it,
  and Pac-Man never stands on an uneaten pellet), of which 80,288 can be
  reached from the start. Blinky's next move is chosen
  before Pac-Man's but does not depend on it, so the policy treats it as
  chance, with the rules' `chances`; the overlay shows the move Blinky
  actually committed, which the policy does not see.
- **Solving**, `make solve-maze`: building the model 1.0 s, value
  iteration 60 sweeps in 3.4 s, peak 117 MB, measured on a Ryzen 5 9600X
  in pure Python. Policy iteration finds the same values (within 0.0001)
  in 22 improvements but 1,233 sweeps, 21.6 s; the 2,109 states where the
  two choose differently are all exact ties.
- **Published** to `godot/game/maze/`, beside the game, so an export carries it: `values.json`, each state's value in
  thousandths, and `policy.json`, its move as a letter, both laid out so
  that a state's place is arithmetic (`spec/maze/mdp.json`'s "about").
  `MdpPacMan` reads them from `res://game/maze` and
  looks up; N15 in `check_no_training.py` solves again and fails if they
  differ, and refuses any GDScript that writes them.
- **How it plays**, `PYTHONPATH=python python3 -m gameaikit.mdp.measure`,
  1,000 games from seeds 1 to 1,000 in that regime:
  - the MDP: 1,000 won, 0 caught, 30.5 steps to win;
  - safe greedy (the A\* path to the nearest pellet, never a move onto a
    cell Blinky may reach next step): 1,000 won, 0 caught, 31.9 steps;
  - greedy (the same path, Blinky ignored): 826 won, 174 caught, 30.0
    steps over its wins, 27.0 over all games.

  **Does it ever walk into the ghost? No, and provably.** Blinky alone,
  at Pac-Man's speed, with no dead end, cannot catch a careful player:
  every state has a move with no catch next step, and the 684 states the
  policy reaches from the start include none whose chosen move could end
  in a catch, whatever the dice (`measure.catch_from_start`, held by a
  test). So the safe rule is never caught either, and what value
  iteration adds here is about 1.4 steps a game -- the weighing of
  waiting for Blinky against running past him.

With V on, the MDP's view is drawn under the ghost's: every cell Pac-Man
could stand on is tinted from red (the least any cell is worth now) to
green (the most), for Blinky and the pellets as they are, with the
policy's arrow on it; beside Pac-Man, each of his four moves is written
with its Q-value -- the step's reward plus 0.95 times the value it leads
to, averaged over Blinky's ways -- and the one the policy takes is boxed.
The panel lists the same numbers. Held by `make test-mdp-vectors` (ten
states' values, Q-values and moves from `spec/vectors/mdp/derive.py`, a
second value iteration that imports nothing) and
`make test-godot-some SUITES="test/maze"`, where the policy wins 40 seeded
games and its move is always the lookahead's best.

## Decisions for the owner

- **Where the policy lives** -- decided (owner, 2026-10-29): beside the
  game, in `godot/game/maze/`, as the checkers weights are, so an export
  carries it. The task had said `data/maze/`, outside the project.
- **Frightened mode** is not in the game, since four plain pellets have no
  energizer. Adding one energizer would bring in the Dossier's random turns
  and a third mode, and multiply T98's states. Decided by the owner,
  2026-10-29: as recommended, left out.
- **The generator existed twice** (`ai_adversarial`'s `Xorshift` and the
  maze's `MazeDice`). Moving one copy into `ai_core` would let both use it,
  and is ADR 0021's to decide. Decided by the owner, 2026-10-29: one
  generator in `ai_core`, the same stream bit for bit -- task T109, which
  amended ADR 0021 and is done (wave 122). `spec/vectors/maze/` did not
  change.
- **The schedule's scale**, two steps a second of the Dossier's, and the
  precision, 0.8, are numbers in `rules.json`, chosen rather than measured.
  Decided by the owner, 2026-10-29: as recommended, kept.
- **T98 and the timed schedule** -- decided (owner, 2026-10-29). The mode
  and the forced reversal depend on the step count, which T98's state does
  not hold. T98 solves the stationary regime, chase for ever as after step
  168, and the demo gains a mode with that schedule for the policy to play;
  the arcade schedule stays in the normal game.
- **Small seeds start small.** Xorshift's first draws from a small seed
  are small numbers (seed 1 gives 270369, about 0.00006 of the span), so
  with R's seeds 1, 2, 3... the first chase fork of a game almost always
  keeps the Dossier's way; the dice spread from the second or third draw
  on. Warming the generator up, or seeding from a spread value, would
  change every vector; left as it is, and named here. Decided by the
  owner, 2026-10-29: no warm-up, as recommended.
