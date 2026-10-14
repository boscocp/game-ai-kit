# T27 — Checkers, and minimax

Size: L · Prereqs: T21 · Files: `godot/addons/ai_adversarial/`, `godot/game/checkers/`, `Makefile`, `spec/`

## Goal

`make run` is the first thing a person opens, and the owner opened it and
could not tell what game it was or what the AI was doing. The answer is a
game nobody needs explained. **Checkers**, against the computer, with the
technique every introduction to game AI starts from: **minimax with
alpha-beta pruning**.

The kit has no adversarial search yet. Every decision so far is one side
choosing a move on its own. Minimax is the first that asks "and then what
will *they* do?", which is why it comes first.

## Steps

1. **`ai_adversarial`**, a new addon depending only on `ai_core`:
   - minimax, then the same search with alpha-beta;
   - a fixed depth, and an evaluation function the game hands in.

   The file reads top to bottom like the pseudocode in Russell & Norvig. Keep
   the names `alpha` and `beta`: they are the literature's names, and belong
   on the readability gate's allowlist like `g`, `h` and `f`.
2. **The rules of checkers in `godot/game/checkers/`**, as the game's, not
   `ai_core`'s:
   - 8x8, diagonal moves, forced captures and multi-jumps;
   - crowning, and a draw after N moves without a capture.

   Write down which variant (English draughts) and its source.
3. **A hand-written evaluation**: pieces, kings, advancement. It is short,
   and it is the thing T32 replaces with a learned one.
4. **Play against the AI**, red against the computer, never two people at
   one mouse:
   - click a piece, and its legal moves light up;
   - click one, and the move is made;
   - a forced capture is highlighted, and a refused move says why.
5. **Show the decision before it is made** (invariant 13). The computer's
   turn draws:
   - the moves it considered, each with its minimax value;
   - how many positions it searched, and how many alpha-beta cut.

   Then a key, or a short delay, plays the move. A depth control (1 to 6)
   makes the cost of looking further visible.
6. **Retire the current board from `make run`.** It is the learned policy's
   example, and it is kept as `make demo-skirmish` until T26 gives that
   policy a real combat on the tactical board, where it is folded in. The
   README and `docs/godot/examples.md` say which target teaches what.

## Acceptance

```bash
make test-godot
make lint-demos
make test-demo-overlays
python3 scripts/check_addon_deps.py
python3 scripts/check_readability.py
```

The suite must include:
- minimax and alpha-beta return the same move and value on a set of
  positions, and alpha-beta searches fewer;
- a forced capture is the only legal move when it exists;
- a multi-jump is one move;
- crowning;
- at depth 1, the AI takes a free piece.

## Manual check

Hand `make run` to somebody who knows checkers and has not read the code.
They should play a game without being told the rules or the keys, and be able
to say, before the computer moves, which move it is about to make and why it
prefers it.
