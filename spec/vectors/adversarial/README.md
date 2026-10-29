# Conformance vectors: adversarial search (MCTS)

<!-- doc-meta
half_life: structure
verified_on: 2026-10-29
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: the xorshift generator, the order of the search's draws, UCB1's tie-break, or Nim's or the dice race's rules change
teaches: none
-->

> One search, two languages, and the files that say they drew the same.

`ai_adversarial`'s `MonteCarloSearch` (GDScript) and
`gameaikit.adversarial` (Python) are the same UCT, drawing every random
choice from the same 32-bit xorshift (Marsaglia, 2003). If they make the
same draws in the same order, they grow the same tree, and the root's visit
counts after a fixed number of iterations are equal. One draw out of place
and they part at once -- which is what these vectors are for. Both sides
check every claim against the files, never against each other: `make
test-adversarial-vectors` on the GDScript side, `make test-python` on the
Python side.

## The files

- `xorshift.json` -- `cases` of a `seed` and its first six `draws`. Seed 1
  starts 270369, which can be worked by hand: 1 xor (1 << 13) is 8193;
  8193 >> 17 is 0, so it stays 8193; 8193 xor (8193 << 5) is
  8193 + 262176 = 270369. Seed 0 is seed 1, because a state of zero would
  stay zero.
- `mcts-nim.json`, `mcts-dice-race.json` -- a `game` (`nim` or `dice_race`,
  the two games the addon's tests own) and `cases`, each with the `state`
  to search from, the `seed`, the `steps` (iterations per call to `step`,
  in order -- the tree carries over between them), the `exploration`
  constant and the `playout_limit`, and the claims: every root move's
  `visits` and `means` in the game's order, and the `action` chosen.

The rules the two searches follow, and that a third implementation must
follow to agree:

1. a draw is spent only when there is a choice: choosing among one move or
   one outcome draws nothing;
2. expansion draws which untried move to try, by its index among the
   untried ones still in the game's order (`next() % count`);
3. an outcome is drawn by `next() / 2^32` against the running sum of the
   probabilities, in the game's order;
4. selection takes the highest UCB1 bound, of equal bounds the first; the
   answer is the most visited move, of equal visits the first;
5. a playout chooses its move first, then its outcome.

## Where the numbers came from

From neither implementation: `derive.py`, a third MCTS written short and
importing nothing from this repository, wrote them:

    python3 spec/vectors/adversarial/derive.py spec/vectors/adversarial

They prove that the two searches agree, not that either is right. That is
the property tests' job (`mcts_test.gd`, `test_adversarial_mcts.py`): Nim's
winning take, the dice race's obvious choices at the end, one child per
face under a roll. Two cases are there to be read:

- `ten sticks after 300: not sure yet` -- seed 1 still prefers taking one;
  `ten sticks after 1000: take two` is the same search, later. An anytime
  answer is not always a right one.
- `one square from home: walk` -- a walk wins for certain, a roll half the
  time; the walk gets most of the visits.
