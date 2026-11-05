# Review: wave/125-mcts-plays-the-squad-mode

T87: Monte Carlo tree search plays the XCOM-style mode. `SquadSearchGame`
is the squad's side of `GakAdversarialGame`, with a Python twin
(`gameaikit.squad.search_game`). `spec/squad/positions.json` holds three
positions whose root visits must match in both languages. `MctsSquad` is a
new roster row that searches the board its side believes in, a frame at a
time in the scene. T85's does-not-cheat check moved into
`SquadUnseenCheck`. `MonteCarloSearch.principal_line` was added to
`ai_adversarial` in both languages. The tactical scene gains
`BlueController.keep_thinking()` and a `_process` hook.

A fresh context reviewed PR #69 at head 402a4bb, detached in a throwaway
worktree. It wrote nothing to the branch. Every planted fault was undone,
and `__pycache__` was cleared after each Python mutation.

**Verdict: approve, with three should-fix findings to apply on the branch
before merge.** Nothing here lets the search see what the fog hides, both
twins are bound, and the walk-equivalence test is real. The should-fix
findings are:

- the addon's new method has an untested half;
- Enter quietly plays the searcher at 4 iterations;
- the page's frame and time figures do not say what a person waits.

## What was reviewed

The full diff against `origin/main`:

- `squad_search_game.gd`, `mcts_squad.gd` and `search_game.py`;
- the addon's `mcts.gd` and `mcts.py` hunks, with their tests;
- `tactical.gd`, `blue_controller.gd`, `squad_status.gd`,
  `squad_ruleset.gd`, `squad_roster.gd` and `squad_match.gd`;
- `squad_unseen_check.gd`, set against the functions it replaced in
  `origin/main:weighed_squad_test.gd`;
- the vectors runner, `squad_search_test.gd`, `mcts_squad_test.gd`,
  `squad_scene_test.gd` and `test_squad_search.py`;
- `squad_mcts_measure.gd`, `docs/godot/squad.md`, the Makefile, the
  manifest and the catalogue.

What holds, measured:

- **The fog.** Two leaks were planted in `MctsSquad.believe`, and the
  real controller's test caught each on position 0:
  - an enemy never seen is put on its true cell instead of its start cell;
  - a guess is dropped when the true board no longer has that enemy (a
    count leak).

  The second leak was caught only through the mean printed in the reason,
  since both runs held on the same cell. The check compares the whole
  reason text, so a leak that only moves the means is still caught.
- **The vectors.**
  - GDScript `evaluate` divided by `full_health() + 1`: the runner exits 1,
    with all 3 positions failing.
  - Python `evaluate`, the same change: `test_squad_search.py` fails 3.
  - Python dash rule removed (`walked` keeps the leftover movement):
    nothing fails. This is an equivalent mutant. The leftover is always
    below one action, so `can_shoot` is false either way, and the walk
    question has already been asked.
- **Walk equivalence.** `squad_search_test.gd`'s walk test was isolated by
  renaming the two tests before it, because gdUnit stops a suite at its
  first failure. Two plants were each caught (60 errors and 83 failures,
  then 160 and 160):
  - `reach` with no piece marked `TAKEN`;
  - `reach` with one bucket too many.

  The test compares each walk's cost with `Move.cost_on` of the route
  `TacticalReach` gives, not with a second flood, so the cost is held
  independently.
- **The moved check is the same check.** The functions of
  `SquadUnseenCheck` were diffed against the ones removed from
  `weighed_squad_test.gd`. They differ only in names and in one change
  that makes the check stronger: the shot's kind and target are now part of
  the compared string. `weighed_squad_test` keeps 60 positions and floors
  of 30.
- **Invariant 2.**
  - No `squad` reference under `godot/addons/ai_adversarial` or
    `python/gameaikit/adversarial`.
  - `check_addon_deps.py` exits 0, and `check_modules.py` reports "ok --
    37 modules".
  - `mcts.gd` is 286 lines.
  - `principal_line` is a pure addition, read-only on the tree, so it
    changes nothing for Nim, the dice race or any other user.
- **The tactical game.**
  - `keep_thinking()` returns false for every other controller, so
    `_process` does nothing outside MCTS.
  - `squad_match.play`'s new `between` defaults to an invalid `Callable`,
    and `_call` skips it.
  - `squad_status` takes the new branch only when the controller
    `is MctsSquad`.
  - The Advance Wars mode is untouched.
- **Readability.** `check_readability.py` exits 0. No new GDScript function
  is over 40 lines. In Python, the `AdversarialGame` overrides in
  `search_game.py` have no docstrings, which matches `toy_games.py`.
