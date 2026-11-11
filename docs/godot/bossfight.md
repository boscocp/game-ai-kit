# The boss fight: a group round you, and one strikes at a time

<!-- doc-meta
half_life: practice
verified_on: 2026-11-11
tier: 2
source: https://github.com/boscocp/game-ai-kit
invalidated_if: the fight's step order, boss_fight.json, difficulty.json, the director's states, the minions' windows or the scripted player change, and the bossfight suites' seeded runs print different numbers
teaches: none
-->

> T157's example, built and measured (wave 175), with T158's director and
> three levels (wave 181). Where its techniques come from is [the
> action-combat page](../concepts/action-combat-ai.md): the tokens are
> T154's `AttackTokens`, the rings T155's `EngagementRings`, the boss T156's
> `BossBrain`. This page says how the fight puts them together, when the
> minions come, what a level changes, and what the tests hold.

## What it is

`make demo-bossfight`. You, in third person, against a boss and its
minions in a square arena with four pillars: three melee minions and two
ranged ones. You walk with WASD, turn the camera with the mouse, attack
with a click (or J), dodge with Shift -- nothing hurts you mid-dodge -- and
lock on with Q. A controller works too: the left stick walks, RT attacks, A
dodges, RB locks on. H hides the reasoning, N fights again, P pauses and
Space takes one decision while paused. Tab (Back on a controller) moves to
the next level -- easy, normal, hard -- and starts the fight again; opened
with `./scripts/godot --path godot res://game3d/bossfight/bossfight.tscn --
--difficulty=hard`, it starts at that level.

The boss is T156's: three phases, each with its own attacks, every blow a
telegraph, an active window and a recovery. When the minions come is the
director's ([below](#when-the-minions-come-the-director)).

The fight is `BossFight` (`godot/game3d/bossfight/boss_fight.gd`), a world a
test can step with no scene: the ground plane as `Vector2`, no physics. The
scene (`bossfight.tscn`) only draws it and feeds it your keys.

## Who strikes, and where the rest stand

Everyone who strikes you asks **your** token pool: the boss and every
minion. Its sizes and delays are the level's (`difficulty.json`, [below](#three-levels-chosen-by-you));
the rest is `boss_fight.json`, the same at every level. At normal:

| | melee | ranged |
|---|---|---|
| tokens | 2 | 1 |
| seconds between grants | 0.6 | 2.0 |
| the pressed multiplier | x 1.0 | x 3.0 |
| the longest a token is held | 5.0 | 4.0 |

The ranged x 3 is the hold below: once melee pressure begins, no ranged
minion asks for a token for 2 s x 3 = 6 s at normal (9 s at easy, 4.5 s
at hard), nor while the pressure lasts.
The fight reads that number from the pool (`delay_for("ranged",
"pressed")`), so a difficulty table that changes the multiplier changes
the hold. The melee x 1 is the pool's own: a grant made while you are
pressed sets the next melee grant's delay by it.

A minion without a token stands on the **waiting ring** (5 m). With a melee
token it walks to a point on the **inner ring** (2 m) and winds up once it
is in reach; with a ranged token it aims, from the **ranged band** (10 m),
only along a line no pillar crosses (`LineOfSight` on the arena's grid). A
point that has no line to you is faded on the floor, and the rings place a
ranged minion elsewhere. A minion walks with `ArriveBehaviour`, kept apart
from the others and the boss by `SeparationBehaviour`. When the rings give
it no point -- every one taken, or a token holder bumped it -- it stays
where it is and asks again at its next decision, a quarter of a second
later.

The boss's heavy blows cost the whole melee pool, so no minion strikes
during one (T156).

## The order of a step

The rule that keeps a ranged minion from shooting while a melee one is on
you is not a check before firing: it is the order of the step.

1. You move, swing, dodge, lock on.
2. Whether you are **pressed** -- a melee minion winding up or striking --
   is read, as of now.
3. Every quarter second the minions ask for tokens and choose ring points.
   A ranged minion asks for none while the ranged hold fire: while you are
   pressed, and for 6 s after the pressure began.
4. The boss decides; the pool grants. So no ranged minion is granted a
   token while you are pressed: none of them is asking.
5. The melee minions act: one in reach starts winding up.
6. If that pressed you, every ranged minion's token is taken back (T154's
   fourth way back) and its request withdrawn, and the 6 s hold starts.
