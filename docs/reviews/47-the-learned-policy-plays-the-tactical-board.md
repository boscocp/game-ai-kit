# Review: wave/47-the-learned-policy-plays-the-tactical-board

One fresh context reviewed it, in the main worktree, at 828c3ee (two
commits on `main`: 9df4af4 and 828c3ee).

**Verdict: merge after the findings.** What is on the branch is what it
claims to be: part of T44, a study, and four task files. Every gate is green.
The models reproduce exactly, and the learned blue never proposed an
illegal decision in 40 games. The measurement the study and T45 are built
on is misattributed, though (finding 1). The turn-start rule the wave
introduces has no test on the side that matters (finding 2). One decision
the new suite claims to hold is not held (finding 3).

What it read: CLAUDE.md, T44 in full (with "What was done so far"), the
wave 47 "Resuming after" section of STATUS, the wave 46 record for the
format, the whole diff, and the files around it: `tactical_combat.gd`,
`tactical_rules.gd`, `tactical_scenario.gd`, `tactical_victory.gd`,
`rule_based_blue.gd`, `board_features.gd`, `learned_policy.gd`, `combat.py`,
`simulate.py`, `rows.py`, `train.py`, the three rules files, the learning
vectors, `tactical_match.gd`, `tactical_win_rates.gd`,
`tactical_learned_blue_test.gd`, the turn helpers in `tactical_game_test.gd`
and `tactical_bridge_test.gd`, T45-T48, ADR 0008's amendment,
`docs/concepts/learning.md`, the README line and
`docs/design/tactical-references.md`.

