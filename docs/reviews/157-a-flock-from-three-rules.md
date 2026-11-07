# Review: wave/157-a-flock-from-three-rules

T150 adds Reynolds' boids to `ai_steering`: `SeparationBehaviour`,
`AlignmentBehaviour`, `CohesionBehaviour` and `Flock`. It also adds a
Python twin, five vectors from an import-free `derive.py`, and `make
demo-flocking`, a hundred seeded boids found by a uniform grid, with each
rule switchable and one boid's decision drawn.

A fresh context reviewed PR #112 at head c1fec22. **Verdict: approve
after the three shoulds; no blocker. The five nits were done too.**

## What was reviewed

- The PR title and body, the task file and its proposed decisions.
- The three rules and `Flock`, against the Python twin and `derive.py`.
- The flock vectors, their runner and checker, and the planted cases in
  `flock_test.gd` and `test_steering_flock.py`.
- The demo: `FlockWorld`, `NeighbourGrid`, `FlockingDemo`, its overlay, its
  card and its suite.
- The Flocking section of `docs/concepts/steering.md`, `ai_steering.md` and
  its pt-BR, the glossary and the vectors README.
- The claims on the page, re-measured on the demo's world.

## Findings

1. **Should.** `flock_world.gd`'s header and the page both say "cohesion
   slows the flock". The slowdown comes from `time_to_target` = 1 s, not
   from the rules. Shiffman steers once a frame. Measured at step 600:
   with 1 s the speed is 76 and the headings agree at 0.70; with 1/60 s
   the speed is 119 of 120, agreement is 0.84 and the nearest-other
   distance is 16.0. Coordinator's decision: build `FlockWorld`'s flock
   with a time of `DT`, re-measure the table and the four-boids prose, and
   say that the vectors keep 1.0.
2. **Should.** "a few hundred" distances a step, in `neighbour_grid.gd` and
   under "Who are my neighbours?", is not what the grid does once the
   boids have flocked. Give the measured figure.
3. **Should.** No committed command produces the table under "What each
   rule was doing". Add one and name it under the table.
4. **Nit.** The vectors README, `flock_vector.gd` and
   `test_steering_flock.py` should say which test pins which self-skip:
   the steps vector pins alignment's, and the self-only gdUnit test pins
   separation's and cohesion's.
5. **Nit.** A click while paused placed an obstacle that did not show
   until the next frame. The click branch has no `queue_redraw()`.
6. **Nit.** The watched boid's forces were drawn from the positions after
   the step those forces moved it by. Draw them from the snapshot instead,
   or reword the claim.
7. **Nit.** Alignment's docstring folded two reasons into one sentence.
   Scaling to top speed is what keeps the flock flying. Unit headings are
   what make a slow neighbour weigh as much as a fast one.
8. **Nit.** `Flock.weights` is set at construction because
   `check_no_training.py`'s N3 net refuses any assignment to `.weights`.
   Say so where it is declared, so nobody turns it back into an
   assignment.

## What was done about them

1. `FlockWorld` now builds its flock with `TIME_TO_TARGET = DT`, and its
   header says why. The table was re-measured: with nothing off, 16.0 /
   119 / 0.84. The page now has a paragraph, "The time to target matters
   as much as the rules", that gives the 1 s numbers (76 / 0.70 / 14.8)
   and blames the time constant. The worked case, `four-boids-flying` and
   the vectors README all say the vectors keep the library's default
   second, and that this is why the four boids settle at half speed. The
   menu card's "watch" line was updated too: without cohesion the flocks
   now loosen and line up (0.95) rather than spread.
2. `NeighbourGrid` now counts the distances it measures. The page and the
   header give the measured figures: 1,622 a step at the start, 1,836
   ten seconds in, and 2,944 with separation off. Even at the start it
   was never "a few hundred".
3. `make measure-flocking` runs `godot/test/demo_flocking/flocking_table.gd`
   through `scripts/godot_checked.py` and prints the table, with
   neighbours and distances a step added. It is seeded, it is a
   measurement and not a gate, and it is not in `make check`. The page
   names it above the table.
4. Done in all three places. The reason is now stated too: counting itself
   moves cohesion's centre but not the direction to it, and separation has
   no direction to push from itself.
5. The click branch calls `queue_redraw()`.
6. `FlockWorld.decided_at` keeps the snapshot. The watched boid's circles,
   lines, centre and arrows are drawn from it, and the demo's header says
   so.
7. Split in `alignment_behaviour.gd` and in `flocking.py`.
8. Noted in `flock.gd` and in `Flock`'s docstring in `flocking.py`.
