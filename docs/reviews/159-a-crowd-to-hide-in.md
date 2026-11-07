# Review: wave/159-a-crowd-to-hide-in

T152 adds a crowd to the infiltration example. The market is a new level
with sixteen civilians in three groups. Each group is a flock from
`ai_steering` (T150), stepped on the walk grid. Walking in step inside a
group weighs a guard's percept down, and sprinting or crouching weighs it
up. The reading becomes a `figure` sign in T115's intruder network. The
branch is stacked on #111 (T115) and #112 (T150) and merges both.

A fresh context reviewed PR #117 at head ec7c623. **Verdict: do not merge
until finding 1 is fixed (one blocker). The rest are four shoulds and four
nits.** The coordinator decided finding 1: take the reviewer's fix.

## What was reviewed

- The PR title and body, the task file and its decisions, and the two
  merges.
- `infiltration_crowd.gd` and `crowd.json`: the flock and the forces added
  to it, the walk-grid step, the cover, and `weigh`.
- The changes to `infiltration_world.gd`, `infiltration_senses.gd`,
  `guard_suspicion.gd`, `suspicion_view.gd`, `infiltration_drawing.gd`
  and the demo's level cycle and overlay.
- `intruder_network.json`, `derive.py` and `the-guards-intruder.json`.
- `crowd_test.gd`, and whether T115's tests and the other levels stay
  unchanged.
- The docs in both languages, the catalogue card and the translations.

## Findings

1. **Blocker.** `InfiltrationWorld._steps_covered` stopped emitting the
   player's footstep while it blended in. That is a second, hidden rule.
   No number in data stood for it, nothing on screen showed it, and it
   carried the headline result: without it, walking in step was alert at
   10.7 s.
2. **Should.** With the accumulator off, a certainty weighed down to 0.25
   still counts as perceived. The guard goes alert at once while the panel
   says 0.25.
3. **Should.** `demo_overlays.gd` opens only the first level, so the
   overlay's `crowd` entry is always off there. Nothing held its fields.
4. **Should.** `crowd_test.gd` measured only civilian-to-civilian
   distance. Civilian-to-player and civilian-to-guard distances had no
   floor, and the 0.5 m civilian floor holds on one seed with the player
   standing still. The test should say so.
5. **Should.** The docs, the PR body and `guard_suspicion.gd` called the
   crowd "evidence, not a second rule". In fact the percept is weighed, as
   the task asked, and the network gets the reading as evidence.
6. **Nit.** `Flock.new(too_close, 1.0)` and `speed * 0.5` are unnamed
   numbers.
7. **Nit.** Distances were compared with `<=` in one place and `<` in
   another.
8. **Nit.** The network's `about` did not say that the figure is entered
   only when the player was picked out, which is why the model treats it
   as ambiguous on purpose.
9. **Nit.** The panel's last line showed the raw identifiers
   "blends_in" and "stands_out".

## What was done about them

1. The footstep is always emitted. `InfiltrationCrowd.weigh` is the one
   site that weighs the percept. The sight certainty is scaled by
   `certainty_scale`. The player's footstep reach is scaled by
   `footstep_scale` (0.25, so 6 m becomes 1.5 m), applied through
   `PathHearing`'s own falloff over the share of the reach left.
   Multiplying the loudness instead was measured first and did nothing:
   any footstep heard at all sends the patrol to look. `LevelSounds` now
   keeps who made a held sound (`from`), so `weigh` knows the footstep is
   the player's. The crowd line shows "its eye 0.25, its ear 0.40", and
   the overlay carries `ear`. Re-measured: walking in step for 12 s, no
   guard is alert. Sprinting, a guard is alert at 4.0 s. The decision is
   recorded in the task file's Notes.
2. Documented, not changed: a "Not done" paragraph in the crowd header
   and in `docs/godot/infiltration.md`. Treating a weighed certainty as
   unseen would also hide the figure sign, which is the point of the
   reading.
3. The overlay fields moved to `InfiltrationCrowd.overlay()`. The demo
   calls it, and a new `crowd_test.gd` case steps the market with the
   player in a group and checks `group`, `reason`, `figure`, `scale` and
   `ear`.
4. The walk down the spine now measures how close civilians come to the
   player and to a guard, with a floor of 0.4 m. The first measurement
   was 0.26 m: civilians gave way to guards no more than to each other.
   Making way for the player and the guards is now its own force, with
   weight 5 within 1.2 m (`make_way_within`). Measured: 0.72 m to the
   player and 0.50 m to a guard. The 0.5 m floor between civilians is now
   0.64 m, and the test's comment says it holds on one seed with the
   player idle.
5. Reworded in `guard_suspicion.gd`, `infiltration_crowd.gd`, the docs
   and the PR body: the percept is weighed, and the network is told why.
6. Both numbers are now named in `crowd.json`: `match_within_seconds` and
   `starting_pace`.
7. All distances now compare with `<`, as "closer than", and
   `crowd.json` says so.
8. The network's `about` now says it.
9. `blends_in` and `stands_out` are now `SAID_AS` "blends in" and "stands
   out", and the test was adjusted.
