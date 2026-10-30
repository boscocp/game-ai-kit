# The RTS: a commander that plans, against a clock that does not wait

<!-- doc-meta
half_life: concept
verified_on: 2026-10-26
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

One upgrade (T56): a complete tower may be **armed** -- 100 ore and 75
magma, ten seconds, queued at the tower as a fighter is at a barracks
(`RtsKinds.ARM`). Armed, it strikes the nearest enemy its side sees within
six cells, every three quarters of a second, with the line of fire every
shot needs, so never through a wall. Arming is not armed, and the gun is
the tower's: a tower lost loses it. The price is a squad's worth of magma,
which is the point -- an armed tower is bought instead of fighters.

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
eleven actions and eleven facts, by T11's heuristic STRIPS or T15's HTN.
*When*:
`BuildSchedule` times each step by jumping to the moment its price is met
at the side's income -- Churchill and Buro's trick -- so the screen can
say "build lab: in 14 s, waiting for magma". It replans every ten
seconds, or at once when the next step cannot run or the goal changed.
That is the lesson the clock adds to T11: the world does not wait while
the plan is made, and a plan is a direction followed and corrected.

**Whether to arm** is a fourth question, asked beside the plan and not in
it, and weighed in quantities rather than triggered (`TowerWorth`; on the
panel, "arm a tower? raid 300 in its reach, help in 24 s, gun in 10 s:
kills 231, costs 175 -- yes"). The raid is the enemy fighters its belief
remembers within the gun's six cells of its tower -- of its home when it has
no tower yet -- priced, each scaled by how much it is still trusted: a raid
lost from sight is worth less every second, one scout is worth little, and
a raid the gun could not reach is worth nothing to it. Help is the first
moment its own fighters walking home would match the raid, or, if they
never would, the time a fresh squad takes to train: the other way to spend
the ore. The gun is ready when `BuildSchedule` says a tower (if there is
none) and the arm would stand, bought from now. What it kills is the share
of the raid's health the gun would take between being ready and help
coming, priced. When that is more than the arm's 175, the commander wishes
the tower or the arm at 85 -- above the plan's 80 -- so the gun comes when
the weighing timed it to. In an earlier version the arm was a goal fact:
the plan put it behind other steps, and the gun came some 25 seconds after
the panel said it would. `arm_tower` and `tower_armed` stay in the domain
because `BuildSchedule` times the gun by them, but no goal asks for them.
It counts one raid only, though a gun lasts for the next: the cautious
half, and the measured one.

**The economy** under it is a priority queue (`EconomyQueue`), what Age
of Empires II's scripts, Supreme Commander and 0 A.D.'s Petra ship. Its one
rule: the top wish waits for its price, and nothing below it spends
meanwhile. The plan's next step is wished at 80; reflexes -- a depot
before the room runs out, workers to a full home, a barracks when ore piles
up -- sit under it. `QueueSide` is the same queue filled by fixed rules and
no plan: the bar a commander must clear. Its tower rule is a rule: an
enemy fighter in sight within ten cells of home wishes a tower, then its
arm, and the wishes are taken back when the raid is out of sight.

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
can see; a shot from afar needs a line clear of walls and buildings; an
armed tower shoots by itself. The board rings an armed tower's reach.
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

### With the armed tower (T56)

`make rts-measure` again on 2026-10-26, on wave 89's branch after its two
reviews: the arm weighed by `TowerWorth` and bought beside the plan, STRIPS
on h_max as before. "Armed" is how many tower arms each side bought over
the 20 matches, first side first:

| pairing | record | armed |
|---|---|---|
| commander (normal, STRIPS) against the queues alone | 19 - 1 | 0 - 1 |
| commander with STRIPS against with the HTN | 12 - 8 | 0 - 0 |
| normal against easy | 19 - 1 | 0 - 1 |
| a commander that may arm against one that never does | 13 - 7 | 0 - 0 |
| the queues against themselves, by seat | 11 - 9 | 11 - 9 |

In whole matches the commander **never armed**, so the ablation's two
sides played alike but for their dice, and 13 - 7 is what 20 matches give
two equal sides. Read every record above that is that close or closer as a
tie, STRIPS against the HTN's 12 - 8 among them. Whole matches seldom reach
the arm's moment: a raid in the gun's reach while the army is away, *and* a
tower already standing. Without a tower, the tower and the arm take twenty
seconds against a fresh squad's twenty-four, and the gun would fire for
four -- never worth 175.

So the moment was staged (`test/rts/staged_raid.gd`), and the staging is
generous to the gun. West mid-match, a tower up at home + (3, -3), 2000
ore and 2000 magma, its four shields in the far east corner; four east
runners **held** for 90 seconds at a spot -- any that wander more than two
cells off are put back every second, so a gun that cannot move always has
them. Ten seeds each way:

| staged raid | arms bought | first arm | worth margin moved, a match | raiders left |
|---|---|---|---|---|
| in the gun's reach, may arm | 10 of 10 | 1.5 s | +1389 | 0 |
| in the gun's reach, never arms | 0 | -- | +1448 | 0 |
| out of the gun's reach (home + (-4, 4)), may arm | 0 | -- | +2000 | 0 |

The weighing does what it says. It arms at once when the raid is in reach,
and the gun stands when the panel said it would. It does not arm a raid
the gun could not reach. **It does not show that arming is worth it.** The
same commander that never arms clears the same raid as well, 59 worth a
match better, by training fighters with the same money. The weighing
counts help as a fresh squad 24 seconds away and does not see that a side
this rich trains one sooner, so here it values the gun above what it buys.
With 2000 of each to spend, a gun or a squad both win. Whether the arm
pays when money is short is not measured. Neither is whether it pays
against raids that recur, which is when a lasting gun ought to.

The planners still found the same plans, 1.38 steps long on 13 distinct
questions: STRIPS 2.1 worlds in 93 us, the HTN 6.8 tasks in 48 us. No goal
the commander sets asks for the arm, so the search is the one it was. A
goal with the arm in it would have raised h_max's worst from 33 worlds to
90 with no horizon, and from 69 to 76 at normal's horizon of four; h_add
would not help, as it also visits 76 at that horizon. `rts_game_test.gd`
gates the count the game runs: every set of the seven economy facts held,
against every goal the commander can set, at normal's horizon, at most
`BuildOrder.WORST_VISITED` (70; 69 measured). A count holds on any
machine, and a time does not. The slowest call in these matches was
1.13 ms of wall time, inside the 1.5 ms strategy share but not what is
gated.

### The seat's bias (T57)

A person always plays west, so a seat that wins more would be a thumb on
the scale nobody sees. `make test-rts-match` now plays the queues against
themselves over six seeds, each twice with the two sides' dice swapped
between the seats (claim 6). It fails when two fair seats would split the
decided matches that unevenly less than one time in twenty -- an exact
two-sided binomial test -- or when fewer than six were decided; planted
records of 10 - 2 either way and of twelve draws must be refused first.
On 12 matches it trips at 10 - 2 (p = 0.039); on 20 at 15 - 5 (0.041),
T20's record before its review. Twelve matches cannot see a 60/40 seat.
`make rts-measure` plays the same mirror over ten seeds, so claim 6's
twelve matches are the first twelve of its twenty, and judges them with
the same function. A fixed 70% share was tried first; on 12 matches two
fair seats crossed it one time in seven, and every change to the RTS
deals the matches again, so it would have gone red by chance.

Each suspect the task named was tested on its own, the queues against
themselves over seeds 1 to 40 from both seats (80 matches each; a fair
coin's spread is about 4.5 either side of 40):

| change, alone | west - east |
|---|---|
| none | 43 - 37 |
| the economy's building ring scanned in each seat's own order | 41 - 39 |
| the squads' open cell near a target scanned the same way | 44 - 36 |
| a flow field's ties broken north or south first, then by the goal's side | 39 - 39 |
| a flow field's ties broken straight at the goal | 45 - 34 |
| west's start units given the lower ids, so they act first | 35 - 45 |
| a unit struck down in a tick still acting in it | 33 - 46 |
| east deciding before west | 45 - 35 |

**None moved the record beyond what 80 matches give by chance**, and every
change replays the matches differently (a tie broken another way early
reaches a different match), so the column is eight draws of one coin. The
first three are kept anyway, because each was a tie that was not a mirror
image and now is (`RtsScenario.as_seen_by`, `FlowField._wins_tie`), held by
a test that the old order fails. The straight-at-the-goal tie-break was
not kept: it walked armies in lines that never took a base -- 78 of 80
matches ran out the clock. The ids, the strike in a tick and the order of
deciding were not changed: they do not move the record, and changing them
changes the core's rules.

**What the record hides.** The wins are even only because two biases
cancel. Over 560 matches of the runs above, a match ended by a base
falling went to west 158 - 77, and one ended by the clock, on worth, to
east 201 - 122. With the three fixes, over seeds 41 to 100, it is still
30 - 9 and 25 - 55. None of the suspects is the cause. Two leads are
left for a task of their own. The sharper, found in review: the bridge's
region, (24, 15), is the only neutral region that is not its own turn --
that is (23, 16), and on a 48 x 32 map no cell is -- so east's home is
about 1.4 cells nearer it (20.6 against 22.0), and `SquadTactics.scores`
divides by distance; claim 1 checks `MAP`, not `REGIONS`. The other: a
region is scored and walked to at its cell's corner (`Vector2(cell)`),
which is not the corner turned half round. The gate holds the wins,
which is what a player meets; the split is open.

`make rts-measure` on wave 116's branch, 2026-10-30: the queues against
themselves 13 - 7 by seat (p = 0.263), inside the bound; claim 6's six
seeds 7 - 5.
The other records, after the new tie-break: commander against the queues
19 - 1, normal against easy 18 - 2, may arm against never 9 - 11, and
STRIPS against the HTN 6 - 14 where it was 12 - 8 -- 20 matches tell
neither of those last two from a tie (two fair sides go 14 - 6 or wider
about one time in nine).

## Difficulty, without cheating

The levels are T12's knobs (`RtsLevels`), and nothing else -- no level
sees, earns or may order more. Two, not three. **Easy** plans nothing
(horizon 0): its economy is the queues' rules, and its noise of 0.6 blurs
each region's score and misjudges the enemy army it has seen. **Normal**
plans four steps ahead with a noise of 0.2. A hard of horizon 8, depth 2
and no noise went 11 - 9 and 10 - 10 against normal and was cut: plans
here are a step or two long, so a longer horizon changes nothing.

## What it does not do

No formations, no air or water, no abilities, and one upgrade only, the
armed tower. The influence map does not weigh an armed tower as strength,
so a squad's odds at home do not count the gun. Squads do not split to
flank. The commander does not plan the army's moves: a plan per squad,
F.E.A.R.'s way, is the alternative ADR 0010 left to T25's league. The
reaction delay and the cap on actions per minute that make a side look
human are T55's.
