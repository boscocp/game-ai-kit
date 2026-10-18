# Review: wave/48-the-planner-plays

One fresh context reviewed it, in the main worktree, at a7378f9 (one commit
on `main`).

**Verdict: merge after findings 1 to 4.** The planner itself is right. A\*
with h_max returns shortest plans. The budget is exact. A partial plan runs.
The packing holds 63 predicates and refuses 64. Every acceptance command
exists and exits 0, and every published number is the number its command
prints. What the wave says about the *game* is weaker than what the game
does, though. The rule that decides where the board is on the plan has no
test, and replacing it turns 7 wins in 20 into 0 with every gate green
(finding 1). The plan moves no walker: every move is the rules' with a
different sentence (finding 2). The partial-plan path the task asks for
can never run in the game, and nothing tests it (finding 3). The benchmark
cannot tell the heuristics apart, because h_max is exact on every board it
holds (finding 4).

What it read: CLAUDE.md; T11 in full, with "What was done"; the wave 48
"Resuming after" section of STATUS; ADR 0010 and its amendment; the wave 47
record for the format; the whole diff. Around the diff it read
`rule_based_blue.gd` (header and `decide_move`), `blue_turn.gd`,
`tactical_match.gd`, `tactical_win_rates.gd`, `tactical_scenario.gd`
(`across_the_river`, the map), `tactical_rules.gd` (costs, income, unit
types), `TacticalCombat.distance`, `tactical.gd` (`new_game`, the swap),
`planning_vectors_runner.gd`, and `check_branch_base.py` (`--check-review`).

What it ran, each exit code read directly rather than through a pipe:
- `make test-godot`: exit 0, 867 cases. All 10 cases in
  `heuristic_planner_test.gd` and all 15 in `tactical_planner_test.gd` are
  listed as PASSED.
- `make test-python`: exit 0, 294 tests.
- `make test-vectors`: exit 0. The `spec/pddl` run prints "1 file(s), 0
  failure(s)".
- `planner_properties.gd`: exit 0. It prints "165 boards, 632 of 660 plans
  found".
- `grep -q "domain" spec/pddl/tactics-domain.pddl`: exit 0.
- `planner_benchmark.gd`: exit 0. It prints 6094 / 6094 / 169 / 169 worlds,
  5.706 / 0.818 / 0.560 / 0.546 ms, 5.18 steps and 4 unsolved.
- `make check`: exit 0.
- `make tactical-win-rates GAMES=20`: exit 0, and every figure is T11's: rr
  20-0, rp 13-7, pr 0-20.
- `check_addon_deps`, `check_readability`, `check_no_training`,
  `check_no_employer_refs` (the term list was on disk), `check_tiers`,
  `check_acceptance`, and `check_commit_msg` on a7378f9's message: exit 0
  each.

Probes, from scratch scripts deleted afterwards:
- the benchmark's 28 boards, split into solved and unsolved;
- the `docs/godot/planning.md` snippet, which printed `true 12 8` and
  `true true march_to_node -> take_the_node`, as the page says;
- a 62-step chain over exactly 63 predicates, solved by A\* and by
  breadth-first;
- budgets of 0, 1 and 2, which visit 0, 1 and 2 worlds; the first two return
  `ran_out` and the third a 1-step partial plan.

Seventeen mutations followed, listed where they bear on a finding. Each ran
the two new suites, `planning_test.gd`, the properties and the benchmark,
and three of them also ran the win rates. Every mutation was undone, and
`git status` was clean afterwards apart from this file.

## What was reviewed

