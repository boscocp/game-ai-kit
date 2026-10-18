# Review: wave/49-the-ai-spends-its-money-and-keeps-its-pieces-moving

One fresh context reviewed it, in the main worktree, at 0b3f8cb (one commit
on `main`).

**Verdict: merge after findings 1 and 2, with T45 left wip.** The code is
sound. No decision is refused in any pairing. Claims never go negative and
never hit a missing key on any path the code takes. The workshop is asked a
second time at most once and cannot loop. Every number in the record, the
STATUS row and the commit message is the number the command prints. The
gates are green.

What the wave says about *why* the acceptance fails is a different matter.
The record's central measured claim is false: most stuck walkers **do** have
a walk. A crude ten-line step-aside rule, which is the controller's own
business, cuts the stuck share by two thirds (finding 1). The planner's
headline gain hangs on one untested line, and removing it costs that gain
with every suite green (finding 2).

The funds argument survives, but not for the reason the record gives
(finding 3). The 5% stuck limit was not reached by anything the review
tried either, so the owner's decision is still needed. It should be taken
on the right numbers.

What it read:
- CLAUDE.md;
- T45 in full, with "What was done so far", and the wave 49 "Resuming
  after" section of STATUS;
- `docs/design/tactical-references.md` §2.1, and the wave 48 record for
  the format;
- the whole diff.

Around the diff it read:
- `blue_controller.gd` and `DecisionPolicy`;
- `tactical_match.gd` and `TacticalReach` (`walks_for`,
  `_open_neighbours`);
- `BoardState.why_production_refused` and `produce`;
- `TacticalRules` (costs, income, `free_cell_beside`, `BUILDABLE`);
- `TacticalScenario` (the map and the points);
- `tactical.gd:148`, the scene's "once a turn" build rule;
- the older boxed-workshop test in `tactical_game_test.gd`.

What it ran, each exit code read directly rather than through a pipe:
- `make check`: exit 0, 879 Godot cases.
- `make tactical-win-rates GAMES=20 LIMITS="..."` (the acceptance): the
  script exits 1 and make exits 2. It prints the three broken limits:
  `rl stuck-percent 43`, `lr stuck-percent 39` and `rl blue-funds-left 97`.
  Every figure in T45's table is the figure printed. That covers all five
  pairings: wins, rounds, stuck counts and funds.
- `check_readability`, `check_addon_deps`, `check_no_employer_refs` (the
  term list was on disk), `check_no_training`, `check_acceptance` and
  `check_tiers`: exit 0 each. `check_commit_msg` on 0b3f8cb's message also
  exits 0. The commit carries the owner's name alone.
- `tactical_win_rates.gd` given `rl:stuck:5` and `rl:stuck-percent:5.5`
  exits 2 each time. A trailing `--at-most` with nothing after it exits 0
  (finding 8).

Probes, from scratch scripts under `godot/test/`, all deleted afterwards:
- **Stuck walkers.** Where each one stands, whether it has any walk, and
  why its goal was out of reach. Over 20 games each of rl, lr and rr.
- **Spending.** Income and spend per own turn, and the time of an own
  turn. Measured on this branch, and on `main` in a temporary worktree,
  since removed.
- **Refusals.** Every pairing of rules, learned and planner, including
  ll, pp, pl and lp, with 20 seeds each.
- **The same question asked again.** `choose` asked repeatedly on one
  state.
- **Shared fallback targets.** How often two fallback walkers head for
  the same red piece in one turn.

Four experiments followed, each a temporary edit undone with
`git checkout`:
- E1: a walker re-asked at the end of the turn;
- E2: a step-aside rule;
- E3: a workshop that keeps a lane open;
- E4: forge, then the dearest piece, every turn.

Then seventeen mutations. Each ran the spending, bridge, game, learned,
planner and combat suites (120 cases). Three of them also ran the win
rates. All were undone. `git status` shows only this file.

## What was reviewed

The code:
- `RuleBasedBlue`: spend first (`_spend_anyway`), never idle (`_fallback`,
  `_nearest_enemies`), claims (`_claim`, `_room_at`, `begin_turn`),
  `NO_ROOM` and `no_room_beside`, and the "stays in reach" hold;
- `LearnedBlue`'s point claims and its `_walk_at` fallback, with the
  point given back;
- `BlueTurn`'s second asking;
- `PlannedBlue.begin_turn` calling `super`;
- the new limits in `tactical_win_rates.gd`.

The tests: `tactical_spending_test.gd`, and the changed bridge test.

The docs: T45's record, STATUS's row and resume section, and the commit
message.

## Checked and true

