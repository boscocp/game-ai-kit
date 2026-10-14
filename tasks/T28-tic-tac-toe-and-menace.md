# T28 — Tic-tac-toe, and a machine that learns it

Size: M · Prereqs: T27, T5 · Files: `python/gameaikit/`, `godot/game/tictactoe/`, `Makefile`, `spec/`, `scripts/check_no_training.py`

## Goal

The learned model in today's `make run` is a regression nobody can see learn.
Tic-tac-toe has the most visual learning machine there is: **MENACE**
(Donald Michie, 1961). It was a matchbox for every position MENACE could face
with itself to move (304 of them, after symmetries), holding coloured beads,
one colour per legal move. MENACE played first. After each game, every box
it drew from is rewarded:
- a win adds three beads of the colour it played;
- a draw adds one;
- a loss removes the bead it played.

A box that runs empty means MENACE resigns. It is reinforcement learning
you can draw.

Tic-tac-toe is also small enough to solve outright. Minimax from T27 plays it
perfectly, so the learned player can be put beside the perfect one and seen
to converge on it, or fail to.

## Steps

1. **MENACE in Python, standard library only** (tier 1), with Michie's
   rewards above and resignation on an empty box. It trains against a
   random player, then against minimax. Against minimax it can only draw or
   lose, so without the draw reward it would only ever drain. Board
   symmetries fold the positions to Michie's 304 boxes. The bead counts are
   published as data, like `weights.json`.
2. **No training at game time** (invariant 6). Godot reads the bead counts
   and plays by them. It never adds or removes a bead. **The gate has to
   learn that too:**
   - `check_no_training.py` only knows `weights.json` and assignments to
     `weights` or `bias`, so `beads[move] += 1` in GDScript would pass it
     today;
   - extend it to forbid writing to bead counts under `godot/`, and to
     regenerate the published beads from their seed;
   - give each new rule a planted case it must reject.
3. **Snapshots at several points in training** (after 10, 100, 1,000 and
   10,000 games), so the game can show the same machine at different ages.
4. **Play against it in Godot, as `make demo-tictactoe`**, an example under
   `check_demos.py`. MENACE moves first, as it did. Each empty square shows
   its beads, as a number and as a bar, before MENACE picks (invariant 13).
   A toggle shows what minimax would play there instead.
5. A page in `docs/concepts/` on the matchboxes, with Michie's paper as the
   source.

## Acceptance

```bash
make test-python
make test-godot
make lint-demos
make test-demo-overlays
make lint-no-training
make lint-selftests
```

The suite must include:
- **Strength, measured by a decidable test.** MENACE moves first and
  always picks its most-beaded move:
  - the 10,000-game snapshot loses no game of 1,000 seeded games against a
    random player;
  - the 10-game snapshot loses at least one.

  Playing by the most beads makes "never" decidable; drawing at random
  would not.
- **Symmetries.** Equal positions fold to one matchbox, and there are 304.
- **A shared vector between the languages.** The Godot player and the
  Python player choose the same move from the same beads and **the same
  uniform draw in [0, 1)**, given as an input. The two engines' random
  number generators differ (PCG32 against Mersenne Twister), so the vector
  carries the draw, not a seed.
- **The extended gate rejects its planted cases.** A bead written in
  GDScript, and a published bead file that does not match its seed.

## Manual check

Play the 10-game snapshot, then the 10,000-game one. A person should feel the
difference and see on the squares why one plays badly and the other does not.
