# Review: wave/61-ai-steering

One fresh context reviewed it at its first commit (e229386), in a worktree
of its own. It committed nothing; its probes lived outside the tree, every
mutated file was restored byte for byte, `__pycache__` was purged after
each Python mutation, and gdUnit4 and the forbidden-term list were copied
in and removed after.

**Verdict: do not merge yet** -- one high finding and three medium. Nothing
was broken at run time; but one of the three properties T22 asks for could
not fail for two of the four behaviours, a teaching claim was wrong, and
several mutations survived everything.

## What was reviewed

- `CLAUDE.md`, T22, the concept page, the Vector2 page, the vectors'
  README, the whole diff, and all three copies of the maths: GDScript,
  Python and `derive.py`.
- Run, all green: `steering_properties.gd` (100 starts, 0 failures), the
  vectors (6 files, 33 samples), gdUnit `steering_test.gd` (11), Python
  (303), `demo_overlays.gd` and `menu_walk.gd` (9 examples each; the only
  `SCRIPT ERROR`s the overlays' own planted crash), every static gate,
  `make lint-docs-freshness`. `derive.py` rerun into a temporary folder:
  the six files byte-identical.
- Mutations on both sides, each run against the properties, both vector
  runners, gdUnit and Python. Survivors: seek's clamp removed (in either
  language), arrive's default `time_to_target` 0.1 to 0.11, avoid's tie
  `<` to `<=`, Python's head-on side flipped; and the infinity guard was
  held by gdUnit alone. Re-deriving with small formula changes showed 1e-3
  is tight enough: 0.11 moves the arrive vector by 4.1e-2.

## Findings

1. *high* -- the third property could not fail for seek or pursue. Every
   vehicle had top speed 10 and force 20, so desired minus velocity never
   exceeded 20 and seek's clamp never fired; avoid always returns exactly
   the limit. Only arrive was being tested. The planted `Unclamped` checked
   the checker, not the behaviours.
2. *medium* -- the concept page blamed the stall in front of an obstacle on
   the line on the weighted sum. It was avoid's: pushing off the clamped
   end of its stretch points straight back. An avoid keeping only the
   sideways part, at the same weights, went round. Its header said
   "sideways"; the vectors showed mostly back.
3. *medium* -- the infinity guard missed offsets too large for 32 bits:
   `direction_to` towards (1e20, 0) gave zero, seek at (1e30, -1e30) braked,
   and Python, in 64 bits, disagreed. The property passed because it only
   measured the force's length.
4. *medium* -- rules pinned by nothing: Python's head-on side, the tie
   between equally near obstacles, the library's default `time_to_target`
   (both runners passed their own 0.1), and a Python "planted" test that
   only exercised `math.isclose`.
5. *low* -- arrive is not seek outside its radius: its `time_to_target`
   asks ten times as hard.
6. *low* -- numbers: `normalized()` warns on an infinite vector (the silent
   case is the overflow); arrive's last speed is 1e-11 in Python but up to
   1.2e-4 in GDScript; "300 starts" is the Python measure.
7. *low* -- `time_to_target` 0, or an infinite force or weight, gave NaN.
8. *low* -- `derive.py` is independent of the code, not of its author.
9. *low* -- the demo's overlay carried only the force's length; pursue's
   "to go" measured to the quarry, not the guess it steers at.
10. *low* -- one comment paraphrased its line.

## What was done about them

Fixed on this branch, and the fix was reviewed again before the merge.

1. The third property now draws each vehicle's top speed and force, most
   with a force under twice the speed, and asks from rest that seek,
   arrive and pursue push towards targets at 1e30 and infinity; a seek
   aimed backwards is planted and refused. The seek vector's vehicle has
   force 8, so its clamp shapes the turn. Seek's clamp removed now fails
   the properties (217), gdUnit and Python (9).
2. Avoid pushes only sideways, to the side of the line the centre is not
   on, in all three copies. The tie vector became `seek-and-avoid-head-on`:
   it turns left and goes round, 2.52 from a centre of radius 2.5. The
   concept page tells the story as it happened, wrong draft included.
3. `direction_to` divides a finite offset by its larger part before
   normalising, in all three copies; `clamped` keeps an infinite force's
   direction. The 1e20 case is a gdUnit test, and the overflow mutation
   fails the properties (300) and gdUnit.
4. Both runners leave an absent field to the library's default, so 0.11
   now fails the vectors (6) and gdUnit; Python tests the head-on side and
   the tie (the first listed wins), gdUnit the tie; the planted Python test
   runs the comparison the real test runs.
5. The header and the page say so.
6. The page and the Vector2 page say what was measured; the GDScript
   vectors' worst difference is now 9.4e-6 on one coordinate.
7. `time_to_target` is never under a millisecond; an infinite force clamps
   along its direction; the weight's contract is stated.
8. The vectors' README says it, plainly.
9. The overlay carries the push's direction and the point steered at; for
   pursue, the guess, and "to go" is measured to it.
10. Rewritten.

**The second look.** The same reviewer re-ran everything at acb9ff9 on a
fresh worktree: properties, vectors (worst 9.36e-6), gdUnit 16, Python 13,
both example walks, every gate, `derive.py` byte-identical. All ten
fixed. The sideways avoid clears the head-on obstacle (it used to stall)
and, in the demo's arena over 300 random targets, grazes obstacles 5 times
instead of 13, never deeper than 0.002. One more, *low*:

- 11. A sideways-only avoid cannot brake, so a look-ahead too short to
  swerve in lets the vehicle cut into the obstacle: with radius 5 and a
  look-ahead of 2, 1.3 deep; with 4 or more, not at all. Docs only: both
  avoid headers now say the look-ahead must be long enough to swerve in,
  with that measurement.