7. The ranged minions act. One whose token was just taken calls its aim
   off, so it never fires.
8. The boss's blow, the bolts, the director's wave, and who is down.

A token taken back in step 6 was granted in step 4 of the same step, while
you were still free; it is the only way a ranged grant goes unused, and it
is not counted as that minion's turn (below).

The request that asked for this example described it as Insomniac's
Spider-Man: a group, one attacks at a time, and a ranged one from far away.
The talk itself was not checked
([action-combat-ai.md](../concepts/action-combat-ai.md#could-not-be-checked-unchecked)); this
order is the kit's own.

## When the minions come: the director

Minions that keep coming at one pace make a boss fight a grind. Left 4
Dead's director alternates a build-up, a peak and a relief [Booth 2009];
the infiltration level's director (T90) does it from the player's
intensity. `BossDirector` (`boss_director.gd`) does it from three things
that happen in the fight, none about how well you play:

- the boss entering a phase, and whether that phase summons;
- how many minions stand, and whether every kind stands at its cap;
- the seconds since the last wave.

Its three states, with `boss_fight.json`'s numbers:

| state | what it does | until |
|---|---|---|
| build-up | a wave every 8 s | every kind stands at its cap: the peak |
| peak | no wave | 2 or fewer stand, or 15 s have passed: the relief |
| relief | no wave | 6 s have passed: build-up again |

A phase that summons brings a wave at once and the peak, from any state:
the boss calls, and the director only times it. A summon during a peak
starts the peak's 15 s over, so a summon late in a peak is not followed
by a relief a moment later. The director's numbers are checked when the
file is read: the seconds must be above 0 and `relief_at` a whole number,
or the fight is refused and says which. No wave comes while the
boss swings a heavy blow; one that is due waits until the blow ends. The
fight's opening wave counts as the first.

The director decides **when**, never **how many**: a wave brings the
level's number of each kind, and never more than the level's cap
standing. The panel shows its state, the waves so far, and what the next
wave waits for: the time left, the heavy blow, fewer minions, or the end
of the relief.

## Three levels, chosen by you

`difficulty.json` holds three levels. You choose one, with Tab or with
`--difficulty=<level>`. Nothing about you is counted to choose it, and a
level never changes during a fight:

| | easy | normal | hard |
|---|---|---|---|
| melee tokens, seconds between grants | 1, 1.2 | 2, 0.6 | 3, 0.4 |
| ranged tokens, seconds between grants | 1, 3.0 | 1, 2.0 | 2, 1.5 |
| the boss's tells, times | 1.25 | 1.0 | 0.8 |
| no tell shorter than | 0.5 s | 0.4 s | 0.4 s |
| a wave brings, melee + ranged | 2 + 1 | 3 + 2 | 3 + 2 |
| at most standing, melee + ranged | 3 + 1 | 4 + 2 | 5 + 3 |

**Hard is faster, never unreadable.** The boss table (T156) sets the
shortest tell any attack may have, 0.4 s. No level's minimum may be lower,
and at each level's speed every attack in every phase must still be shown
for at least that level's minimum. At hard the shortest is the cracked
phase's swipe, 0.6 s x 0.85 x 0.8 = 0.408 s. Every level is checked when
the file is read, not only the one you chose. One level that breaks the
rule refuses the whole file, and the refusal names that level.

A level that does not exist is refused by name, with the names there are.
The fight is built and shows the refusal, and nothing moves.

**Why this is not `ai_planning`'s `Difficulty`.** That one teaches that a
level should change only how much a searching AI thinks: how far it plans,
how deep it searches, how much its judgement is blurred. It calls giving
the AI more "a lie told to the player", and `test-difficulty-knobs` holds
it to that. These levels do give the boss's side more: more tokens,
shorter delays, faster tells and bigger waves. They are a different
thing, and an honest one, because nothing is hidden: the panel shows the
level and every number it sets, all fight long, even with the reasoning
hidden. A boss fight's AI does not search, so there is no thinking to
turn down. What a person feels as harder here is how many may strike at
once and how soon. `difficulty.gd` and its test are unchanged.

## What the overlay shows

On the floor: the three rings and every point on them, a green line from
each minion to the point it claimed, a yellow ring at the feet of each
melee token holder and a cyan one for ranged, the boss's reach filling
orange through its telegraph and red while the blow lands, a ranged
minion's aim growing towards you, and your lock-on. Over each head: its
state and its place in the queue. In the panel on the left: each kind's
holders, its queue in the order it would be served, and the reissue timer
-- the base delay, the factor in force (for ranged, x 3 while the hold
lasts), the seconds left -- and each ring's claims. On the right, T156's `BossPanel`:
the phase, the attack, the telegraph bar, and every attack's score. At
the top of the left panel: the level and its numbers, and the director's
state and next wave.

`decision_overlay()` hands the same to a test (`BossFightShown`), the
director and the level included. No field is ever empty: "none" says
there is nothing.

## What the tests hold

`godot/test/bossfight/fight_test.gd` plays the fight with a scripted player
for up to 60 s on eight seeds. The player goes for the boss, swings at a
minion in reach, dodges a telegraph about to land and a bolt about to hit.
Four things are read from what the run recorded, never from the fight's own
flags:

- **at most the pool's melee attackers at any step**: the minions in a
  melee window, plus the boss in one at its attack's cost, never above 2;
- **every minion that waits gets a turn**: none spends more than 15 s
  queued between two tokens it kept. A token taken back in the step it was
  granted is no turn. The time a ranged minion's request is withdrawn by
  the hold is not counted: the hold is the rule, not the pool passing it
  over;
- **a ranged minion never fires while melee pressure is on**, the pressure
  read from the minions' states;
- **the fight ends**.

And four the fight adds:

- **no ranged grant to a minion at a step that began with you pressed**,
  and none within 6 s after a hold began, the 6 s read from the pool;
- **no kind above the level's cap** at any step, every wave included;
- **the overlay names a real holder, a real queue and a real claim** at
  some step -- not only "none".

Each check first rejects a planted case: a fight that forgets to take the
ranged token back (it fires under pressure on some seed), a fight whose
hold is cut to nothing (a grant inside the 6 s), waves that add a whole
wave on top of the living, minions that believe they hold a token (the pool
is passed), a minion left waiting 16 s, an overlay that only ever says
"none", and a fight where nothing hurts a player who never swings (it runs
the full 60 s). The runs are not empty: in them the pool fills, melee
minions strike, ranged ones fire, ranged tokens are taken back, summons
come, and a ranged grant comes after a hold. Two cases are set up by hand:
a melee minion that falls holding its token gives it back, and a minion
the rings refuse a point gets one at its next decision once one is free.

Measured on 2026-11-11 in wave 175, before the director and the levels,
when a summon refilled the group to 3 + 2, seeds 1, 2, 3, 5, 8, 13, 21
and 34: every fight was won by the scripted player, in 25 to 48 s; the melee load reached the pool
and never passed it; the ranged held fire 7 to 13 times a fight; 2 or 3
ranged tokens a fight were granted while you were free and taken back in
the same step; no minion fired under pressure, and none was granted a
ranged token inside a hold. The longest queued wait was 7.7 s for a melee
minion and 4.0 s for a ranged one. Melee never stood above 3, ranged above
2. About 0.25 s of compute per fight.

`difficulty_test.gd` plays the same eight seeds at each level and holds,
from what each run recorded, that the level's table is kept:

- **the pools are the level's**: at every step each kind's pool, counted
  as the pool counts it (free plus held), is the level's size;
- **no tell under the minimum**: every attack the boss started was shown
  for at least the level's minimum and the boss table's 0.4 s;
- **no kind above the level's cap**;
- and T157's promises at that level: the melee pool never passed, no fire
  under pressure, no minion left waiting.

`director_test.gd` steps the director alone through each state, and over
the seeds holds that every wave came in build-up or with a summoning
phase, never in a relief cut short and never while the boss -- read from
the boss, not from the director -- was in a heavy blow.

The planted cases each is first shown: a level whose minimum is under the
table's 0.4 s, a level whose speed takes the swipe under its minimum,
an unknown level name, a wave above its cap, an empty pool, a default that
is not a level, two levels of one name, a fight whose melee pool is one
over its level's, a director deaf to the heavy blow, one whose relief is
no pause, and one that sends waves in the peak. The runs are not empty: at
each level the melee pool fills, a kind reaches its cap, the boss
telegraphs and the director sends waves after the first; over the seeds
the director goes round build-up, peak, relief and build-up again, with
summoned waves and timed ones.

Measured on 2026-11-11 in wave 181, the same eight seeds at each level:

| | easy | normal | hard |
|---|---|---|---|
| won by the scripted player | 8 of 8 | 8 of 8 | 8 of 8 |
| fight length | 24 to 35 s | 27 to 45 s | 36 to 49 s |
| shortest tell seen | 0.64 s | 0.51 s | 0.41 s |
| reliefs, over the eight | 9 | 9 | 8 |
| waves summoned, timed | 16, 9 | 16, 15 | 16, 15 |
| longest queued wait | 8.6 s | 6.8 s | 7.2 s |

The scripted player is not a person: that hard takes it longer and easy
less is the only reading these numbers allow.

## Decisions this wave took

- The player's camera and walking are the infiltration level's, **copied**:
  an example depends on no other example (`modules/`), and the code is 20
  lines.
- The bodies are the Kenney models the other 3D examples already reference
  (`assets.json`): the mini characters for you and the minions, the
  survivor at three metres for the boss. No new pack; the primitives stand
  in when nothing is downloaded.
- "Pressure" is a melee minion winding up or striking, not the boss: the
  boss attacks most of the time, and counting it would leave the ranged
  minions nothing.
- The boss's own ranged attack (`hurl`) does not hold fire: the minions'
  pressure is their rule, and the boss's blows obey only the token count
  (T156). Its ranged token is never taken back.
- The scripted player always wins at these numbers. "The fight ends" is the
  property; who wins is not.

## Decisions wave 181 took (T158)

- **The task's proposal, confirmed**: three levels in `difficulty.json`,
  each setting the pools, the delays, the minimum telegraph, the wave and
  the cap; no adaptation, so ADR 0016 is not extended; `Difficulty` not
  reused, for the reason [above](#three-levels-chosen-by-you); a director reading events, not
  skill.
- **A level sets a speed and a minimum, and the table's own check refuses
  it.** A level writes its speed into every attack's telegraph and its
  minimum in place of the table's, and `BossTable` refuses what it always
  refused: an attack shown for less than the minimum. Nothing is clamped,
  as T156 refuses rather than clamps.
- **"Wave cap" read as the most of each kind standing at once**, not a
  number of waves. That is what keeps a fight readable, and what a test
  can hold at every step.
- **The pools and delays moved** from `boss_fight.json` to the levels, so
  each number has one home. `BossFightRules.read()` reads the default
  level, normal, whose numbers are T157's.
- **"Chosen in the example's menu" is a key in the example**, Tab, with the
  level on screen. The catalogue's modes build a ruleset per mode for a
  different game (the tactical card); a level is three numbers, not a
  different game.
- **The peak also ends after 15 s.** At hard the group is large and a
  scripted player never brought it down to 2: the peak never ended, and
  there was no relief. Booth sustains a peak 3 to 5 s and then fades it
  whatever the player did ([infiltration.md](infiltration.md) reads his
  slides). The 15 s is this wave's choice, not his number.

## Manual check

- Play it: the group surrounds you, one strikes at a time, the ranged one
  fires from the edge, and the overlay says why at each moment.
- Record a clip for the video's next cut (T153).
- Easy can be won by a newcomer, and hard is harder without being unfair.
- The director's relief is visible as a pause: after a peak, the panel
  says "a pause", and no minion comes for 6 s.