`PackedDomain`, `RelaxedCost`, `HeuristicPlanner` and the `partial` field
of `PlanResult`. `TacticalPlanBridge`, `PlannedBlue`, the `begin_turn`,
`plan_lines` and `plan_marks` hooks on `BlueController` and `BlueTurn`.
`TacticalDecision.buy`; the swap key, overlay and status lines in
`tactical.gd`, `intent_view.gd` and `tactical_status.gd`.
`spec/pddl/tactics-domain.pddl`, the opening problem, `tactics.json` and the
game's copy. The Python vector test's second directory. The
`planner_properties.gd` extension, `planner_benchmark.gd`,
`heuristic_planner_test.gd`, `tactical_planner_test.gd` and the
win-rate pairings. The docs: the addon header, `planning.md` (concepts and
godot), `planning-in-strategy-games.md`, the ADR 0010 amendment, T11, STATUS
and README.

## Checked and true

- **A\* returns the shortest plan under h_max.** It tests the goal on
  expansion (`heuristic_planner.gd:178`). A world reached more cheaply is
  queued again, and the dearer copy is skipped as stale when it comes off
  (`:173`), so reopening is handled. Ties are broken deterministically. The
  properties held h_max against an exhaustive search on 156 random plans.
  The separating domain keeps it apart from h_add.
- **The budget is exact.** `visited` counts only fresh expansions and is
  checked before each pop, and budgets of 0, 1, 2 and 3 never exceed
  themselves. Breadth-first stops at `next >= budget`.
- **A partial plan runs.** `steps_to` follows parents fixed at generation,
  so every prefix is a chain of applicable actions. An empty one is
  reported as `ran_out`, not as a partial plan.
- **`UNREACHABLE` pruning is sound.** The delete relaxation reaches a
  superset of what the real problem reaches, whichever way costs are
  combined. The four unsolvable benchmark boards are each declared
  impossible with 0 worlds visited, and breadth-first agrees after
  exhausting them.
- **The bits.** In Godot 4, `&` binds tighter than `==`, so
  `from & wanted == wanted` means what it says. `after` deletes, then adds,
  and a test holds the order. 63 predicates pack, and 64 push an error and
  return `gave_up`.
- **The domain is one thing in three places.** `tactics.json` and the game
  copy are byte-equal, held by a test. `make test-python` holds the PDDL
  equal to the JSON. The opening board reads as `tactics-opening-problem.pddl`,
  also held by a test.
- **The facts read the board as the comments say.** The banks split at
  column 7, and the bridge's two cells are one on each bank. Guard radius 2
  matches the fight's `nearby_radius`. `funds_banked` means 5, the forge,
  which is the dearest purchase (ram 4). Forge plus ram is 9 funds, three
  turns of the base income of 3. Before control-point income, that is the
  header's reason for `REPLAN_EVERY`.
- **New games.** `TacticalMatch` hands one `PlannedBlue` twenty games in a
  row. `turn_number <= _seen_turn` resets the plan, and a mutation to `<`
  fails its test. The scene's C key builds a fresh controller and a fresh
  game.
- **No decision is refused**, from either seat, over six seeds (test).
- **Mutations that the suites catch.** h_max computed as h_add, and a guess
  doubled, each fail a gdUnit case on its own. The review checked this with
  the visited-count case disabled, because a failing case hides the ones
  after it. Deletes ignored in `PackedDomain.after` fails the unit tests,
  the properties and the benchmark. The budget check as `>` fails the unit
  tests and the benchmark. A partial plan missing its first step fails the
  unit tests. `zone_of`'s home and across swapped fails the unit tests and
  the properties. The new-game reset weakened fails its test.
- **Invariants 2, 6, 10 and 11.** `ai_planning` names nothing in the game,
  and `check_addon_deps` passes. Nothing trains. The commit carries the
  owner's name alone, with no byline.

## Findings

### Must fix

