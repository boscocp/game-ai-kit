# Review: wave/89-the-armed-tower

A fresh context reviewed T56 at bf8fafa (PR #28). That commit held the
arm in the core (`RtsKinds.ARM`, `RtsUnit.armed`, `RtsOrders.tower_target`
and `_shoot`), `arm_tower` and `tower_armed` in the build-order domain,
the commander's goal, the queues' rule, the screen and `rts-measure`'s
count of arms. The reviewer read the code, probed the commander in
headless matches of its own, and swept the planner over held sets.

**Verdict: fix first.** The core rule is sound; the commander's half did
not meet T56's goal.

## What was reviewed

- **The rule in the core.**
  - Whether a tower shoots only once armed, and only at what its side sees.
  - Its line of fire.
  - Refusals of a second arm.
  - The state, the digest and the snapshot.
- **The domain.** The PDDL against both JSON copies.
- **The commander's goal.** Its threat measure, probed with one runner
  killed at home and with raids at 0 s and 90 s in headless matches.
- **The cost to the planner.** STRIPS swept over 128 held sets and three
  army goals, with and without the arm.
- **The queues' rule, the screen and the measure.**

## Findings

1. **The threat was a ratio, and nothing weighed the arm** (blocker).
   `home_threat()` was the enemy's share of the strength at home, so the
   raid's size did not matter, and with the army away any one remembered
   fighter gave 1.0. Fading did nothing, since both terms shrank together:
   one runner killed at home stayed at 1.000 from 1 s to 44 s, and fell to
   0 at 46 s, the cutoff. The comment and `rts-ai.md` claimed a fading
   weighing. `tower_armed` was simply added to the goal; nothing set the
   arm against a squad.
2. **Raided mid-match, it never armed** (blocker for the goal). Probes:
   - a raid at 0 s: the goal asked at 1 s, and the arm was bought at 55 s;
   - a raid at 90 s: the threat peaked at 0.72, the goal was on at 91 s and
     off by 95 s as its runners came home, and no arm was bought in 300 s;
   - one runner: 0.49 at most, no arm.

   `_plan_is_stale` replans on any goal change, so the goal's flicker threw
   the plan away. The doc's "never rises above a half" was wrong. Wanted:
   commitment, a raid test with two contrasting no-arm cases, and an
   ablation in `rts-measure`.
3. **The arm about tripled the worst STRIPS search** (should-fix).
   - Empty held, goal workers, mortars and expansion: 24 worlds and 615 us
     became 63 worlds and 1320 us once the arm was in the goal.
   - Over 128 held sets and 3 army goals: 33 worlds at worst became 90,
     and 2249 us.
   - The doc's 1.14 ms is wall time, which is what `rts_match.gd` gates
     against the 1.5 ms share.
4. **A raid stopped all training in the queues** (should-fix). The tower
   and arm wishes sat at 40, above the fighters' 30, and the queue stops at
   the first wish it cannot pay.
5. **No replay held an arm** (should-fix): none bought one and fired.
6. **Nits:**
   - invariant 13: the weighing was not on the panel;
   - `rts.gd` `_train(ARM)` took the first selected tower even if it was
     armed or arming, and the refusal read "trains a arm";
   - `test_fetch_rts_art.py` said its list is every kind in the table,
     and `arm` is not one;
   - lines left unwrapped in `rts_commander.gd` and `rts-ai.md`;
   - T56 was not marked done in `tasks/STATUS.md`.

Sound, by the reviewer's reading:
- The tower's target is chosen from the side's fogged view
  (`visible_to`), with the line of fire every shot needs.
- `armed` is in the unit's state, so in the digest, and in the snapshot.
- The PDDL and both JSON copies are equal.
- `_free_to_train` passes over an armed tower.

## What was done about them

1. **The arm is weighed in quantities** (`TowerWorth`, new). What the gun
   saves is the raid's worth times the share of the raid's health the gun
   would kill between being ready and help coming, and that is set against
   the arm's price.
   - The raid is the fighters `RtsInfluence.fighters_near` remembers near
     home, each scaled by trust, so size matters and fading works: a test
     holds that a raid 20 s out of sight weighs under 0.6 of the one seen.
   - Help is the first moment its own fighters walking home match the
     raid, or a fresh squad's training time, the other way to spend the
     ore.
   - The gun is ready when `BuildSchedule` says so, a tower first if there
     is none.

   `home_threat()` is gone. The header, the comment and the doc say what is
   computed.
2. **Held once chosen, and measured.**
   - The goal keeps the arm for `COMMIT_SECONDS` (30) past the last
     decision that weighed it worth it.
   - `rts_game_test.gd` plays a raid held at home with west's shields in
     the far corner, and asserts one arm bought within 60 s. A planted
     `may_arm = false` fails it.
   - Two contrasts buy none: a passing scout, and the same raid met by the
     shields at home.
   - `rts-measure` gained the ablation: a commander that may arm against
     one that never does, and the raid moment played on purpose both ways.
     The result is plain in `rts-ai.md`. In 20 whole matches the commander
     never armed, so 14 - 6 is two equal sides and the noise floor. In the
     raid moment, arming won: 10 arms in 10 seeds, every raider killed,
     and +1219 worth a match against +555 without.
3. **STRIPS moved to h_add.** Over the same sweep it visits 13 worlds at
   worst and never found a longer plan than h_max's shortest.
   `rts_game_test.gd` gates both: plan lengths, and the count against
   `BuildOrder.WORST_VISITED` (20). A count is machine-independent; the
   doc's budget sentence now says the 1.05 ms it quotes is wall time and
   not what is gated.
4. **The queues' tower and arm wish at 25, under the fighters.** The arm is
   wished only with a complete tower to take it, and both wishes are
   forgotten each decision unless the raid is still in sight.
5. **A replay with an arm.** `rts_core_test.gd` buys an arm, lets the gun
   strike a shield that nothing else can hurt, and replays the recording
   on a fresh world to the same digest.
6. **Nits.**
   - The panel prints the weighing: "arm a tower? raid 300 at home, help
     in 24 s, gun in 10 s: saves 220 of 175 -- yes".
   - `_train` takes the first selected tower that can take the arm, and
     its refusal reads "select a tower, complete and not yet armed".
   - The Python comment is reworded.
   - The lines are wrapped.
   - T56 is done in `tasks/STATUS.md`.

## What was run after

On the branch rebased onto 57c4c5e:
- `make test-godot-some` on `rts_core_test.gd` and `rts_game_test.gd`:
  70 cases, 0 failures, no SCRIPT ERROR.
- `rts_simulation.gd`: 0 failures.
- `rts_match.gd`: 0 failures; the commander beat the queues 8 - 0.
- `make test-python-some` on the planning vectors, the PDDL reader and the
  RTS art: OK.
- `make test-demo-overlays`: 0 failures, in both en and pt_BR.
- `check_readability.py` and `check_modules.py`: clean.
- `make rts-measure`: the record is in `docs/concepts/rts-ai.md`.

`make check` was not run in this round, on the owner's instruction.

## Manual check

Still the owner's: play against normal and say whether arming a tower
felt like a choice between it and another squad. On this map the
commander will seldom be seen to arm, and the panel line says why.

## Second review

A second fresh context reviewed 4b9d8fa. It ran its own probes on a staged
raid and swept the planner at the game's horizon. **Verdict: fix first.**

### What was reviewed

- Whether the gun the weighing timed is the gun the commander delivers:
  plans, wishes and purchase times on a staged raid, rich and poor.
- Whether the weighing knows where the tower stands.
- The planner gate against the horizon the game plans with.
- The commitment, the gun's rate of fire, and the tests' and measure's
  staging.

### Findings

1. **The weighing timed a gun the commander did not deliver** (blocker).
   `tower_armed` was a goal fact, and STRIPS ordered it behind other steps
   (`["train_workers", "arm_tower"]`), while only step 1 is wished.
   `gun_ready_in` timed the arm alone.
   - On a staged raid with 2000 of each, the panel said "gun in 10 s" and
     the arm was bought at about 38 s, with no fighter trained meanwhile.
   - With 200 of each, the weighing flipped to no while the commitment
     held the goal: one shield in 60 s, and all four raiders survived.
   - The raided test passed only because its window was 60 s.
2. **The weighing ignored where the tower stands** (should-fix). It counted
   a raid within 10 cells of home, but the gun reaches 6 and towers are
   sited 3 to 7 cells out. A raid 11 cells from the tower bought the arm.
   The staged raid stood beside the tower and was teleported back, which
   went undisclosed.
3. **The planner gate measured the wrong search** (should-fix).
   `WORST_VISITED` swept with no horizon, but the game plans at normal's
   horizon of 4, where h_max and h_add both visit 76 with the arm. So
   h_add did not cut the search the game runs, and the first step differed
   from h_max's in 86 of 2048 questions.
4. **The commitment held a plan the weighing had rejected** (should-fix).
   Once an arm was queued, `gun_ready_in` returned 0, so the panel said yes
   for money already spent and the commitment renewed itself.
5. **Nits:**
   - The gun fires on look ticks, every 50 and not 45.
   - The weighing reads the previous decision's belief.
   - "saved" is the enemy worth killed.
   - `RAID_REACH` and `RAID_CELLS` were two independent 10s.
   - The staging was duplicated in the test and the measure.
   - The ablation comment's "both raid" did not match the record.

Sound, by the reviewer's reading:
- `TowerWorth` reads only the fogged belief and the side's own snapshot.
- Its units are consistent: worth with worth, health with health.
- Six planted mutations of the weighing were killed by the tests.
- The queues still train fighters during a raid.
- The core rule and the replay hold.
- h_add's plans were never longer than h_max's.

### What was done about them

1. **The arm is bought beside the plan.**
   - When the weighing says yes, the commander wishes a tower (if it has
     none) or the arm (once one stands complete) at 85, above the plan's
     80. `tower_armed` is in no goal.
   - The domain keeps `arm_tower`, because `BuildSchedule` times the gun
     by it.
   - `gun_ready_in` times exactly what is wished: the tower if there is
     none, then the arm.
   - The raided test now allows only what the weighing promised plus 1.5
     s. Planting the arm's priority at 20 fails it.
   - Measured: first arm at 1.5 s on average, against "gun in 10 s".
2. **Only raiders within the gun's reach are counted.** That is 6 cells of
   the side's tower, or of its home when it has none. A new test and a
   staged run with the raid at home + (-4, 4), out of reach, buy no arm.
   `test/rts/staged_raid.gd` now holds the staging for the test and the
   measure alike, and `rts-ai.md` says plainly that the raid is held.
3. **STRIPS is back on h_max.** No goal asks for the arm, so the in-game
   search is unchanged. The gate now sweeps every economy set against
   every goal the commander can set at normal's horizon:
   `WORST_VISITED` = 70, with 69 measured. The doc says what is gated and
   claims no saving.
4. **The commitment is gone.** The raided test passes without it. A side
   with a tower armed or arming weighs "bought", and the panel says so
   instead of yes.
5. **Nits:**
   - The gun's rate counts the look cycle.
   - A comment notes the one-decision-old belief.
   - `killed` replaces "saved".
   - `QueueSide.RAID_CELLS` says why it is its own number: the baseline
     asks the cruder question.
   - The staging lives in one file, and the ablation comment matches what
     is measured.

### What the measure now says

The first review's staged result, arming +1219 against +555, did not
survive the fixes. With the arm bought on time and the plan no longer bent
by a goal fact, the commander that never arms clears the same held raid
with fighters, and comes out 59 worth a match better (+1448 against
+1389; 0 raiders left both ways). Whole matches still never arm. **The
weighing is now honest about when the gun stands and what it can reach. It
is not shown to make a better player:** with money to spare, a squad does
as well. The weighing counts help as a fresh squad 24 s away, and a side
this rich trains one sooner. `rts-ai.md` records this, and leaves the
poor-side and recurring-raid cases unmeasured.

### What was run after

On the branch rebased onto 6d615cb:
- `make test-godot-some` on `rts_core_test.gd` and `rts_game_test.gd`:
  72 cases, 0 failures, no SCRIPT ERROR.
- `rts_simulation.gd`: 0 failures.
- `rts_match.gd`: 0 failures; the commander beat the queues 8 - 0, and
  the slowest plan took 272 us.
- `make test-python-some` on the planning vectors, the PDDL reader and the
  RTS art: OK.
- `make test-demo-overlays`: 0 failures, in both en and pt_BR.
- `check_readability.py` and `check_modules.py`: clean.
- `make rts-measure`: the record is in `docs/concepts/rts-ai.md`.

`make check` was not run in this round, on the owner's instruction.