What it ran: `make test-python` (293 tests, OK); `make test-godot` (839
cases, 0 failures); `make check` (exit 0); `make tactical-win-rates GAMES=20`
(exit 0; the same figures as T44's table, to the decision);
`check_no_training.py`, `check_addon_deps.py`, `check_no_employer_refs.py`
directly (exit 0 each); `train.run()` in memory. Probes, from the scratchpad
and not committed: the win-rate pairings re-counted per side, and the
rounds of every draw. Ten mutations, listed where they bear on a finding.
Three of the design doc's [V] sources were spot-checked online: the
Wargroove First Turn Advantage page, the AWBW guide, and the Wesnoth RCA AI
page with `src/ai/default/attack.cpp`. Every mutation was undone and
`git status` was clean afterwards, but for this file.

## What was reviewed

Commit 9df4af4: `ControlPoints`, `TurnStart` and their use in `tactical.gd`;
`TacticalScenario.POINTS` and `TacticalRules.POINT_INCOME`; the status line,
legend and README; `LearnedBlue`; `RuleBasedBlue._nearest_walk_to` and the
`_past_red` target; `LearnedPolicy.chance_to_win`, `rank_nodes` and
`graph_for(unit)`; `BoardFeatures`' fifth feature, walkers only, and the
defender's own ground; `strong_against` in the three rules files;
`combat.counter`, typed dataset units and `fight_features`; the retrained
weights; `TacticalMatch`, `tactical_win_rates.gd` and the Make target;
`tactical_learned_blue_test.gd` and the Python tests. Commit 828c3ee:
`docs/design/tactical-references.md`, T45-T48, and T44's and STATUS's
account of the wave.

## Checked and true

- **The five numbers agree across the three places.**
  `BoardFeatures.combat_row`, `TacticalCombat.inputs` and Python's
  `fight_features` count the same friends: walkers only (`type.mobile`;
  `is_walker` also lets an untyped unit through, which the board never has),
  within the same radius of 2, from the same sides. The defender's ground
  is read off `graph_for(defender)` in both Godot places. The counter is the
  attacker's side of the same table in all three. One difference is older
  than this wave and changes no fight: `TacticalCombat._nearest_friend`
  caps a distance at 15 (`mini`), and `BoardFeatures` deliberately does not
  (its own comment says why). A friend 16 or more cells away is 15 to the
  dice and 16+ to the model, on a board where Manhattan distance reaches 21.
  Its weight is -0.046, and no fight lasts 15 rounds.
- **The rules copies.** `spec/combat/rules.json` and both copies have the
  same sha256 (d89bfb2b...). `test_combat_vectors.py:52` and
  `tactical_combat_test.gd:10` hold them byte-equal. The new test holds the
  Godot table equal to `TacticalRules` for the five buildable types.
- **The numbers.** `train.run()` gives 2915 + 953 combat rows, a score of
  0.8604, majority 0.5771, table 0.7051, twinned 62%, 1757 distinct rows and
  counter weight +1.4159, and capture error 0.616 against 1.093. Those are
  the committed weights and every figure in T44, ADR 0008 and
  `learning.md`.
- **The learned blue is never refused.** The probe played 20 games with it
  as blue and 20 as red: 0 refused decisions. Every walk comes from
  `TacticalReach.walks_for`, and `decide_attack` asks `why_refused` first.
- **The points.** Both are plain ground, mirror each other through the
  centre (the test holds this), and touch no building at the start. Each
  pays before the towers fire.
- **Mutations the suites catch.** `is_walker` always true (tower test);
  `defender_terrain` read off `state.graph` (wader test); a point's
  neighbours ignored (contested test); the capture ranking's last point
  walked at instead of the first (ranking test: the reason names the chosen
  point and the runner-up, so the wrong one leaves the other out); Python's
  counter sign reversed, and dataset units left untyped (two Python
  failures each).
- **Invariants 6, 10 and 11.** `LearnedBlue` keeps nothing between
  decisions. Both commits are the owner's alone with no byline. The
  employer gate ran on its term list.

## Findings

### Must fix

1. **The stuck and build figures are both sides added together, and T44,
   STATUS, the study and T45 give them all to the learned side.**
   `tactical_win_rates.gd`, `_measure`: `_counting(red, counted)` and
   `_counting(blue, counted)` share one `counted` dictionary. The win
   rates are per side, and the funds are too. *Reproduced*, re-counted per
   side over the same 20 seeds:
   - rules red against learned blue: red 495 of 5636 decisions stuck
     (8.8%), built 284 of 787; blue 5540 of 10559 stuck (52.5%), built 409
     of 787;
   - learned red against rules blue: red 4653 of 10599 stuck (43.9%),
     blue 532 of 5708.

   Those sums are exactly the script's 6035 of 16195 and 693 of 1574. So:
   - "37% of the learned side's walker decisions" (study §4.1, T45's Goal)
     is 52.5%.
   - "its workshop built nothing on 881 of 1574 turns" (T44, T45) is both
     workshops. Red's 503 non-builds equal 787 - 284 to the turn, so the
     "503 because the rules' build refuses a type that cannot get past
     red's pieces" belongs to the **rules** controller playing red,
     walled in by the learned blue. The sentence says "red's pieces"
     because the rules always say red. The learned blue's own non-builds
     are 378: 377 boxed in, plus 1.
   - "a third of its walkers stuck" (STATUS) is half.

   T45's step 1 aims at both refusals as the learned side's. Its
   acceptance (`rl:stuck-percent:5`) needs a per-side count to mean
   anything.
   *Fix:* count per side in `tactical_win_rates.gd` (one dictionary per
   controller, printed with the side's name). Correct the figures in T44,
   STATUS, the study and T45, and re-read T45's step 1 in light of them.

2. **Nothing holds that the scene opens turns through `TurnStart`.**
   *Reproduced (mutation):* `tactical.gd:_open_turn` put back to the old
   `end_turn` and `towers_fire`, with no points paid. All 839 cases pass.
   `TurnStart`'s header gives this as its reason to exist: "a new rule ...
   would have reached the screen and not the measurements". The test for
   it only calls `TurnStart.open`. The header also says the tests used to
   open turns by hand and implies they no longer do. Six helpers still do,
   and they play whole games without points or towers:
   `tactical_game_test.gd:551,585,597` and
   `tactical_bridge_test.gd:65,75,92`
   (`_play_against_a_parked_runner` is "a whole game").
   *Fix:* a scene test in which a red walker holds a point and red's funds
   rise by `POINT_INCOME` after `end_turn()` twice, as
   `tactical_combat_test.gd:193` does for towers. Move the six helpers to
   `TurnStart.open`, or say in each why not.

### Should fix

3. **`decide_attack`'s threshold is not held.** *Reproduced (mutation):*
   `if best == null or best_chance < policy.threshold()` became
   `if best == null`, so every walker attacks whatever is in reach. The
   suite passes. The retreat test asks `decide_attack` only after the
   retreat, when nothing is in reach, so it returns null for that reason.
   T44's acceptance names "attacks when the combat model clears the
   threshold and retreats when it does not". It is the attack that
   `decide_attack` gates, and a walker that stays on a point beside an
   enemy reaches that call without passing `_attack_or_retreat`.
   *Fix:* a case with the enemy already in reach and a model at 0.1:
   `decide_attack` is null. At 0.9 it is the strike.
   Also unheld: the edge-of-reach retreat that T44 says replaced running
   to the furthest cell. *Mutation:* `_out_of_reach` always returns the
   furthest cell, and the suite passes. T44 reports that this change made
   no difference to the draws, so either keep it with a case that holds it,
   or drop it.

4. **"Learned-against-rules games all end" cannot fail.**
   `tactical_learned_blue_test.gd`, the last test, asserts
   `winner != NOBODY`. `TacticalMatch.play` returns only once that is true
   (`while TacticalVictory.winner(state) == TacticalVictory.NOBODY`). A game
   that never ended would hang the suite, not fail it. Only the
   nothing-refused half has teeth. *Fix:* give `play` a turn guard above
   the round limit and return NOBODY past it, so the assertion can be red.
   Or say in the test that the round limit is what is being relied on, and
   assert the rounds instead.

5. **A draw is counted as 41 rounds.** `tactical_match.gd`:
   `state.turn_number / TacticalScenario.FACTIONS + 1`, read after the
   80th turn. *Reproduced:* all 17 draws in rules against learned, and all
   18 the other way round, report 41. The draws are "after 40 rounds"
   (`TacticalVictory`). T44's 40.2 and 40.5 averages include them. *Fix:*
   count rounds played, not the round the state would open next.

6. **No shared vector carries the fifth feature.** Every learning-vector
   case has `"counter": 0`, and every vector unit is untyped
   (`spec/vectors/learning/*.json`). So ADR 0007's guarantee, that both
   languages compute the same row from the same board, does not cover the
   counter. Two tests stand in for it, written separately on each side
   (`test_the_counter_is_the_attackers_side_of_the_table`,
   `test_the_combat_row_carries_the_counter_from_the_attacker_s_side`).
   They agree today. Nothing makes them agree tomorrow. *Fix:* one vector
   with typed units, with the counter at +1 and -1. Both runners have to
   learn to read a unit's type for it, and the task should say so if that
   is left for later.

7. **The study overstates Wesnoth's `attack_close`, and T46 builds a rule
   on it.** `src/ai/default/attack.cpp`: `attack_close` is
   `distance_between(*i, loc) < 4`, which means within three hexes, not
   four. It waives one thing: the sanity check that returns -1 for an
   attack with `vulnerability > 50`, `vulnerability > support*2`,
   `chance_to_kill < 0.02` and `aggression < 0.75`. Retreat is a separate
   candidate action. The study's "once someone has committed nearby, the
   caution check is waived ... the mechanism that stops one unit at a time
   from retreating" (§2.1) is marked [I], but T46's Goal states it as
   Wesnoth's rule: "the caution check is waived within four cells ... so
   pieces join a fight instead of leaving one at a time". Its step 2 is
   "no retreat ... within four cells". The rule may well be right for this
   board. It is this repository's, though, and should be presented as
   inspired by `attack_close` rather than taken from it. The other
   spot-checks hold: the RCA scores, including move-to-any-enemy at 1,000
   and recruitment at 180,000; the formula's quoted lines (the doc leaves
   out the exposure term between them); the AWBW day-limit, capture-limit
   and predeployed-infantry quotes; and Wargroove's four FTA counters.
   "Recommended by Chucklefish" is attached, on the page, to keeping
   interactions symmetrical, which it then calls a half-turn advantage.
   The doc's reading is fair.

8. **T47's acceptance does not state its band.** Its Goal and step 1 want
   red's mirror win rate in 40-60%. The command
   `--at-most rr:red:60 --at-most rr:blue:60 --at-most rr:draw:5` over 100
   games accepts red at 35 (35 red, 60 blue, 5 draws). An `--at-least`, or
   a red limit written as a band, says what the task means. T45's and
   T46's commands use outcomes the script rejects today with exit 2
   (`stuck-percent`, `blue-funds-left`, `flips-percent`). Their steps say
   the script must gain them, so they are honest. T45's also depends on
   finding 1.

### Minor

9. **Texts the code contradicts.**
   - `tactical_match.gd:9`: "used ... by `export_capture_rows.gd`, which
     cuts the capture model's rows out of these games". No such file
     exists, and T44 says the capture rows are not done.
   - "Four" where there are now five: `tactical_combat.gd:189` ("the same
     four numbers the learned model sees"), `rows.py:80`, `train.py:40`,
     and `report.py:185`, which prints "Four weights" into the committed
     `weights.txt:69`.
   - `TurnStart`'s header on the tests (finding 2).
   - `LearnedBlue`'s reasons say "red's workshop" and "red holds it" when
     it plays red in the `lr` pairing. `TacticalMatch` admits this for the
     rules, and the learned blue inherits it. Nobody reads it headless
     today, but T44's step 4 will put a controller key on the screen.

## What was done about them

Each finding was answered on this branch, before the merge.

1. **Fixed.** `tactical_win_rates.gd` counts each side on its own and prints
   both. Re-measured: the learned blue is stuck on 5540 of 10559 walker
   decisions (52.5%), 4653 of 10599 (43.9%) as red; its workshop missed 378
   of 787 turns, 377 boxed in; the 503 "cannot get past" refusals are the
   rules controller's. T44's table, STATUS, the study and T45's goal and
   step 1 now carry these numbers, and T44 says the first table was wrong.
2. **Fixed.** `test_the_scene_pays_a_point_when_it_opens_the_holder_s_turn`
   mounts the scene, ends red's turn and holds blue's funds to income plus
   one point. The review's mutation -- the old `_open_turn` -- now fails it.
   The six helpers in `tactical_game_test.gd` and `tactical_bridge_test.gd`
   open turns through `TurnStart`; the four in `tactical_combat_test.gd`
   stay, because they open a turn to test the towers alone.
3. **Fixed.** Two tests: no attack below the threshold (and one above), and
   a retreat that stops at the edge of a mortar's reach (6, not the 7 the
   old retreat ran to). Removing the threshold, or running as far as it
   can, each fails its test.
4. **Fixed.** `TacticalMatch.play` stops after the round limit's turns and
   returns `NOBODY`, so a game that will not end fails the assertion instead
   of hanging the suite.
5. **Fixed.** A draw reports 40 rounds. The averages are now 39.4 and 39.6.
6. **Fixed.** `spec/vectors/learning/a-counter-on-the-board.json`: typed
   units, a runner and a mortar read from both sides (+1 and -1), a shield
   as a friend, the published five-feature model, predictions from a
   throwaway dot product. Both loaders read a unit's `type`. Reading the
   counter backwards fails both languages.
7. **Fixed.** The study says what the source says -- `< 4`, and only the
   near-hopeless-attack check -- and calls the retreat rule an extension of
   this board's own. T46's goal and step 2 say the same, at three cells.
8. **Fixed.** `tactical_win_rates.gd` takes `--at-least`; T47's acceptance
   is the band, `--at-least rr:red:40 --at-most rr:red:60`.
9. **Fixed, but one.** `tactical_match.gd` no longer names a script that does
   not exist; "four" is "five" in `report.py` (and so `weights.txt`),
   `train.py`, `rows.py`, `descent.py` and `TacticalCombat.inputs`, with the
   figures re-measured (3868 rows, 1757 distinct, 62% twinned, 0.7051).
   **Not fixed:** a controller playing red still says "red's workshop".
   Nobody reads it until T44's step 4 puts a controller on the screen, and
   that step is where the sentences take the side's name.

On the way, a trap of the author's own making, now in CLAUDE.md: a
same-size mutation of `simulate.py`, restored within the same second,
left Python running the mutant from its bytecode cache, and
`lint-no-training` reported the committed weights as stale. Clearing
`__pycache__` showed the weights were right.
