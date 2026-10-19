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
| learned | 59 | 11 | +311 | +219 to +417 |
| lookahead (hard) | 55 | 15 | +263 | +162 to +397 |
| HTN | 38 | 32 | +92 | -4 to +199 |
| GOAP | 33 | 37 | +46 | -61 to +154 |
| behaviour tree | 31 | 39 | +28 | -75 to +121 |
| rules | 28 | 42 | 0 | -- |
| state machine | 25 | 45 | -28 | -134 to +76 |
| planner | 11 | 59 | -177 | -312 to -69 |

No game was drawn: T47's last round settles them all.

**What the table can say.** Each interval is a difference from the rules,
so the table answers one question per team: is it told apart from the
rules? Three are. The learned policy and the lookahead beat them, their
intervals clear of 0. The planner loses to them, clear of 0 the other way --
as T12 found, T11's plan to save for the forge and a ram is a worse use of
the money than buying what beats most. The four T15 teams are **not told
apart from the rules**: each interval covers 0 -- the HTN's only just, at
-4, so it is the one a longer league might separate. Whether, say, the lookahead
is told apart from the HTN is a question these intervals do not answer, and
the page does not claim it.

**What it cannot say.** That the four T15 techniques are equally good. They
are not told apart *here*, with five deeds and the rules' production under
them. The deeds are where the walking is decided, and over the 41,000 to
47,000 decisions each made (the runner prints each count) the four spent
them alike -- about half siege, a quarter points, a tenth defending, the
rest hunting and falling back. The state machine defends most (16%), as
its arrow home waits for home to be clear, not merely unthreatened. On this
board that documented difference moves the result less than the noise does.

The table moved between two runs in this wave, after a fix to how a point
is read (an enemy standing on it no longer counts as free -- wave 58's
review): the four T15 teams gained, the state machine least. Their
intervals covered 0 both times.

## What a decision costs

Milliseconds on the machine that ran it (mean, 95th percentile, slowest)
against a budget of one 60 Hz frame, 16.7 ms, and the work where the
technique counts any:

| team | decisions | mean | 95th | slowest | work |
|---|---|---|---|---|---|
| rules | 23,363 | 0.63 | 1.72 | 6.33 | -- |
| state machine | 46,174 | 0.93 | 4.28 | 14.92 | 0.5 states updated |
| behaviour tree | 41,723 | 0.93 | 4.19 | 12.82 | 5.2 nodes ticked |
| GOAP | 42,232 | 1.23 | 4.02 | 10.98 | 1.3 worlds |
| HTN | 42,910 | 0.94 | 4.17 | 15.30 | 0.4 tasks; planned before 17% of decisions |
| planner | 25,371 | 0.70 | 2.21 | 5.96 | 0.1 worlds; planned before 3% |
| learned | 44,684 | 0.61 | 1.81 | 5.46 | -- |
| lookahead (hard) | 44,024 | 1.20 | 3.97 | 16.60 | -- |

The league holds the teams that count worlds -- the planner and GOAP -- to
T11's 2000 a decision, and every team to the clock's budget at the 95th
percentile. The others count no worlds (the rules, the learned policy, the
lookahead) or count in other units (nodes, tasks, states), and T11's budget
says nothing about them. The slowest decision is printed, not held: in this
run none passed 16.7 ms, in the run before three did, once each in tens of
thousands of decisions -- the machine, not the technique.

**The search is not the cost.** GOAP looks at 1.3 worlds a decision and the
HTN at 0.4 tasks; the tree ticks five nodes. The four cost 0.3 to 0.6 ms
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
