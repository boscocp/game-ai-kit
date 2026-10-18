# T23 — The racing demo, and three difficulties that do not cheat

Size: L · Prereqs: T21, T22 · Files: `godot/demos/racing/`

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
3. The controller: look ahead along the line, steer towards the point with
   `ai_steering` (pure pursuit), and choose a speed from how sharp the line
   is between here and there. Braking is the interesting half — a car that
   only steers will understeer off every corner at full throttle. The speed
   limit along the line is computed once per track from curvature and grip,
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
./scripts/godot --headless --path godot -s res://test/racing_ladder.gd
```

That script runs every level over a fixed seed set and asserts three things: a
harder level's mean lap time is lower than an easier one's by a margin it
states as a number; every level finishes the lap, because a difficulty that
cannot complete the track is not a difficulty; and the ordering is monotonic,
since a ladder with a rung out of order is not a ladder.

And the part that makes the rest mean anything:

```bash
./scripts/godot --headless --path godot -s res://test/racing_does_not_cheat.gd
```

That script asserts the three presets share one physics resource, field for
field, that no car exceeds its stated grip limit or top speed on any frame
of a recorded race, and that no driver's three knobs change during the race
(the skill-based rubber band of T53's survey). If a level is faster, it is faster because of the three
knobs or the script fails.

## Manual check

Watch a race at each level, then watch the hardest one alone with the overlay
on. **Can you see why it is faster?** The braking point should move later and
the line through the corner should be visibly different. If the hard car simply
pulls away on the straight, something is giving it speed and the cheat check
has a hole in it.

## Changed by T53 (2026-10-18, wave 54)

The survey (`docs/concepts/racing-ai.md`) gave each knob a source and named
the braking knob for what it moves: a grip margin. It also sharpened the
refusal of rubber-banding. Shipped games mostly hide it as **skill that
moves with the player's position** -- Pure did, under another name -- rather
than as speed. This task refuses that too: a level's three knobs are fixed
for the whole race, and `racing_does_not_cheat.gd` holds it by checking that
no knob changes during a recorded race.
