# Review: wave/64-the-racing-demo

One fresh context reviewed it at `3676228`, with no permission to edit,
commit or run `make check`, `make check-affected` or `make test-godot`
while `make check` was running beside it. Its probes lived under the job's
scratch directory; two that had to run under `godot/test/demo_racing/`
were deleted before it finished.

**Verdict: do not merge yet.** T23 promises that a level is faster because
of its three knobs "or the script fails", and five cheats got through
`racing_does_not_cheat.gd` with no finding. The physics, the speed profile
and the ladder held.

## What was reviewed

- `CLAUDE.md`, T23 with its "Done in wave 64" section, the T23 part of
  `docs/concepts/racing-ai.md`, and the whole diff: `godot/demos/racing/*`,
  `godot/test/demo_racing/*`, the Makefile, the menu card, the overlay
  list, the module manifests and the README.
- Run: both racing scripts, the readability, demo, module, tier and
  acceptance lints, and probes -- five cheats against a copy of
  `cheat_findings`, and re-measurements of lap times, lookahead, wander
  and lap counting.

## Findings

Each is followed by what was done about it.

1. **Confirmed: rule 2 checked only what the car reported.** A car
   subclass with 1.5 times the engine, and a driver adding 5 cm to the
   car's position every frame (about 3 s a lap), both passed. *Fixed* in
   `daf7c2d` by replaying every frame on a fresh car, and a car must be a
   plain `RacingCar`; top speed and grip are measured from where the car
   was to where it is, not read off it. The replay was later replaced by
   the honest twin (see the second review).
2. **Confirmed: rule 1 ran once, before the first step.** A driver that
   swapped `car.physics` for a stronger copy after a second passed.
   *Fixed*: rule 1 runs on every frame, against the race's physics and
   against the fields it began with.
3. **Confirmed: rule 4 trusted the index the driver reported.** *Fixed*:
   the check recomputes from the line sample the race handed the driver,
   read before the step.
4. **Confirmed: the turn was never checked, only the aim.** A driver that
   reported its honest aim and steered at a point twice as far passed.
   *Fixed*: first by recomputing the turn as pure pursuit of the reported
   aim, then by the twin, whose turn every frame must equal.
5. **Confirmed: "wander past 1.5 metres puts the car on the grass" was
   wrong.** It does from about a metre; easy's 2 m spends about one frame
   in seventeen there, some 0.8 s a lap. *Fixed*: the comment gives the
   measurement and says easy running wide is meant.
6. **Confirmed: "a car that cuts across the grass gains nothing it did not
   drive" was false.** A 60 m lookahead was credited about 41 m a lap it
   did not drive; the grass's speed cap is what keeps that from paying.
   *Fixed*: the comment says so.
7. **Confirmed: the card called the braking bar red.** It is cyan, and red
   is the line's slow colour. *Fixed*.
8. **Plausible: the racing line's origin and the aim's drawing disagreed
   between the code and `racing-ai.md`.** *Fixed*: both say the offsets
   came from a one-off search that is not in the kit and cannot be rerun,
   and that the aim is drawn as a line to the point.
9. **Plausible: `_turn_towards` read as seek doing more than it does.**
   *Fixed*: `pursuit_turn`'s doc comment says seek is asked only for the
   velocity it wants, and why its clamp never bites.
10. **Plausible: a top-speed clamp in `RacingCar.step` could never act.**
    *Fixed*: removed.
11. **Plausible: a race that did not finish went green on fewer frames.**
    *Fixed*: a car that has not finished its laps is a finding.

The review also confirmed what held: the sqrt(margin) argument (every term
is linear in the margin, and capping before or after the backward pass
gives the same profile), the backward pass from the bottleneck, the
curvature and left/right conventions, grip on the frame speed changes, lap
counting that cannot double-count, the ladder (easy's knobs at 0.97 lap in
35.88 s, hard's at 0.75 in 38.68 s, so the margin orders it), and the
measured lap times (39.59 / 36.60 / 35.10 s).

## Found while fixing it

- Turning each rule off once, the first version of the ladder's
  out-of-order plant was refused by the wrong rule (the gap rule), and the
  fixed cheat check's "plans from further down the line" plant was refused
  by the aim rule, not the index. Each plant now has to be refused by a
  finding naming its own rule, the second was split into a speed lie and
  an aim wider than the wander, and a plant past the top speed was added,
  which had none. Twelve rules mutated off; twelve went red. (The second
review replaced most of these rules; see below.)

## The second review, of the fixes

A second fresh context reviewed `daf7c2d` under the same limits; its two
probes under `godot/test/demo_racing/` were deleted before it finished.
**Verdict: do not merge yet** -- the fix closed the five cheats, and the
gate still trusted three things a driver can write to.

1. **Confirmed: the track was taken as the truth.** Raising
   `full_grip_limit` by a tenth made easy 2.9 s a lap faster with no
   finding (caught only when the cheater raced after the others had
   decided); moving the nearest centre sample onto the car kept it off the
   grass, 0.8 s a lap.
2. **Confirmed: the race's books were never checked.** A driver adding
   30 cm a frame to `race.covered` lapped in 24.2 s instead of 39.6 s.
3. **Confirmed: the knobs could move mid-race.** Rules 3 and 4 read the
   driver's own `level` and `used`; a driver that set its margin to 1.0
   for its laps and forged `used` was 0.4 s a lap faster.
4. **Arguably within the rules: wander was an "at most" budget.** Aiming
   exactly at the lookahead point made easy 0.8 s a lap faster with no
   finding. Not a way past the line, but the knob did not bind.
5. **Checked, no hole: the float tolerance.** A push under it every frame
   was caught, and worth about 0.01 s a lap anyway.
6. **Confirmed true**: the cyan bar, the grass numbers (1394 of 23,756
   frames, one in 17.0; normal and hard never off), the lap-counting
   wording, the racing line's origin.
7. **Confirmed: the task file and STATUS counted ten plants; there were
   twelve.**

*Done about them*: the replay and the recomputed decision were replaced by
one rule that trusts nothing the race under test holds. The script builds
its own race from what it entered -- each level's numbers, copied before
the start, its seed, and the physics as it began -- with plain drivers,
steps it alongside, and every car, decision and lap record must equal the
twin's on every frame. That closes 1-3 and makes 4 bind exactly: a driver
indistinguishable from the honest one is the honest one. The fields are
compared in causal order (decision, car, books) so the first that differs
names what was done. Plants were added for the track, the books, a level
changed and reported, a level changed and forged, and a driver that never
wanders: seventeen in all, and the counts in the task and STATUS now say
so. Fifteen mutations of the rules and the twin's fields went red; one
survived at first (the check's copy of the entered levels), because no
plant changed the very level it was entered with -- the crooked drivers
are now entered with their own level, and a "knob" plant changes it.

## What was done about them

Commits `daf7c2d` (the first review) and the one after it (the second).
Every finding of both reviews is fixed as described above; finding 4 of
the second, arguably within the rules, is fixed too, since the twin makes
the wander exact. Both racing gates, the racing suite, the overlay and
menu walks and the lints were rerun green on the final tree; `make
check-affected` (all of `make check`, the Makefile having changed) was
green at `3676228` and is rerun before the merge.
