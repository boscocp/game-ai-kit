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
