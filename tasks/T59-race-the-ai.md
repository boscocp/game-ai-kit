# T59 — Race the AI: a car you drive, in the same car as the driver

Size: S · Prereqs: T23 · Files: `godot/demos/racing/`, `godot/test/demo_racing/`

## Goal

T23's demo had three AI cars and nothing to drive. The owner opened it and
asked whether they were meant to control a car -- the lesson the kit
learned in T27 and wrote down: every example is played against the AI, on
a game that needs no explaining, with the technique said on screen. A
racing game is the one everybody knows how to play.

So: you drive a car with the keyboard, against one AI driver at the level
you pick, for three laps. Your car is a plain `RacingCar` on the race's one
`RacingPhysics` -- the same top speed, brakes and grip -- so the only
difference between you and the AI is who decides. Its decisions stay on
screen while you race it: the point it steers at, where it must be
braking, the line coloured by the speed it dares. And a few plain lines
say what it is doing and why the harder one is faster.

T23's three-car view stays, as a mode you switch to, for watching the
levels side by side.

## Steps

1. A driver whose decisions come from held keys (`RacingHumanDriver`):
   throttle asks for the top speed, brake for none, neither holds the
   speed; left and right ask for the full turn rate. The car does the
   rest -- turn into a corner too fast and the grip holds you to a wider
   line, onto the grass.
2. A race: you and the AI side by side on the start line, a three-second
   count, three laps, and who finished first and by how much. 1-3 choose
   the AI's level and start again; R starts again.
3. On screen, beside the race: your speed and lap, the AI's, and what the
   AI is doing in a sentence each -- the white dot, the white bar, the line.
4. Tab switches to T23's view: the three levels, 1-3 to follow one.
5. **Asked while it was being built** -- the owner, on T23's demo: the
   track was too narrow, one car drew over another, and there had to be
   collision. So the track is 24 metres wide (the racing line re-placed for
   it), cars on a grid from the line back, and two cars that touch are
   pushed apart, each losing what it was closing on the other with -- the same
   for everybody. An AI that does not see you would run into you, so every
   AI driver also follows: never faster than the car close ahead on its
   path. No knob, the same at every level, so T23's three-knob rule holds.
6. **And: contrast, and open art.** Kenney's Racing Pack (CC0) for the cars,
   grass, trees, tyres and a stand, each file the pack's own and listed in
   `godot/assets/LICENCES.md`; the tarmac and kerbs drawn in its colours.
   Every mark of the AI's reasoning outlined in black, so it reads on tarmac
   and grass; a dark panel behind the text. The camera follows you close
   enough to see the cars, and a minimap shows the rest.

7. **After the owner raced it.** "When I get close to the other car I lose
   speed and it does not -- a collision would be better; the brake seems
   not to work, it needs feedback; the hard part is controlling the car;
   the corners are too hard, I go onto the grass." So: a collision trades
   the cars' velocities along the line between them (equal masses, some
   bounce), pushing the car that was hit and turning both a little, with a
   flash; letting go of the throttle now coasts down instead of holding the
   speed; brake lights, tyre marks under hard braking or at the grip's
   limit, and a speedometer that says which pedal is down and when you are
   on the grass; a wheel that goes over in 0.15 s; your own braking point,
   a yellow bar, worked out as the AI's is; and a kinder car for everyone
   -- 2.4 g of grip instead of 1.6, brakes of 26 m/s^2 instead of 14 (18
   first, and the owner asked for more), grass that holds you to 25 m/s
   instead of 18.

## Acceptance

```bash
make test-godot-some SUITES=test/demo_racing
python3 scripts/check_demos.py
python3 scripts/check_readability.py
```

```bash
./scripts/godot --headless --path godot -s res://test/demo_racing/racing_does_not_cheat.gd
./scripts/godot --headless --path godot -s res://test/demo_racing/racing_ladder.gd
./scripts/godot --headless --path godot -s res://test/menu/demo_overlays.gd
```

The suite holds that the keyboard's car is a plain `RacingCar` on the
race's physics, that held throttle reaches the top speed and no more, and
that a full turn at speed is held to the grip -- the human gets nothing the
AI does not. And that two cars never end a step on top of each other, that
the one running into the other drops to its speed, and that an AI asks for
no more than the speed of the car close ahead. `racing_does_not_cheat.gd`'s
honest twin now races with collisions too: the twin bumps exactly as the
race does, so nothing in it had to change.

## Manual check

`make demo-racing`: race the easy driver and then the hard one. You should
be able to beat easy without much practice, and lose to hard until you
learn where to brake -- which the white bar is showing you.

## Measured

Alone, five seeds, two laps each from a standing start, on the 24-metre
track with the kinder car: easy 32.5 s, normal 31.3 s, hard 29.9 s a lap
(normal's margin moved from 0.87 to 0.84 to keep it over a second off
hard). In traffic, watch mode with easy in front finishes hard, normal,
easy on five seeds of six -- 23 (the demo's), 5, 7, 99, 11; on seed 42 hard
finishes a second behind normal after a pass that went across the grass.
Traffic is where a ladder is not guaranteed; the ladder gate measures each
level alone. A car parked on the line is passed wherever it is; a car held
at 20 m/s is passed by easy and hard from either slot. A car passing near the
edge of a corner can put its wheels on the grass, up to two seconds over
three laps. Mutating off the collision step, the following rule, the
pass's memory or the push onto the car ahead fails the suite.
