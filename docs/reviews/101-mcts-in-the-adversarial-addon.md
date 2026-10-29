# Review: wave/101-mcts-in-the-adversarial-addon

T86: Monte Carlo tree search goes into `ai_adversarial`, beside alpha-beta
and over the same `AdversarialGame`.

- `MonteCarloSearch` is UCT with one child per outcome drawn.
- `MctsResult` gives each root move's visits, mean and bound.
- `Xorshift` is a generator written out in both languages.
- `AdversarialGame` no longer promises that the players alternate, and it
  gains a concrete `outcomes`.
- `gameaikit.adversarial` is the Python twin, and `spec/vectors/adversarial/`
  holds the two languages to one another.

A fresh context reviewed PR #41 at head 2caf7d1.

**Verdict: no blockers.** There were three should-fix findings and several
nits. Every one was applied on the branch, except where this record says
otherwise.

## What was reviewed

The diff against main:

- `mcts.gd`, `mcts_result.gd` and `xorshift.gd`, and the changes to
  `adversarial_game.gd`, `minimax.gd` and `alpha_beta.gd`;
- the Python package, line by line against the GDScript;
- `derive.py` and the vectors it writes, with both suites that read them;
- the test folder's Nim and dice race, the planted twins, and the
  gdUnit suites;
- the concept page, the technique page in both languages, the glossary and
  the literature row;
- the manifest, the Makefile target and the STATUS row.

## What the reviewer found sound

- **The UCT phases are correct.** SELECT, EXPAND, SIMULATE and
  BACK-PROPAGATE match AIMA 5.4 and figure 5.11, in that order.
- **The backed-up value has the right sign when a side moves twice.** Each
  branch is credited from the side of the player who chose it.
- **Chance nodes are closed-loop.** There is one child per outcome, made
  when that outcome is first drawn, and a branch's visits are the sum of
  its children's.
- **The tree is reused across `step()`.** The reviewer checked it: 70
  iterations then 130 give the same tree as 200 at once.
- **Minimax and alpha-beta are unchanged where the players alternate.**
  Checkers' suites and vectors pass untouched.
- **The Python twin matches line for line**, draw for draw.
- **The claim about seeds 1-40** (1000 iterations find Nim's winning take
  up to 11 sticks, and 13 needs about 2000) was verified independently.

## Findings

1. **The bound was never checked except for `INF` (should-fix).** The
   reviewer planted two mutants, and both survived every suite and the
   vectors:
   - in `mcts.gd`, the root bound computed with a parent count of 1, which
     makes the bound just the mean;
   - in Python, the parent count taken as `_iterations + 1`.

   T87 is meant to draw this number.
2. **A wall-clock assertion inside a gdUnit suite (should-fix).**
   `test_a_frame_of_iterations_fits_in_half_a_frame` was the only timing
   check in any `*_test.gd`. Elsewhere, timing claims have their own
   targets (`test-rts-budget`), because they flake under load.
3. **The planted twin was misdescribed (should-fix).** "One draw out of
   order" in fact calls `uniform()` before every playout move, even when
   the move has one outcome.
   - On Nim it breaks rule 1 of the README (a draw only on a real choice),
     not rule 5 (the move before the outcome).
   - Its comment, "the same draws, one of them out of place", was untrue.
