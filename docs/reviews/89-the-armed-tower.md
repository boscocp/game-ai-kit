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
