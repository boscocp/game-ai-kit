# Review: wave/73-racing-in-3d

A fresh context reviewed the wave at `a09183e`, rebased onto main: T54 --
a 3D car on ray-cast wheels, tracks with a racing line found by an elastic
band, a driver that is an agent on its own view, a grip test pad,
`PidController` and `HeatLine` in `ai_steering` with Python twins and
vectors, three levels, the racing gates and the demo. It was not allowed
to edit the worktree. It ran the readability and modules gates, the Python
tests, the racing vectors, car and does-not-cheat gates, the gdUnit suites
of `racing3d` and `ai_steering`, and the other lints; it did not run the
ladder or effects gates. It ran 49 one-line mutations of the Python twins
against the vectors, and probed the grip pad with nine cars.

**Verdict: fix before merge.** The physics, the driver's arithmetic and the
twins were sound on every path the gates exercise. But one check could
never fail, the vectors' runner went green on a script error, and the
vectors and the portability test pinned much less than the docs said.

## What was reviewed

- `CLAUDE.md`, the T54 task and its prereqs, `docs/godot/racing3d.md`,
  `docs/godot/3d-headless.md`, and `git diff main...HEAD`.
- Units and signs end to end; state between races; anything that favours
  a grid slot or a level beyond its knobs.
- Every check, for a planted case it truly rejects.
- The twins, line by line, and by mutation.
- That `ai_steering` only gained.

## Findings

Each one is followed by what was done about it.

1. **"No tyre past its grip" could never fail** (high): the car reported
   the force clamped to its limit, and both gates compared it with that
   limit. *Fixed*: the friction circle is its own method and the car
   reports the force it applied; a planted car whose circle lets the force
   through is named by the check.
2. **The vectors' runner went green on a script error** (medium), the trap
   `CLAUDE.md` names: a vector missing a decided key printed SCRIPT ERROR
   and "0 failure(s)". *Fixed*: the runner counts engine errors and fails
   on any, a vector missing a field or with too short a view is refused,
   and each is planted.
3. **25 of 49 mutations of the twins survived the vectors** (medium): a
   rival alongside, the heat line's edges, one rival at a time, the
   traffic speed cap, the PID's integral limits, the steering cap, points
   behind the car, room along the line, the pedal toggle. *Fixed*: 21
   vectors, 35 in all, each naming the rule it pins, and the four missing
   PID and heat tests ported to Python. 0 of 50 mutations survive.
4. **The portability test was a deny-list over five files** (medium).
   *Fixed*: an allow-list of the classes the decision may name, with the
   engine, loading, the scene tree, input, map positions and every
   track's title and file -- read from the tracks at test time -- refused,
   each planted. The docs now say the untuned second track in the ladder
   is the real defence, since a reading cannot see a number tuned to one
   track.
5. **The honest twin shares the race's code** (medium-low), so an advantage
   written there replays in it. *Fixed*: each frame, each driver's grip,
   braking and slip steer must equal its own car's measurement; a tenth
   planted cheat, a driver on more grip, is refused by it.
6. **What a car measured depended on its pad slot** (low, about 2e-6).
   *Fixed*: every car measures from one spot. The ladder held (one time
   moved by 0.01 s); the four-car heat-line race moved (changes of side 75
   against 22, was 74 against 40), and the docs now call those race
   numbers fragile.
7. **The error counter had no planted case** (low). *Fixed*: each racing
   script first pushes a marked error and requires it counted once.
8. **NaN read as equal** (low). *Fixed*: every limit is written so NaN
   fails it.
9. **Two twin edges differed** (low): a clamp with its bounds crossed, and
   a view of fewer than five points. *Fixed* on both sides.
10. **Readability** (low): single-letter names in the twin and its
    `derive.py`, a comment saying below for above, and a braking check
    silent on a car that never reached its speed. *Fixed*.

## What was done about them

All of it is in `895dd2f` to `5cab977`, after `a09183e`. The racing gates
pass: the car (with its planted car past its grip named), 35 vectors, the
does-not-cheat race (6198 frames, ten planted cheats refused), the ladder
(loop 50.61 / 48.43 / 47.20 s, kidney 43.90 / 41.86 / 40.41 s) and the
effects; the Python tests, the steering and racing suites, the demo
overlays and every lint pass. `make check-affected BASE=origin/main` runs
on the pull request.

## What the review found sound

The driver's units and signs; the engine's power and top speed, the
brake's fade, the damping, and weight transfer from the centre of mass;
a new race and new drivers each time; the ladder's equal seeds and grid
spot; rules 1 and 3 of the no-cheat race and the twin's exact replay;
`PidController` and `HeatLine` line for line in both languages; that
`ai_steering` only gained; and the module and Makefile wiring.
