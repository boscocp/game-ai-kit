# The bot match: what each technique does, measured

<!-- doc-meta
half_life: practice
verified_on: 2026-10-21
tier: 2
source: https://github.com/boscocp/game-ai-kit
invalidated_if: the match's rules, arena or techniques change, and botmatch_effects.gd prints different numbers
teaches: none
-->

> T51's example, played and measured. The techniques and where they come
> from are in [the shooter AI page](../concepts/shooter-ai.md). This page
> covers what they did here, including the one result that did not go the
> way the task expected.

## What it is

Six bots a side, in three squads of two, on a 48 by 32 metre arena with
three points to capture and hold (`make demo-botmatch`). Neither side
starts with better ground: every box, every spawn and the walk grid are
mirrored. Each team plays with three techniques, and each can be switched
off for that team alone:

- **claims** (`TacticalPositions`): a bot weighs the spots near its
  squad's point, by Killzone's weights, and takes the best one no teammate
  has claimed;
- **the commander** (`TeamCommander` over `TeamInfluence`): each squad is
  sent to a point by its worth and its distance. Without it, every bot heads
  for its own nearest point;
- **retreat** (`SquadConfidence`): a squad whose confidence falls below
  0.5 falls back in two waves, one moving while the other covers. Without
  it, a squad never falls back.

The match runs as a simulation with no physics engine in it: a sight line
is a segment against the boxes, answered exactly, and
`botmatch_test.gd` holds that answer to Godot's own ray casts on the same
boxes. So 80 matches run headless in about four and a half minutes. The 3D scene draws
one match; the techniques never read anything the scene computes.

## Watching, and playing inside a team

Tab watches the next bot. The discs round it are every spot it weighed,
coloured by why each was kept or dropped, with its score. The map (top
right) shows the watched team's influence, each squad's order, and each
squad's confidence bar with its retreat and attack marks.

T takes the watched bot over, on either team (the owner's choice,
2026-10-21), and T again gives it back. You play it in first person, as
in Counter-Strike or Unreal; the owner asked for that after playing a
first cut in third person.

- **Controls:** WASD walks, the mouse aims round and up and down, a click
  fires, R reloads, Ctrl crouches.
- **The shot:** a ray from your eyes. It must cross the target's body in
  height as well as across, and a box or the floor stops it.
- **What you see:** every shot leaves a tracer, a flash at the muzzle and
  a spark where it struck. A hit shows a marker, being hit reddens the
  screen's edge, and each shot makes a sound generated in code.
- **The AI's reasoning** is hidden while you play, so the view is a
  shooter's; V shows it again.
- **Your team:** your teammates leave the spot you stand on to you, and
  your squad's commander counts you.

## What was measured

`make test-botmatch-effects`: 20 seeded matches per pairing. Red always
plays with everything on, and blue has one technique off at a time. The
seeds are the same in every pairing. These are the numbers with the
rifle's rules: ten shots a second, a magazine of thirty, nine hits to kill.

| blue plays | points held | its orders span | points covered | bunched in cover | bots lost a point lost |
|---|---|---|---|---|---|
| everything on | 5423 s | 2.44 points | 0.71 | 0.1 s | 34.2 |
| no claims | 5816 s | 2.51 | 0.96 | 500.4 s | 56.2 |
| no commander | 5166 s | 1.94 | 0.70 | 3.1 s | 29.5 |
| no retreat | 6001 s | 2.64 | 1.44 | 0.3 s | 700.0 |

Each technique does what it is for, and the test holds that much:

- **Claims** keep a squad off one spot: 0.1 seconds bunched, against 500.
- **The commander** sends its squads over the map: its orders span 2.44
  points at once, against 1.94 when each bot picks its own nearest.
- **Retreat** loses far fewer bots for each point it gives up: 34 against
  700.
- **Honesty:** in about 460,000 shots, no bot fired at an enemy outside
  its own sight row. A planted bot that shoots the nearest enemy through
  walls fired 455 such shots, and the same count caught every one.

**What none of them does is win.** With claims off, blue held its points
longer. With retreat off, it held them longest, and never gave red a
point to keep (6001 s is the pairing's ceiling). With the commander off,
blue held 5166 s against 5423: 5% less, inside the noise. The first rules,
at four shots a second, gave the opposite sign. So the task's first claim
for the commander, "holds points longer", is not one the test makes.

On this arena caution loses to aggression, and each technique is a kind
of caution:

- claims send a bot to the second-best spot;
- the commander keeps squads on points the team already has;
- retreat gives a point up.

Days Gone's own talk says its squads are built for legibility, not
efficiency [Karlsson 2021], and that is what was measured here.

The owner decided, on 2026-10-21, to state this result rather than tune
the match until the expected one appeared. Making a coordinated team win
is a task of its own, T65, which studies how shipped bot matches reward
holding before it changes a number.

## What was fixed on the way, each measured

- **Shots were resolved in id order**, so blue fired first in every step,
  and a red bot killed that step could not fire back. Deaths are now
  settled when the step ends.
- **The spawns sat on cell edges.** x = 3 and x = 45 mirror each other on
  the floor but not on the walk grid, so red started one cell further from
  every point. The mirror test won 14-6 for blue until the spawns moved to
  cell centres. It then went 9-11.
- **A point inside a box.** The places "on" point B were in blocked cells,
  so the path there was empty and bots stood still.
- **Moving a body through its node** reaches the physics space only on the
  next physics frame (`docs/godot/3d-headless.md`). The simulation does not
  use physics, so this matters only to the 3D tests.
- **Cover did not protect.** A bot standing behind low cover to shoot now
  shows half its width, and is hit half as often. That is the reason
  Killzone's partial-cover weight is 40.
- **Bunching cost nothing**, because two bots could share a spot. Bodies
  are now pushed apart.
