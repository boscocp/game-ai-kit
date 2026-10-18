# Review: wave/51-the-second-player-and-the-last-round

One fresh context reviewed it, in the main worktree, at 3e8fbc1 (one commit
on `main`).

**Verdict: merge after finding 1. Findings 2 and 3 should be answered in the
same pass, because they are one test each.** The numbers are honest. Every
figure in T47's two tables, the STATUS row and the commit message is what
the commands print. The acceptance passes, and so do the gates. The funds
row of the sweep is wired, and it really changes nothing. The tally is
counted correctly through whole games, and no path that makes a state
drops it.

What is weak is the test of the rule itself:
- The *order* of the score is the substance of step 2. Swapping its first
  two keys leaves every suite green (finding 1).
- The count of point turns across real turns is unheld. A tally wiped at
  every `end_turn` also leaves every suite green (finding 2).
- What one unit of "turns holding points" means is said three ways, and
  the code is held to none of them (finding 3).

What it read:
- CLAUDE.md;
- T47 in full, with "What was done";
- STATUS's "Resuming after 2026-10-18 (wave 51)" section and the T47 row;
- `docs/design/tactical-references.md` §1.4, §1.5, and §4 items 2 and 4;
- the wave 50 record, for the format;
- the whole diff.

Around the diff it read:
- `BoardState` in full, for every path that copies a state;
- `TurnStart.open`, `ControlPoints`, `TacticalCombat._resolve` and
  `towers_fire`;
- `TacticalRules`' unit types, for the costs: buildings cost 0;
- `TacticalScenario`'s map and placements;
- `tactical.gd`'s `_open_turn` and `_status_text`;
- `test/tactical_match.gd`;
- `tactical_win_rates.gd`'s argument parsing;
- `spec/pddl/tactics.json`'s init.

What it ran, each exit code read directly rather than through a pipe or
make:
- `make check`: exit 0, 908 Godot cases.
- `make test-godot` on its own: exit 0, 908 of 908, 46 suites.
- `check_readability`, `check_addon_deps` and `check_no_employer_refs`,
  with the term list on disk: exit 0 each.
- `check_commit_msg` on 3e8fbc1's message: exit 0. The author is the owner
  alone, and there is no byline.
- The acceptance at the size the task names:
  `tactical_win_rates.gd -- 100 --at-least rr:red:40 --at-most rr:red:60
  --at-most rr:draw:5`. Exit 0. Every row equals the record's second table:

  | pairing, 100 games | red | blue | draws | settled at the round limit |
  |---|---|---|---|---|
  | rr | 59 | 41 | 0 | 23 |
  | rl | 0 | 100 | 0 | 61 |
  | lr | 100 | 0 | 0 | 61 |
  | rp | 33 | 67 | 0 | 13 |
  | pr | 28 | 72 | 0 | 58 |

- `--pairings` refusals:
  - `--pairings xx`, a bare `--pairings`, `--pairings rr,`, and a limit on
    a pairing that is not played (`--pairings rr --at-most rl:red:5`).
  - Each exits 2 before playing a game.

Probes, from scratch scripts under `godot/test/`, all deleted afterwards:
- **P1, a whole-game probe.** It copies `TacticalMatch.play`'s loop over
  seeds 0-39 for rr, rl and lr. It recounts `ControlPoints.held_by` at
  every turn opening and compares that with the final `tally`. It also
  scores each game that reaches the limit twice:
  - as it stands after blue's round 40;
  - after round 41 has opened, which is what the code reads.
- **P2, the counter sweep re-run without editing a rule.** It takes
  `TacticalScenario.build()` and alters it, removing the shield and adding
  0, +2 or +3 to blue's funds. Then it plays rules against rules over
  seeds 0-99.

Then nine mutations, each against the six suites that name the score, the
tally, the scenario or the board state:
- `tactical_last_round_test`;
- `tactical_game_test`;
- `tactical_bridge_test`;
- `tactical_combat_test`;
- `board_state_test`;
- `tactical_scenario_test`.

All nine are undone. `git status` shows only this file.

## What was reviewed

The code:
- `BoardState.tally`, and its copy in `duplicate_state`;
- `ControlPoints.POINT_TURNS` and `pay`;
- in `TacticalVictory`: `winner`, `at_the_limit`, `score`,
  `_higher_score`, `rule`, `announcement` and `_at_the_limit_said`;
- in `TacticalRules`: the three `SECOND_PLAYER_*` constants;
- in `TacticalScenario`: `_counter_for_the_second_player` and
  `SECOND_PLAYER_SHIELD_CELL`;
- the `at_the_limit` field in `tactical_match.gd`;
- `--pairings` and `at-the-limit` in `tactical_win_rates.gd`.

The tests: `tactical_last_round_test.gd`, and the two changed cases in
`tactical_game_test.gd`.

The docs:
- the README's tactical paragraph;
- T47's record;
- the STATUS row and resume section;
- the commit message.

## Checked and true

- **Invariant 2 holds.** `tally` is a field with a doc comment. `ai_core`
  only copies it, deep (`duplicate(true)`), beside `funds` and `upgrades`,
  and never reads it. `check_addon_deps` is green.
