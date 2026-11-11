# The boss fight: a group round you, and one strikes at a time

<!-- doc-meta
half_life: practice
verified_on: 2026-11-11
tier: 2
source: https://github.com/boscocp/game-ai-kit
invalidated_if: the fight's step order, boss_fight.json, the minions' windows or the scripted player change, and fight_test.gd's seeded runs print different numbers
teaches: none
-->

> T157's example, built and measured (wave 175). Where its techniques come
> from is [the action-combat page](../concepts/action-combat-ai.md): the
> tokens are T154's `AttackTokens`, the rings T155's `EngagementRings`, the
> boss T156's `BossBrain`. This page says how the fight puts them together,
> and what its tests hold.

## What it is

`make demo-bossfight`. You, in third person, against a boss and its
minions in a square arena with four pillars: three melee minions and two
ranged ones. You walk with WASD, turn the camera with the mouse, attack
with a click (or J), dodge with Shift -- nothing hurts you mid-dodge -- and
lock on with Q. A controller works too: the left stick walks, RT attacks, A
dodges, RB locks on. H hides the reasoning, N fights again, P pauses and
Space takes one decision while paused.

The boss is T156's: three phases, each with its own attacks, every blow a
telegraph, an active window and a recovery. When it enters a phase that
summons, the group comes back to full. T158's director will replace that
rule with its pacing; the overlay already has its slot (`director`).

The fight is `BossFight` (`godot/game3d/bossfight/boss_fight.gd`), a world a
test can step with no scene: the ground plane as `Vector2`, no physics. The
scene (`bossfight.tscn`) only draws it and feeds it your keys.

## Who strikes, and where the rest stand

Everyone who strikes you asks **your** token pool: the boss and every
minion. The pool is the one numbers file, `boss_fight.json`:

| | melee | ranged |
|---|---|---|
| tokens | 2 | 1 |
| seconds between grants | 0.6 | 2.0 |
| the pressed multiplier | x 1.0 | x 3.0 |
| the longest a token is held | 5.0 | 4.0 |

The ranged x 3 is the hold below: once melee pressure begins, no ranged
minion asks for a token for 2 s x 3 = 6 s, nor while the pressure lasts.
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
8. The boss's blow, the bolts, the summons, and who is down.

A token taken back in step 6 was granted in step 4 of the same step, while
you were still free; it is the only way a ranged grant goes unused, and it
is not counted as that minion's turn (below).

The request that asked for this example described it as Insomniac's
Spider-Man: a group, one attacks at a time, and a ranged one from far away.
The talk itself was not checked
([action-combat-ai.md](../concepts/action-combat-ai.md#could-not-be-checked-unchecked)); this
order is the kit's own.

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
the phase, the attack, the telegraph bar, and every attack's score.

`decision_overlay()` hands the same to a test (`BossFightShown`). No field
is ever empty: "none" says there is nothing.

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
- **no kind above the wave's size** at any step, summons included;
- **the overlay names a real holder, a real queue and a real claim** at
  some step -- not only "none".

Each check first rejects a planted case: a fight that forgets to take the
ranged token back (it fires under pressure on some seed), a fight whose
hold is cut to nothing (a grant inside the 6 s), summons that add a whole
wave on top of the living, minions that believe they hold a token (the pool
is passed), a minion left waiting 16 s, an overlay that only ever says
"none", and a fight where nothing hurts a player who never swings (it runs
the full 60 s). The runs are not empty: in them the pool fills, melee
minions strike, ranged ones fire, ranged tokens are taken back, summons
come, and a ranged grant comes after a hold. Two cases are set up by hand:
a melee minion that falls holding its token gives it back, and a minion
the rings refuse a point gets one at its next decision once one is free.

Measured on 2026-11-11, seeds 1, 2, 3, 5, 8, 13, 21 and 34: every fight was
won by the scripted player, in 25 to 48 s; the melee load reached the pool
and never passed it; the ranged held fire 7 to 13 times a fight; 2 or 3
ranged tokens a fight were granted while you were free and taken back in
the same step; no minion fired under pressure, and none was granted a
ranged token inside a hold. The longest queued wait was 7.7 s for a melee
minion and 4.0 s for a ranged one. Melee never stood above 3, ranged above
2. About 0.25 s of compute per fight.

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

## Manual check

- Play it: the group surrounds you, one strikes at a time, the ranged one
  fires from the edge, and the overlay says why at each moment.
- Record a clip for the video's next cut (T153).
