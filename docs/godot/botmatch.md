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
> covers what they did here, including the two results that did not go
> the way the task expected.

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
rifle's rules (ten shots a second, a magazine of thirty, nine hits to
kill) and a fair mirror (below).

What each technique decides, which the test holds:

| blue plays | its orders span | bunched in cover | retreating decisions, none uncovered |
|---|---|---|---|
| everything on | 2.34 points | 0.0 s | 2835 |
| no claims | 2.32 | 79.2 s | 2781 |
| no commander | 1.81 | 0.2 s | 2739 |
| no retreat | 2.55 | 0.1 s | 0 |

- **Claims** keep a squad off one spot: 0.0 seconds bunched, against 79.
- **The commander** sends its squads over the map: its orders span 2.34
  points at once, against 1.81 when each bot picks its own nearest point
  not yet its team's.
- **Retreat** falls back in two waves. In 2835 decisions of a squad
  retreating, never once was every member on the move with nobody
  covering. A planted retreat that moves the whole squad at once is caught
  (605 of 704).
- **Honesty:** a shot is checked along the line at the moment it is
  fired, not by the sight table, which is up to a decision old. In about
  515,000 shots no bot fired at an enemy it could not see. Two planted
  bots are caught:
  - one that shoots the nearest enemy through walls (666 shots);
  - one that fires at whom it saw at its last decision without looking
    again (32 shots at enemies gone behind cover since).

And what the fighting made of it, printed and not claimed. The margin is
blue's points held minus red's, a match, with its standard error over the
20 seeds:

| blue plays | wins, blue - red | margin a match |
|---|---|---|
| everything on (the mirror) | 9 - 11 | -4.5 +- 49.1 s |
| no claims | 11 - 9 | +57.8 +- 54.1 s |
| no commander | 6 - 14 | -80.3 +- 44.7 s |
| no retreat | 20 - 0 | +297.5 +- 1.5 s |

- **Claims** change nothing in the score that 20 matches can tell (1.1
  errors).
- **The commander** looks like it helps: without it blue lost 6 to 14, at
  1.8 errors. That is suggestive, not shown.
- **Retreat** costs the match, and by far: a team that never falls back
  won all 20 against one that does.

Days Gone's own talk says its squads retreat for legibility, not
efficiency [Karlsson 2021], and on this arena it is not efficient. The
task's two claims about the score -- the commander holds points longer,
retreat loses fewer bots a point lost -- are not ones the test makes. The
owner decided, on 2026-10-21, to state what was measured rather than tune
until the expected result appeared.

Making a coordinated team win clearly is T65, after the map the owner
asked for: lanes, flanks, protected spawns and high ground, on which
falling back to cover may pay.

## The mirror, and how it was bent twice

Every comparison above stands on the mirror being fair: with the same
techniques on both sides, the test needs blue's mean margin within 2.5
standard errors of zero. A planted blue with a faster reaction and a
steadier aim must fail that check, and does (+300 a match). The mirror
was bent twice before it held:

- **The spawns sat on cell edges.** x = 3 and x = 45 mirror each other on
  the floor but not on the walk grid, so red started one cell further from
  every point. Blue won 14 to 6.
- **A\* breaks ties by a fixed order of neighbours** -- north, east, south,
  west -- so a path east is not the mirror of a path west. Blue won 18 to 2,
  and every pairing above was measured against that bent mirror until the
  runner printed red's score too. Red's paths are now searched in the
  mirrored arena and mirrored back, so the two sides walk each other's
  mirror image exactly.

## What was fixed on the way, each measured

- **Shots were resolved in id order**, so blue fired first in every step,
  and a red bot killed that step could not fire back. Deaths are now
  settled when the step ends.
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
