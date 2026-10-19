# The league: one team per technique, and what strength costs

<!-- doc-meta
half_life: concept
verified_on: 2026-10-19
tier: 1
source: book:David R. Hunter, "MM algorithms for generalized Bradley-Terry models", Annals of Statistics 32(1), 384-406, 2004
invalidated_if: a team, the tactical rules, the scenario or LeagueRating changes, or league_runner.gd prints a different table
teaches: comparing-techniques
-->

> Measured with `godot/test/league_runner.gd`, five seeds a seat, in wave 58.
> Every way this kit has of deciding the tactical board plays every other,
> from both seats, and the league says who wins, by how much it can tell,
> and what each decision cost. This is the **strength** half of T25. The
> other half -- which team plays most like a person -- needs recordings of a
> person, and waits for them. Tier 1: `make league` runs it headless on any
> machine that runs the kit.

## The teams

Eight teams, each a `BlueController`, made fresh for every game:

| team | how it decides | hands to the rules |
|---|---|---|
| rules | priority rules: build what beats most, walk at their workshop (T30, T45) | nothing |
| state machine | a machine per walker; it commits until an arrow fires (T15) | production, attacks |
| behaviour tree | one tree, asked from the root each turn; it reconsiders (T15) | production, attacks |
| GOAP | a goal per walker, the cheapest plan to it in turns, replanned every decision (T15) | production, attacks |
| HTN | ranked methods per walker, the plan kept until done, broken or bettered (T15) | production, attacks |
| planner | heuristic STRIPS for purchases, ADR 0010 (T11) | walking, attacks |
| learned | the combat and capture models for its walkers (T44, T46) | production |
| lookahead (hard) | two plies at the exact odds of a fight, T12's hard level | production |

The four T15 teams share their facts (`TeamFacts`) and five deeds -- siege,
hunt, defend, take point, fall back -- so a difference between them is a
difference in how a deed is *chosen*, which is the lesson, and nothing else.

## The table

`make league`, five seeds from each seat, every pairing: 280 games, played
twice to hold the table to its seeds. Bradley-Terry ratings on the Elo
scale, the rules at 0, with 95% bootstrap intervals (`LeagueRating`):

| team | won | lost | rating | 95% interval |
|---|---|---|---|---|
| learned | 57 | 13 | +248 | +152 to +362 |
| lookahead (hard) | 53 | 17 | +204 | +90 to +311 |
| HTN | 34 | 36 | +26 | -90 to +125 |
| behaviour tree | 32 | 38 | +9 | -97 to +116 |
| rules | 31 | 39 | 0 | -- |
| state machine | 31 | 39 | 0 | -114 to +95 |
| GOAP | 28 | 42 | -27 | -129 to +71 |
| planner | 14 | 56 | -163 | -294 to -71 |

No game was drawn: T47's last round settles them all.

**What the table can say.** Three groups, and only three. The learned
policy and the lookahead beat the rules, and their intervals sit clear of
0. The planner loses to them, and its interval sits clear of 0 the other
way -- as T12 found, T11's plan to save for the forge and a ram is a worse
use of the money than buying what beats most. The four T15 teams and the
rules are **not told apart**: every interval in the middle covers every
other. HTN on top of them by 26 points is noise at 70 games a team.

**What it cannot say.** That the four T15 techniques are equally good. They
are equally good *here*, with five deeds and the rules' production under
them. The deeds are where the walking is decided, and over 44,000 decisions
the four spent them alike -- about 43% siege, 35% points, 10-15% defending,
the rest hunting and falling back. The state machine defends most (15%), as
its arrow home waits for home to be clear, not merely unthreatened; GOAP
sieges most (49%) and takes fewest points (29%), as its prices send a walker
to whichever of the two is nearer. Those are the documented differences,
and on this board they move the result less than the noise does.

## What a decision costs

Milliseconds on the machine that ran it (mean, 95th percentile, slowest)
against a budget of one 60 Hz frame, 16.7 ms, and the work where the
technique counts any:

| team | mean | 95th | slowest | work |
|---|---|---|---|---|
| rules | 0.63 | 1.73 | 5.76 | -- |
| state machine | 0.86 | 3.88 | 17.28 | 0.5 states updated |
| behaviour tree | 0.84 | 3.49 | 16.84 | 5.3 nodes ticked |
| GOAP | 1.20 | 3.94 | 16.93 | 1.3 worlds |
| HTN | 0.85 | 3.87 | 14.56 | 0.4 tasks; planned before 17% of decisions |
| planner | 0.71 | 2.23 | 6.25 | 0.1 worlds; planned before 3% |
| learned | 0.62 | 1.82 | 7.54 | -- |
| lookahead (hard) | 1.21 | 3.80 | 16.66 | -- |

The league holds every team to T11's 2000 worlds per decision and to the
budget at the 95th percentile. The slowest decision is printed, not held:
three teams brushed past 16.7 ms once in tens of thousands of decisions,
which is the machine, not the technique.

**The search is not the cost.** GOAP looks at 1.3 worlds a decision and the
HTN at 0.4 tasks; the tree ticks five nodes. The four cost 0.2 to 0.6 ms
a decision more than the rules, whose routes they walk, and what they add
is mostly the facts -- a flood for the walks, one for the way to their
workshop, where each enemy could strike -- read alike by all four. That
split was not profiled; it is the arithmetic of searches this small. On a
problem this size, which way of deciding to choose is not a question of
speed.

## When you would choose which

- **The strongest here is the one that weighs fights**: the learned models
  and the lookahead both put a number on *this* fight, where every other
  team asks a yes-or-no question of the counter table. Strength on this
  board is in the fights.
- **A planner over purchases loses** to a reflex that buys what beats most,
  because the plan is right about the order of purchases and wrong about
  what the board needs now. Plan where the order is the problem.
- **Among state machine, tree, GOAP and HTN, choose by what you need to
  change later**, not by strength: the tree adds a branch without touching
  another, the machine commits where you want commitment, GOAP finds a
  cheaper way when the prices move, and the HTN keeps a plan until something
  better is possible. With the same facts and deeds under them, the league
  cannot tell them apart.
- **Neither strongest nor most human** -- the rules -- is the one to choose
  when a designer must predict what the opponent will do, and when the
  budget is the smallest. It is also, so far, as strong as four of the
  techniques built to replace it.

## Not measured yet

How human each team plays -- the second score -- needs a person's games on
this board. `make record-tactical` keeps every game played to its end in
`data/tactical/` as the decisions both sides made, which replay to the same
board (`TacticalRecording`). T25's steps 4-6 and its eighth team, a clone,
wait for the owner's twenty.
