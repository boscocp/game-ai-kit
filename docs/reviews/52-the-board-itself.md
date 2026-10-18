# Review: wave/52-the-board-itself

One fresh context reviewed it, in the main worktree, at 28eec3b (one commit
on `main`).

**Verdict: do not merge as it stands. Answer findings 1-4 first; the rest
can go in the same pass.**

The code mostly does what it says:
- the map is still the same turned half round;
- the planner's domain rename is complete and the two JSON copies are
  byte-equal;
- `_what_broke` replays forward correctly;
- the threat map follows its header;
- every figure in T48's acceptance table is what the command prints, to
  the decimal.

Two things change the conclusion of the record, though.
- **The stop rests on a sweep that missed the variant the record itself
  names first.** Fords at rows 1 and 7, cost 3, with blue's shield, is
  the "ford placed between those two" left to the owner. Run here over
  T47's 100 seeds, it lands the rules' mirror at **53-47** -- inside 40-60
  (finding 1). T47 may not need to be wip at all.
- **The record credits the fords with two measures that main already
  had.** On the same 40 seeds at main, the learned side was stuck 29%, not
  44%. The rules' mirror was decided before round 40 in 36 of 40 games,
  against 32 of 40 with the fords (finding 3).

Then there are gaps in what the tests hold:
- the ford's cost (finding 2);
- the bolt tower's part of the threat map, and the edge of a walker's
  reach (finding 6);
- and a reason the rules' blue shows on the board that is now false
  (finding 4).

What it read:
- CLAUDE.md;
- T48 in full, with "What was done so far";
- the note added to T47, and T47's wave 51 record;
- STATUS's "Resuming after 2026-10-18 (wave 52)" and the T47/T48 rows;
- `docs/design/tactical-references.md` §2.2, §2.5 and §4 items 5-7;
- the wave 51 record, for the format;
- the whole diff.

Around the diff it read:
- `TacticalReach` (`walks_for`, `route_costs`, `_relax`, `_expand`);
- `GridGraph.neighbours` and `cost_at`;
- `BoardState.graph_for`;
- `TacticalRules.graphs_from` and the unit types;
- `TacticalCombat.why_refused`, for range, and to confirm that a walker
  may move and then attack;
- `RuleBasedBlue._crossing`;
- `LearnedBlue._out_of_reach`;
- `tactical.gd`'s `_press`, `_terrain` and `_explained`;
- `planner_properties.gd`'s `_check` and `_check_no_plan`;
- `planner_benchmark.gd`'s header;
- every live use of "bridge" in `godot/`, `spec/`, `python/`, the README
  and `docs/` outside the review records.

What it ran, each exit code read directly:
- `make check`: exit 0. Its six `SCRIPT ERROR`s were read:
  - three are `interfaces_test.gd`'s intended parse failures;
  - three are `demo_overlays.gd`'s planted crash, which its header says
    prints a backtrace on every run.
- `check_readability`, `check_addon_deps`, and `check_no_employer_refs`
  with the term list on disk: exit 0 each.
- `check_commit_msg` on 28eec3b's message: exit 0. The author is the owner
  alone, and there is no byline.
- `planner_properties.gd` on its own: exit 0, no `SCRIPT ERROR`. Both
  halves run: "842 boards, 1692 of 3368 plans found".
- `cmp spec/pddl/tactics.json godot/game/tactical/tactics_domain.json`:
  equal.
- **The acceptance**, `tactical_win_rates.gd -- 40 --at-most rr:draw:8`:
  exit 0. Every figure equals T48's table:
  - wins and draws;
  - games settled at the limit;
  - both stuck percentages, recomputed from the printed counts;
  - both ford-game counts.
- **The same script on `main`**, from a `git archive` copy under
  `/tmp`, 40 games each of rr, rl and lr. It is the baseline for
  finding 3:

  | pairing, 40 games | main: red-blue | main: at the limit | main: stuck red / blue | branch: red-blue | branch: at the limit | branch: stuck red / blue |
  |---|---|---|---|---|---|---|
  | rr | 26-14 | 4 | 17.7% / 24.4% | 7-33 | 8 | 14.8% / 18.2% |
  | rl | 0-40 | 25 | 18.2% / 28.9% | 4-36 | 19 | 12.0% / 15.2% |
  | lr | 40-0 | 24 | 29.2% / 20.2% | 40-0 | 17 | 15.9% / 19.6% |

- **The balance sweep**, `--pairings rr` at 100 games. The constants and
  the map were edited by a script, restored from copies, and `git status`
  checked afterwards:

  | fords at | cost | blue's counter | T48 says | measured here |
  |---|---|---|---|---|
  | rows 0 and 8 | 3 | the shield (shipped) | 17 | 17 (28.2 rounds, 17 at the limit) |
  | rows 0 and 8 | 3 | none | 100 | 100 (11.5 rounds) |
  | rows 0 and 8 | 5 | the shield | 20 | 20 |
  | rows 2 and 6 | 3 | the shield | 14 | 14 |
  | **rows 1 and 7** | 3 | the shield | not run | **53** (27.9 rounds, 22 at the limit) |

