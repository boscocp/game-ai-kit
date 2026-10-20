# The RTS: a commander that plans, against a clock that does not wait

<!-- doc-meta
half_life: concept
verified_on: 2026-10-20
tier: 1
source: https://ojs.aaai.org/index.php/AIIDE/article/view/12435/12294 ; https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter31_Spatial_Reasoning_for_Strategic_Decision_Making.pdf ; https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter12_Exploring_HTN_Planners_through_Example.pdf ; https://docs.wildfiregames.com/javascript/petra/PETRA.QueueManager.html
invalidated_if: test/rts/rts_measure.gd or test/rts/rts_match.gd print records that differ from the ones below, or the build-order domain changes
teaches: strategy-ai
-->

> How the computer in `make demo-rts` decides. The game is
> [`godot/game/rts/`](../../godot/game/rts/), on T19's real-time core
> [`ai_rts_core`](../../godot/addons/ai_rts_core/). Why it is built this
> way is [planning in strategy games](planning-in-strategy-games.md) and
> [ADR 0010](../adr/0010-the-rts-enemy-plans-at-the-top.md); this page is
> what was built and what it measured.

## The game, built backwards from the AIs

Every feature is there because some technique has nothing to decide
without it (T20's table). Two resources, ore and magma, so spending is a
trade. A worker; three fighters in T10's counter circle -- the runner
beats the mortar, the shield the runner, the mortar the shield, each blow
doubled against the kind it beats. A base, a barracks, a lab the mortar
needs, a depot because a population cap lengthens the chain without a new
rule, and the tower that sees eleven cells. Buildings take a third of any
blow but the mortar's: without that, the first matches ended with runners
razing a base at two minutes, and no match ever reached the lab.

The map is T10's ground, grown: a river, one bridge two cells wide -- the
chokepoint -- and two slow fords. Each side has a home and, by the far
ford, an expansion. A match ends when a side has no base, or at twenty
minutes on what each side holds, priced.

## Three layers, and only the top one plans

**The commander** (`RtsCommander`) asks three questions every half
second. *What to aim at*: workers always; then the counter to the fighter
it has seen most -- mortars for shields -- or runners when it has seen
nothing; a tower when nothing has been seen for two minutes, so it can
look; the expansion after four. *How*: a plan over a level 1 PDDL domain,
[`rts-build-order-domain.pddl`](../../spec/pddl/rts-build-order-domain.pddl),
ten actions and ten facts, by T11's heuristic STRIPS or T15's HTN.
*When*: `BuildSchedule` times each step by jumping to the moment its price
is met at the side's income -- Churchill and Buro's trick -- so the screen
can say "build lab: in 14 s, waiting for magma". It replans every ten
seconds, or at once when the next step cannot run or the goal changed.
That is the lesson the clock adds to T11: the world does not wait while
the plan is made, and a plan is a direction followed and corrected.

**The economy** under it is a priority queue (`EconomyQueue`), what Age
of Empires II's scripts, Supreme Commander and 0 A.D.'s Petra ship. Its one
rule: the top wish waits for its price, and nothing below it spends
meanwhile. The plan's next step is wished at 80; reflexes -- a depot
before the room runs out, workers to a full home, a barracks when ore piles
up -- sit under it. `QueueSide` is the same queue filled by fixed rules and
no plan: the bar a commander must clear.

**Squads** of six run a state machine -- gather, advance, fight, fall back
-- and go where `SquadTactics` scores highest: each region's worth to the
side, times the odds there, over distance, Dill's way for Kohan II. The
odds come from `RtsInfluence`, the side's belief: its own strength spread
over the map, and the enemy's as last seen, fading over 45 seconds. A
region looked at and found empty is cleared, so a squad that razed a home
goes looking for the expansion. **Units** follow T19's flow fields.

## Whom to strike

Once a squad is in a fight, `FocusFire` scores every enemy it can see --
the damage a second it deals the squad, over the seconds the squad needs
to kill it, over its distance -- and every member strikes the best. The
counter table counts both ways: a squad kills what it beats faster, and
what beats it threatens more. A worker or a building is struck only when
nothing armed is near. A member that struck the nearest by reflex is turned
to the focus, and the focus moves only to an enemy scoring a quarter
better, so a squad does not swap targets with every blow. The board rings
the focus and its two rivals with their scores; the panel says why.

The rules under it are the same for both sides, a person's units included:
units keep apart, an idle fighter takes on the nearest enemy its side can
see within two cells past its own sight, and strikes back at a striker it
can see; a shot from afar needs a line clear of walls and buildings.
Only the choices -- the plan, the queue, the region, the focus -- are the
computer's.

## What was measured

`make rts-measure`, ten seeds from both seats (20 matches a pairing), on
2026-10-20, on the code merged:

| pairing | record |
|---|---|
| commander (normal, STRIPS) against the queues alone | 19 - 1 |
| commander with STRIPS against with the HTN | 12 - 8 |
| normal against easy | 17 - 3 |
| the queues against themselves, by seat | 9 - 11 |

The commander beats the queues it sits on, which is what ADR 0010 asked
of it before it earned its cost; `make test-rts-match` keeps holding that
on four seeds. Its matches are short -- a median of 160 seconds of game --
because it builds runners at once, which the queues' fixed rotation does
not answer. STRIPS and the HTN are **not told apart** by 20 matches: on
the 13 distinct questions one match asked, both found the same plans, 1.4
steps long; STRIPS visited 2.1 worlds in 84 us a plan, the HTN 6.8 tasks
in 45 us. Every planning call was under 0.5 ms, inside the 1.5 ms strategy
share.

Before the review's fixes the queues' mirror went 15 - 5 to the west seat;
after them, 9 - 11. T57 makes that a gate, since a person always plays
west.

## Difficulty, without cheating

The levels are T12's knobs (`RtsLevels`), and nothing else -- no level
sees, earns or may order more. Two, not three. **Easy** plans nothing
(horizon 0): its economy is the queues' rules, and its noise of 0.6 blurs
each region's score and misjudges the enemy army it has seen. **Normal**
plans four steps ahead with a noise of 0.2. A hard of horizon 8, depth 2
and no noise went 11 - 9 and 10 - 10 against normal and was cut: plans
here are a step or two long, so a longer horizon changes nothing.

## What it does not do

No formations, no air or water, no abilities, no upgrades -- the armed
tower is T56. Squads do not split to flank. The commander does not plan
the army's moves: a plan per squad, F.E.A.R.'s way, is the alternative
ADR 0010 left to T25's league. The reaction delay and the cap on actions
per minute that make a side look human are T55's.
