# Conformance vectors: MENACE

<!-- doc-meta
half_life: structure
verified_on: 2026-10-14
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: the symmetry order or the canonical box changes, or a draw stops being laid out square by square
teaches: none
-->

> Python trained it, GDScript plays it, and this is the file that says they
> draw the same bead.

MENACE draws a bead at random. Python's generator is a Mersenne Twister and
Godot's is PCG32, so the same seed gives different numbers and a seed cannot
be what the two sides agree on. Each case therefore carries **the draw
itself**, a number in [0, 1), and both sides must turn it into the same move.

Every case says:

- `board`: the real board, nine characters from the top left, `X`, `O` or `.`;
- `box`: the matchbox it folds into, the smallest of its eight turns as text;
- `beads`: the box's bead counts, square by square of the box;
- `draw`: the uniform number;
- `move`: the square of the real board to play, or `null` when the box is
  empty and MENACE resigns.

Each side checks the box and the move against the file, never against the
other side. The cases were worked out by hand on paper, so they cannot
confirm a mistake both implementations share:

- `make test-python` reads them through `gameaikit.menace`;
- `make test-menace-vectors` reads them through `godot/game/tictactoe/`.