- **No refusals.** Nine pairings, 20 seeds each: 0 refused decisions.
- **Claims are safe on every path the code takes.** Every `-= 1` follows a
  successful `_claim` of the same key:
  - `rule_based_blue.gd:139-143`;
  - `learned_blue.gd:77-78`, `:82-83` and `:217`.

  So no count goes negative and no key is missing. It is fragile, though.
  With the learned point claim removed (mutation M1), `_walk_at`'s `-= 1`
  hits a missing key, and the suites report 2191 errors.
- **Claims are reset for every controller that plays through `BlueTurn`.**
  - `BlueTurn.begin` calls `begin_turn`, and `RuleBasedBlue.begin_turn`
    clears.
  - `LearnedBlue` inherits that.
  - `PlannedBlue` now calls `super`.
  - Both wrappers forward `begin_turn`: `_Counting` in the win rates and
    `_Recording` in the spending test.
  - The scene builds its turn with `BlueTurn` (`tactical.gd:93`).

  The one path that is not reset is finding 6.
- **The second asking cannot loop or skip.**
  - The first answer to the workshop is played before the second asking is
    decided, so `_asked_already` finds it.
  - A hold is never refused, so there is no path that appends the workshop
    twice.
  - A workshop destroyed in between is skipped (`unit == null`).
  - Only a workshop with `no_room_beside` is asked again.
- **The stuck walkers are where the record says.** 4490 of 4942 stuck
  decisions in rl stand within three cells of blue's own workshop, and the
  top cells are (11, 3), (10, 2), (11, 2), (12, 3) and (10, 1).
- **One build a turn is a rule of the game, not of the controller.**
  `BoardState` does not limit it. The scene refuses a second build from the
  player ("the workshop has already built this turn", `tactical.gd:148`), and
  `BlueTurn` holds the AI to the same. So changing it is the owner's call,
  as the record says.
- **The task's four claimed mutations are caught.** Each turns its case
  red: no learned point claim (M1), no second asking (M2), no spend first
  (M3), and no fallback (M4).
- **Invariants 2, 10 and 11.** The wave touches no addon and nothing from
  the employer, and the commit carries no byline.

## Findings

### Must fix

1. **The reason the record gives for stopping is contradicted by a
   measurement, and the option it rules out is a controller fix that
   works.** `tasks/T45-the-ai-spends-and-keeps-moving.md:115-122`. The
   record says: "most of what is still stuck has **no walk at all**", and
   that a staging rule "cannot help a piece with no walk".

   *Measured* over 20 games per pairing: of the stuck decisions, those
   with at least one legal walk (`TacticalReach.walks_for` not empty) were:
   - rl (learned blue): 2548 of 4942, 52%;
   - lr (learned red): 2053 of 3745, 55%;
   - rr (rules blue): 522 of 742, 70%.

   These pieces could move, just not nearer their goal or any of the three
   red pieces the fallback considers.

   *Experiment E2.* At the end of `_fallback`, before the hold, a walker
   with any walk steps to the walk cell furthest from its own workshop.
   That is ten lines. It moved the stuck share from 43% to **14%** (rl)
   and from 39% to **22%** (lr). The games turned decisive: rl went from
   0-3-17 to 0-11-9, and lr from 5-0-15 to 14-0-6. Blue's funds barely
   moved, 97 to 91.

   The same crude rule also upsets every other pairing:
   - the rules' mirror becomes 2-18;
   - rp becomes 11-2-7;
   - pr becomes 1-19.

   So it is not a fix to ship as it stands. It still shows that the
   controller holds the larger lever, which is step 2's "staging cell"
   half, left unbuilt on a false premise.

   Two other ideas moved little:
   - E1, re-asking a stuck walker after the others have moved: 39% and
     38%;
   - E3, never building into the last free cell beside the workshop: 41%
     and 37%.

   Nothing the review tried reached 5%, so the owner's decision is real.
   But the record, the STATUS resume section ("Both are the board's") and
   the STATUS row put it as the board's alone, and that is not shown.

   *Fix:*
   - correct the record and STATUS with the measured split;
   - say that staging is a controller option, with E2's numbers, both the
     good and the bad;
   - either build a staging rule that keeps the other pairings in band, or
     defer it explicitly, as the owner's choice beside T48's.

2. **The planner's headline gain hangs on one line no test holds.**
   `planned_blue.gd:170`, `super.begin_turn(state)`.

   *Reproduced (mutation M6):* that line removed. All 120 cases in the six
   suites stay green. The win rates change as follows:

   | pairing | as published | with the line removed |
   |---|---|---|
   | rp | 0-16-4 | 0-2-18 |
   | pr | 4-12-4 | 0-11-9 |

   Without the reset, the planner's claims on red's workshop pile up
   across turns. Within a turn or two every walker is "already has a walker
   of blue's for each cell beside it" and falls back. That gain, "16-0 as
   blue (was 7)", is the wave's headline result in the commit, STATUS and
   T45.

   *Fix:* a case that plays two turns of a `PlannedBlue` through `BlueTurn`
   and asserts the second turn's walkers aim at red's workshop as the first
   did. Better still, a case over every controller class: after
   `begin_turn`, a controller answers like a fresh one. Then a subclass
   that overrides `begin_turn` without `super` goes red.

