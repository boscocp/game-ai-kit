# Conformance vectors: the maze

<!-- doc-meta
half_life: structure
verified_on: 2026-10-29
tier: 1
source: https://www.gamedeveloper.com/design/the-pac-man-dossier
invalidated_if: spec/maze/rules.json or spec/maze/maze.json changes, or the order of a step's six moments changes
teaches: none
-->

> A seed and Pac-Man's moves in, where everyone is after every step out:
> the files that say Python's maze and Godot's are one game.

T98 solves the maze as an MDP in Python and ships the policy to Godot. The
policy means something only if a move in Python lands where the same move
lands in Godot, and a ghost's choice is the same choice. So the rules are
written twice -- `gameaikit.maze` and `godot/game/maze/` -- and held here.

Both languages draw from the same generator, Marsaglia's 32-bit xorshift,
written out in each (`maze_dice.gd`, `gameaikit/maze/dice.py`), so a seed
*can* be what the two agree on -- unlike MENACE's vectors, where Python's
generator and Godot's differ and each case carries the draw itself.

Each file is one game:

- `seed`, `ghosts` (which ghosts play, in order -- the order of the draws),
  `moves` (Pac-Man's, one a step: `up`, `left`, `down`, `right`);
- `trace`: a snapshot before the first move and after every move. Each
  snapshot is Pac-Man's cell and facing; for each ghost its cell, the move
  it chose next, how it chose it (`only way`, `nearest`, `dice`,
  `reversal`) and its target tile; the pellets left; the mode of the step
  about to be played; and `playing`, `won` or `caught`.

## Where the answers came from

From neither implementation: `derive.py`, beside the vectors, is a third
copy of the rules, written from the words of `rules.json`'s "about" in
plain dictionaries, importing nothing from this repository. Independent of
the code, not of its author: it would repeat a misreading of the Dossier
the other two share. It also checks that each case shows what its name
says -- a reversal, a dice turn, Pinky's target with the overflow bug, a
catch, a win -- because a vector named for a rule it never reaches holds
nothing.

    python3 spec/vectors/maze/derive.py spec/vectors/maze

`make test-maze-vectors` checks the Godot side, and
`python3 -m unittest discover -s python/tests -t python -p "test_maze*.py"`
the Python side; each compares with the file, never with the other.
