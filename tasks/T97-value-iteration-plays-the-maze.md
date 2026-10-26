# T97 — Value iteration plays the maze: an MDP solved in Python, its policy shipped

Size: M · Prereqs: T96 · Files: `python/gameaikit/mdp/`, `python/tests/`, `spec/vectors/mdp/`, `data/maze/`, `godot/game/maze/`, `godot/test/maze/`, `modules/maze.json`, `scripts/check_no_training.py`, `docs/concepts/`, `docs/techniques/`, `Makefile`

## Goal

The owner, 2026-10-26, answering T73's question 6: a small Pac-Man-style
maze (T96), **value iteration in Python, the policy shipped** (invariant
6). It teaches the step from search to sequential decisions under chance:
states, actions, a transition model, rewards, a discount, and the Bellman
update until the values settle (AIMA 4th ed., 17.1-17.2: 17.2.1 Value
Iteration, 17.2.2 Policy iteration).

Gymnasium's *Frozen Lake* is the usual first MDP -- on slippery ice a move
goes the intended way or to either side, each with probability 1/3, and
only the goal pays [Gymnasium] -- and T73 named it as the alternative. The
owner chose the maze: a game people know, with an opponent in it.

## Decisions written down first (the owner confirms in review)

- **The state**: Pac-Man's cell, the ghost's cell and heading, the ghost's
  mode, and which pellets remain. With about 50 cells, 4 headings, 2 modes
  and 4 pellets, that is about 50 x 50 x 4 x 2 x 16 = 320,000 states;
  value iteration over them in pure Python (tier 1, standard library) is
  measured before the size is fixed, and the page says how long it took.
  A second ghost multiplies it by about 200, so it stays out of the solved
  game unless measured feasible.
- **The transition model is the game's rules**, imported from T96's
  Python twin, not rewritten: the imprecise ghost's probability is where
  the chance comes from. Rewards: a pellet +1, all pellets +10 and the
  episode ends, caught -10 and it ends, a small cost per step; discount
  0.95. All in `spec/maze/mdp.json`.
- **Invariant 6**: value iteration runs in Python and writes
  `data/maze/policy.json` (state to action) and `data/maze/values.json`;
  Godot reads and looks up, never updates. `check_no_training.py` gains a
  rule, numbered the next free N when written: the published policy is
  what `gameaikit.mdp` produces from the committed rules (a fresh run
  matches it), and no GDScript writes where it lives. Planted: a policy
  edited by hand, and a GDScript that writes one. Q-learning or any update
  at game time is refused by ADR 0016's amendment of 2026-10-26.
- **Policy iteration too**, in Python only, as the comparison AIMA draws:
  the same policy, fewer sweeps, more work per sweep -- measured.

## Steps

1. `python/gameaikit/mdp/`: a generic finite MDP (states, actions,
   transition, reward, discount), value iteration with a stopping
   threshold, policy iteration, both tested on two small grids whose
   values are worked out by hand, one of them Frozen-Lake-like.
2. The maze as an MDP from T96's rules; solve; write the policy and the
   values. Vectors: for ten states, the value and the action.
3. `MdpPacMan`, a controller in `godot/game/maze/` that looks the policy
   up; C cycles person and MDP.
4. Measured, in the maze page: the MDP's mean pellets and catches over
   1,000 seeded episodes against the imprecise ghost, against a greedy
   controller (nearest pellet by A\*, ignoring the ghost).
5. The N rule and its planted cases; a concepts page on MDPs; a technique
   page if the MDP becomes a module of its own (the decision is the
   reviewer's -- it is Python and a lookup).

## Acceptance

```bash
python3 -m unittest discover -s python/tests -t python -p "test_mdp*.py"
make test-mdp-vectors
python3 scripts/check_no_training.py
python3 scripts/check_no_training.py --self-test
make test-godot-some SUITES="test/maze"
python3 scripts/check_demos.py
make lint-modules
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

Watch the MDP play `make demo-maze` with V on: does it wait for the ghost
to commit before crossing a corridor, and does the value map explain
why? Does it ever walk into the ghost?

How invariant 13 is met: with V, the value of each cell for Pac-Man drawn
as a heat map over the maze (for the ghost's current cell, heading and
mode, and the pellets left), the policy's arrow on each cell, and beside
Pac-Man the expected value of each of its four moves before it takes the
best -- what value iteration computed, at the moment it is used.

References, opened on 2026-10-26: AIMA 4th ed., contents (17.1-17.2)
<https://aima.cs.berkeley.edu/contents.html>; Gymnasium, *Frozen Lake*
<https://gymnasium.farama.org/environments/toy_text/frozen_lake/>.
