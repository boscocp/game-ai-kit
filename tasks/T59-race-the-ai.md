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

On the 24-metre track, five seeds, two laps each from a standing start:
easy 38.0 s, normal 35.9 s, hard 34.4 s a lap (on T23's 16 metres: 39.6,
36.6, 35.1). No level leaves the tarmac now, so wander is only seen, not
paid for; lookahead from 8 to 24 metres moves hard's lap by under two
tenths. Mutating the collision step or the following rule off fails the
suite.

