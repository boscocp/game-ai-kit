# T86 — Monte Carlo tree search plays the squad

Size: M · Prereqs: T85 · Files: `godot/addons/ai_adversarial/`, `godot/test/ai_adversarial/`, `modules/ai_adversarial.json`, `python/gameaikit/adversarial/`, `spec/vectors/adversarial/`, `godot/game/squad/`, `godot/test/squad/`, `docs/concepts/`, `docs/techniques/ai_adversarial.md`, `docs/techniques/ai_adversarial.pt-BR.md`, `Makefile`

## Goal

The owner, 2026-10-26, answering T73's questions 1 and 2: every entry of
the roadmap's part A, **MCTS first** ("todos"; the recommended three first),
and its home the tactical game as an XCOM-style mode ("será que pode ser
estilo X-com?" -- T84, T85).

MCTS teaches two things the kit's alpha-beta cannot: **sampling instead of
an evaluation function**, and **anytime search** -- stop it whenever, it
has an answer (AIMA 4th ed., 5.4). It is the search Roelofs used for
*Xenonauts 2*, "a tactical game akin to X-Com", with UCT, "the most common
and battle tested variant", and with each turn split into one unit's
actions [GAP3 ch. 28].

## Decisions written down first (the owner confirms in review)

- **MCTS lives in `ai_adversarial`, beside alpha-beta**, over the same
  `AdversarialGame` interface. T73's page said "a new module beside
  `ai_adversarial`"; invariant 2 says no addon depends on another, so a
  separate `ai_mcts` addon could not use `AdversarialGame` and would carry
  a copy of it. One addon, two families of adversarial search, one game
  interface -- which is also B.2's question ("whether `AdversarialGame` is
  an interface or checkers' shape") answered by use.
- **`AdversarialGame` loses one promise and gains one optional method**:
  - "the players alternate" goes; `to_move(state)` is read at every node,
    so a side may act several times in a row (T84's unit actions). Minimax
    and alpha-beta alternate by their structure today (`_max_value` calls
    `_min_value` and back, in `minimax.gd`); they must instead pick max or
    min by `to_move` at each node. Their suites show it, with checkers'
    values unchanged.
  - `outcomes(state, action) -> Array` of `{probability, state}`, empty
    for a deterministic action, and `result` keeps returning one sampled
    outcome. MCTS samples; T87's expectiminimax sums. Checkers does not
    implement it.
  If T64 has fixed the prefix for ports by then, the interface's name
  follows it; otherwise T64's rename covers it.
- **Chance in the tree**: after a shot the node has one child per outcome
  (hit, miss), visited as the dice fall, so each subtree's value is
  conditioned on what happened. Open-loop MCTS (one child per action,
  outcomes mixed) is the named alternative, left out.
- **Fog**: MCTS searches its side's view; unseen enemies stand where they
  were last seen. One determinization, said so on its page; sampling
  several is a later choice.
- **The playout**: random legal actions for a fixed number of turns, then a
  fixed score (each side's health left, normalised to [-1, 1]); every
  constant written in `spec/squad/rules.json`. Nothing is fitted, so
  invariant 6 is not touched.
- **Never on the frame**: a budget of iterations per frame (the RTS's
  `FrameBudget` idea, rewritten here, not imported), so the search runs
  across frames and the game shows it thinking. Checkers' alpha-beta at
  depth 6 stalls a frame up to ~730 ms (T27); MCTS must not.
- **A Python twin** in `python/gameaikit/adversarial/`, held to Godot's by
  vectors. Godot's and Python's generators differ, so the twin and the
  addon share a small generator written in both (a 32-bit xorshift), used
  for the playouts; the game's dice stay the board's.

## Steps

1. Read `adversarial_game.gd`, `minimax.gd`, `alpha_beta.gd` and their
   suite; relax the alternation promise and add `outcomes`, with a case
   where one side moves twice and minimax still finds the known value.
2. `mcts.gd`: selection by UCB1 on the tree, expansion of one untried
   action, the playout, backpropagation -- named as AIMA 5.4 names them,
   top to bottom like the book's pseudocode -- and
   `MctsResult`, the record of a finished or paused search: per root
   action its visits, mean value and bound, and the iterations run.
3. The squad's `AdversarialGame` adapter in `godot/game/squad/`, and
   `MctsSquad`, a `SquadController` row in the squad roster.
4. Vectors: three small positions, the root's visit counts after a fixed
   number of iterations from a fixed seed, equal in both languages
   (`make test-adversarial-vectors`).
5. Measured and written down in `docs/godot/squad.md`: MCTS at 200, 1,000
   and 5,000 iterations against T85's `WeighedSquad`, 100 seeded matches
   a seat each, with the time a decision takes and the worst frame.
6. Teaching: a section of `docs/concepts/` on MCTS (UCT, the four phases,
   anytime), and the `ai_adversarial` technique page in both languages
   gains MCTS -- `check_translations_docs.py` pins the pair.

## Acceptance

```bash
make test-adversarial-vectors
make test-godot-some SUITES="test/ai_adversarial test/squad test/checkers"
python3 -m unittest discover -s python/tests -t python -p "test_adversarial*.py"
make test-squad-match
python3 scripts/check_translations_docs.py
python3 scripts/check_demos.py
make lint-modules
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

In `make demo-squad`, switch the enemy to MCTS (C) and turn on V: while it
thinks, do the visit counts on each of the unit's options grow, and does
the one it then plays have the most? Stop it early (a key): is there still
a move, and is it a worse one?

How invariant 13 is met: on the board, for the unit about to act, each
option's visits (as a bar), mean value and UCB bound, updated each frame
while the search runs, and the principal line drawn after it -- the
search's tree read at its root, before the action is played.

References, opened on 2026-10-26: AIMA 4th ed., contents (5.4 Monte Carlo
Tree Search, 5.5 Stochastic Games) <https://aima.cs.berkeley.edu/contents.html>;
Roelofs, GAP3 ch. 28, sections 28.1-28.3 (T84 gives the URL); Browne et
al. 2012 and Sturtevant, GAP2 ch. 25, as cited by T73.
