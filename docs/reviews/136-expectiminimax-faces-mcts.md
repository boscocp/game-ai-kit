# Review: wave/136-expectiminimax-faces-mcts

T88 adds `ExpectiminimaxSearch` to `ai_adversarial`. It is AIMA 5.5's
expectiminimax with a depth cutoff, deepening one ply at a time on an
explicit stack so that `step(positions)` can stop in any frame. It has a
Python twin written as the book's recursion, and dice-race vectors that
`derive.py` wrote in exact fractions. In the squad, it moves what T87's
`MctsSquad` shared into `SearchingSquad`, adds `ExpectiSquad` over a
hand-written evaluation (`SquadEvaluatedGame`), and adds the duel
(`spec/squad/duel.json`, `make test-squad-duel`) plus the docs.

A fresh context reviewed PR #87 at head 557f22a (origin/main efdb996
merged in), in a throwaway worktree. It read the code and planted faults
one at a time, restoring each before the next. It made no commit, push or
PR comment.

**Verdict: changes requested, one blocker.** The search is right. Every
planted fault in the probabilities and in min and max fails in both
languages, and the vectors were derived independently. MCTS's digest is
pinned and holds through the refactor. The blocker is in the new duel
gate: a SCRIPT ERROR in either half of the runner (positions or matches)
leaves it searching or playing nothing, and it still exits 0 with
"0 failure(s)". This wave was bitten by that trap once already, and the
gate is going into `make check`. There are also five should-fix findings
and three nits.

## What was reviewed

- `CLAUDE.md`, the task file, the PR body, and the reviews of waves 125
  and 133.
