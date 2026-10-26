# T88 — Expectiminimax faces MCTS on the same positions

Size: M · Prereqs: T87 · Files: `godot/addons/ai_adversarial/`, `godot/test/ai_adversarial/`, `python/gameaikit/adversarial/`, `spec/vectors/adversarial/`, `godot/game/squad/`, `godot/test/squad/`, `spec/squad/`, `python/gameaikit/squad/`, `python/tests/`, `docs/godot/squad.md`, `docs/concepts/`, `docs/techniques/ai_adversarial.md`, `docs/techniques/ai_adversarial.pt-BR.md`, `Makefile`

## Goal

The owner, 2026-10-26, answering T73's question 5: part B "segue o
recomendado" -- **B.2 together with A.1**: `ai_adversarial` in a second
game, the same one as MCTS, "so MCTS and alpha-beta face the same
position". The second game is the XCOM-style mode (T84), where shots are
dice, so alpha-beta faces it as **expectiminimax**: max and min nodes as
before, and chance nodes that weigh each outcome by its probability (AIMA
4th ed., 5.5, Stochastic Games). Alpha-beta's own header already says why:
"a game with dice or hidden cards ... need[s] expectiminimax or a
different family altogether" (`adversarial_game.gd`).

What it shows: whether `AdversarialGame` is an interface or checkers'
shape (B.2's question), and the lesson only a side-by-side gives -- an
evaluation function and a depth against samples and a budget, on one
position, at one time limit.

## Decisions written down first (the owner confirms in review)

- **`expectiminimax.gd` in `ai_adversarial`**, reading T86's `outcomes`;
  at a chance node, the sum of probability times value. No pruning at
  chance nodes in this task (*-minimax pruning bounds need the evaluation's
  range; a later task can add it).
- **The evaluation is written by hand** in the squad's adapter -- health,
  cover held, enemies flanked, each with a fixed weight in
  `spec/squad/rules.json`. Nothing fitted (invariant 6). The point of the
  comparison is that MCTS needs none of it.
- **Same positions, same time**: a committed set of 30 positions
  (`spec/squad/positions.json`), drawn from seeded matches and chosen by
  hand to include a flank, a long shot, a retreat to cover; each searched
  by both at the same wall-clock budget per decision (50, 200, 1,000 ms),
  and in full seeded matches against each other and against T85's
  baseline. Written down as measured, whichever wins.
- **Fog**: the same single determinization as T87, so the two are compared
  on the same information.

## Steps

1. Expectiminimax with a depth cutoff, its `AdversarialResult` carrying
   per root action its expected value; gdUnit cases on hand-built trees
   with known values, chance nodes included; checkers' suite unchanged.
2. The Python twin of it in `python/gameaikit/adversarial/`, and the
   addon's vectors on T86's toy dice game (root values at depth 2 and 3,
   equal in both languages) -- the addon's twin imports no example. The
   squad positions' expected values are the squad's own gate, in
   `godot/test/squad/` and the squad's Python tests.
3. `ExpectiSquad` in the squad roster; it searches across frames under the
   same per-frame budget as T87 (iterative deepening, the deepest finished
   depth's answer -- anytime too, by a different route).
4. The duel: `make test-squad-duel` runs the 30 positions and 100 seeded
   matches a seat, and prints a table; `docs/godot/squad.md` keeps it.
   Where they disagree on a position, the page shows one and says why.
5. The `ai_adversarial` technique page, both languages, and the
   `docs/concepts/` page: when each family wins, from the table.
6. T73's literature page: the MCTS and "stochastic games" rows now name
   `ai_adversarial` and `demo-tactical` (`make lint-literature` holds them).

## Acceptance

```bash
make test-adversarial-vectors
make test-checkers-vectors
make test-squad-duel
make test-godot-some SUITES="test/ai_adversarial test/squad test/checkers"
python3 -m unittest discover -s python/tests -t python -p "test_adversarial*.py"
python3 scripts/check_literature_table.py
python3 scripts/check_translations_docs.py
make lint-modules
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

Open one of the positions where the two disagree (`make demo-tactical MODE=squad`, the
position picker), with V: do the two overlays -- expected values per
option, visits per option -- make it clear *why* each chose what it chose?

How invariant 13 is met: for expectiminimax, each option's expected value
and the depth finished so far, drawn on the board before the move; at a
shot, the hit and miss branches with their probabilities. Side by side
with T87's overlay on the same position.

References, opened on 2026-10-26: AIMA 4th ed., contents (5.5 Stochastic
Games, 5.5.1 Evaluation functions for games of chance)
<https://aima.cs.berkeley.edu/contents.html>.