- **Every path that makes a state carries the tally.** These all go
  through `duplicate_state`:
  - `apply`, `produce`, `buy` and `end_turn`;
  - `TacticalCombat._resolve`, both of its copies;
  - `ControlPoints.pay`.

  The only other `BoardState.new` calls in the game are listed below.
  Neither runs mid-game:
  - `TacticalScenario.build`, where a new game starts with an empty tally;
  - `main.gd`'s skirmish, which has no tally.

  Nothing serialises a state.
- **The tally counts what it says, through whole games.** P1 covered 120
  games across rr, rl and lr. In every one, the final tally equals the
  recount of points held at each turn opening.
- **The funds variant is wired, and changes nothing.** In P2, blue starts
  with 4, 6 or 7. The +2 and +3 rows are 70-30-0, the same as no counter,
  and **0 of 100 games differ** from the no-counter row. The shield row is
  59-41-0, with 43 of 100 games different. That matches the record. The
  cause the record gives fits: the rules end games with 31-34 funds unspent.
- **The shield's placement is legal and changes nothing else.**
  - Its cell, (11, 0), is open ground and not on a point.
  - Its id, 11, follows the ten placed units, and `next_id` becomes 12.
  - It does not take a production cell of blue's workshop at (12, 1).
  - The PDDL init (`spec/pddl/tactics.json`) is abstract and does not
    count units.
  - The planner's suite is green.
- **The round limit changes no loop.** `TacticalMatch` still stops when
  `winner` is no longer `NOBODY`, which at turn 80 it now never is, as it
  never was before.
- **Edge cases on the limit hold:**
  - A workshop that falls on the last turn wins outright, since `winner`
    asks about workshops first. `at_the_limit` is then false, so a fallen
    workshop's health never enters a score.
  - Both workshops cannot fall in one action.
- **§4 item 2's acceptance is met as well as the task's.** It asks for
  draws at or below 5% over rr and learned-v-rules. The measured rate is 0
  of 100 in each.
- **Mutations caught:**

  | | mutation | what went red |
  |---|---|---|
  | M2 | a draw whenever the first key ties | `turns_holding_points_decide...`, `the_round_limit_goes_to_the_higher_score` |
  | M4 | tally copied shallow | `a_tally_is_copied_with_the_state_not_shared` |
  | M5 | tally not copied at all | `a_held_point_is_counted...` |
  | M8 | point turns never counted | `a_held_point_is_counted...` |
  | M9 | shield not placed, constant still true | `blue_moving_second_starts_with_a_shield...` (error), `the_round_limit_goes_to_the_higher_score` |

  The planted equal position (`_mirrored()`) would also catch ties handed
  to either side.
- **Invariants 10 and 11 hold.** Nothing from the employer is present, and
  the commit has no byline.

## Findings

### Must fix

1. **The order of the score is not held. Swapping its first two keys
   leaves every suite green.**
   `tactical_victory.gd:67`; `tactical_last_round_test.gd:18-40`.

   *Mutation M1:* `return [held, workshop, standing]`, so points come
   before the workshop. All six suites stay green: 145 cases, 0 failures.

   *Why the tests miss it.* Each of the three comparison tests varies
   *one* key and leaves the others equal:
   - `healthier_workshop`: red's workshop at 19, nothing else different;
   - `turns_holding_points`: equal workshops, a 3-2 tally;
   - `left_standing`: one extra blue shield.

   Any order of the three keys passes all three. Nothing sets two keys
   against each other. Yet the order is what step 2 specifies, what
   `rule()` puts on screen, and what decides real games:
   - In P1, the workshop key decided 48 of the 53 games that reached the
     limit.
   - The points key decided 5.
   - The standing key decided none.

   *Fix:* two cases where an earlier key and a later key disagree:
   - red's workshop healthier, but blue ahead on points and standing:
     red wins;
   - workshops equal, red ahead on points, blue ahead on standing: red
     wins.

### Should fix

2. **Point turns counted across real turns are not held. A tally wiped at
   every turn change leaves every suite green.**
   `board_state.gd:287` (`end_turn`); `turn_start.gd:22`;
   `tactical_last_round_test.gd:43-53`.

   *Mutation M6:* `next.tally = {}` in `end_turn`. All six suites stay
   green: 145 cases.

   The counting test calls `ControlPoints.pay` twice on the same state.
   It never passes a turn. In play, the tally goes through `end_turn`, then
   `pay`, then the towers' `_resolve`. A reset or drop anywhere on that way
   would leave the second key counting only the last turn, and nothing
   would notice. The shipped code is correct: P1's recount matched in 120
   of 120 games. It is just unguarded.

   *Fix:* a test that opens turns with `TurnStart.open` while a walker
   holds a point, and reads the tally a round or two later.

