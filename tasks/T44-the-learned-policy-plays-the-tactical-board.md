# T44 — The learned policy plays the tactical board

Size: L · Prereqs: T26 · Files: `godot/game/`, `godot/game/tactical/`, `godot/addons/ai_learning/`, `python/gameaikit/`, `godot/test/`, `Makefile`, `scripts/check_demos.py`, `README.md`, `docs/`

## Goal

The owner, choosing from T42's fun review: of all the examples, only the
skirmish and the tactical board do not feel like games, and the skirmish
should be folded into the tactical one. Two thin games become one real one.

This was always where it was headed. `BlueController` names "the learned
policy T26 makes possible" as one of blue's controllers, and `make
demo-skirmish` says "where the policy finally plays is T30's question: blue
on the tactical board". After T26 the tactical board has combat, and the
learned policy's attack-or-retreat question finally has an answer there.

**Decided with the owner (2026-10-17):** the tactical map gains **control
points** -- the skirmish's nodes, moved to the board where they matter. The
capture model, the kit's one linear regression (README), answers its own
question there: which point falls first. Kept, not dropped.

## Steps

1. **Control points.** Two or three on the tactical map -- for instance the
   bridge and one on each bank -- each paying its holder income at the start
   of its turn, as cities do in Advance Wars. Holding is T41's rule: a unit
   on the point and no enemy beside it. Where they go and what they pay is
   decided here and written down with why; the map stays the same turned
   half round.
2. **A `LearnedBlue` controller.** The combat model decides attack or
   retreat against red's pieces (T26 gives the attack); the capture model
   ranks the points; walking otherwise goes at red's workshop as the rules
   do. T41's contest rule -- a unit with no fight to weigh walks at a point
   an enemy holds -- moves with it, said as a rule, not the model.
3. **The models.** The combat dataset is the one T26 rebuilt from the
   game's rules (its step 8 names the features); this task does not retrain
   it again unless the features change, and says so if they do. The capture
   dataset is regenerated from the tactical map with points. Nothing trains
   at game time (invariant 6). Known on the way: `ai_learning` routes on
   `state.graph`, which is wrong for a wader (T11's STATUS row) -- fixed
   here, or the learned blue builds no waders and says why.
4. The tactical scene can be given either controller, rules or learned, and
   the screen says which. A key switches between them between games.
5. **The skirmish leaves.** `make demo-skirmish`, `main.tscn` and
   `SkirmishVictory` go; `check_demos.py`, the README and the docs that name
   the skirmish follow. What it taught -- a probability against a threshold,
   on screen -- is the learned controller's overlay on the tactical board.
6. Learned against rules, many seeded games: the win rates are written in
   this file, measured, not guessed.

## Acceptance

```bash
test -f godot/test/tactical_learned_blue_test.gd
make test-godot
make test-demo-overlays
make test-python
```

`tactical_learned_blue_test.gd` must hold: a point pays its holder and not
a contested one; the learned blue attacks when the combat model clears the
threshold and retreats when it does not; it walks at the point the capture
model ranks first; and learned-against-rules games, seeded, all end -- a
win or the round limit.

## Manual check

The owner plays the tactical board against the learned blue three times and
says whether it is a game now.
