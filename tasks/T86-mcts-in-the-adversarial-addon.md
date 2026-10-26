# T86 — Monte Carlo tree search in `ai_adversarial`, on a game it does not know

Size: M · Prereqs: none · Files: `godot/addons/ai_adversarial/`, `godot/test/ai_adversarial/`, `modules/ai_adversarial.json`, `python/gameaikit/adversarial/`, `spec/vectors/adversarial/`, `python/tests/`, `docs/concepts/`, `docs/techniques/ai_adversarial.md`, `docs/techniques/ai_adversarial.pt-BR.md`, `Makefile`

## Goal

The owner, 2026-10-26, answering T73's questions 1 and 2: every entry of
the roadmap's part A, **MCTS first** ("todos"; the recommended three
first), and its home the tactical game as an XCOM-style mode ("será que
pode ser estilo X-com?" -- T84, T85).

MCTS teaches two things the kit's alpha-beta cannot: **sampling instead of
an evaluation function**, and **anytime search** -- stop it whenever, it
has an answer (AIMA 4th ed., 5.4). It is the search Roelofs used for
*Xenonauts 2*, "a tactical game akin to X-Com", with UCT, "the most common
and battle tested variant" [GAP3 ch. 28].

This task is the technique, in the addon, on a small game the addon's own
tests own (Nim, and a toy game with dice); T87 puts it in the squad mode.
Split so that the addon's vectors never depend on an example's rules.

## Decisions written down first (the owner confirms in review)

- **MCTS lives in `ai_adversarial`, beside alpha-beta**, over the same
  `AdversarialGame` interface. T73's page said "a new module beside
  `ai_adversarial`"; invariant 2 forbids an addon depending on another, so
  a separate `ai_mcts` could not use `AdversarialGame` and would carry a
  copy of it. One addon, two families of adversarial search, one game
  interface -- which is also B.2's question ("whether `AdversarialGame` is
  an interface or checkers' shape") answered by use.
- **`AdversarialGame` loses one promise and gains one method**:
  - "the players alternate" goes; `to_move(state)` is read at every node,
    so a side may act several times in a row (T84's unit actions). Minimax
    and alpha-beta alternate by their structure today (`_max_value` calls
    `_min_value` and back, in `minimax.gd`); they must instead pick max or
    min by `to_move` at each node, with checkers' values unchanged.
  - `outcomes(state, action) -> Array` of `{probability, state}`. It is a
    **concrete method on the base class with a default** -- one outcome,
    `result(state, action)`, probability 1 -- not an abstract one, so
    checkers, which does not override it, keeps compiling and behaving.
    MCTS samples from it; T88's expectiminimax sums over it.
  If T64 has fixed the prefix for ports by then, the interface's name
  follows it; otherwise T64's rename covers it.
- **Chance in the tree**: after an action with several outcomes the node
  has one child per outcome, visited as they are drawn, so each subtree's
  value is conditioned on what happened. Open-loop MCTS (one child per
  action, outcomes mixed) is the named alternative, left out.
- **Every random draw inside the search uses one generator**: a small
  seeded 32-bit xorshift written in both GDScript and Python, so the twin
  matches draw for draw -- the outcome sampled at a chance node, the
  random playout's moves, the tie-break. Only the real game's dice stay
  the game's (the board's `dice_seed` in the squad mode); the search never
  touches them.
- **The playout**: random legal actions to the end or to a fixed depth,
  then the game's `evaluate` on the last state (for Nim, the outcome).
  Nothing is fitted, so invariant 6 is not touched.
- **Never on the frame**: `step(iterations)` runs a bounded number of
  iterations and returns; the caller gives it a budget per frame (the
  RTS's `FrameBudget` idea, rewritten, not imported). Checkers' alpha-beta
  at depth 6 stalls a frame up to ~730 ms (T27); MCTS must not.

## Steps

1. Read `adversarial_game.gd`, `minimax.gd`, `alpha_beta.gd`, their suite
   and checkers' Python twin; relax the alternation promise, add the
   default `outcomes`; a case where one side moves twice and minimax still
   finds the known value; checkers' suite and vectors unchanged.
2. `mcts.gd`: selection by UCB1 on the tree, expansion of one untried
   action, the playout, backpropagation -- named as AIMA 5.4 names them,
   top to bottom like the book's pseudocode -- and `MctsResult`: per root
   action its visits, mean value and bound, and the iterations run.
3. `xorshift.gd` and its Python twin; the Python MCTS in
   `python/gameaikit/adversarial/`, which imports nothing of any example.
4. Vectors in `spec/vectors/adversarial/`, on Nim and on a toy dice game
   defined in the addon's test folder and in Python: from a seed, the
   root's visit counts after a fixed number of iterations, equal in both
   languages (`make test-adversarial-vectors`). Planted: a twin with one
   draw out of order must fail them.
5. Teaching: a `docs/concepts/` section on MCTS (UCT, the four phases,
   anytime), and the `ai_adversarial` technique page in both languages
   gains MCTS, its minimal example on Nim.

## Acceptance

```bash
make test-adversarial-vectors
make test-checkers-vectors
make test-godot-some SUITES="test/ai_adversarial test/checkers"
python3 -m unittest discover -s python/tests -t python -p "test_adversarial*.py"
python3 scripts/check_addon_deps.py
python3 scripts/check_translations_docs.py
make lint-modules
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

Read `mcts.gd` beside AIMA's pseudocode for MCTS: does it read top to
bottom like it, phase by phase? Run the Nim example from the technique
page: after a few hundred iterations, is the winning move the most
visited?

How invariant 13 is met: by T87 in the squad mode. This task gives it what
to draw -- `MctsResult` holds each root option's visits, mean and bound
after every `step`, so a caller can draw the search while it runs.

References, opened on 2026-10-26: AIMA 4th ed., contents (5.4 Monte Carlo
Tree Search, 5.5 Stochastic Games) <https://aima.cs.berkeley.edu/contents.html>;
Roelofs, GAP3 ch. 28, sections 28.1-28.3 (T84 gives the URL); Browne et
al. 2012 and Sturtevant, GAP2 ch. 25, as cited by T73.