1. **Where the board is on the plan is not held by any test, and getting
   it wrong loses every game.** `planned_blue.gd:12-16` and `:208-217`:
   the header's central claim is that each call finds the *latest* step
   from which the rest of the plan runs. *Reproduced (mutation):*
   `range(plan.steps.size(), -1, -1)` became `range(0, plan.steps.size() + 1)`,
   so the earliest step is taken. Both new suites, the properties and the
   benchmark stay green. `tactical-win-rates` with 20 games moves rp from
   13-7 to **20-0**; pr stays 0-20. Here is why. Once the ram stands at
   home, the suffix from `bank_income` also runs: bank, build a ram, cross,
   and so on. Taking it makes the workshop buy rams again instead of
   letting the plan move on. No test builds a board on which two suffixes
   run.
   *Fix:* a case on the opening plan after the forge and the ram are bought
   (ram home, forge owned, funds banked). `next_step` is the cross, and
   `decide_build` buys nothing for the plan. A second case on a board where
   the ram has died: `next_step` falls back to the purchase.

2. **The plan decides no walker's move, and T11 says it does.**
   `planned_blue.gd:96-104`. `decide_move` returns `super.decide_move` in
   both branches; only `reason` differs. `RuleBasedBlue` already walks
   every unit at the enemy workshop (`rule_based_blue.gd`, header), and
   attacks are the rules' too. Several texts claim otherwise:
   - T11 "What was done" (`:112`): "The plan decides purchases ... and
     which walker type goes where".
   - The header (`planned_blue.gd:5-7`): "which walker type goes where".
   - STATUS: "buys the forge, builds the ram and sends it". The rules would
     send it anyway.
   - Step 2 asks that a planned action "becomes a `Move`". Here a move step
     becomes a sentence.

   The plan's whole effect on play is the workshop's purchases. That also
   explains two mutations that survived and changed no game:
   - `REPLAN_EVERY * FACTIONS` as `REPLAN_EVERY` replans every 1.5 own
     turns. rp stays 13-7 and pr 0-20.
   - `funds_banked` true at any funds also leaves 13-7 and 0-20.

   The step numbers on walkers (`plan_marks`) label pieces the plan does
   not steer.
   *Fix:* say what is true: the plan chooses purchases, and the walker
   steps are annotations on the rules' moves. The alternative is to make a
   move step change a move, for example a walker the plan does not name
   holding at home. Either way, correct T11, STATUS, the header and the
   README row ("forge, ram, siege").

3. **The partial plan is never used by the game, nothing tests the game's
   handling of it, and two texts describe it differently.**
   - `PlannedBlue.BUDGET` is 2000 (`:55`). Every plan the game makes on
     the benchmark's boards takes at most 8 worlds, so `partial` is never
     true in play.
   - *Reproduced (mutation):* `_aim` set to the goal even for a partial
     plan (`:190`) survives every suite. So does the "partial plan's steps
     were done" replan, disabled at `:180`.
   - The task's step 6 (T11 `:42`) and `PlanResult.partial`'s doc
     (`plan_result.gd:499-502`) say the game "acts on its first step" and
     asks again. `PlannedBlue` follows the whole partial plan until its
     steps are done or the cadence fires. The ADR amendment says the
     latter.

   *Fix:* make the budget injectable. Add a case in which a tiny budget
   gives a partial plan that is carried out, and one where a replan follows
   when its steps are done. Make `PlanResult`'s doc and T11 step 6 say what
   `PlannedBlue` does, or make it do what they say.