- **The frame, measured in the real scene** with a throwaway gdUnit suite
  (since deleted). It opens `tactical.tscn` in XCOM mode, sets MCTS with C
  and S, and runs 4 decisions, headless:

  | what is timed | median | worst |
  |---|---|---|
  | `keep_thinking` (4 iterations) | 4.1-4.2 ms | 4.7 ms |
  | `_refresh` | 1.1 ms | 1.2 ms |
  | the space press (play the decision, then the next decision's first frame) | | 15.6-21.6 ms |

  Each decision took 249 frames.

## Findings

1. **Should-fix: half of `principal_line` is untested, in both
   languages.**
   - `godot/addons/ai_adversarial/mcts.gd:147` and
     `python/gameaikit/adversarial/mcts.py:114` follow "the outcome drawn
     most often" (`_most_visited(branch.children)`).
   - Both tests run on Nim, which has no chance, so `children` always has
     one entry.
   - Planted `node = branch.children[0]` in each language. Nothing failed
     in `test_adversarial_mcts.py` or `test_squad_search.py`.
     `test/ai_adversarial`, `mcts_squad_test.gd` and `squad_scene_test.gd`
     ran 52 cases and none failed.
   - This matters in this mode. A shot's first child is the hit, so for
     any shot under 50% the line shown would follow the less likely
     outcome, and nothing would notice.
   - Fix: a case on the dice race (`DICE_RACE` / `toy_games.Race`, both
     already in the tests) whose second line entry is checked against the
     most visited child of a roll.
2. **Should-fix: Enter plays the searcher at 4 iterations, and nothing
   on screen says so.**
   - `tactical.gd:420`, `play_rest_of_computer_turn`, calls
     `step_decision` in a loop with no frame in between. Each MCTS decision
     is therefore played after `_start`'s single `_per_frame` run.
   - That is 4 iterations over a question of about 40 answers, so it plays
     roughly the first answers it expands. The PR names this as decision 2.
   - Enter is the documented key for a long game ("for the many holds a
     long game brings"). A person who uses it sees MCTS play far worse than
     its measured strength, and only the reason string says why.
   - Fix (one loop):
     `while computer.keep_thinking(): pass` before each `step_decision` in
     `play_rest_of_computer_turn`.
   - The freeze that follows is about 1 s a piece (0.8 s a decision
     measured, plus 249 x 1.1 ms of redraw that the loop can skip). At the
     least, the status line should say that Enter plays without searching.
3. **Should-fix: the page's time figures do not describe what a person
   sees.** All three are in `docs/godot/squad.md`, about lines 355-366.
   - **What a person waits.** "0.8 s a decision" is CPU time. In the scene
     a decision is `iterations / iterations_per_frame` = 250 frames. That
     is about 4.2 s at 60 frames a second, whatever the CPU. A squad turn
     has up to eight decisions, so a person who waits for every bar sees
     about half a minute a turn. The page should say so, because it is
     what the manual check will meet.
   - **Where the worst frame comes from.** The page says a decision's first
     frame costs "about 1.5 ms more". Measured in the scene, the steady
     frame is about 5 ms (search 4.2 + redraw 1.1) and the hand-off frame
     is 15.6-21.6 ms. The 22 ms worst frame is that hand-off: playing the
     decision, then `believe` (called again by `decide_attack`),
     `TacticalReach.walks_for`, and the first 4 iterations. It is not a
     search frame.

     The verdict on 22 ms: acceptable, not a blocker. It is one dropped
     frame per decision, at the moment the person presses space, in a
     turn-based game, and the steady frames are well under 16.7 ms. The
     page should name it as the hand-off frame. It should also say that the
     measure times only `keep_thinking`, without the redraw `_process`
     adds.
   - **5,000 iterations.** "at about a minute a decision" (line 364)
     contradicts the table's 6.1 s average and 9.8 s maximum. It probably
     means a game.
4. **Nit: `mcts_squad_test.gd:154` returns early and stays green** when
   the first decision is a hold, so the refused-walk test can assert
   nothing. Assert `first.move != null` (seed 4 at 60 iterations), or
   choose a position where a walk is certain.
5. **Nit: the check's budget is below the root's width.** `BUDGET` is 24
   and the root has 43 answers (position 0). The check never sees a tree
   below an expanded root: each iteration is one expansion and a playout.
   Leaks still show, since every playout reads the believed board, as
   finding 1 of "What holds" shows. The comment should say the budget is
   below the root's answer count, so nobody reads the check as covering
   the selection step.
6. **Nit: `SquadSearchGame._entry_costs` is a static cache.** It is keyed
   by the graph's instance id, and it lives across searches and games. Its
   comment says "a board's terrain never changes under a search", but the
   cache outlives any single search. Nothing in the squad calls `set_cost`
   after `TacticalRules.graphs_from`, so it is correct today. The comment
   should state the real assumption: a graph's costs are never changed
   after it is built.
7. **Nit: `mcts.py` `principal_line`'s docstring** says what, not why.
   The GDScript twin's "A line, not a plan: the deeper a move, the fewer
   playouts it rests on" belongs in both.
8. **Nit: `_after_shot` (`squad_search_game.gd:268`) builds the board again
   without saying why.** `next = next.duplicate_state()` is what drops a
   piece at 0. The comment two lines above says so ("a target left at 0 is
   gone"), but not that this line is the mechanism. `SquadUnseenCheck:115`
   says it inline, and this line should do the same.

## Items for the owner

1. **The bars are close to uniform on a walk question.** In the committed
   vectors at 1,000 iterations:
   - "the opening" visits its 41 answers 22 to 26 times each;
   - "a shield beside the rock" visits its 46 answers 19 to 26 times each.

   At 25 visits the UCB1 term is about 0.26
   (0.5 · √(ln 1000 / 25)), while the means differ by a few hundredths
   (health over 33). So the manual check's "does the one it plays have the
   most?" is answered by one or two visits. The measured strength (56 and
   63 of 100 against the weighed enemy) says the means still count. Even
   so, the overlay will mostly teach "it tries everything evenly".

   The choices are:
   - accept it, and say so on the page;
   - lower the exploration constant further;
   - widen the score, for example by scaling the health difference to the
     spread playouts actually reach.
2. **Iterations a frame, by count or by time.** A fixed 4 a frame leaves
   roughly 11 ms of a 16.7 ms frame unused, and makes a decision last 250
   frames however fast the machine is. A time budget per frame, about
   8 ms, would roughly double the iterations a second without a worse
   steady frame. That is a design choice beyond this task.
3. **PR decisions 1-10.** The reviewer found nothing against ratifying 1,
   3, 4, 5, 6, 7, 9 and 10. On 2, see finding 2. On 8, the measurement
   scope is honest as written, once finding 3's wording is fixed.

## How to reproduce

```bash
git fetch origin pull/69/head && git checkout --detach FETCH_HEAD && make worktree-setup
# finding 1: no test sees the outcome step of principal_line
sed -i 's|            node = _most_visited(branch.children)|            node = branch.children[0]|' python/gameaikit/adversarial/mcts.py
python3 -m unittest discover -s python/tests -t python -q -p "test_adversarial_mcts.py"   # OK
git checkout python/gameaikit/adversarial/mcts.py && find python -name __pycache__ -prune -exec rm -rf {} +
# a fog leak is caught: put never-seen guesses on their true cell in MctsSquad.believe, then
make test-godot-some SUITES="test/squad/mcts_squad_test.gd"   # test_changing_what_it_cannot_see... FAILED
```

## What was done about them

Applied on the branch by the implementer, after the review.

1. **Should-fix 1, applied.** A coin game in both twins' tests: heads one
   time in five, then "a"; tails, then "b". The line must be `flip, b`.
   The reviewer's plant (`node = branch.children[0]`) now fails
   `mcts_test.gd` and `test_adversarial_mcts.py`. Both plants were run and
   undone.
2. **Should-fix 2, applied.** `play_rest_of_computer_turn` lets the
   controller finish thinking before each decision is played: Enter skips
   the watching, not the search. `squad_scene_test.gd` holds it: after
   Enter, every search ran its whole budget (40 there), not the first
   frame's 4. PR decision 2 now says so.
3. **Should-fix 3, applied.** `docs/godot/squad.md` separates the search's
   own time from what a person waits (250 frames, about 4.2 s at 60 a
   second). It gives the steady frame (about 5 ms) and says where the worst
   frame comes from: space plus the next decision's start, about one
   dropped frame a decision. The 5,000 line now matches the table.
4. **Nit 4, applied.** The refused-walk test builds the refused walk
   itself, a route through (2, 2), so it always asserts something.
5. **Nit 5, applied.** `BUDGET` is 50, above the 43 answers at the root.
   The planted searchers are still caught on 20 of 24 positions each. The
   seeded game's digest was written again (blue wins in round 11).
6. **Nit 6, applied.** The comment now says the cache is kept across
   searches and games, at most `COSTS_KEPT` graphs, and why that is safe.
7. **Nit 7, applied.** The docstring says why visits, not means.
8. **Nit 8, applied.** The comment says the rebuild is what removes a
   destroyed piece.

The owner's items (the near-flat bars, and iterations a frame by count or
by time) are in PR #69's body, each with a recommendation.