### Should fix

3. **The funds conclusion holds, but its explanation hides half the
   gap.** `T45:111-114` says a side holding both points is paid 7 a turn,
   more than any walker costs, and that "Spending every turn still banks
   money".

   *Measured* over rl's 20 games, learned blue:
   - it builds on 799 of its 800 turns;
   - its income averages **4.35** a turn, not 7;
   - it spends **2.06** a turn.

   It builds what beats the most red pieces, which is mostly runners at 1
   and shields at 2.

   The ceiling with one build a turn:
   - Without the forge, which the rules never buy, the dearest piece is the
     mortar at 3. That leaves at least about 58 at 4.35 income over 40
     rounds.
   - With the forge and a ram every turn, the floor is about 17.

   So "at most 10" is indeed out of reach at this income with one build a
   turn. Experiment E4 (forge, then the dearest piece every turn) ended
   with 99 left all the same: rams filled the corner, the stuck share rose
   to 80%, and builds stopped for want of room.

   *Fix:* give these numbers in the record. Income is about twice spend.
   Spending everything is capped by the dearest piece and, in practice, by
   room beside the workshop, not by income alone.

4. **"One piece per target" holds for points only. The fallback, where
   every walker turned away now goes, has no claims.**
   `rule_based_blue.gd:173-180`.

   *Measured:* of the fallback walks, those heading for a red piece another
   fallback walker had already taken that turn were:
   - rr: 602 of 1504, on 312 of 536 turns;
   - rl: 363 of 923, on 196 of 800 turns.

   That covers the walkers redirected by "already has a walker of blue's
   for each cell beside it", which then queue for the nearest red piece
   instead. T45's acceptance says "two walkers of one side never take the
   same target in one turn". The test holds it for control points only
   (`tactical_spending_test.gd:60-66`), and the header's "the rest take the
   fallback above" reads as if that settles it.

   *Fix:* claim fallback targets too (one per open cell beside the red
   piece), or narrow the wording in the header, T45 and the test name.

5. **Rules with no test, two of which change results.** Each mutation
   below leaves the six suites green:
   - **M11: the cap on red's workshop removed** (`_room_at` unlimited for a
     non-point). This is the biggest. The win rates become:

     | pairing | as published | with the cap removed |
     |---|---|---|
     | rr | 10-5-5, 27.3 rounds | 9-11-0, 13.5 rounds |
     | rp | 0-16-4 | 2-17-1 |
     | pr | 4-12-4 | 8-12-0 |

     So the end of the first-mover sweep comes from the fallback and spend
     first, not from the cap. The cap is what makes the five draws.
   - **M8 and M9: no point given back** (`rule_based_blue.gd:143`,
     `learned_blue.gd:217`).
   - **M16: spend first choosing the type that beats the *fewest*.**
     `test_it_builds_even_when_nothing_that_reaches_beats_a_red_piece`
     asserts only that something is built, not that it is the shield, which
     beats the two runners.
   - **M12: the workshop asked again after *any* non-build**, including no
     money.
   - **M17: the learned walker standing on a point not claiming it.**

   *Fix:*
   - a case for the cap (the fifth walker in a turn takes the fallback);
   - assert the type in the spend-first case;
   - a case in which a workshop with no money is asked once;
   - say in T45 what the cap does to the mirror.

6. **A controller is now stateful outside `BlueTurn`, and the docs say it
   is not.**
   - `blue_controller.gd:22-24` says "The rules keep nothing, and do
     nothing." `RuleBasedBlue` now keeps `_claims`.
   - `DecisionPolicy.choose` (`blue_controller.gd:67`) calls
     `decide_move` with no `begin_turn`, so the claims are never reset.

   *Reproduced:* `choose` asked again and again for one runner on one
   state. The first four answers walk "towards the workshop at (1, 7)".
   From the fifth on, the same question on the same state gets the
   fallback: "towards the watchtower at (4, 1): the workshop at (1, 7)
   already has a walker of blue's for each cell beside it". That is the
   entry point T12 and T25 are meant to call.

   *Fix:* say in `BlueController` that `begin_turn` must open every turn
   and that decisions within a turn depend on each other, and fix the
   stale sentence. Alternatively, reset in `choose`.

### Minor

7. **The win-rate output now miscounts workshop turns.** The second asking
   goes through `_Counting.decide_build`, so it counts as another workshop
   turn. Its no-room hold is listed under "built nothing".

   rl's blue line reads "built or bought on 799 of 861 workshop turns ...
   built nothing 62 times: no room". There are 800 turns, and blue built
   on 799 of them. On 61 of the 62 turns it was boxed in, the second
   asking built. A reader takes from
   that line that the workshop was boxed in 62 times without building.

   *Fix:* count a turn once, and count a no-room hold only when the second
   asking also failed.