4. **The benchmark's first assertion cannot fail on this domain, and its
   table measures less than the docs say.** `planner_benchmark.gd`,
   `heuristic_planner.gd:19-35`, and the same table in two concept pages,
   the ADR and STATUS.
   - **h_max is exact here.** On all 24 solvable boards A\* visits exactly
     plan length + 1: 7 worlds for each 6-step plan, 8 for the one 7-step
     plan. That is the whole 169. So "h_max's plans are exactly as long as
     breadth-first's" holds for any guess that is not grossly wrong.
     *Reproduced:* h_max computed as h_add, and a guess doubled, both leave
     the properties and the benchmark green. Only the gdUnit cases catch
     them. The docs' explanation ("plans are short and nearly unique") is
     true but stops short of saying that the table cannot separate the two
     guesses. "The heuristic the game uses is the one the table picks"
     (step 7) was therefore not a choice the table could make.
   - **The 28 boards are from rules-against-rules games.** The header says
     so (`:8-9`); the docs say "28 boards from real games". None of them
     has `forge_owned`, any ram fact, or `their_workshop_unguarded`. So the
     boards the planner plans from after its first purchase are not in the
     table.
   - **Four of the 28 have no plan.** In each, the bridge is shut and the
     workshop guarded. Breadth-first spends 696 of its 6094 worlds
     exhausting them, and A\* spends 0. On solvable boards it is 5398
     against 169, about 32-fold, not 36. The 5.18 "steps on average"
     counts the four as 0; on solvable boards it is 6.04.
   - **The header says the empty world is "where the plan is longest"
     (`:10-11`).** The empty world has no plan: it has no `bridge_open` and
     no unguarded workshop, so nothing can reach the goal. It is one of the
     four.

   *Fix:*
   - Take the problems from planner games as well, as the properties
     already do.
   - Print solved and unsolved problems on separate lines.
   - Correct the comment about the empty world.
   - Say in the docs that h_max is exact on every solvable board here, so
     the tie says nothing about guidance.
   - Optionally, add a problem set on which the guesses differ, such as
     the separating domain or the generator that found it.

### Should fix

5. **The win-rate script counts the forge as "built nothing".**
   `tactical_win_rates.gd:139` counts `decision.order != null` only. Its
   output for rp reads "built nothing 20 times: plan step 1 of 6,
   buy_the_forge: buys the forge, which a ram needs", and pr shows the same
   line. So "built on 79 of 183 workshop turns" undercounts the planner's
   purchases. *Fix:* count a buy as a purchase.

6. **A purchase of the forge is drawn as a hold.** `intent_view.gd:47-57`
   has no `"buy"` case, so the decision falls through to the ring, which
   the header calls "the piece that is staying put". The one decision the
   rules never make looks on screen exactly like doing nothing. Only the
   reason text tells them apart (invariant 13). *Fix:* draw a buy like a
   build, or with its own mark, and add it to the overlay test.

7. **What the planner cannot see goes unsaid.** The domain has no action
   that clears the bridge or removes a guard. So on any board where the
   bridge is shut and the workshop is guarded, the planner finds no plan
   and the rules play the whole turn. That happens on 4 of the 28
   benchmark boards and on 28 of the 660 property calls (7 boards in
   every search). That is an honest STRIPS answer about this abstraction.
   T11, the PDDL's comment block and the ADR amendment should still say
   so, beside "a fight on the bridge is not that question".

### Minor

8. **Status lines that misreport.**
   - `planned_blue.gd:117`: with `next_step == -1`, which means the plan
     stopped running, every step is marked "done". `_find_the_place`
     recomputes the step on every decision, so this can show mid-turn when
     a precondition breaks during blue's own turn.
   - `planned_blue.gd:278`: any refusal of a build reads "saves -- ...".
     That includes no room beside the workshop, which `free_cell_beside`
     reports as "(12, 1) is not next to unit 6", already seen in the rules'
     output.
9. **Unheld lines.** Each mutation below survived every suite:
   - the cadence at half its length (finding 2);
   - `bank_income` always skipping to the next purchase. It holds with a
     different sentence, so nothing changes;
   - the stale-entry skip in A\* removed (`heuristic_planner.gd:173`).
     This is equivalent on the tested domains, because h_max is
     consistent and never reopens a world.

   None is wrong today. The cadence is the one worth a case: it does
   *not* replan at 2 or 4 turns.
10. **Step 7 narrowed, and disclosed.** Strings against bits is measured
    for breadth-first only, and T11, the header and the ADR say so. The
    task is marked done with that part of step 7 not done, so the owner
    should accept the narrowing explicitly. Separately, "28 in 20000"
    (`heuristic_planner_test.gd:57`, T11) has no command behind it: the
    generator that found the separating domain is not in the repository.
