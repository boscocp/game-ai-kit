# T23 — The racing demo, and three difficulties that do not cheat

Size: L · Prereqs: T21, T22 · Files: `godot/demos/racing/`, `godot/test/demo_racing/`

## Goal

Cars that drive a track, at three difficulties, where the hardest one is harder
because it **drives better** and not because it was given anything.

Racing is the genre where difficulty is most often a lie, and the lie has a
name: rubber-banding. The AI behind you is quietly given more speed until it
catches up, and the AI ahead is quietly slowed. It makes a race feel close and
it teaches nothing, because the thing on screen is not making a decision.

Here the three levels differ in **how well the car is driven**: how far ahead
it looks, how early it brakes for the corner it can see, and how much its
steering wanders. Every car runs the same physics, and a command proves it.

This is deliberately placed after the RTS, because it is the fourth game and
the owner wanted the three strategy games first. It does **not** need T19: a
handful of cars is not two hundred units, and a task that claims a dependency
it does not have is how a backlog stops being read.

## Steps

1. A track as a closed sequence of points, and a racing line through them. Both
   drawn, because the racing line is the thing the AI is reasoning about and
   T21 says the reasoning goes on screen.
2. A car crude on purpose: position, heading, speed, a turn rate and a grip
   limit. **Not a driving simulator, and the file says so** — the lesson here
   is the controller, and tyre models are a different hobby.
3. The controller: find the point a lookahead distance down the line,
   steer towards it with `ai_steering`'s seek -- T22 has no pure pursuit,
   and this task builds the lookahead point itself (pure pursuit's idea,
   T22's behaviour) -- and choose a speed from how sharp the line is between
   here and there. The lookahead distance is the knob, a constant per level,
   not a gain times speed, so the cheat check below can tell it from what
   it produces. Braking is the interesting half — a car that
   only steers will understeer off every corner at full throttle. The speed
   limit along the line is computed once per track and level from curvature
   and grip,
   backwards from the tightest corners; the car brakes where full braking
   would no longer make the next corner's limit (T53's survey: Tomlinson &
   Melder; Xue et al.).
4. Three presets over exactly three knobs — lookahead distance, grip margin
   (the fraction of the grip limit the driver dares to use, which is what
   moves its braking point), steering wander — and nothing else. A fourth
   knob is written down and justified where it is added, as in T12. Each
   knob has its source in `docs/concepts/racing-ai.md` (T53): pure
   pursuit's one parameter, Game AI Pro's skill as a grip fraction, and the
   error offset from the line.
5. The overlay: the lookahead point, the chosen speed, the braking point and
   the level that is driving. A person watching should see the hard car brake
   later and turn earlier, and be able to say so without being told.

## Acceptance

```bash
make test-godot
python3 scripts/check_demos.py
python3 scripts/check_readability.py
```

The ladder, measured rather than felt:

```bash
./scripts/godot --headless --path godot -s res://test/demo_racing/racing_ladder.gd
```

That script runs every level over a fixed seed set and asserts three things: a
harder level's mean lap time is lower than an easier one's by a margin it
states as a number; every level finishes the lap, because a difficulty that
cannot complete the track is not a difficulty; and the ordering is monotonic,
since a ladder with a rung out of order is not a ladder.

And the part that makes the rest mean anything:

```bash
./scripts/godot --headless --path godot -s res://test/demo_racing/racing_does_not_cheat.gd
```

That script asserts the three presets share one physics resource, field for
field, that no car exceeds its stated grip limit or top speed on any frame
of a recorded race, and that the three knob values the controller
**actually used** on every frame -- recorded from inside the controller,
not read back from the preset -- are the same on every frame of the race. A
rubber band applied where a knob is used (`margin * f(gap)`) is what that
catches. Born with a planted case it must reject (invariant 4): a driver
whose grip margin scales with its distance to the leader. If a level is
faster, it is faster because of the three knobs or the script fails.

## Manual check

Watch a race at each level, then watch the hardest one alone with the overlay
on. **Can you see why it is faster?** The braking point should move later and
the line through the corner should be visibly different. If the hard car simply
pulls away on the straight, something is giving it speed and the cheat check
has a hole in it.

## Changed by T53 (2026-10-18, wave 54)

The survey (`docs/concepts/racing-ai.md`) gave each knob a source and named
the braking knob for what it moves: a grip margin. It also sharpened the
refusal of rubber-banding. Besides speed and the car's physics, some
shipped games use **skill that moves with the player's position** -- Pure
did, under another name, and Game AI Pro's rubber-banding chapter
recommends it -- and Game AI Pro's architecture adds a slow "biorhythm" in
skill. This task refuses both: a level's three knobs are fixed for the
whole race, and `racing_does_not_cheat.gd` holds it on the values the
controller used. The cost is the close finish those systems exist for.

The same chapter warns that a narrow skill range makes drivers hard to tell
apart. The three presets are spread far enough that the manual check below
can see the difference, and the ladder script's margin says how far.

## Done in wave 64 (2026-10-20)

What was built differs from the steps above in four places, each on purpose:

- **The speed limit is computed once per track, not once per track and
  level.** A driver who dares a fraction m of both grip and brakes goes
  exactly sqrt(m) times the full-grip limit, top speed applied after --
  every speed in the formula is the square root of an acceleration, and
  capping before or after the backward pass gives the same profile. So the
  grip margin is applied every frame, where the driver uses it, which is
  also what lets the cheat check see it.
- **The cheat check races an honest twin.** Two reviews found eight
  cheats the earlier versions let through -- a stronger engine, a nudge
  forward, a physics swapped mid-race, a speed planned from further down
  the line, a turn at a point other than the one reported, a faster limit
  written into the track, distance credited on the race's books, a level
  changed mid-race with its report forged. Each version had trusted
  something a driver can reach. So the script builds its own race from
  what it entered (each level's numbers and seed, the physics as it began)
  with plain drivers, steps it alongside, and every car, decision and lap
  record must equal the twin's on every frame. A driver indistinguishable
  from the honest one is the honest one; it also makes wander bind exactly,
  where "at most" had let a driver drop it. The knobs' own report, one
  physics for all, the limits measured over each step, and finishing are
  held besides. Seventeen planted races, each refused by a finding naming
  its rule.
- **Lookahead buys almost no lap time on this track.** Measured: from 8 to
  16 metres the hard driver's lap moved by under a tenth of a second, and at
  20 it cut corners onto the grass. The grip margin is what orders the
  ladder; lookahead is there for what a person sees -- turning in earlier.
  The presets are easy 8 m / 0.75 / 2.0 m, normal 12 / 0.87 / 1.0, hard
  16 / 0.97 / 0.3.
- **The cars are ghosts.** They drive through each other; overtaking is
  T54's heat line.

Measured: easy 39.6 s, normal 36.6 s, hard 35.1 s a lap, over five seeds
and two laps from a standing start; the ladder's stated margin is 1.0 s.
Both scripts are `make test-racing-ladder` and `make test-racing-does-not-cheat`,
gates of the `demo_racing` module. Every rule in both was mutated off once
and its planted case went red (the ladder's rung-out-of-order case first
passed by the wrong rule, and now must be named for what it is).