3. **"Turns holding points" means points × turns in the code, and is said
   three ways around it.**
   `control_points.gd:46` and `:62`; `tactical_victory.gd:16` and `:81`;
   README.md:114; T47 step 2; `tactical-references.md` §4 item 2.

   What each place says:
   - `pay` adds `held.size()`, so two points held for one turn count 2.
   - The `POINT_TURNS` comment and `TacticalVictory`'s header say that,
     correctly: "points it held summed over the turns", "a point held for
     a turn is one".
   - The screen (`rule()`), the README and the STATUS row say "turns
     holding points". A player reads that as turns.
   - The task says "rounds spent holding points", and the reference says
     "control-point rounds held".

   *Mutation M7:* `+ 1` per turn instead of `+ held.size()`. The suites
   stay green, so whichever meaning ships is unheld too.

   *Fix:*
   - Choose one meaning. Points × turns is defensible, since it is what
     income pays.
   - Say it the same way on screen, in the README and in STATUS.
   - Hold it with a test where one side holds both points.

### Low

4. **The third key rewards the counter, and cannot see a lost building.**
   `tactical_victory.gd:59-67`; `tactical_game_test.gd:679-686`.

   *The counter.* "What is left standing" adds `type.cost`, and blue's free
   shield costs 2. An untouched opening at the limit is therefore a blue
   win. The changed game test asserts exactly that, and calls it "worth its
   cost in what is standing". The counter exists to pay back red's tempo.
   Counting it again in the tiebreak is a second payment, and it is not
   stated as a rule.

   *Buildings.* Towers and workshops cost 0, so a side that lost its bolt
   tower ties a side that kept it. A shield at 1 health also counts the
   same as a fresh one. The reference's "unit value" is usually scaled by
   health (Advance Wars).

   Measured, none of this has decided a game yet (0 of 53 in P1).

   *Fix:* either count from the opening's baseline, or say in `rule()`'s
   doc that the counter counts. The owner may prefer to decide this.

5. **The limit is read after round 41 has opened.**
   `turn_start.gd:21-30`; `tactical.gd:414-418`; `tactical_match.gd:39-41`.

   At turn 80, `TurnStart.open` runs before `winner` is asked:
   - red is paid and counted for the points it holds;
   - red's towers fire one more volley.

   Blue's towers fired 40 times by then, and red's 41. The tally comes out
   even (40 payments each, because red's turn 0 never pays), but the volley
   can change "left standing".

   Measured, it changed no outcome: P1 found 0 of 53 games that reached
   the limit with a different winner before and after the opening.

   *Fix:* say it in `TacticalVictory`'s header. Or score the state as blue's
   round 40 left it.

6. **The old draw sentence is now unreachable, and a test holds it.**
   `tactical_victory.gd:91-92`; `tactical_game_test.gd:686`.

   `tactical.gd:466` always passes `state`. A `DRAW` without
   `at_the_limit` cannot happen. So "a draw: 40 rounds, and nobody
   destroyed a workshop" is never shown, and the renamed test asserts on
   that sentence rather than on the one a player sees.

   *Fix:* assert on `announcement(winner, state)`, and drop the stateless
   branch or the default argument.

7. **"Beside its workshop" is diagonal.**
   `tactical_scenario.gd:50-51`; `tactical_rules.gd:61`; STATUS:100.

   Blue's workshop is at (12, 1) and the shield at (11, 0). On this board,
   "beside" means one of the four steps (`GridGraph.DIRECTIONS`,
   `why_no_room`, `ControlPoints.holder`). Either move the cell, or write
   "diagonally beside" / "next to".

### Not a defect, for the record

- **The funds counter is rejected for the AI's sake, not the player's.**
  P2 confirms it changes 0 of 100 games because the rules never run short
  of money. Against a human red, who does run short, it was not measured.
  The task's record already gives that cause. This only notes that the
  sweep answers the AI mirror alone.
- **The learned side's 100-0 needs its last column.** The record and
  STATUS both read it that way. The rl and lr figures are no longer
  comparable with waves 47-50's draws.

## What was done about them

Answered on the branch, in one commit after 3e8fbc1; `make check` exits 0
afterwards. No game rule changed, so the acceptance figures stand.

1. **Fixed.** Two tests set keys against each other: red with more
   point-turns and a weaker workshop loses, red with more point-turns and
   less standing wins. Swapping the first two keys turns the first red
   (planted and undone).
2. **Fixed.** A test opens four real turns through `TurnStart` with a red
   runner on a point and expects 2; wiping the tally at each change of turn
   turns it red (planted and undone).
3. **Fixed by naming it.** The count stays point-turns -- each point, each
   turn -- because it keeps a second point worth holding; the header, the
   screen, the README, STATUS and T47's record now say "point-turns held",
   and the record notes the task said rounds. A test holds two points for
   one turn as 2; counting one per turn turns it red.
4. **Recorded.** `TacticalVictory`'s header says the second player's shield
   counts in what is left standing like any piece; that is what a counter is
   for, and the changed test says so.
5. **Recorded.** The header says the score is read when round 41 would open,
   and that the review measured it changing no outcome.
6. **Fixed.** That assertion now checks the announcement of the score that
   the game can actually show.
7. **Fixed.** "Diagonal to its workshop" wherever it said "beside".