11. **The record's name.** The brief that commissioned this review named
    the file `the-planner-plays.md`, but `check_branch_base.py
    --check-review` looks for `docs/reviews/<branch slug>.md`, which is
    `48-the-planner-plays.md`. It is written there so that `make
    wave-merge` finds it.

## What was done about them

Answered on the branch, in one commit after a7378f9. `make check` exits 0
afterwards (874 Godot cases), and `make tactical-win-rates GAMES=20` still
gives 13-7 and 0-20 for the planner's two seats.

1. **Fixed.** `tactical_planner_test.gd` now holds where the plan is: with
   the forge and a ram on the board, the next step is `cross_the_bridge_ram`
   and the workshop says the plan buys nothing more. Taking the earliest
   runnable step instead turns two cases red (planted and undone).
2. **Fixed by saying what is true.** The plan decides purchases; it moves no
   walker the rules would not, because every walking step in this domain ends
   where the rules' walk ends. `planned_blue.gd`'s header, T11's record,
   STATUS, the README row and ADR 0010's amendment now say so, and a test
   pins it: a walker a step names makes the rules' decision, with the step in
   its reason. Step 2's "a planned action becomes a Move" is recorded as half
   done, on purpose. A domain whose walking steps end somewhere the rules do
   not go -- staging, the bridge -- is where that changes, and it waits for
   T45-T48.
3. **Fixed, and it found a bug.** `PlannedBlue.budget` is a variable a test
   can lower; a game played at a budget of 2 showed every call coming back
   as "found none". h_max is flat across banking steps, so no expanded world
   looked strictly nearer than the start and the partial plan was empty.
   `HeuristicPlanner` now breaks ties for the nearest world towards the
   deeper one (`_looks_nearer`), the test asserts a partial plan is played
   without a refusal and replaced when its steps are done, and removing the
   tie-break turns it red. `PlanResult` and `PlannedBlue` now say the game
   follows a partial plan's steps rather than its first step only, and T11's
   record notes the difference from step 6. A call that gave up and one that
   proved there is no plan are worded differently on screen.
4. **Fixed in the numbers, disclosed in what it cannot do.** The boards now
   include the planner's own games from both seats (forge, ram and
   unguarded workshops among them): 66 boards, 60 with a plan, counted apart
   from the 6 without. With a plan: breadth-first 11102 worlds, the guesses
   383 each (29-fold, not 36), bits about seven times strings. Every
   published copy of the table is updated. The benchmark's header says it
   cannot tell h_max from h_add because h_max is exact here, and points to
   the gdUnit case that can. The empty-world claim is gone with the empty
   world.
5. **Fixed.** A purchase of the forge counts as "built or bought".
6. **Fixed.** A purchase is a diamond round the workshop (`_draw_purchase`).
7. **Disclosed.** The PDDL file's header, T11's record and ADR 0010 say the
   domain cannot clear the bridge or draw off a guard, and that the rules
   play such a turn. Adding those actions is a domain change for later.
8. **Fixed.** A plan that stopped running is marked "off", not "done", with a
   line saying so; a refused purchase says "saves" only when the money is
   short, and "cannot" otherwise.
9. **Mostly fixed.** The interval is pinned to its own argument (the forge
   and a ram, in turns of income), and changing it turns a case red; the
   bank skip has a case (planted and undone); a test also holds that it
   keeps its plan before the cadence comes round. The stale-entry skip is
   left as the reviewer found it: equivalent on every tested domain, and
   kept because it is what makes `visited` a count of worlds rather than of
   pops, as `ai_search`'s A* explains.
10. **Left to the owner, and said so.** T11's record asks the owner to accept
    or refuse the narrowing of step 7. The "28 in 20000" figure is now
    described as a throwaway search that is not committed.
11. **Accepted.** The record is named for the branch slug the gate reads.
