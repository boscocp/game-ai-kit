# The bot match: what each technique does, measured

<!-- doc-meta
half_life: practice
verified_on: 2026-10-21
tier: 2
source: https://github.com/boscocp/game-ai-kit
invalidated_if: the match's rules, arenas or techniques change, and botmatch_effects.gd prints different numbers
teaches: none
-->

> T51's example, rebuilt by T66 on maps made for tactics, played and
> measured. The techniques and where they come from are in [the shooter AI
> page](../concepts/shooter-ai.md); the level design the maps follow is its
> T66 section. This page covers what they did here, including the results
> that did not go the way the tasks expected.

## What it is

Six bots a side, in three squads of two, capturing and holding three
points (`make demo-botmatch`; L switches arenas). Two arenas, both
mirrored -- every box, platform, stair, spawn, cover spot and walk cell --
so neither side starts with better ground:

- **the lanes** (`arena.json`, 48 by 32 m, the owner's option 1): a lane
  and one door for each point, spawn rooms opening into a rear corridor,
  two bridges 2.5 m up over B with a stair at each end;
- **the yards** (`yards.json`, 64 by 40 m), made unlike the lanes so the
  same agents are seen to cope on another map: B on a tower 3 m up with a
  stair from each side, A and C in walled yards, houses along the streets.

Height is in the simulation: each walk cell has a floor, a bot stands on
it with its eyes 1.5 m up, and A\* walks a step only within 0.6 m of rise -- up a stair, never a wall (`ArenaWalk`, a `SearchGraph`).

The rules (`rules.json`), the owner's asks after playing T51: Shift
sprints at 6.5 m/s and no shot is fired while sprinting; a rifle has 120
rounds, a magazine of 30 and three reloads, and only the base's resupply
gives more; a reload is three clicks heard and a lowered rifle seen; the
power weapon on one bridge does three times the damage with 20 rounds and
comes back a minute after it is taken; five kills since the last death earn
it at the base; a body has a head (2x), a torso (1x) and limbs (0.5x); and
bodies are solid, friend and enemy alike.

Each team plays with three techniques, and each can be switched off for
that team alone:

- **claims** (`TacticalPositions`): a bot weighs the spots near its
  squad's point, by Killzone's weights, and takes the best one no teammate
  has claimed;
- **the commander** (`TeamCommander` over `TeamInfluence`): each squad is
  sent to a point by its worth and its distance. Without it, every bot heads
  for its own nearest point;
- **retreat** (`SquadConfidence`): a squad whose confidence falls below
  0.5 falls back in two waves, one moving while the other covers. Without
  it, a squad never falls back.

And each bot weighs, rather than follows a rule:

- **where to aim** (`AimChoice`): each zone's chance at its distance and
  aim error, times its multiplier, spill onto the neighbours included --
  close, the head; at range, the torso;
- **how to get past a body** (`PassageChoice`): wait, go round (an A\*
  over the walk with the bodies near closed, `CrowdedWalk`), ask a
  teammate, or take another spot, each priced in seconds; a teammate
  asked weighs what moving costs it against what it saves the asker (the
  owner's design);
- **its errands** (`MatchSupply`): go back for rounds, or fetch the power
  weapon, each a gain less its costs.

What is still a fixed rule -- the bot's priority list, and its perception
written for this match rather than taken from `ai_perception` -- is T67's.

The match runs as a simulation with no physics engine in it: a sight line
is a segment against the boxes, answered exactly, and
`botmatch_test.gd` holds that answer to Godot's own ray casts on the same
boxes, platforms and stairs. So 142 matches run headless in about sixteen minutes. The 3D scene draws
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

- **Controls:** WASD walks, Shift sprints, the mouse aims round and up and
  down, a click fires, R reloads -- and only R: an empty magazine clicks --
  Ctrl crouches. You walk while reloading and may not sprint.
- **The shot:** a ray from your eyes. It takes the zone it crosses -- a
  headshot shows a larger marker and HEADSHOT -- and a box, a platform or
  the ground stops it.
- **What you see:** every shot leaves a tracer, a flash at the muzzle and
  a spark where it struck. A hit shows a marker, being hit reddens the
  screen's edge, and each shot makes a sound generated in code.
- **The AI's reasoning** is hidden while you play, so the view is a
  shooter's; V shows it again.
- **Your team:** your teammates leave the spot you stand on to you, and
  your squad's commander counts you.

## What T66 measured, on the lanes and the yards

`make test-botmatch-effects` on the commit the review's fixes landed in:
20 seeded matches per pairing, red always with everything on, the same
seeds in every pairing.

| claim | measured | needs |
|---|---|---|
| the mirror, lanes | -3.2 +- 32.0 s, 11-9 | within 2.5 errors |
| the mirror, yards | +26.2 +- 35.5 s, 12-8 | within 2.5 errors |
| claims | 2.0 s bunched with them, 312.8 s without | <= 10 and >= 40 |
| the commander | orders over 2.74 points with it, 1.33 without | 1.5 times |
| retreat | 13849 retreating decisions, none uncovered | some, none |
| honesty | 0 of 34433 shots at an unseen enemy | none |
| sprint | 0 shots while sprinting, 8053 s sprinted | none, some |
| aim | 4.71 damage a shot by worth, 3.39 always the head | 1.1 times |
| ammunition | always going back: -268.5 +- 18.5 s, 0-10 | below weighing by 2.5 errors |

Each claim's planted case is caught, each put in the good pairing's place:
a sharper blue (+294 +- 3, 10-0), a commander on one point (1.71 points,
1.29 times -- under 1.5), a retreat in one wave (4617 of 4618 uncovered), a
wallhack (1158 shots) and a bot firing on stale sight (27), always the head
(3.39 a shot), the weighing blue in always going back's place, and the
matches without claims in the claims' place. The yards' mirror is claim
0's check on another arena; claim 0's planted case is its planted case.

The commander's bar was 1.2 times in T51, when it made 1.29; the planted
commander on one point made 1.19, 1.24 and 1.29 times in three runs here,
so the bar is 1.5 -- more asked of the commander, and the plant rejected.

**Never going back for rounds is printed, not claimed.** A bot dies, and
comes back full, before it runs dry: four runs measured 5.8, 1.2, 4.6 and
8.6 s dry a match never going back, against 3.4, 1.1, 0.1 and 0.2
weighing, and its margin (-53.7 +- 63.5) says nothing. The decision is held
in `botmatch_test.gd` instead: near its base with ten rounds it goes back,
full it does not, and a part-used power weapon is worth no walk.

**T65's question** -- does a team with every technique on hold points
longer than the same team with any one off? Measured as blue's margin a
match against red with everything on, and each pairing against blue with
everything on by the two-margin method the test uses:

| blue plays | margin a match | wins | against everything |
|---|---|---|---|
| everything | -3.2 +- 32.0 s | 11-9 | |
| no claims | -48.4 +- 24.3 s | 7-13 | 1.1 errors worse |
| no commander | -39.0 +- 14.9 s | 6-14 | 1.0 errors worse |
| no retreat | +270.5 +- 5.3 s | 20-0 | far better |

- **Claims and the commander both look like they help**, and neither is
  shown: about one standard error each. The commander's decision -- its
  spread of orders -- is shown; what the fighting makes of it is not.
- **Retreat costs the match**, by far: a team that never falls back won
  20 of 20, on lanes made to reward holding. So T65's claim does not hold,
  and is not made. On these maps falling back gives up a point that the
  lane's one door then makes hard to retake.

## What T51 measured, on the open arena

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

## What T66 fixed on the way, each measured

- **Every reload took two.** A bot's action stays RELOAD until its next
  decision, and a reload that had just finished began again in that gap,
  since T51. The owner saw it as reloading without pressing R.
- **A person froze while reloading**: reloading took the action away from
  walking. You walk now, and may not sprint.
- **Bodies were not solid.** They were pushed apart after moving, so a
  person shoved an enemy across the floor and walked into one against a
  wall. A step into a body is now refused, and the push only parts bodies
  that began inside each other.
- **A bot cutting a corner stood still**: it dropped a path cell only when
  it stood in the first one. It now drops the path up to wherever it is.
- **Spots crowded each other across faces**: walls end to end put two
  spots 0.5 m apart, and two bots on them were bunched however the claims
  kept them off each other's spot -- 174 s with claims on the first cut of
  the lanes. Spots now keep their spacing across faces too, by a rule the
  mirror keeps.
- **Three faults bent the yards' mirror** (blue 9-1, then red 8-2): a
  body was walked round by a fixed "left first", which is south for blue
  and north for red; a shot at an arm asked only the arm on the shooter's
  right; and two bots reaching the power weapon in one step gave it to
  the first in id order, always blue. Each is now chosen by where it
  leaves the bot, by the arm seen better, and by who is nearer.
- **A pillar was its own mirror, twice**: a box on the mirror line was
  listed with its mirror copy on top of it.

## What T51 fixed on the way, each measured

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
