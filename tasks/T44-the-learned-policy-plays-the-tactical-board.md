# T44 — The learned policy plays the tactical board

Size: L · Prereqs: T26 · Files: `godot/game/`, `godot/game/tactical/`, `godot/addons/ai_learning/`, `python/gameaikit/`, `godot/test/`

## Goal

The owner, choosing from T42's fun review: of all the examples, only the
skirmish and the tactical board do not feel like games, and the skirmish
should be folded into the tactical one. Two thin games become one real one.

This was always where it was headed. `BlueController` names "the learned
policy T26 makes possible" as one of blue's controllers, and `make
demo-skirmish` says "where the policy finally plays is T30's question: blue
on the tactical board". After T26 the tactical board has combat, and the
learned policy's attack-or-retreat question finally has an answer there.

## Steps

1. A `LearnedBlue` controller: the combat model decides attack or retreat
   against red's pieces, and walking goes at red's workshop as the rules do.
   The capture model's question -- which node falls first -- has no node on
   this board; say what replaces it, or drop it and say why.
2. The features are the tactical board's: unit types, the counter table and
   terrain. The dataset is rebuilt from T26's rules (ADR 0008) and the model
   retrained in Python. Nothing trains at game time (invariant 6).
3. The tactical scene can be given either controller, rules or learned, and
   the screen says which. A key switches between them between games.
4. The skirmish leaves the menu: `make demo-skirmish` goes, and what it
   taught -- a probability against a threshold, on screen -- is the learned
   controller's overlay on the tactical board. T41's flag rule and its
   contest rule go with the skirmish, or move with the policy if they still
   mean something; the commit says which.
5. Learned against rules, many seeded games: the win rates are written in
   this file, measured, not guessed.

## Acceptance

```bash
make test-godot
make test-demo-overlays
make test-python
```

with the learned-against-rules games as a command with an exit code, named
here when written.

## Manual check

The owner plays the tactical board against the learned blue three times and
says whether it is a game now.
