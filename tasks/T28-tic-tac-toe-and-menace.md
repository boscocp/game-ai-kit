# T28 — Tic-tac-toe, and a machine that learns it

Size: M · Prereqs: T27, T5 · Files: `python/gameaikit/`, `godot/game/tictactoe/`, `Makefile`, `spec/`

## Goal

The learned model in today's `make run` is a regression nobody can see learn.
Tic-tac-toe has the most visual learning machine there is: **MENACE**
(Donald Michie, 1961). It was a matchbox for every position, with coloured
beads for each move. Win, and the beads of the moves you made are added;
lose, and they are taken away. It is reinforcement learning you can draw.

Tic-tac-toe is also small enough to solve outright. Minimax from T27 plays it
perfectly, so the learned player can be put beside the perfect one and seen
to converge on it, or fail to.

## Steps

1. **MENACE in Python, standard library only** (tier 1). Self-play against
   a random player, then against minimax. Board symmetries fold the
   positions to a few hundred, as Michie did. The bead counts are published
   as data, like `weights.json`.
2. **No training at game time** (invariant 6). Godot reads the bead counts
   and plays by them. It never adds or removes a bead.
3. **Snapshots at several points in training** (after 10, 100, 1,000 and
   10,000 games), so the game can show the same machine at different ages.
4. **Play against it in Godot.** Each empty square shows its beads, as a
   number and as a bar, before MENACE picks (invariant 13). A toggle shows
   what minimax would play there instead.
5. A page in `docs/concepts/` on the matchboxes, with Michie's paper as the
   source.

## Acceptance

```bash
make test-python
make test-godot
make test-demo-overlays
make lint-no-training
```

The suite must include:
- the trained snapshot never loses to a random player over many games;
- the 10-game snapshot does;
- the symmetries fold equal positions to one matchbox;
- the Godot player and the Python player choose the same move from the same
  beads and seed (a shared vector).

## Manual check

Play the 10-game snapshot, then the 10,000-game one. A person should feel the
difference and see on the squares why one plays badly and the other does not.
