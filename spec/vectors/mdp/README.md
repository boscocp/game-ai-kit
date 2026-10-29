# Conformance vectors: the maze's MDP

<!-- doc-meta
half_life: structure
verified_on: 2026-10-29
tier: 1
source: https://aima.cs.berkeley.edu/contents.html
invalidated_if: spec/maze/mdp.json, spec/maze/rules.json or spec/maze/maze.json changes
teaches: none
-->

> Ten states of the maze in, each one's value and best move out: the file
> that says the policy Godot plays is what value iteration computes.

T98 solves the maze as a Markov decision process in Python
(`gameaikit.mdp`) and publishes the values and the policy to
`godot/game/maze/`, which Godot only reads (invariant 6). These vectors hold
both ends to a third reading of the same rules.

`ten-states.json` holds a `tolerance` and ten `cases`. Each case is:

- the state: `pacman` and `ghost` (Blinky's) cells as [column, row],
  Blinky's `heading` (the direction of his last move) and the `pellets`
  left;
- `value`: the state's value, rounded to thousandths;
- `q`: what each of Pac-Man's four moves is worth there, by a one-step
  lookahead over the values -- the numbers the demo writes beside him;
- `action`: the best of the four, ties going up, left, down, right.

## Where the answers came from

From neither implementation: `derive.py`, beside the vectors, is a third
copy of the maze's rules and a second value iteration, written from the
words of `spec/maze/rules.json`'s and `spec/maze/mdp.json`'s "about" in
plain dictionaries, importing nothing from this repository. It solves the
whole MDP (about ten seconds), and refuses a case whose two best moves are
within 0.01 of each other, since rounding could swap them, and a case whose
name claims a move that is not the best. The two solvers sum in different
orders, so a value may differ in the last places: `tolerance`, 0.002, is
twice the published rounding.

    python3 spec/vectors/mdp/derive.py spec/vectors/mdp

`make test-mdp-vectors` checks the Godot side -- `MdpPacMan`'s lookup and
its lookahead over the published values -- and
`python3 -m unittest discover -s python/tests -t python -p "test_mdp*.py"`
the Python side, the published files and a fresh solve; each compares with
the file, never with the other.