- `planner_benchmark.gd` on main and on the branch, for finding 8.
- A probe script under `/tmp`, run with `-s`, for finding 4. Nothing was
  written under `godot/`.

Then six mutations, each against `threat_map_test`,
`tactical_scenario_test`, `tactical_bridge_test`, `tactical_spending_test`,
`tactical_planner_test` and `tactical_game_test` (122 cases). The first was
also run against the whole Godot suite. All are undone, and `git status`
shows only this file.

## What was reviewed

The code:
- `TacticalRules.FORD` / `FORD_COST` and `_ground_cost`;
- `TacticalScenario.MAP`, its header and the `POINTS` comment;
- `ThreatMap`, whole;
- in `IntentView`: `show_threat`, `_draw_threat` and `THREAT`;
- in `tactical.gd`: `threat()`, the T key, the `"threatened cells"`
  overlay field and the ford's tile;
- the legend;
- in `TacticalPlanBridge`: `crossings()`, `_crossing_open`, `_theirs_on`
  and the `asks` prefixes;
- `PlannedBlue._what_broke` and `_first_missing`;
- the PDDL domain and problem, and the godot copy;
- the ford counter in `tactical_win_rates.gd`;
- `_shut_and_guarded` in `planner_properties.gd`.

The tests:
- `threat_map_test.gd`, new;
- the changed cases in `tactical_scenario_test`, `tactical_bridge_test`,
  `tactical_spending_test` and `tactical_planner_test`.

The docs:
- T48's record, and T47's note;
- the STATUS rows and resume section;
- the README's tactical paragraph;
- the new CLAUDE.md trap;
- the commit message.

## Checked and true

- **The map is still the same turned half round.** Row 0
  `..T...ff......` reversed is row 8, `......ff...T..`. Each ford cell
  mirrors to the other ford's: (6,0)->(7,8), (7,0)->(6,8).
  `test_the_map_is_the_same_turned_half_round` is green.
- **`across_the_river`, the control points and the second player's shield
  still read right.**
  - A ford's cells sit at x 6 and 7, like the bridge's, so `x < 7` splits
    them by bank.
  - (5,0) and (8,8) are one step from a ford, as the new comment says.
- **The threat map is what its header says.**
  - It floods each piece's own cost map (`state.graph_for(unit)`).
  - `route_costs` charges the cell entered, exactly as `walks_for` does,
    so `<= type.movement` is the same reach a full-movement walk has.
  - Pieces are not walls.
  - Attack range is Manhattan, as `TacticalCombat.why_refused` measures
    it, and a walker may move and then attack.
  - Fixed pieces keep their own cell. Range-0 pieces are skipped, a
    redundant skip: `_within(…, 0)` is empty anyway.
