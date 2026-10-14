# Conformance vectors: checkers

<!-- doc-meta
half_life: structure
verified_on: 2026-10-14
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: the move order, the square names, the three counts or their order change
teaches: none
-->

> Python self-plays and fits the weights, GDScript plays the game, and these
> two files say the two agree on what is legal and what a position is worth.

- `rules.json`: positions drawn as eight rows from the top (`r` `w` men,
  `R` `W` kings, `.` empty), the side to move, and every legal move in the
  order both sides list them -- pieces from the top-left, row by row, each
  piece's moves trying up-left, up-right, down-left, down-right. Covers the
  opening, a compulsory capture, a branching double jump, crowning ending a
  move, a king stepping back, white moving down, and a side with no move.
- `evaluation.json`: positions, a player and a set of weights, with the three
  counts (men, kings, rows advanced by men, each the player's minus the
  opponent's) and the score. Worked out by hand.

Each side checks against the file, never against the other side:

- `make test-python` reads them through `gameaikit.checkers`;
- `make test-checkers-vectors` reads them through `godot/game/checkers/`.
