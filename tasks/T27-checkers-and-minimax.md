# T27 — Checkers, and minimax

Size: L · Prereqs: T21 · Files: `godot/addons/ai_adversarial/` (with LICENSE and NOTICE), `godot/game/checkers/`, `godot/project.godot`, `Makefile`, `README.md`, `docs/concepts/`, `docs/godot/examples.md`

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

   The file reads top to bottom like the pseudocode in Russell & Norvig,
   *Artificial Intelligence: A Modern Approach*, 4th edition, chapter 5. Keep
   the literature's names `alpha` and `beta`. They are whole words, so the
   readability gate already allows them; nothing needs adding to its list.
2. **The rules of English draughts in `godot/game/checkers/`**, as the
   game's, not `ai_core`'s, with the source written down:
   - 8x8, dark squares only; men move and capture diagonally forward only,
     and kings both ways;
   - capturing is compulsory, but when several captures exist the player may
     choose any of them (no majority rule). A capture sequence, once begun,
     must be completed;
   - a man that reaches the far row is crowned, and **crowning ends the
     move**, even mid-jump;
   - a draw by the 40-move rule: 40 moves by each side with no capture and
     no man moved.
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
6. **Retire the current board from `make run`.** `run/main_scene` in
   `project.godot` points at the checkers scene. The current board, the
   learned policy's example, is kept as `make demo-skirmish`. Where that
   policy finally lives is T30's question: blue on the tactical board is
   one controller chosen among several. T24 later makes the menu the main
   scene, and `make run` keeps opening checkers. The README and
   `docs/godot/examples.md` say which target teaches what.

## Acceptance

```bash
make test-godot
make lint-demos
make test-demo-overlays
make lint-license
python3 scripts/check_addon_deps.py
python3 scripts/check_readability.py
grep -q 'run/main_scene="res://game/checkers/' godot/project.godot
grep -q '^demo-skirmish:' Makefile
```

The suite must include:
- **Minimax against alpha-beta.** Over a set of positions:
  - both return the same value;
  - with a fixed move order and tie-break, both return the same move;
  - alpha-beta never searches more positions, and searches fewer in total.
- **Forced capture.** When a capture exists, only captures are legal.
- **Free choice among captures.** With two captures available, either may
  be played.
- **Multi-jumps.** A multi-jump is one move, and it must be completed.
- **Crowning.** A man is crowned on the far row, and crowning ends the move
  mid-jump.
- **The 40-move draw.**
- **Lookahead.** The test must be one only lookahead passes:
  - the position has two captures, one of which loses the piece to an
    immediate recapture;
  - at depth 2 or more the AI takes the other;
  - at depth 1 it may not.

  A test that a capture is taken when one exists cannot fail, because
  captures are compulsory.

## Manual check

Hand `make run` to somebody who knows checkers and has not read the code.
They should play a game without being told the rules or the keys, and be able
to say, before the computer moves, which move it is about to make and why it
prefers it.