4. **Nits.**
   - The technique page still said that minimax "alternates down the tree",
     in both languages: the promise this wave removed.
   - The concept page said "with C = √2 this is UCT". UCT is UCB1 on a
     tree with any C. It also did not say that √2 belongs to results in
     [0, 1] while the toy games score in [-1, 1].
   - Whether a drawn number exactly on a boundary between outcomes falls
     below or above it (`<` against `<=`) was not pinned by any test.
   - Python's `wrong_claims` left `found` unbound when a case had no
     `steps`.
   - The PR body said there were 6 cases on Nim; there are 7, and 5 on
     the dice race.
   - Optional: every test game was zero-sum, so a mutant that gave the
     opponent the negation of the root player's value survived.
   - `docs/concepts/minimax.md` keeps its title. MCTS stays a section of it
     until T88 adds to it (the owner's choice).

## What was done about them

1. A property test in each language checks that every visited root move
   reports mean + C * sqrt(ln(iterations) / visits), the root being
   visited once per iteration:
   - GDScript: `test_a_visited_root_move_reports_its_ucb1_bound` in
     `mcts_test.gd`;
   - Python: the same name in `test_adversarial_mcts.py`.

   Both of the reviewer's mutants now fail.
2. The timing check moved to `godot/test/ai_adversarial/mcts_budget.gd` and
   a new target, `make test-mcts-budget`.
   - It is wired into `check` beside `test-rts-budget`, and listed among
     the module's gates.
   - It measures 20 frames of 100 iterations each. Both the mean and the
     95th percentile must stay under half a frame.
   - It must show its work: every iteration counted.
   - Its check is first shown a run over the share, and a run with nothing
     measured, both of which it must refuse.
3. The twin is now `SpareDraw`, described as what it is: it breaks rule 1,
   and on the dice race rule 5 as well. A second twin was added,
   `MirroredExpansion`. It makes the same draws in the same order and reads
   expansion's index from the other end, so it breaks rule 2 alone. Both
   twins must fail both games, in both languages.

   A twin that breaks rule 5 alone was not written, because it cannot be.
   Whether an outcome is drawn at all depends on the move the earlier draw
   chose, so putting the outcome's draw first changes how many draws there
   are. The README and the twin's comment both say so.
4. The nits:
   - The technique page now reads "your best on your turn, their worst on
     theirs" (pt-BR: "o seu melhor na sua vez, o pior dele na dele").
     `translation_of` was recomputed.
   - The concept page now says that UCB1 at every node is UCT, and that √2
     is the usual default. It explains that √2 is the constant for results
     in [0, 1], so with scores in [-1, 1] the default explores about half
     as much as that analysis suggests, and that `exploration` is the knob.
   - The boundary is pinned. Seed 2281717760 draws exactly 2^31 first; it
     was found by running `Xorshift.next` backwards. That makes a uniform
     of exactly 0.5, which falls in the second outcome of 0.5 / 0.25 / 0.25.
     A test in each language holds this, and the README states the rule.
   - `wrong_claims` starts from `search.result()`.
   - The PR body is corrected.
   - The per-chooser value is held by a game that is not zero-sum:
     `SharedLeaves` in Python and the `SHARED` tree in `turns_test.gd`. A
     search that gave the opponent the negation of the root player's value
     plays the wrong move there.
   - `minimax.md`'s title is unchanged, as the owner chose.

A second mutation round covered the new rules. Each mutation broke one rule
and the suites had to fail:

- the root bound with a parent count of 1 (GDScript), and with
  `_iterations + 1` (Python);
- the opponent credited with the negation of the root player's value, in
  both languages;
- a boundary draw staying in the outcome below (`<=`), in both languages;
- the budget's check accepting any time;
- the budget's search doing no work.

All eight were caught. The first round's 22 GDScript and 18 Python
mutations still apply.

## The reviewer's runs

- **Vectors:** `make test-adversarial-vectors`, 4 draw cases and 12 search
  cases, 0 failures.
- **gdUnit:** `make test-godot-some SUITES="test/ai_adversarial
  test/checkers"`, 76 cases, 0 failures.
- **Python:** `make test-python`, 368 tests, OK.
- **Lints:** every one the wave touches exited 0.
- **Mutants:** 10 in Python and 5 in GDScript. The survivors were:
  - the two bound mutants of finding 1;
  - the "negate the root player's value" mutant;
  - the `<` / `<=` boundary.

  The rest were caught.

After the fixes, the wave's own runs:

- the same gdUnit run, 79 cases, 0 failures, no SCRIPT ERROR;
- `make test-mcts-budget`: mean about 2.4 ms, 95th percentile about 3.0
  ms, against a share of 8.3 ms;
- the vectors: 0 failures;
- `make test-python`: 371 tests, OK;
- the lints: exit 0.

## The owner's open choices, with the reviewer's opinion

Decided by the owner, 2026-10-29, as recommended: the ties (UCB1's and
the final answer's to the first move), MCTS as a section of `minimax.md`,
and tier 0 in the literature table. The dice race's scoring stays open.

- **Ties.** The generator chooses which untried move to expand; ties in
  UCB1 and in the final answer go to the first move in the game's order.
  The reviewer agrees.
- **The dice race scores an unfinished game as the lead divided by the
  goal.** The reviewer finds this fine: it is only read when a playout
  stops at its limit.
- **MCTS as a section of `minimax.md`.** The reviewer finds this acceptable
  now, and would split it into its own page when T88 adds to it.
- **Tier 0 in the literature table.** The reviewer finds this correct under
  the table's rule. Invariant 13 is met only when T87 lands, because MCTS
  has no demo until then.