- The diff against `origin/main`: `expectiminimax.gd`, the
  `adversarial_game.gd` and `adversarial_result.gd` headers,
  `expectiminimax.py`, `derive.py`, the vector file and README, both
  vector runners and both test suites, and `searching_squad.gd`,
  `mcts_squad.gd` (compared with main's), `expecti_squad.gd`,
  `squad_evaluated_game.gd` and its Python twin. Also `squad_duel*.gd`,
  `test_squad_duel.py`, the Makefile target, both module manifests, the
  locale rows, `docs/godot/squad.md`, `docs/concepts/minimax.md` and
  `docs/techniques/ai_adversarial{,.pt-BR}.md`.
- For context: `side_view.gd`, `squad_victory.gd`, `squad_match.gd`,
  `scripts/godot_shards.py`, and the Makefile's other slow match gates.

## What was run (green at 557f22a unless stated)

- `make test-godot-some SUITES="test/ai_adversarial"`: 41 cases, 0
  failures, no `SCRIPT ERROR`.
- `make test-godot-some SUITES="test/squad"`: 96 cases, 0 failures, no
  `SCRIPT ERROR`, MCTS's digest test included.
- `make test-adversarial-vectors`: 4 draw, 12 search and 7 expectiminimax
  cases, 0 failures.
- Python: `test_adversarial*.py` OK and `test_squad*.py` OK.
- `check_readability.py`, `check_addon_deps.py`, `check_no_training.py`,
  `check_tiers.py`, `check_translations_docs.py`,
  `check_translations_game.py` and `check_literature_table.py`: all exit 0.
- `derive.py`'s first case worked by hand. From (0, 0) at depth 2, walk
  gives MIN the choice of walk (0) or roll (1/2 x 1/6 + 1/4 x -1/6 +
  1/4 x -3/6 = -1/12). MIN takes -1/12 = -0.0833, which is the file's value.
- At every root of the 30 duel positions, the outcome probabilities sum
  to 1 (611 actions, Python twin).
- The full duel was not rerun: the PR's tables are a measurement, and the
  brief asked for narrow runs.

### Planted faults

| planted | where | caught by |
|---|---|---|
| a chance node ignores the probability (`expected += value`) | `expectiminimax.gd:162` | both addon suites, vectors (13 failures) |
| uniform weights (`value / outcomes.size()`) | same | both suites, vectors (11) |
| MAX and MIN flipped | `expectiminimax.gd:198` | both suites, vectors (14) |
| MIN takes the max | `expectiminimax.gd:175` | both suites, vectors (20) |
| `step` returns the depth under way's partial answer, labelled with that depth | `expectiminimax.gd:93-97` | `test_one_ply_deep...` only, by accident of its loop |
| the same partial answer, labelled as the finished depth (`depth_limit - 1`) | same | **survives the addon's suites and vectors**; caught only in the squad module (`expecti_squad_test.gd`) |
| Python: no probability / flip / max for min / a ply short | `expectiminimax.py:81,91,78` | 32 / 33 / 10 / 28 failures |
| runner: a SCRIPT ERROR in `_seat` | `squad_duel_runner.gd:115` | **survives**: exit 0, "1 match(es) a seat a pairing, 0 failure(s)", no match played |
| runner: a SCRIPT ERROR in `SquadDuel.searched` | `squad_duel.gd:67` | **survives**: exit 0, "30 position(s), ... 0 failure(s)", no position searched |

A probe looked for the T87 crash's state: a `MctsSquad` whose `believe`
reports a finished board while the real board is not. It played 12
seeded matches against the weighed enemy at 30 iterations a decision and
found no case. The crash happened under the clock and was not reproduced
here.

## Findings

1. **The duel gate goes green with nothing searched (blocker).**
   `godot/test/squad/squad_duel_runner.gd:43-49`. Both planted SCRIPT
   ERRORs above aborted their function, and `_init` printed the summary
   and called `quit(0)`. The summary line counts the file's positions and
   the `games` argument, not the rows produced, so it read as a clean run.
   This is CLAUDE.md's `-s` trap. The wave met it once (the ternary) and
   fixed that instance, not the class. Invariant 4 asks for a gate that
   cannot pass on an empty run.
   Fix: have the runner count what it produced: `positions x 3` rows and
   `3 pairings x 2 seats x games` matches. Exit 1 when either count is
   short, and print the counts it saw. Put the comparison in `SquadDuel`
   (say `missing_rows(expected, produced)`) so `squad_duel_test.gd` can
   plant a short run. Also, or instead, run the target through
   `scripts/godot_shards.py` or a wrapper that fails on `^SCRIPT ERROR`.
   That is what T72 built for this exact trap, and it also gives the
   timeout a hang needs.

2. **`make test-squad-duel` should not be in `make check` as written
   (should-fix; disagrees with decision 10).** `Makefile:530-537`,
   `modules/squad.json` `gates`. The target takes about 3 minutes on the
   wall clock, and it runs whenever anything `squad` depends on changes:
   `ai_adversarial`, `ai_core`, `board`, `tactical` and the rest. The
   precedent is to keep slow match gates out of `check` and put a fast
   one in: `test-rts-league` against `test-rts-clock-limits`
   (`Makefile:862-871`, PR #70's review), and `test-difficulty-matches`
   (`Makefile:922-925`). The structural rules the gate holds do not need
   the clock. An answer that is one of the position's, depth ≥ 1, a
   match that ends and no lost decision can all be checked with fixed
   work budgets (positions and iterations), seeded, in a few seconds.
   Fix: make `test-squad-duel` that fast deterministic gate (the 30
   positions at fixed budgets plus one match a pairing a seat). Move the
   timed run to `measure-squad-duel`, outside `check`, beside
   `measure-squad-mcts`. That run prints the page's tables.

3. **"A longer budget that searched less" is a rule that load can break
   (should-fix).** `godot/test/squad/squad_duel.gd:113`. The PR says the
   gate "fails only on what load cannot excuse". But a 200 ms window
   that is starved by load can finish fewer MCTS iterations, or a
   shallower depth, than the 50 ms window before it. The PR's own runs
   were at load 2 to 21. The planted rows in `squad_duel_test.gd` test
   the rule, not whether it is safe under the clock. Fix: under finding
   2's split this rule goes into the measurement and stays out of the
   gate. If it stays in a timed gate, compare against a floor (for
   example, at least half the shorter budget's count) instead of strict
   order.

4. **The search seldom lets the other side move, and the pages do not
   say so (should-fix, invariant 1).** `expecti_squad.gd:7-9`,
   `docs/godot/squad.md` ("its own side's pieces as MAX, the other
   side's as MIN"), `docs/concepts/minimax.md` (the walks paragraph). A
   ply here is one piece's answer, and a side's turn is up to eight of
   them. Following the first answer from each of the 30 duel roots, the
   number of plies before the other side is to move is: 1 on five
   positions (05, 09, 15, 18, 30, all shots), 2 on four, and 3 to 8 on
   the rest. MIN chooses only at a position above the cutoff. So at
   depth 2, which is the gate's depth and what the clock mostly buys,
   the opponent chooses in 5 of 30 positions and in none of the 14 walk
   questions. At depth 3 it chooses in 2 of the walks. On walks, the
   expectiminimax in this duel is expectimax against an enemy that
   stands still. MCTS's playouts do reach the other side's turn. That is
   the most likely reason for the walk disagreements and for the 97 in
   100 losses to the weighed enemy, and it is the lesson a reader should
   take from the table. Fix: say it on both pages and in
   `ExpectiSquad`'s header, with these counts. Name a whole side's turn
   as the ply, or a cutoff counted in turns, as the next step (a later
   task).

5. **A partial depth that claims to be finished slips past the addon's
   own tests (should-fix).**
   `godot/test/ai_adversarial/expectiminimax_test.gd:82-94`. The mutant
   that returns the depth under way's answer, labelled with the finished
   depth, passes all 15 addon cases and all 7 vectors. Only
   `expecti_squad_test.gd` catches it, in another module, and someone who
   copies only the two addon folders loses that check (invariant 2's
   promise). The stepped test compares only the final answer. Fix: in
   that test, at every `step(1)`, assert that `result()`'s values equal
   `search_to(result().depth)` on a fresh search (or a cached one per
   depth). That holds "the deepest finished depth's answer, never a
   partial one" directly.

6. **The guard for T87's crash is right, but what it plays is described
   wrongly and it has no test (should-fix, not a blocker).**
   `godot/game/squad/searching_squad.gd:248-253`. Searching a terminal
   root is meaningless, so the guard is correct code in any case, and
   the state it leaves is legal. On a walk, the piece holds. On a shot,
   `decide_attack` has already returned null, because a believed board
   with no enemy has no shots. MCTS's digest is unchanged, so the seeded
   game never reaches the guard. Two problems remain. The hold is
   explained as "has nowhere to walk" (`:97`), which is false in this
   state and is what a person would read on the board. And nothing tests
   the guard. A believed board with no enemy while the real game goes on
   is a contradiction the side could detect: the game is announced as
   over when it ends, so a side that is still asked has an enemy alive.
   It probably comes from the memory bookkeeping in `believe` and
   `SideView`, and the probe above did not reproduce it. Fix: a reason
   that says what happened ("believes no enemy is left, and holds").
   Add a unit test that builds that belief (a controller whose `_known`
   lists every enemy, with none seen and none remembered) and asserts the
   hold. File decision 9's task. Another option is to have `believe`
   fall back to the enemies it knows at their last cells when its belief
   would end a game that is still going on.

7. **A position that is not terminal but has no move is worth 0 in Godot
   and raises an error in Python (nit).** `expectiminimax.gd:171-181`
   (with no action, `_finish_move` takes `maxf(-INF, 0.0)`) and
   `expectiminimax.py:80-81` (`max([])` raises `ValueError`). The squad
   always offers a hold, so nothing in the kit reaches this. For a
   library, though, the two twins disagree. Fix: in both, treat a
   position with no actions as a cutoff and return `evaluate`. Add one
   hand-tree case.

8. **The status's search line, under `think_for`, and the header's
   promise (nit).** `expecti_squad.gd:80-82`. Under `think_for`, `_left`
   starts at `UNLIMITED`, so `{visited}` prints a large negative number.
   The duel never shows it, but the next caller will. The header
   (`:18-21`) promises "the depth finished so far and the one under way",
   but the line shows the deepest allowed (8), not
   `_search.depth_under_way()`. The one under way is what tells a person
   watching why the framed option has not changed yet (invariant 13).
   Fix: print `positions_visited()` for the work done, and add the depth
   under way.

9. **The Python duel test does not check the decision its docstring
   promises (nit).** `python/tests/test_squad_duel.py:6-8, 36-45`. It
   checks answers, values and depth, not `wanted["decision"]`. The
   GDScript twin does check it (`expecti_squad_test.gd:217`). Fix: assert
   `described(found.action) == wanted["decision"]`.

Held, with nothing to add:

- Invariant 2: `check_addon_deps.py` passes, and `ai_adversarial` reads
  only its own interface.
- Invariant 6: the weights are in `rules.json`, and nothing is fitted.
- The headers say when not to use each file.
- The functions and nesting pass the gate.
- The pt-BR page's new italic terms (*expectiminimax*, *anytime*,
  *plies*) are all in `glossary.pt-BR.md`, and the locale rows all have
  translations.
- Invariant 13 is met as far as a headless run can show: each answer's
  expected value is on the board, the best one is framed, and the status
  gives bars and, for a shot, hit and miss with chance and value. The
  manual check stays a person's job.

## The owner's decisions

1. `duel.json` and not `positions.json`: **agree**. The shapes differ,
   and reusing the name would break T87's vectors.
2. Weights 0.6 / 0.2 / 0.2, with "flanked" counting a piece in the open:
   **agree** with keeping them as the written guess. Finding 4 matters
   more to the comparison than the weights do.
3. "Chosen by hand" as a written rule in `squad_duel_draw.gd`: **agree**.
   It redraws, and a person read the result.
4. The same budget per frame, read as the same time: **agree**. Both are
   about 4 ms a frame and about 1 s a decision, and the duel itself uses
   the wall clock.
5. 100 matches a seat at 50 ms, 20 at 200 ms, none at 1,000 ms:
   **agree**. The page says so. 33 to 7 over 40 matches is a clear
   enough reversal for the claim the page makes.
6. No position picker: **agree** that it is a later task. Until then the
   manual check cannot reach `03 flank` reliably, and the page says so.
7. The Python twin as a recursion: **agree**. Two walks meeting one
   file is the stronger check. Finding 7 is where they still differ.
8. The `SearchingSquad` refactor: **agree**. The digest is pinned
   (`mcts_squad_test.gd:32`, unchanged since wave 125), and it passed
   here. `after_refusal` moved from integer visits to float preferences
   and orders them the same way.
9. The crash guarded, not explained: **agree**, with finding 6's
   additions: an honest reason, a test, and the task filed.
10. `make test-squad-duel` in `make check`: **disagree**. See findings 2
    and 3. Split it into a fast deterministic gate in `check` and a timed
    measurement outside it.

## What was done about them

Applied on the same branch, after merging main at aa57b15 (T119's
`lint-glossary` included; it found one italic word on the pt-BR page,
*esperado*, now in plain type).

1. **Blocker, fixed.** The runner counts what it finishes: a position row
   only once `SquadDuel.searched` or `searched_fixed` has returned a whole
   row, and a match only once it is over. `SquadDuel.missing_rows` turns a
   short count into a failure, and `squad_duel_test.gd` plants a short run.
   The two SCRIPT ERRORs were planted again (a call on `null` in `_seat`,
   and in `searched_fixed`), and a third in the clock's `searched`. Each
   run exits 1: "matches: 0 produced, 6 expected", "position rows: 0
   produced, 30 expected", "position rows: 0 produced, 90 expected".
2. **Split.** `make test-squad-duel` is now the fast deterministic gate
   and stays in `check:` and `squad`'s gates. It searches the 30 positions
   on counted budgets (100 iterations, 400 positions) and plays one seeded
   match a pairing a seat (40 iterations, 150 positions a decision), in
   about 22 s. The timed run is `make measure-squad-duel`, beside
   `measure-squad-mcts` and out of `check`. Decision 10 is rewritten in
   the PR.
3. **Moved.** "A longer window searched less" is `SquadDuel.searched_less`.
   The measurement prints it as a note and never fails on it.
   `wrong_position` no longer compares budgets.
4. **Said, with the review's counts,** in `ExpectiSquad`'s header,
   `docs/godot/squad.md` (a new paragraph, "What a ply is here, and what
   it hides"), `docs/concepts/minimax.md`, and the technique page in both
   languages. At depth 2 the enemy chooses in 5 of 30 positions and in
   none of the 14 walks; on a walk the search is expectimax against an
   enemy that stands still. A ply counted in whole turns is named as the
   next step, a later task.
5. **Held.** The stepped test now checks at every `step(1)` that the
   answer's values equal `search_to(depth)`'s for its depth. The planted
   mutant (the depth under way's partial answer, labelled as the finished
   depth) fails it: 58 failures in `expectiminimax_test.gd`, while the
   vectors stay green, as the review found.
6. **Reason and test.** The guard says "believes no enemy is left, and
   holds" (pt-BR row added). `expecti_squad_test.gd` builds that belief
   for both searching enemies and asserts the hold, the reason and an
   empty overlay. The root cause is **T134** (task file and STATUS row),
   with the review's fallback as its second option.
7. **One behaviour.** A position that is not over and has no move is
   scored by `evaluate`, as at the cutoff, in Godot, in Python and in
   `derive.py`; the vector files did not change. The vectors' README says
   so, and a hand-tree case pins it in both suites, since the dice race
   has no such position.
8. **Fixed.** The status line counts the positions this decision has
   searched (never `positions - UNLIMITED`). It shows the depth under way
   beside the finished one, and `∞` for the budget on the clock. A test
   holds the clock's line.
9. **Fixed.** `test_squad_duel.py` asserts the decision.

## Second review

Reviewed by a fresh context, on 2026-11-06, the diff 557f22a..37a3a51 less
what main aa57b15 brought (`git diff 726d42c 37a3a51`), in a worktree of
37a3a51 of its own.

### Verdict

**Changes requested, one blocker.** Most of the fixes hold: the split is
right, the fixed gate is deterministic, the stepped test, the no-move
scoring and the status line each fail their planted fault. The blocker is
the claim the fix commit is built on. The Makefile, the runner's header
and `SquadDuel.missing_rows` all say that a SCRIPT ERROR "leaves the run
short, never green". That holds only where the error is in a search or a
match. Five of the twelve planted SCRIPT ERRORs leave `make test-squad-duel`
green with exit 0, and three of those silently skip every check the gate
exists to make.

### What was run

- `make test-squad-duel` twice: exit 0 both times, 23 s, no SCRIPT ERROR.
  The two outputs are byte for byte the same.
- `make test-godot-some SUITES="test/ai_adversarial"` (42 cases) and
  `SUITES="test/squad"` (100 cases): green.
- `test_adversarial*.py`, `test_squad*.py`, `make test-adversarial-vectors`
  (7 expectiminimax cases): green.
- `make lint-tasks lint-status`, `check_glossary.py` and
  `check_readability.py`: green.
- The runner was called directly to get its own exit code, with one plant
  at a time, each restored with `git checkout` and checked clean afterwards.

### Plants

| plant | exit | caught? |
|---|---|---|
| SCRIPT ERROR at the top of `SquadDuel.searched_fixed` | 1, "0 produced, 30 expected" | yes |
| SCRIPT ERROR at the top of `_match` | 1, "matches: 0 produced, 6 expected" | yes |
| SCRIPT ERROR at the top of `_matches` | 1 | yes |
| `{"positions": [{}]}`, `[1, 2]` | 1 | yes |
| `{}`, `{"positions": []}`, no file | 2 | yes |
| **SCRIPT ERROR at the top of `SquadDuel.wrong_position`** | **0**, 30 rows, 0 failures | **no**: no answer is checked |
| **SCRIPT ERROR at the top of `SquadDuel.wrong_match`** | **0**, 6 matches, 0 failures | **no**: no match is checked |
| **SCRIPT ERROR in `_rows_for` after `_rows_done += 1`** | **0**, 30 rows counted, each position line empty | **no** |
| **SCRIPT ERROR in `SquadDuel.missing_rows`** | **0** | **no** |
| **SCRIPT ERROR in `_run` before the summary** | **0**, no summary printed | **no**: `quit(null)` exits 0 |
| `rows_wanted` replaced by `_rows_done` | 0 | no (no test of the runner's wiring) |
| `GAMES=0` | 0, 0 matches | no (by argument) |
| `fixed 1 50 2` (a shard that skips the positions) | 0, 0 rows | no (by argument; make does not pass FIRST in fixed) |
| addon: `step` returns the partial depth, labelled `depth_limit - 1` | red, 82 failed assertions in the stepped test, with the accidental catcher disabled | yes |
| `_is_cutoff` back to `is_terminal` only (GDScript) | red, `test_a_position_with_no_move_is_scored_not_searched` | yes |
| `_value` back to `is_terminal or depth` (Python) | error (`max([])`) in the same test | yes |
| `searching_squad.gd`: the no-enemy guard removed | red, only on the reason text | partly (finding 3) |
| `ExpectiSquad`: `visited = positions - _left` | red, `test_on_the_clock_..._never_below_zero` | yes |

A function that a SCRIPT ERROR aborts hands its caller the default value
of its return type. Measured here on 4.7.2, a typed `Array[String]`
function returns an empty array. So a validator that breaks reads exactly
like a validator that found nothing. A count of rows cannot tell the two
apart, because the row was produced. Only the output can tell.

### Findings

1. **A SCRIPT ERROR in a validator, in the count, or in `_run` leaves the
   gate green (blocker).** See `godot/test/squad/squad_duel_runner.gd:60`
   (`quit(_run(...))`), `:66-75` and `:104-112`,
   `godot/test/squad/squad_duel.gd:133` (`wrong_position`), `:175`
   (`wrong_match`) and `:158` (`missing_rows`), and `Makefile:538-544`.
   The plants above show it. The comments in three places say otherwise,
   and a reader who trusts them will trust a green that checked nothing.
   This is invariant 4's "a gate that only knows how to go green".
   Fix: read the run's output for engine errors, as
   `scripts/godot_shards.py` already does (`engine_errors`,
   `ENGINE_ERROR`, with planted cases in its `--self-test`). One way is a
   small wrapper, or a `--shards 1` path in that script, that runs a `-s`
   gate, returns its exit code, and turns any `SCRIPT ERROR:` or `ERROR:`
   line into exit 1. `test-squad-duel` and `measure-squad-duel` would both
   go through it. Inside the runner, also stop `_run`'s failure from
   reaching `quit(null)`: keep a member `_verdict: int = 1`, set it to 0
   only as `_run`'s last statement, and call `quit(_verdict)`. Then reword
   the three comments to say what the count catches (a search or a match
   that broke) and what the output scan catches (everything else). A
   follow-up task can put the other `-s` gates behind the same wrapper.
   The trap in CLAUDE.md applies to all of them.

2. **The gate's expected counts come from its arguments (minor).**
   `squad_duel_runner.gd:66-75`. `GAMES=0 make test-squad-duel` is green
   with no match played, and `fixed 1 50 2` is green with no position
   searched. Make does not pass FIRST in fixed mode, so the second is
   reachable only by calling the runner directly. Fix: in `fixed` mode,
   refuse `games < 1` and `first != 1` with exit 2. The gate is one run
   with one shape, and it should not be possible to ask it for less.
   Nothing tests that the runner wires `missing_rows` to an expected count
   that does not depend on the produced one (the `rows_wanted = _rows_done`
   plant survives). Finding 1's output scan does not cover that either. A
   short comment at `:70` saying why the expected count is computed before
   anything runs would at least make the next edit careful.

3. **The guard test holds the guard's sentence, not its effect (minor).**
   `godot/test/squad/expecti_squad_test.gd:216-222`. The test does reach
   the guarded state: with the guard removed, both searchers fail, but
   only on the reason text. The null move, the null attack and the empty
   `weighed()` all still pass without the guard, and no SCRIPT ERROR
   appears. So on counted budgets the test does not reproduce the crash it
   guards against, and a guard that set the reason and then searched
   anyway would pass. Fix: also assert `searcher.work_done() == 0`, so that
   no search ran. If T134 records the timed turn that crashed, add it then
   (T134 step 2 already asks for that).

4. **The status line can say "depth 0 under way" (nit).**
   `godot/game/squad/expecti_squad.gd:91`. `depth_under_way()` returns 0
   once the search is complete, and `ExpectiSquad` keeps `_search` until
   `_stop_search`. Read in code, not reached in a run: completing to depth
   8 within 5,000 positions is rare. When `_search.is_complete()`, show
   `--`, as when `_search` is null.

5. **`ExpectiSquad`'s header does not match the page's counts (minor,
   docs).** `godot/game/squad/expecti_squad.gd:18-23`. The header says "(3
   in depth 3: 2 of the walks)", but `docs/godot/squad.md:536-542` says the
   other side is to move after 2 plies on four positions, and at depth 3 in
   2 of the walks. A learner reading both cannot work out what the 3
   counts. Fix: use the page's wording, "at depth 3, in 4 more, 2 of them
   walks", or whatever the count really is, and say in both places that it
   follows each root's first answer. Also, "depth 2 -- the gate's depth"
   on the page: the fixed gate's walks finish only depth 1 (14 at depth 1,
   16 at depth 2 in its table). Say "duel.json's depth".

6. **pt-BR: "o turno de um lado chega a oito" has no noun (nit).**
   `docs/techniques/ai_adversarial.pt-BR.md:58`. Fix: "chega a oito
   respostas".

7. **`derive.py`'s no-move rule is exercised by no vector (nit).**
   `spec/vectors/adversarial/derive.py:115`. The README is honest about it
   ("the dice race has no such position"), and both hand-tree suites pin
   the rule. Reverting that line in `derive.py` fails nothing. Either leave
   it as written, or add a hand-tree vector so all three walks are held.

8. **T134 (fine, one suggestion).** It is well specified. The goal, the
   decisions written first, the fallback named, and lint-tasks and
   lint-status pass. Its acceptance has no command that fails while the
   cause is still open. Once step 2's recorded-turn test exists, name it
   in `## Acceptance`. Step 3's "read its output for SCRIPT ERROR" becomes
   a command once finding 1's scan exists.

Readability on the new code: within the limits (`check_readability.py`
green). Names are full and every new public function says what it does and
why. The ply paragraph on the page is clear and is the right lesson to
draw from the table.

### What was done about it

Applied on the same branch, in `fix: T88 second review, ...`.

1. **Blocker, fixed.** `scripts/godot_checked.py` (new) runs one `-s` gate
   and turns any engine-error line in its output into exit 1. It reuses
   `godot_shards.py`'s `engine_errors`, `wait_or_kill` and
   `godot_command` rather than a copy, and has its own `--self-test` (8
   planted verdicts), which `lint-selftests` runs. Both duel targets go
   through it. Inside the runner, `_verdict` starts at 1 and `_run` sets
   it on its last line, so `quit(_verdict)` exits 1 when `_run` stops
   half-way, wrapper or not (the plant in `_run`, run straight through
   `scripts/godot`, exits 1). The three comments now say what the count
   catches (a search or a match that broke) and what the output scan
   catches (everything else). Every plant again, as make runs the gate
   (through the wrapper), one at a time, each restored:

   | plant | exit | last line |
   |---|---|---|
   | SCRIPT ERROR at the top of SquadDuel.searched_fixed | 1 | godot_checked: an engine error, so the run fails: SCRIPT ERROR: Invalid call. Nonexistent function 'free' in b |
   | SCRIPT ERROR at the top of _match | 1 | godot_checked: an engine error, so the run fails: SCRIPT ERROR: Invalid access to property or key 'winner' on  |
   | SCRIPT ERROR at the top of _matches | 1 | godot_checked: an engine error, so the run fails: SCRIPT ERROR: Invalid call. Nonexistent function 'free' in b |
   | SCRIPT ERROR at the top of SquadDuel.wrong_position | 1 | godot_checked: an engine error, so the run fails: SCRIPT ERROR: Invalid call. Nonexistent function 'free' in b |
   | SCRIPT ERROR at the top of SquadDuel.wrong_match | 1 | godot_checked: an engine error, so the run fails: SCRIPT ERROR: Invalid call. Nonexistent function 'free' in b |
   | SCRIPT ERROR in _rows_for after the count | 1 | godot_checked: an engine error, so the run fails: SCRIPT ERROR: Invalid call. Nonexistent function 'free' in b |
   | SCRIPT ERROR in SquadDuel.missing_rows | 1 | godot_checked: an engine error, so the run fails: SCRIPT ERROR: Invalid call. Nonexistent function 'free' in b |
   | SCRIPT ERROR in _run before the summary | 1 | godot_checked: an engine error, so the run fails: SCRIPT ERROR: Invalid call. Nonexistent function 'free' in b |
   | rows_wanted replaced by _rows_done | 0 | squad duel, fixed: 30 position row(s), 6 match(es), 0 failure(s) |
   | GAMES=0 in fixed | 2 | squad_duel_runner: give me the path of duel.json after `--`, then fixed or clock, the games a seat, the millis |
   | fixed 1 50 2 (a shard skipping the positions) | 2 | squad_duel_runner: give me the path of duel.json after `--`, then fixed or clock, the games a seat, the millis |
   | a file with an empty position: {"positions": [{}]} | 1 | godot_checked: an engine error, so the run fails: SCRIPT ERROR: Invalid access to property or key 'name' on a  |

   The one that still exits 0 is the wiring plant: an expected count
   replaced by the produced one. Neither the count nor the scan can see
   it. The runner now says, where `rows_wanted` is computed, why it comes
   from the arguments before anything runs.
2. **Refused.** `fixed` with `games < 1` or `first != 1` exits 2: the
   gate is one run of one shape.
3. **Held.** The guard test also asserts `work_done() == 0`. Planted, a
   guard that set the reason and then searched anyway fails it twice: on
   the reason, which the search overwrote, and on the work, which was 40
   where 0 was expected.
4. **Fixed.** Once the search is complete, the status line shows `--`
   for the depth under way.
5. **Agreed.** `ExpectiSquad`'s header and `docs/godot/squad.md` now say
   the same counts, each following every root's first answer: at depth 2,
   5 of 30 positions and no walk; at depth 3, 4 more, 2 of them walks.
   "The gate's depth" is now "`duel.json`'s depth".
6. **Fixed.** The pt-BR line now reads "chega a oito respostas".
7. **Said.** The vectors README says why no vector holds the no-move rule
   (a dice race position is over or has both moves). It says that the
   hand-tree case `STUCK` is what fails when Godot or Python drops the
   rule, and that `derive.py`'s line, reverted alone, fails nothing.
8. **Left for T134**, as suggested: its acceptance gains the recorded-turn
   test once step 2 writes it. Step 3's read for `SCRIPT ERROR` is now
   `make measure-squad-duel`'s own verdict, through the wrapper.
