# Review: wave/104-a-small-pac-man-maze

T97: a small Pac-Man maze, `make demo-maze`, with ghosts that follow
Pittman's *Pac-Man Dossier*, one rule of the kit's own (the imprecise
ghost, for T98's MDP), a Python twin held to the game by vectors, and the
ghosts' decisions drawn before they move.

A fresh context reviewed PR #45 at head 14e9423.

**Verdict: approve once two should-fixes are applied; no blockers.** Both
should-fixes and the nits were applied on the branch.

## What was reviewed

The diff against main:

- `godot/game/maze/` (`MazeRules`, `MazeGhost`, `MazeGame`, `MazeDice`,
  `MazePerson`, `MazeView`, `MazePanel`, the scene) and its suite;
- `spec/maze/` and its two copies, `python/gameaikit/maze/`, its tests;
- `spec/vectors/maze/`, its `derive.py` and README, and both runners;
- the menu card, `check_demos`, `demo_overlays`, `locale_screen`, the
  pt-BR table, `modules/maze.json` and `menu`'s dependency, `games.json`
  and the regenerated catalogue;
- `docs/godot/maze.md`, the task file, the STATUS row and the screenshots.

## What the reviewer found sound

- **Dossier fidelity, checked against the text.** Reversal only on a mode
  change; the tie order up, left, down, right; level one's schedule,
  scatter 7, chase 20, scatter 7, chase 20, scatter 5, chase 20, scatter 5,
  then chase; Pinky four cells ahead with the up bug; the corners outside
  the walls.
- **The departures are named, and none weakens the lesson.** Equal
  speeds, the choice on the ghost's own cell, no energizer, house, tunnel
  or lives.
- `derive.py` regenerates the committed vectors byte for byte.
- Godot mutants caught: Pinky's bug off, the keep region flipped, the
  dice's index changed, no forced reversal, xorshift's shift 5 made 6.
  Python mutants caught: the `chances` formula, the second draw, a
  precision of 0.75 in `choose` only, the reversal one step late.
- `chances` sums to 1; over 60,000 draws the ways came out 0.868, 0.066,
  0.067 against 0.867, 0.067, 0.067.
- `MazeDice` is bit for bit `Xorshift`, and copying it is the right call.
- The menu-to-maze wiring is the other games'; the screenshots are
  legible and pt-BR fits.

## Findings

1. **No vector held the tie order (should-fix).** None of the 157
   snapshots was a tie, though ties happen at about 2% of forks in play
   (over 2,000 games: up/left 207, down/right 89, up/right 67, left/down
   48, left/right 24, up/down 3). A mutant giving `MazeGhost` the order
   left, up, down, right survived `make test-maze-vectors` and `test/maze`:
   the unit tests covered only down against right, and the Python mutant
   died only through an unrelated test -- one inside `nearest` would pass.
2. **T98's state is not Markov for this game (should-fix).** The mode and
   the forced reversal depend on the step count; the reviewer found 621
   pairs of equal T98 states whose committed moves differed for no reason
   but a pending reversal. Without reversals and dice the committed move
   is determined by T98's state. The step count in the state, 169 values,
   gives about 29 million states, not workable in pure Python on tier 1.
   "Exact" was claimed in `maze_ghost.gd`, `docs/godot/maze.md` and the
   task file.
3. **Nits.**
   - Cruise Elroy was not named as a departure (at 20 dots left Blinky
     speeds up and keeps chasing through scatter; with four pellets it
     would hold from step 0), nor the arcade's red zones.
   - "Exact" probabilities: `index` is `next() % count` over 1 to 2^32 - 1
     and `uniform` never returns 0, a bias of about 2^-32.
   - The panel wrote a roll with two decimals, so one in [0.795, 0.8) read
     "dice 0.80, under 0.80".
   - After a catch the panel still listed the ghost's pending decision.
   - The dice's index taken from the high bits, and the keep region
     flipped, were each caught by a single vector and no suite test.
   - The manual check did not ask to watch a tie, a dice turn, or the
     panel after a catch.

## What was done about them

1. Two vectors, `ties-go-up-before-left` and `ties-go-down-before-right`,
   from `derive.py`, which now records every tie the order decided and
   refuses a case that does not show the ties its name says (up/left,
   left/down, up/right; down/right, left/right), each with a dice turn too
   (8 files, 239 snapshots; the six earlier files are unchanged byte for
   byte). `nearest` now asks the tie order itself, in both languages,
   rather than trusting the order the ways were listed in, and a unit
   test in each language ties up with left and lists the ways backwards.
   The order mutant now dies in each language's tests and in the vectors,
   both in the constant and inside `nearest` alone.
2. "Exact" is qualified in the three places: exact for a ghost's turn,
   except for the timed schedule. T98's task file states the problem and
   lists the owner's options: (a) the step count, capped at 168, in the
   state, measured first; (b) solving the stationary regime, chase for
   ever as after step 168, with the demo offering that schedule; (c) a
   stated random mode change. The owner chose (b) on 2026-10-29, and the
   task file writes it as decided: T98 solves "chase for ever", about
   160,000 states and exact for that regime, the demo gains a mode with
   that schedule, and the arcade schedule stays in the normal game. It also
   says plainly that the ghost's committed move, drawn before Pac-Man
   moves, does not depend on his action, so a policy that does not see it
   is valid, only less informed than the overlay.
3. The nits:
   - Cruise Elroy and the red zones are named in `rules.json`'s "about"
     (and its two copies) and in `docs/godot/maze.md`.
   - The generator's 2^-32 bias is stated in the rules, `chances`'
     docstring and the page.
   - The roll is shown with three decimals.
   - Over, the panel lists no ghost's decision, as the view draws none.
   - A unit test in each language replays one stream of draws against a
     mirror and checks every keep and every second draw; the high-bits
     index and the flipped keep region now die in the suites alone too.
     Writing it found that fresh small seeds never reach the second draw
     (a small seed's first xorshift draw is small), so the test uses one
     stream and requires more than 30 dice turns; the page names the
     consequence in play -- the first chase fork of a game almost always
     keeps.
   - The manual check asks for a tie, a dice turn and the panel after a
     catch.

The reviewer's runs, at 14e9423: 28 maze Python tests; 6 vectors, 157
snapshots; `test/maze` 15 of 15; the lints and the screen checks, all 0.

## Decisions for the owner, with the reviewer's opinion

Decided by the owner, 2026-10-29: as recommended. The dice
stay copied until T109 moves one generator into `ai_core`; the
generator is not warmed up.

- **No frightened mode** (no energizer): agree.
- **The dice copied** as `MazeDice` rather than used from `ai_adversarial`:
  agree.
- **The schedule at two steps a second, and the precision 0.8**:
  reasonable.
- **T98's timer**: real. The owner chose the stationary regime, chase for
  ever (2026-10-29), written in T98's task file.

## Manual check

Done by the owner, 2026-10-29: `make demo-maze` plays well, nothing to
adjust.
