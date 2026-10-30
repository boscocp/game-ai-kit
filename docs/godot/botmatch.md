# The bot match: what each technique does, measured

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: https://github.com/boscocp/game-ai-kit
invalidated_if: the match's rules, arenas or techniques change, and botmatch_effects.gd prints different numbers
teaches: none
-->

> T51's example, rebuilt by T66 on maps made for tactics, its bots made
> agents by T67, played and measured. The techniques and where they come from are in [the shooter AI
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
it with its eyes 1.5 m up, and A\* walks a step only within 0.6 m of rise -- up a stair, never a wall (`ArenaWalk`, a `GakSearchGraph`).

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
- **its errands** (`ErrandChoice` in `ai_utility`, T67): go back for rounds, or fetch the
  power weapon, each a gain less its costs;
- **what to do now** (`ActionChoice` in `ai_utility`, T67): reload, fall back, shoot, move,
  look towards a shot it heard, or hold -- every one scored at once from
  what it perceives, the highest done (below).

The match runs as a simulation with no physics engine in it: a sight line
is a segment against the boxes, answered exactly, and
`botmatch_test.gd` holds that answer to Godot's own ray casts on the same
boxes, platforms and stairs. So 149 matches run headless in about 21
minutes. The 3D scene draws one match; the techniques never read anything
the scene computes.

## The bot as an agent (T67)

The owner's ask, during T66: as few fixed `if`s in a demo as can be, and
the bot as AIMA's agent, which perceives the world and itself and decides
what to do towards its goal, so that on another map it copes.

- **It perceives through `ai_perception`, into one record.** Its eyes are
  a `VisionCone` asked in the open -- 40 m, 60 degrees either side, all
  round within 3 m -- with the line answered by the arena's boxes. Its
  ears are `Hearing`: every enemy shot within 30 m, louder nearer, through
  walls. That, its body and its orders are `MatchPercepts`, and
  `MatchBot.decide` reads nothing else; a test decides a bot with no match
  at all.
- **It weighs, it does not follow a list.** T51's priority list -- dead,
  reload, fall back, reload early, shoot, go -- is `ActionChoice` over six
  actions in `actions.json`: each consideration one percept through a
  line or a step, multiplied, times the action's weight. An empty
  magazine vetoes a shot; a reload is worth more the emptier the magazine,
  less with an enemy it could fire at, less away from its spot; a shot is
  worth what `AimChoice` expects of it, so a far one loses to walking on.
  Whom it shoots is the enemy reacted to that a shot is worth most at. A
  reload not carried on is lost, so it is a choice and not a lock. The
  panel shows every score (`weighs: > shoot 0.92 | reload 0.00 | ...`).
- **It weighs how to hold its body and how fast to go**, after the
  action, from the same numbers (`postures` and `paces` in
  `actions.json`; the panel shows `body:` and `pace:`). Crouching is
  weighed down while it moves (a crouch halves its speed) and while it
  shoots (behind low cover a crouched bot shoots into the box), and up by
  what the cover beside it hides -- a low box all of it, a high one less,
  the open nothing -- by the danger it perceives, and while it reloads.
  Danger is 1 with an enemy in sight, else the louder of a shot heard and
  the nearest enemy its team remembers, by closeness within 20 m.
  Sprinting counts only while it moves, is worth more the further it has
  to go -- passing walking just beyond 8 m, as the old rule did -- and
  less with danger; an enemy in sight vetoes it, because a sprinting bot
  may not fire. That is still the game's rule, in the rules; the bot only
  weighs the chance it will need to fire.
- **The errands are a technique**, `ErrandChoice`, with its twin and
  vectors; the weights are still `rules.json`'s.
- **Steering was not taken.** `ai_steering`'s avoid is for round
  obstacles, not walls or corridors, and head-on it turns to the vehicle's
  left: north going east, south going west -- the fixed side that bent the
  yards' mirror in T66. The step round a body and `PassageChoice` stay.
- **Portability is held by a test.** `RandomArena` makes an arena from a
  seed, random within the mirror -- size, points, cover, pillars, walls, a
  platform and its stair -- keeping only one where every point and spawn
  can be reached. The effects test plays six, one match each.

What is still fixed, said so, and where it would move:

- **a dead bot waits, and a person drives the one they took**, with Shift
  and Ctrl as before -- neither is the bot's choice, and stays so;
- **whom it shoots** (`MatchBot._best_target`): the reacted enemy a shot
  is worth most at -- a single score, not a weighing of several reasons;
  a target choice by `ActionChoice` (threat, distance, who is aiming at
  it) is later work, after T68;
- **danger and cover as numbers**: `danger_of`, its `DANGER_METRES` of
  20 m, and the cover values 1, 0.5 and 0 are code, not data. T68, whose
  healing is weighed against danger, is where they would move into
  `actions.json`;
- **a reload not carried on is lost** (`MatchActions.act`): a rule of the
  body, as a magazine pulled half way, and stays one;
- **an errand overrides the spot** (`TeamTactics.think`): a bot sent back
  for rounds gives up its spot without weighing the one against the
  other. Weighing errand against post in one choice is later work, after
  T68, which adds a third errand, going home to heal;
- **the orders** -- where to stand, which point -- are the team's
  techniques, read by the bot as its orders.

### What T67 measured

`make test-botmatch-effects` on this branch rebased onto main (the T66
review's fixes included), after the review's findings were fixed: every
claim held, 0 failures, 1279 s over 149 matches.

| claim | measured | needs |
|---|---|---|
| the mirror, lanes | +31.5 +- 22.8 s, 13-7 | within 2.5 errors |
| the mirror, yards | +8.9 +- 32.0 s, 11-9 | within 2.5 errors |
| claims | 1.2 s bunched with them, 368.4 s without | <= 10 and >= 40 |
| the commander | orders over 2.69 points with it, 1.33 without | 1.5 times |
| retreat, lanes and yards | 13503 and 14346 retreating decisions, none uncovered | some, none |
| honesty, every arena | 0 of about 251,000 shots at an unseen enemy | none |
| sprint, every arena | 0 shots while sprinting, 8155 s sprinted by both sides on the lanes | none, some sprinting |
| aim | 4.53 damage a shot by worth, 3.80 always the head | 1.1 times |
| ammunition | always going back: -260.0 +- 11.7 s, 0-10 | below weighing by 2.5 errors |
| portability | 6 random arenas, every point taken, every match ended | all |

Each planted case was caught: a sharper blue (+300 +- 0, 10-0), a
commander on one point, a retreat in one wave (3203 of 3547 uncovered), a
wallhack (574 shots) and a bot firing on stale sight (34), always the
head, the weighing blue against itself, and a random arena with point C
walled in.

**Two mirror faults, found by the review and fixed.** Each bot used to
perceive and decide in one pass in id order, and a decision sets its
posture at once; a shot's worth reads the target's posture, so red
perceived blue's new posture and blue red's old one. On the yards 312 of
12,325 mirrored two-a-side setups decided differently on the two sides,
and the yards' mirror failed at 20 matches (+100.1 +- 32.4 s, 14-6).
Every bot now perceives before any decides, and the same twenty measure
+8.9 +- 32.0 s. And a turn to what was exactly behind wrapped the same
way for both sides, north for blue and south for red; it now sweeps
towards +z for both. `botmatch_test.gd` holds each, with the faulty order
planted.

**Posture and pace make no claim of their own in the effects test.** They
are held in `botmatch_test.gd` -- idle in the open it stands, at low
cover or reloading it crouches, it stands to shoot over cover and to
walk; it sprints far, walks near, with a shot heard close, or with an
enemy in sight -- and each test fails with the weighing it holds set to
nothing. No measure of the match was found that a bot that never crouches
must fail, so none is claimed. The sprint claim is unchanged: no shot
while sprinting, with some sprinting done.

T65's question, again, blue's margin a match against red with everything:

| blue plays | margin a match | wins |
|---|---|---|
| everything | +31.5 +- 22.8 s | 13-7 |
| no claims | -6.7 +- 33.3 s | 11-9 |
| no commander | -9.2 +- 14.9 s | 9-11 |
| no retreat | +241.6 +- 8.3 s | 20-0 |

- **The commander** is 40.7 s a match better, 1.5 combined errors:
  suggested, not shown. What it decides -- orders over twice the points
  -- holds.
- **Claims**, 38.2 s, 0.9 errors: nothing the score can tell.
- **Retreat still costs the match**, 20-0 for the team that never falls
  back.

**The fault the first run found.** The first full run with the weighing
bots failed one planted case: the sharper blue passed the mirror as even,
at ten matches (+64 +- 44) and at twenty (+17 +- 28, 6-14). Watched, its
bots killed sixty for two and then stood at their base all match: their
streaks earned power weapons, and going back counted the share of a power
weapon's rounds spent as a gain, though the base gives a power weapon
nothing until it is empty. That fault was T66's; weighing bots that kill
faster met it more. The facts now count only what the base gives back,
and `botmatch_test.gd` holds it.

## Health that comes back, and healing weighed (T68)

**The rule** (`rules.json`, `MatchHealth`). After 10 s without a hit --
the owner's number -- health comes back 20 points a second, to the whole
100 and never past it; a hit starts the clock again. At its base, where
the rounds are, a bot is healed whole at once. The person's bot follows
the same rule. Twenty a second fills an empty bar in 5 s, slower than
every refill the sources give (Halo: Combat Evolved's shields take 4 s,
Halo 3's 2 s, Modern Warfare's health about 1.4 s), because the owner
asked for it to come back gradually; the 10 s delay is longer than every
delay they give (4.25 to about 6 s). The sources, and what could not be
opened, are in the shooter AI page's T68 section.

**Healing is weighed, and priced by the fight.** `ErrandChoice` weighs
three errands in one unit -- a gain less its costs -- beside staying at
the post, which is no errand.

- **Health comes back while a bot stays, too, unless it is hit.** So the
  health either errand gains is the share missing times the bot's
  **exposure** where it stands (`MatchHealth.exposure`): 1 when it was hit
  in the last 2 s, under fire whoever fired; else the share of the enemies
  its team knows of with a line from their eyes to its body; 0 when it
  knows of none. Unseen and unhit, a hurt bot heals where it stands, and
  going home for health alone is worth nothing. (The first cut counted
  the health whatever the exposure, and the constant cost of leaving
  made it a threshold in disguise -- the wave 76 review's finding.)
- **Go home**: the share of rounds spent, plus the health times the
  exposure, less 0.05 a second of the walk, less leaving (0.3 holding a
  point, 0.5 attacking one).
- **Hide**: the health times the exposure, less 0.02 a second away -- the
  walk to cover, then what is left of the delay and the refill -- less
  leaving. Where it hides is `TacticalPositions` asked to hide: a place
  within 15 m that no enemy its team knows of sees it crouched on, the
  nearest, nobody else's. It is asked again when the known enemies change,
  and otherwise kept a second, as a fighting spot is.

**The break-even**, under fire (exposure 1), cover at its feet, just hit
(a 10 s wait plus the refill): hiding pays when 0.9 x hurt > 0.5 holding
a point -- below 44 health -- and 0.9 x hurt > 0.7 attacking -- below 22.
At half exposure it never pays: 0.4 x hurt cannot reach 0.5. Going home
with full rounds, 4 s from the base, holding: below 50 health under fire,
never unseen.

`ErrandChoice`, not T67's `ActionChoice`, though step 3 named the
selector: `ActionChoice` multiplies answers in [0, 1], so it can veto and
grade but cannot set a gain against a cost in one unit, which is what the
step asks for; and an errand changes where a bot is sent, which is the
team's to carry out (`TeamTactics`). Each bot is weighed on its own facts.

Hiding is only looked for when its best case -- cover at its feet --
could score above zero: asking every hurt bot every decision made a
match four times slower.

**What it measured.** `make test-botmatch-effects`, after the review's
fixes, on main with waves 75 and 77: every claim held, 0 failures. The
healing claim held is the weak one, and what it cannot catch is said
below.

| claim | measured | needs |
|---|---|---|
| regeneration | none before 10 s, never past 100, back to 100 | all three; health at once is caught |
| healing weighed | weighing +10.0 +- 22.7 s, 12-8; never heals +25.4 +- 23.7 s, 10-10; heals below half -53.1 +- 20.8 s, 6-14 | neither fixed healer above weighing by 2.5 errors |

Every margin is blue's against a red that weighs.

**What the weak claim cannot catch: a weighing that does nothing.** Never
healing, put in the weigher's place, passes it. The review asked for the
stronger claim, that weighing holds longer than each fixed rule; it was
written and measured, and it failed: weighing is 0.5 errors *behind*
never healing, and 2.1 errors ahead of breaking off below half, short of
2.5. Said as measured, not tuned until it passed: priced by exposure, a
weighing bot seldom breaks off -- 4.3 s hiding a match, 1171 health
healed at its base, 732 regenerated -- and that is about what never
breaking off does. What the numbers do show is that a fixed threshold
loses: below half, blue spent its time out of fights it could stay in.
The gate's planted case is one the weak claim rejects: always going back
for rounds (-292.1 +- 3.3 s).

Before the fixes the same run measured weighing +13.9, never healing
-121.6 and below half -198.6, with every hurt bot's health counted as a
gain whatever its exposure, and 3049 points a match healed at the base.
The gap closed with the fixes; which of them closed how much was not
measured apart.

**Two numbers that moved, and where they came from.**

- **Without the commander** blue measured +60.8 +- 11.7 s, 19-1, before
  the fixes; after them, -4.1 +- 13.5 s, 9-11, as in T67 (-9.2). Planting
  the old step order back -- the base healing a bot a lethal hit had taken
  -- with the exposure pricing kept, moved it by about a second (+11.1
  with the commander, -5.0 without, twenty matches each). So the shift came
  from the first cut's weighing, not from the resurrection. Where blue
  died and lived, after the fixes: with the commander, 343 of 956 deaths
  within 15 m of its base, living 13.4 m from it on average; without,
  135 of 691, at 18.3 m: the commander keeps blue nearer its base. That
  this is why the first cut's healer favoured the team without one is a
  guess the numbers do not test.
- **The yards' mirror** sat at -47.6 +- 21.0 s before the fixes, 2.3 of
  the 2.5 errors allowed, the nearest to its edge so far. After them it is
  +47.6 +- 32.0 s, 13-7, 1.5 errors the other way; the lanes' mirror is
  +10.0 +- 22.7 s, 12-8. Twenty matches on the yards swing by that much,
  and a mirror within 2.5 errors either side is what the claim can tell.

## Retreat measured again, before T65 (wave 96)

T68's runs played the no-retreat pairing, but nobody wrote its number
down. `make test-botmatch-effects` on main at 1b70831, 0 failures, 657 s
on 12 shared cores, every pairing below on the lanes:

| blue plays | margin a match | wins |
|---|---|---|
| everything | +10.0 +- 22.7 s | 12-8 |
| no claims | -37.3 +- 23.3 s | 7-13 |
| no commander | -4.1 +- 13.5 s | 9-11 |
| no retreat | +186.7 +- 10.2 s | 20-0 |

T68 as a whole -- health that comes back and the weighing of when to heal,
not measured apart -- narrowed the gap from T67's +241.6 and did not close
it. Blue's deaths: 956 with retreat, 958 without -- the retreat saves no
lives. Why, from the reading, and what T65 proposes, is in the shooter AI
page's T65 section.

## Falling back weighed, and respawn waves: tried, and reverted (T65, wave 97)

The owner picked T65's recommended proposals on 2026-10-26 -- "1+2 depois
3" -- and wave 97 built and measured them. They did not make a team that
falls back win, and the owner closed T65 as measured: **all three were
reverted, and the match plays as above.** This is the record. Every
hash here -- `581820e` (the baseline run, and the source of the dying table), `6523962` (1 and 2, after a claims fault was fixed), `8739ed5` (with 3) and `c5a995a` (the reverted match) -- is a commit of PR #40's branch, the first
three from before its rebase; none survives the squash merge. The
reverted state on main is the squash-merge commit of PR #40.

**What was tried.**

1. *Where*: a bot fell back to T68's hiding place -- hidden from every
   enemy its team knew of -- within 15 m of its squad's point, not 8 m
   towards its spawn; with none, it held.
2. *When*: falling back was a fourth errand in `ErrandChoice`'s unit,
   weighed by each bot. Gain: the health missing times its exposure (as
   T68 prices hiding), plus the death it would avoid -- the chance of
   dying within 5 s where it stood less the chance in cover, times the
   respawn wait and the walk back, at 0.05 a second. Costs: each second
   away at 0.02, and, for the last of its team within 4.5 m of its point
   with an enemy known within 20 m, the seconds until the enemy would own
   it at 0.3. The chance was not chosen: a printed run of the gate at
   581820e counted, for every living bot of both sides at every decision,
   its band of health (tenths) and exposure (0, a half, 1) and whether it
   died within 5 s, and that table went into `rules.json` with the commit.
   The waves stayed -- one member moved while another covered -- and
   confidence chose only attack or hold.
3. *A rule*: respawn waves every 10 s, a dead bot joining the wave after
   next -- 10 to 20 s, as Team Fortress 2's, unscaled.

The panel showed the fall-back sum term by term, in both languages, and
the map ringed each bot falling back.

**What it measured.** `make test-botmatch-effects`, 20 matches a pairing
on the lanes, blue against red with everything; in brackets, how many
combined errors everything is ahead of that pairing:

| blue plays | before (581820e) | 1+2 (6523962) | 1+2+3 (8739ed5) |
|---|---|---|---|
| everything | +10.0 +- 22.7 s, 12-8 | -38.7 +- 24.3 s, 8-12 | +0.2 +- 23.8 s, 12-8 |
| no claims | -37.3 +- 23.3 s, 7-13 (+1.5) | -49.3 +- 24.5 s, 8-12 (+0.3) | -13.4 +- 33.5 s, 7-13 (+0.3) |
| no commander | -4.1 +- 13.5 s, 9-11 (+0.5) | -182.0 +- 7.7 s, 0-20 (+5.6) | -161.7 +- 10.0 s, 0-20 (+6.3) |
| no retreat | +186.7 +- 10.2 s, 20-0 (-7.1) | +223.1 +- 8.4 s, 20-0 (-10.2) | +200.5 +- 14.1 s, 20-0 (-7.2) |
| the yards' mirror | +47.6 +- 32.0 s, 13-7 | -8.4 +- 38.1 s, 8-12 | -0.7 +- 41.0 s, 11-9 |

| falling back (blue, everything) | before | 1+2 | 1+2+3 |
|---|---|---|---|
| fall-backs a match | 130.3 | 251.2 | 144.5 |
| from a held point, then lost within 8 s | 95 of 298, 0.319 | 9 of 334, 0.027 | 8 of 303, 0.026 |
| the same, the point's cost at 0 (planted) | -- | 0.026 | 0.034 |
| deaths, with it / never falling back | 956 / 958 | 850 / 645 | 439 / 339 |

**Each prediction against its outcome** (the task file has them beside
each other):

- 1 alone, no retreat at about +100: not measured -- the owner picked 1 and
  2 together;
- 2 with 1, no retreat at about +10 +- 30, within 1.5 errors: **+223.1 +-
  8.4, 20-0**, 10.2 errors ahead -- wrong;
- 3 with 1 and 2, no retreat at -40 to -80: **+200.5 +- 14.1, 20-0**,
  everything 7.2 errors behind -- wrong;
- the weighing's own claims: (a) at least one fall-back a match held, 251;
  (b) at most half today's share of points lost after a fall-back (0.159)
  held, 0.027 -- but its planted case, the point's cost at 0, passed it at
  0.026.

**Two findings of the gate, with the change in.** Portability regressed:
on the six random arenas 3 points, then 2, were never taken, where every
point had been; replayed with falling back off on both sides, the same
arenas took every point 2 to 7 times, and with it on one never had a bot
within 3 m of its point A. And claim (b)'s plant passing says the point's
cost kept no point that falling back near it did not already keep.

**Without the commander** blue swung from -4.1 (9-11) to -182.0 (0-20)
once falling back was weighed. Nobody predicted it, and it was not
studied further.

**Why, as far as the counts say -- not tested apart.** Falling back was
short and constant: 251 a match, about 1.3 s each by the squad-decisions
spent on it, and blue regenerated less health with it (571 points a
match) than never falling back (883). The health a bot would regain was
priced by its exposure *where it stands*; once in cover that reads 0, the
reason to be there was gone, and the bot walked back out before it
healed. Blue died more with it than without (850 to 645).

**Possible future work, not tasks:** price the health at the post a bot
left -- the exposure it would return to -- rather than where it stands;
and respawn waves alone, never measured without 2.

**What stayed.** The gate still prints, for each pairing, blue's
fall-backs a match and the share of those from a held point followed by
losing it within 8 s, and for the mirror the dying table by band
(`MatchFallBacks`): measurements of today's retreat, read and never
claimed, which change no step of play. And a bot no longer claims a
hiding place over a teammate's claim -- in wave 97's first run, places
claimed that way stacked two bodies on one spot, 366 s bunched.

**The match after the revert** (c5a995a, on main at 3ab7462): `make
test-botmatch-effects`, 0 failures, 431 s in 12 shards. The pairings the
claim guard cannot touch -- no claims, never resupply, always resupply,
never heals, the random arenas -- measured exactly the baseline's. The
rest moved, because a bot no longer claims a hiding place over a
teammate: everything -5.7 +- 20.4 s, 11-9 (was +10.0 +- 22.7, 12-8; the
mirror fair, 0.3 errors); no commander +5.2 +- 13.5, 11-9 (-4.1); no
retreat +184.5 +- 10.1, 20-0 (+186.7), 8.4 errors ahead of everything;
heals below half -38.9 +- 17.0 (-53.1); always the head -187.0 (-170.9);
the yards' mirror +45.0 +- 31.4, 13-7 (+47.6), fair. Today's retreat:
133.1 fall-backs a match, a held point lost within 8 s after 95 of 293
(0.324).

The no-commander comparison flipped sign with the guard: everything is
now 0.4 errors *behind* no commander, where it was 0.5 ahead. What this
page says of the commander's help -- suggested at best -- is weaker still:
on this run it is not suggested at all. The numbers in
`botmatch_effects.gd`'s header (its line 105 and round it) and the T51
and T68 tables above predate the guard; they are to be refreshed at the
next effects run.

## Running the effects gate in shards (T72)

`make test-botmatch-effects` plays 187 whole matches, and two planted
cheats'. One after another, in one Godot process, they took 1279 s in T67
(147 matches) and 2343 s on T68's branch,
and a wave runs the gate again whenever its review changes the code. The
matches are independent: each is a function of its pairing and its seed,
and draws from its own random generator (`world.random`). Measured on
2026-10-22, seed 3 played alone and after seeds 1 and 2 gave the same
margin to the last decimal place.

So `scripts/godot_shards.py` starts one Godot process a core (12 here,
capped at 12), each told `-- --shard K/N --out DIR`. A shard walks the
gate's own list of pairings and seeds, plays the matches whose place in it
is K modulo N, and writes each match's counts (`EffectShards`, in
`test/botmatch/`). A last process, told `-- --merge DIR`, plays nothing:
it adds the counts back one match at a time in seed order, the order the
serial run adds them, and asks every claim and planted case as before.
Only the two planted cheats' matches and T68's regeneration check are
played in the merge, about 30 s.

**The same numbers, bit for bit.** With a temporary line printing every
pairing's sums in full (`var_to_str`), the serial run and the sharded run
of the whole gate printed the same lines character for character, and
the same report: thirteen lines before T68, and fifteen and a 94-line
report on the gate with T68's pairings. Times on this machine, the two
running at the same time on its 12 cores, on that gate: 2748 s serial,
455 s sharded (423 s of shards, 31 s of merge) -- 6.0 times faster;
before T68, 1396 s against 250 s. Run alone, the shards would have the cores
to themselves; how much faster that is was not measured.

What the runner refuses, each a planted case: a shard that exits non-zero,
writes no counts or is still running at `--timeout` (an hour by default;
an error inside `_initialize` can leave a script that never quits), and
Godot that cannot be started (exit 2: it did not run); an engine error in a
shard's or the merge's output (exit 1: a SCRIPT ERROR does not fail a `-s`
run, so the exit code alone cannot say a shard played its share); and the
merge's own 0, 1 or 2 otherwise. A passing run's folder under
`build/shards/` is removed; a failing one's is kept and named. The merge
refuses a missing shard file, a match no shard played, a match two shards
played, a match the gate never asked for, a shard that played nothing, and
a stat that is neither a sum nor a margin: summing a maximum would be a
different number with nothing to say so, which is also why every stat the
gate's `_add` keeps must be a sum, and a suite case plays two real matches
both ways and compares them exactly. With one of the twelve files removed,
the real gate failed 13 times and exited 1. The serial run is still there, unchanged:
`./scripts/godot --headless --path godot -s res://test/botmatch/botmatch_effects.gd`.

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
- **Your health** (T68): the corner says how many seconds until it
  starts to come back, then that it is coming back; at your base it is
  whole at once. The watched bot's overlay says the same of it, and where
  it would hide; its errands line shows hiding's score beside going home.
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