- **The scene draws the right side's threat.** `threat()` is
  `ThreatMap.of(state, FACTIONS - 1 - current_faction)`: blue's on red's
  turn, red's on blue's. T flips `_showing_threat` and refreshes. The
  overlay field is populated, and `check_demos` / `demo_overlays` are
  green (invariant 13's half).
- **The planted straight-line map does show the failure.** It counts
  (8,2) from a shield at (5,2): distance 3, against movement plus reach 4.
  A river-blind `ThreatMap`, flooding the wader's map for every piece,
  turns `test_across_deep_water…` red at line 21.
- **The rename is complete in live code and specs.** No `bridge_open` or
  `cross_the_bridge_` is left outside the review records.
- **`crossings()` is right for this map.** Each crossing is one row: the
  two cells needed to cross a two-wide river. "Shut" means one of theirs
  on any cell of it, and that is what blocks a walk.
- **`_what_broke` replays forward correctly.** It is the same walk as
  `_runs_from`. Reverting it to "the step it was at" turns
  `test_shut_crossings_break_a_plan…` red. The reason then names
  `buy_the_forge`, not `crossing_open`.
- **A crossing check that looks only at the bridge** turns
  `test_a_crossing_stays_open_while_one_of_the_three_is_clear` red.
- **The property check's derived worlds** make the "no plan" half run
  again, and they print no `SCRIPT ERROR`.
- **The author's diagnosis of rows 0 and 8 holds as measured.** With no
  counter, red wins 100 of 100 in 11.5 rounds on average.
- **T47 back to wip is clearly said** in T47's note, the STATUS row and the
  resume section.
- **Invariants 2, 10 and 11 hold.** Nothing new reaches `ai_core`, nothing
  from the employer is present, and the commit has no byline.

## Findings

### Must fix

1. **The sweep missed the variant it names first, and that variant lands
   in the band.** `tasks/T48-the-board-itself.md`, "What the fords broke";
   `tasks/STATUS.md`'s T47/T48 rows and resume section; T47's note.

   The record says "no ford cost or place swept lands 40-60". It leaves
   "a ford placed between those two" to the owner as an open question.

   Run here: fords at rows 1 and 7 (`.TT...ff.T....` /
   `....T.ff...TT.`), rows 0 and 8 back to deep water, cost 3, with the
   shield. Over T47's 100 seeds the mirror is **red 53, blue 47, 0
   draws**: 27.9 rounds on average, 22 settled at the limit. That is the
   map turned half round, inside 40-60, and decided before round 40 in
   78%.

   This does not settle the design. It is one row of one pairing, and 78%
   is under §4 item 6's 80%. But it changes what the owner is asked:
   - not "nothing works, choose a mechanism";
   - but "rows 1 and 7 restore T47's band; measure the other pairings
     and the ford counts there, or say why not".

   The record should carry the row. Before the merge, the author should
   either run rows 1 and 7 through the full acceptance, or state it as the
   first thing for the owner to decide, with this number.

2. **Nothing holds the ford's cost.** `tactical_rules.gd:177-178`
   (`FORD: return FORD_COST`).

   *Mutation:* delete those two lines, so a ford costs what open ground
   costs. **The whole Godot suite stays green: 918 of 918.**

   The cost is the whole of the ford's design: "slow ... so the bridge is
   still the quick way". It is also the lever the sweep turned (3-6). The
   tests check only *whether* the far bank can be reached by each
   crossing.

   *Fix:* one case that a runner entering a ford is charged
   `FORD_COST`, the way `test_a_wader_can_step_into_water` checks the
   wader's bill. Or that a walk over the ford costs more than the same
   number of steps on open ground.

3. **The record credits the fords with what main already measured.**
   - T48: "The learned side's stuck walkers fell from 44% and 42% (T45) to
     15.2% and 15.9%".
   - STATUS: "The fords did what staging was meant to: ... stuck walkers
     fell from 44% to 15%, and 80% of the rules' mirror is decided before
     round 40".
   - The commit message says the same.

   On the same 40 seeds at main, with T46's and T47's controllers:
   - The learned side was stuck **28.9% as blue and 29.2% as red**, not
     44% and 42%. Those are T45's numbers, from before T46 changed the
     learned blue. The fords' own effect is 29% -> 15%. That is still
     real, but half what is claimed.
   - The rules' mirror was decided before round 40 in **36 of 40** on
     main and **32 of 40** on the branch. On T47's 100 seeds it is 77 ->
     83.

     §4 item 6 asks that share to *rise* to 80% or more. At 40 seeds it
     fell, and at 100 it rose by 6, so the fords are not shown to move it
     either way. The record states "32 of 40 (at least 80% asked)" with no
     before.

   *Fix:* quote main's figures beside the branch's, and drop "did what
   staging was meant to".

4. **The rules' blue tells the player it is "making for the bridge" while
   it walks to a ford.** `rule_based_blue.gd:374-382` (`_crossing`), and
   the header at :12-14 ("for anything that is not a wader, over the
   bridge").

   *Probe:* a blue shield at (8,1), with a red runner on the bridge's west
   cell. The rules walk it to (8,0), the mouth of the top ford, and the
   reason on screen is "walks to (8, 0), towards the workshop at (1, 7),
   making for the bridge". A shield standing on a ford cell gets the same
   text, because `_crossing` knows only `BRIDGE` and the wader.

   Invariant 13 asks the board to show *why*, and here the why is false.
   The fords are new in this wave, and in rr the rules cross one in 31 to
   40 games of 40, so this is no corner case.

   *Fix:* name the crossing the route uses, or say "making for the river".
   Pin it with a case where the bridge is shut.

### Should fix

5. **The threat map is drawn but nothing decides by it, and the record
   does not say so about retreats.** `learned_blue.gd:353-356`.

   §4 item 7 says "Feed it into staging (#5) and retreat choices, and
   draw it". T48's goal also names "for retreats and staging". The record
   says staging was not built. It does not say that `LearnedBlue`'s
   retreat (`_out_of_reach`) still measures "movement and attack range in
   Manhattan cells". That is the straight-line reach the new
   `ThreatMap` header calls wrong ("would send every piece running from
   the bank").

   Wiring it in is a measured change, and fine to leave. Leaving it
   unsaid is not. One line in T48's record and in STATUS's "Next".

6. **Two halves of the threat map are unheld.** `threat_map.gd:33-38`
   and `:61`; `threat_map_test.gd:30-36`.
   - *Mutation A:* skip fixed pieces in `of` (`or not
     unit.type.mobile`), so no bolt tower ring. All 122 cases are green.
     `test_a_bolt_tower_threatens_the_ring…` asserts `of` has
     `tower + (2,0)`. Red's runner and shield reach that cell anyway. Its
     second assertion asks `strikes(tower)` directly, which the mutation
     leaves alone.
   - *Mutation B:* `costs[cell] < unit.type.movement`, a walker one short
     of its whole movement. All 122 are green. No case pins the last cell
     a walker's threat reaches.

   *Fix:* build the tower case on a board with only the tower, as `_with`
   does. Add one case at the exact edge of a runner's reach on open
   ground: in at movement + range, out at one more.

7. **The legend prints the trees' cost as the ford's.**
   `tactical_legend.gd:28`: `"ford: anyone crosses, cost %d" %
   TacticalRules.TREES_COST`. They are equal today, by choice. In every
   sweep row with `FORD_COST` 4-6, the legend said 3. Use `FORD_COST`.

8. **The comments about "no plan" are wrong in two places.**
   - `planner_properties.gd:212-215` says that, shut and guarded, "no plan
     in this domain gets past". Its own output says otherwise. The 421
     sampled boards account for at most 1684 of the "1692 of 3368 plans
     found", so at least 8 calls -- 2 derived boards -- find one: a ram
     already across sieges a guarded workshop (`siege_with_ram` needs
     only `ram_at_their_workshop`). The check is still sound. The
     sentence is not.
   - `spec/pddl/tactics-domain.pddl:19-22` changes "4 of the benchmark's
     boards" to "6 ... before T48 added the fords". `planner_benchmark.gd`
     on main prints **53** boards with no plan, of 166. On the branch it
     prints **1**, of 103.

     So the number was wrong before and is wrong now. And the benchmark's
     "boards with none" table now rests on a single board. Its header
     (:13) still says "bridge shut". Say what the benchmark prints now.

### Nits

9. **Prose left from before the fords.**
   - `tactical_scenario.gd:10` is one 117-character comment line that
     was never rewrapped. It says "The map is the same turned half round"
     a second time, two lines after the first.
   - `:44-48` is also unwrapped, and still says "a flag there hides the
     only dry crossing".
   - `planned_blue.gd:248-249` still opens with "the step it was at, and
     the first of that step's preconditions", above the new paragraph
     that says the opposite.

10. **The ford's cost was not looked at for the wader.**
    `tactical_rules.gd:105`. `graphs_from` gives the wader 1 on deep
    water and `_ground_cost(FORD)` = 3 on a ford. So "shallow water anyone
    can wade" is the slowest water on the board for the one piece that
    wades. Probably harmless, since its flood goes round. If it is meant,
    say so in the comment on `FORD`.

11. **The ford counter counts a step onto a ford, not a crossing.**
    `tactical_win_rates.gd:230-238`. The record reads it as "both
    crossings used in most games". §4 item 6 asks for "unit crossings per
    tile". A walker that steps onto the near ford cell and back counts.
    Rename it ("stepped on a ford") or count walks that change bank.

## What was done about them

Answered on the branch, in one commit after 28eec3b; `make check` exits 0
afterwards.

1. **Fixed, and it changed the wave's outcome.** The fords are at rows 1 and
   7. Rules' mirror over 100 games: 51-49, no draws -- T47's acceptance exits
   0 again and T47 is done; T48's acceptance at 40 games exits 0. The sweep
   table in T48's record carries the row, and says the first sweep missed it.
2. **Fixed.** A test holds a ford's cost on the walkers' map and on the
   wader's.
3. **Fixed.** T48's record compares with main on the same 40 seeds, using
   this review's figures (stuck about 29% -> 17-20%; 35 of 40 decided before
   round 40 against main's 36), and says its first version overclaimed.
4. **Fixed.** The rules say "crossing the bridge", "crossing by the ford" or
   "making for a crossing"; the test that pinned the old words is renamed and
   follows.
5. **Recorded.** T48's record says nothing decides by the threat map yet and
   that the learned blue still retreats by straight-line reach.
6. **Fixed.** The tower is tested alone through `ThreatMap.of`, and a cell
   one step past a runner's full movement must be in its reach; leaving
   towers out and `<` for `<=` each turn a case red (planted and undone).
7. **Fixed.** The legend prints `FORD_COST`.
8. **Fixed.** `planner_properties.gd` says most such worlds have no plan and
   why some do; the PDDL comment no longer gives a stale count.
9. **Fixed.** The scenario's header is rewrapped and says where the fords
   are and why; the points' and `_what_broke`'s comments are current.
10. **Fixed.** A wader pays 1 on a ford, as in deep water; the measurements
    above are with that rule (the review's 53-47 was with 3).
11. **Fixed.** The counter and the record say "stepped onto a ford".