8. **The limits.**
   - Rounding down favours passing an `--at-most`. A stuck share of 5.9%
     passes "at most 5", and 10.9 funds pass "at most 10". The header
     documents the rounding, but not that it leans one way.
   - A trailing `--at-most` with no value is ignored and the script exits
     0. That predates this wave.
   - The exit-2 message names the pairings but not the new outcomes.
9. **Stale or inaccurate text.**
   - `rule_based_blue.gd:51-56`, the complexity: the fallback adds up to
     three floods per walker turned away, which the header leaves out.
     Measured against the rules over 20 games, the learned side's own turn
     (decisions only) was:

     | | `main` | this branch |
     |---|---|---|
     | as blue | 9.6 ms mean, 22.4 ms max | 18.5 ms mean, 41.7 ms max |
     | as red | 11.4 ms mean, 27.8 ms max | 15.5 ms mean, 37.3 ms max |

     No single decision exceeded 3.1 ms, so no frame is at risk. The
     header's 4.9 ms figure is from T41 against a random red, and it no
     longer describes the cost.
   - `rule_based_blue.gd:295-298`: `_why_nothing` is now called only when
     nothing is buildable. A cheapest type that is refused then returns
     first, so its last two sentences cannot be reached.
   - `T45:118`: "one bridge two cells wide". The bridge is one cell wide
     and two long: row 4, columns 6 and 7.
   - `_spend_anyway`'s "the cheapest" is `buildable[0]`. It is right only
     because `BUILDABLE` happens to start with the runner.
10. **The stuck measure changed in the same wave that is judged by it.**
    - A walker in reach of red's workshop now "stays in reach", which is
      not counted as stuck. Before, it was counted.
    - A shut-bridge hold that the fallback cannot turn into a walk is now
      counted, because its reason begins "stays: no walk this turn". Before
      ("stays: red's pieces stand on every way"), it was not.

    On `main` the same probe gives the learned side 52% (rl) and 43% (lr),
    against 43% and 39% here. Part of that difference is the new
    definition, not the new behaviour. The record should say so beside any
    before-and-after comparison.

## What was done about them

Answered on the branch, in one commit after 0b3f8cb; `make check` exits 0
afterwards, and T45 stays wip.

1. **Corrected, not built.** T45's record no longer says most stuck walkers
   have no walk; it gives the review's counts (2548 of 4942, 2053 of 3745),
   says a staging rule is the controller's answer, reports the review's crude
   one (stuck 14% and 22%, other pairings thrown off: rules mirror 2-18,
   planner 1-19 as red) and why it is not shipped: the reference picks the
   staging cell from a threat map, which T48 builds. The owner asked, after
   this review, to carry on with the design study in its order, so that is
   where staging lands.
2. **Fixed.** `tactical_spending_test.gd` holds that `PlannedBlue.begin_turn`
   forgets last turn's claims; removing `super.begin_turn` turns it red.
3. **Fixed in the text.** The record gives the review's 4.35 earned and 2.06
   spent a turn, the floors (about 58, about 17 with forge and rams), and the
   dearest-every-turn run ending at 99.
4. **Fixed.** A fallback walk claims its red piece like any goal, by the same
   room rule, and skips a piece already full. It moved the figures, and the
   record's table is the new run: rules mirror 12-7-1, planner 13-3-4 as blue
   and 0-20 as red (was 4-12-4), stuck 44.4% and 41.5%, 99.3 funds left.
5. **Fixed.** Tests for the workshop's cap (and a fifth walker taking the
   fallback), a point given back, spend-first's choice with an explicit
   cheaper-of-a-tie, a workshop with room and no money asked once, and a
   walker on a point keeping it. Removing the cap turns them red.
6. **Fixed.** `blue_controller.gd` says what the rules keep and when they
   forget it; `RuleBasedBlue.choose` forgets the claims first, so the same
   question on the same board gets the same answer, and a test asks it seven
   times and checks the claims as well as the answer (planted and undone).
7. **Fixed.** A second asking in the same turn is the same workshop turn: a
   build then takes back the miss counted the first time, and a reason whose
   count falls to nothing is not printed.
8. **Fixed.** Limits compare unrounded (printed to one decimal), a trailing
   `--at-most` exits 2, and the message lists every outcome.
9. **Fixed.** The complexity header gives the review's timings; the
   unreachable sentences in `_why_nothing` are gone; the bridge is "one cell
   wide and two long"; spend-first breaks ties on cost, not on list order.
10. **Recorded.** T45's record says the stuck definition changed in this wave
    and part of the fall from T44 is the definition.
